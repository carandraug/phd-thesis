#!/usr/local/bin/octave
##
## Copyright (C) 2016 Carnë Draug <carandraug+dev@gmail.com>
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, see <http://www.gnu.org/licenses/>.

pkg load image;

pkg load bioformats;
javaMethod ('enableLogging', 'loci.common.DebugTools', 'ERROR');

function points = read_points (coord_fpath)
  points = csvread (coord_fpath, 1, 0);
  if (columns (points) != 4)
    error ("read_points: expect csv file with points to have 4 columns");
  endif
  ## swap x and y coordinates so we end with [rows columns z time]
  points(:, [2 1]) = points(:, [1 2]);
  ## we need integers for indexing.
  points = round (points);
endfunction

function [img] = read_lsm_series (r)
  n_planes = r.getImageCount ();
  img = bfGetPlane (r, 1);
  img = postpad (img, n_planes, 0, 4);
  for p_idx = 2:n_planes
    img(:,:,p_idx) = bfGetPlane (r, p_idx);
  endfor

  ## Dimensions in the 3rd dimension are in the order [channel, z, time]
  img = reshape (img, [size(img)(1:2) r.getSizeC() r.getSizeZ() r.getSizeT()]);

  ## But swap them so that Z is the third and time is the fourth.  This
  ## gives faster access to data and less awkward singleton dimensions
  ## for our needs.
  img = permute (img, [1 2 4 5 3]);
endfunction

function [img, t] = read_lsm_fancy_frap (pre_fpath, post_fpath, post_series_fpath)

  [~, ~, ~, series_idx] = regexp (pre_fpath, '(?<=position=)\d+(?=,)');
  series_idx = str2double (series_idx{1});
  timestamps = {};

  ## Read pre bleach
  reader = bfGetReader (pre_fpath);
  pre_img = read_lsm_series (reader);
  timestamps(end+1) = reader.getMetadataStore ().getImageAcquisitionDate (0).asInstant ();

  ## Read post bleach (t = 0)
  reader = bfGetReader (post_fpath);
  post_img = read_lsm_series (reader);
  timestamps(end+1) = reader.getMetadataStore ().getImageAcquisitionDate (0).asInstant ();

  ## Read post bleach time series (t = 1 .. N)
  reader = bfGetReader (post_series_fpath);
  reader.setSeries (series_idx -1);
  post_series_img = read_lsm_series (reader);
  timestamps(end+1) = reader.getMetadataStore ().getImageAcquisitionDate (0).asInstant ();

  img = cat (4, pre_img, post_img, post_series_img);

  ##
  ## Figure out time intervals
  ##
  n_t = size (img, 4);
  t = zeros (n_t, 1);

  ## For the time difference between pre, post and t1, we don't have time
  ## interval planes, we only have acquisition time (start of experiment).
  t(2) = javaObject ("org.joda.time.Duration", timestamps{1},
                     timestamps{2}).getStandardSeconds ();
  t(3) = javaObject ("org.joda.time.Duration", timestamps{2},
                     timestamps{3}).getStandardSeconds ();

  ## Then we have the time delta for each plane since t=1.  Despite the name,
  ## all planes (all channels and z stacks) for a single point, seem to have
  ## the same delta T.  But that does make it easier on us.
  n_planes_by_t = prod (size (img)([3 5]));
  m = reader.getMetadataStore ();
  for t_idx = 4:n_t
    plane_idx = n_planes_by_t * (t_idx - 3);
    t(t_idx) = m.getPlaneDeltaT (series_idx -1, plane_idx).value ();
    ## Do not forget to add the time from when we started
    t(t_idx) += t(3);
  endfor

endfunction

function img = denoise (img)
  ## LSM data is ridiculously noisy.  We use nothing fancy, a simple
  ## gaussian blurring is enough.
  sigma = 2;
  g = fspecial ("gaussian", 2 * ceil (2*sigma) +1, sigma);

  cls = class (img);
  img = cast (convn (img, g, "same"), cls);
endfunction

