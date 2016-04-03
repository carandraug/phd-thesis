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

function [rv] = main (coord_fpath, pre_fpath, post_fpath, series_fpath, plot_fpath)

  if (nargin != 5)
    error ("usage: plot_fraps.m COORD_FPATH PRE_FPATH POST_FPATH SERIES_FPATH PLOT_FPATH");
  endif
  [img, timestamps] = read_lsm_fancy_frap (pre_fpath, post_fpath, series_fpath);

  coords = read_points (coord_fpath);
  np = rows (coords);

  timestamps = timestamps(coords(:,4));   # remove time points without data points
  timestamps /= 60; # convert seconds to minutes


  img = denoise (img);

  act = img(:,:,:,:,1);
  bl = img(:,:,:,:,2);

  act_coords = sub2ind (size (img), num2cell (coords, 1){:});
  bl_coords = sub2ind (size (img), num2cell (coords, 1){:});

  h = figure ("visible", "off");
  plot (timestamps, act(act_coords), "-xg;photoactivated;",
        timestamps, bl(bl_coords), "-xr;photobleached;");

  ylabel ("Intensity (uint8)");
  xlabel ("Time (minutes)");
  box ("off");
  legend ("boxoff");

  limits = axis ();
  axis ([limits(1)-10 limits(2:end)]); # some padding before the photoconversion


  print (plot_fpath);

  rv = 0;
  return;
endfunction

main (argv (){:});
