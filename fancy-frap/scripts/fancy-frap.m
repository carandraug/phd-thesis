#!/usr/local/bin/octave -qf
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

## Do not use this code for anything other than producing the figures for
## the thesis. The core of this script can be found at:
## https://github.com/af-lab/scripts/blob/master/microscopy/CropReg.m

pkg load image;
pkg load bioformats;
javaMethod ('enableLogging', 'loci.common.DebugTools', 'ERROR');

function [img] = read_lsm_series (r)
  n_planes = r.getImageCount ();
  img = bfGetPlane (r, 1);
  img = postpad (img, n_planes, 0, 4);
  for p_idx = 2:n_planes
    img(:,:,p_idx) = bfGetPlane (r, p_idx);
  endfor

  ## Dimensions in the 3rd dimension are in the order [channel, z, time]
  img = reshape (img, [size(img)(1:2) r.getSizeC() r.getSizeZ() r.getSizeT()]);
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

  img = cat (5, pre_img, post_img, post_series_img);

  ##
  ## Figure out time intervals
  ##
  n_t = size (img, 5);
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
  n_planes_by_t = prod (size (img)([3 4]));
  m = reader.getMetadataStore ();
  for t_idx = 4:n_t
    plane_idx = n_planes_by_t * (t_idx - 3);
    t(t_idx) = m.getPlaneDeltaT (series_idx, plane_idx).value ();
    ## Do not forget to add the time from when we started
    t(t_idx) += t(3);
  endfor

endfunction

function main (pre_fpath, post_fpath, post_series_fpath)

  if (nargin != 3)
    error ("usage: pre_fpath post_fpath post_series_path");
  endif

  [img, t_deltas] = read_lsm_fancy_frap (pre_fpath, post_fpath,
                                         post_series_fpath);


endfunction


main (argv (){:});