## We are finding the bleach area by watershed on the pre-bleach image.
## Return a 2d array of subscript offsets (1 point per row) for the pre bleach
## time point.
function [bleach_offsets] = find_bleach_area (img, coords)
  pre_bl = denoise (img(:,:,:,1,2));
  wt = watershed (imcomplement (pre_bl));

  first_point_idx = sub2ind (size (pre_bl), coords(1,1), coords(1,2), coords(1,3));
  label = wt(first_point_idx);

  ## We would have used bwselect if it supported ND
  marker = false (size (wt));
  marker(first_point_idx) = true;
  bleach_spot = imreconstruct (marker, wt == label, 8);

  ## watershed() returns a segmented image with watershed lines that
  ## reasonably split the plateus regions where different catchment basins
  ## come together.  However, we don't want any plateu region at all.  So
  ## we remove the minimun value to get only the catchment basin.
  bleach_spot = (pre_bl != min (pre_bl(bleach_spot)(:))) & bleach_spot;

  [r, c, z] = ind2sub (size (pre_bl), find (bleach_spot));
  bleach_offsets_2d = [r c] .- coords(1, 1:2);
  bleach_offsets = [bleach_offsets_2d zeros(rows (bleach_offsets_2d), 1)];
endfunction

## Returns cell array with linear indices for each time point.
function [foci_ind] = bleach_area_idxs (dims, coords, bleach_offsets)
  ## Cell array with subscript indices for each time point.
  ## Created from a 3D array of offsets to points of bleach area.  Rows
  ## are points, columns are dimensions, and 3rd dimension is (was) time.
  foci_sub = permute (coords(:,1:3), [3 2 1]) .+ bleach_offsets;
  foci_sub = num2cell (foci_sub, [1 2]);

  ## The bleach region may go out of the image border in some cases, so
  ## remove them.  It also means that each time pint may end up with
  ## different number of pixels so we need a cell array.
  foci_ind = cell (size (foci_sub));
  for i = 1:dims(4) # should be same as numel (foci_sub)
    this_time_sub = foci_sub{i};
    out_of_range = (this_time_sub < 1) | (this_time_sub > dims(1:3));
    out_of_range_idx = any (out_of_range, 2);
    this_time_sub(out_of_range_idx, :) = [];
    time_sub = repmat (coords(i,4), rows (this_time_sub), 1);
    foci_ind{i} = sub2ind (dims(1:4), num2cell (this_time_sub, 1){:}, time_sub);
  endfor

endfunction

function [photo_recovery, photo_loss] = get_mean_intensities (img, coords)
  bleach_offsets = find_bleach_area (img, coords);
  foci_ind = bleach_area_idxs (size (img), coords, bleach_offsets);

  act_channel = img(:,:,:,:,1);
  photo_loss = cellfun (@(x) mean (act_channel(x)), foci_ind);
  bl_channel = img(:,:,:,:,2);
  photo_recovery = cellfun (@(x) mean (bl_channel(x)), foci_ind);
endfunction


function [rv] = main (coord_fpath, pre_fpath, post_fpath, series_fpath, plot_fpath)

  if (nargin != 5)
    error ("usage: plot_fraps.m COORD_FPATH PRE_FPATH POST_FPATH SERIES_FPATH PLOT_FPATH");
  endif
  [img, timestamps] = read_lsm_fancy_frap (pre_fpath, post_fpath, series_fpath);
  timestamps /= 60; # convert seconds to minutes

  coords = read_points (coord_fpath);
  np = rows (coords);

  ## remove time points and img data without data points
  timestamps = timestamps(coords(:,4));
  img = img(:,:,:,coords(:,4),:);

  [photo_recovery, photo_loss] = get_mean_intensities (img, coords);

  h = figure ("visible", "off");
  plot (timestamps(:), photo_loss(:), "-xg;photoactivated;",
        timestamps(:), photo_recovery(:), "-xr;photobleached;");

  ylabel ("Intensity (uint8)");
  xlabel ("Time (minutes)");
  box ("off");
  legend ("boxoff");

  ## Add some padding before the photoconversion.
  limits = axis ();
  axis ([limits(1)-10 limits(2:end)]);

  print (plot_fpath);

  rv = 0;
  return;
endfunction

main (argv (){:});
