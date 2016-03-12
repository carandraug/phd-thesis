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

function [img] = read_lsm_fancy_frap (pre_fpath, post_fpath, series_fpath)
  [~, ~, ~, series_idx] = regexp (pre_fpath, '(?<=position=)\d+(?=,)');
  series_idx = str2double (series_idx{1});

  reader = bfGetReader (pre_fpath);
  pre_img = read_lsm_series (reader);

  reader = bfGetReader (post_fpath);
  post_img = read_lsm_series (reader);

  reader = bfGetReader (series_fpath);
  reader.setSeries (series_idx -1);
  series_img = read_lsm_series (reader);

  img = cat (5, pre_img, post_img, series_img);
endfunction

function [rv] = main (pre_fpath, post_fpath, series_fpath, out_fpath)
  if (nargin != 4)
    error ("usage: PRE_FPATH POST_FPATH SERIES_FPATH OUT_FPATH");
  endif
  [img] = read_lsm_fancy_frap (pre_fpath, post_fpath, series_fpath);

  sz = size (img);
  img = reshape (img, [sz(1:2) 1 prod(sz(3:end))]);
  imwrite (img, out_fpath);

  rv = 0;
  return;
endfunction

main (argv (){:});
