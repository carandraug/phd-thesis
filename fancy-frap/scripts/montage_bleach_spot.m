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
pkg load statistics;

pkg load imagej;
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

  ## But swap them so that Z is the third and time is the fourth.  This
  ## gives faster access to data and less awkward singleton dimensions
  ## for our needs.
  img = permute (img, [1 2 4 5 3]);
endfunction

function [img] = read_lsm_fancy_frap (pre_fpath, post_fpath, post_series_fpath)

  [~, ~, ~, series_idx] = regexp (pre_fpath, '(?<=position=)\d+(?=,)');
  series_idx = str2double (series_idx{1});

  ## Read pre bleach
  reader = bfGetReader (pre_fpath);
  pre_img = read_lsm_series (reader);

  ## Read post bleach (t = 0)
  reader = bfGetReader (post_fpath);
  post_img = read_lsm_series (reader);

  ## Read post bleach time series (t = 1 .. N)
  reader = bfGetReader (post_series_fpath);
  reader.setSeries (series_idx -1);
  post_series_img = read_lsm_series (reader);

  img = cat (4, pre_img, post_img, post_series_img);
endfunction

function bw = im2bw_yen (img)
  bw = im2bw (img, ij_threshold (img, "Yen"));
endfunction

## Computes the transformation structure to be used in the pre bleach
## image so that t registers with the post bleach.  PRE and POST should
## be the channel that is being bleached (because it has more reference
## points) but then can be used on the channel being activated.
function [tform] = pre_bleach_transform_structure (pre, post)
  ## cp2tform and tformfwd only work woth 2 dimensional images. That's ok
  ## for us because the time interval between pre and post bleach is less
  ## than 1 minute and there's little Z movement in that scale.  So we get
  ## the Z slice with the most reference points, and use the transformation
  ## from it on the other slices.

  nZ = size (pre, 3);

  thresh = ij_threshold (pre, "Yen");
  pre_bw = im2bw (pre, thresh);

  label = bwlabeln (pre_bw, 8);
  n_obj = cellfun (@(x) numel (unique (x)), cellslices (label, 1:nZ, 1:nZ, 3));
  [~, z_idx] = max (n_obj);

  pre_cen = cell2mat ({regionprops(pre_bw(:,:,z_idx), pre(:,:,z_idx),
                                   "WeightedCentroid").WeightedCentroid}');
  post_cen = cell2mat ({regionprops(im2bw (post(:,:,z_idx), thresh), post(:,:,z_idx),
                                    "WeightedCentroid").WeightedCentroid}');

  ## In case one of them is empty, we still need two columns.
  pre_cen = postpad (pre_cen, 2, 0, 2);
  post_cen = postpad (post_cen, 2, 0, 2);

  dists = pdist2 (pre_cen, post_cen);

  ## Hopefully this wouldn't happen but if one region dissappears
  ## (or a new one appears), between pre and post bleach, we need
  ## to remove the extra ones.  We do this by pairing them up to
  ## the closest ones, and then leaving only the closest pair.

  if (rows (dists) != columns (dists))

    if (rows (dists) > columns (dists))
      [min_dists, col_pairs] = min (dists, [], 2);
      min_dist_pairs = accumarray (col_pairs(:), min_dists , [], @min);

      [~, rows_to_keep] = max (min_dist_pairs' == min_dists, [], 1);
      ## remove rows without a pair at all (NaNs from accumarray)
      rows_to_keep(isnan (min_dist_pairs')) = [];

      cols_to_keep = unique (col_pairs);

    elseif (rows (dists) < columns (dists))
      [min_dists, row_pairs] = min (dists, [], 1);
      min_dist_pairs = accumarray (row_pairs(:), min_dists , [], @min);

      [~, cols_to_keep] = max (min_dist_pairs == min_dists, [], 2);
      ## remove cols without a pair at all (NaNs from accumarray)
      cols_to_keep(isnan (min_dist_pairs)) = [];

      rows_to_keep = unique (row_pairs);
    endif

    dists = dists(rows_to_keep, cols_to_keep);
    pre_cen = pre_cen(rows_to_keep, :);
    post_cen = post_cen(cols_to_keep, :);
  endif

  ## Place closest centroids pairs on same order (pre and post)
  [~, post_cen_order] = min (dists, [], 1);
  post_cen = post_cen(post_cen_order, :);

  tform = cp2tform (post_cen, pre_cen, "nonreflective similarity");
endfunction


function bw_activated = find_bleach_spot (img)

  activated_c = img(:,:,:,:,1);
  bleached_c = img(:,:,:,:,2);

  ## LSM data is ridiculously noisy.  So we appy a gaussian filter
  ## which helps to find the features and registration.  Not using
  ## it for the actual measurements.
  sigma = 2;
  g = fspecial ("gaussian", 2 * ceil (2*sigma) +1, sigma);

  cls = class (img);
  pre_bleaching = cast (convn (bleached_c(:,:,:,1), g, "same"), cls);
  post_bleaching = cast (convn (bleached_c(:,:,:,2), g, "same"), cls);
  pre_activation = cast (convn (activated_c(:,:,:,1), g, "same"), cls);
  post_activation = cast (convn (activated_c(:,:,:,2), g, "same"), cls);

  ## On the channel being activated, the signal of PAGFP is too weak
  ## that changes in the cytoplasm are picked up sometimes.  On the
  ## channel being bleached, the change on mRuby is also too small.
  ## So we use the difference from both channels.

  ## Use channel being bleached to get the transformation, since that has
  ## more reference points.
  tform = pre_bleach_transform_structure (pre_bleaching, post_bleaching);

  ## Nice! imtransform() works with 3D images.  It is a bit odd though,
  ## how size only takes the first 2 dimensions.
  reg_pre_activation = imtransform (pre_activation, tform, "bicubic",
                                    "size", size (pre_activation)(1:2));

  reg_pre_bleaching = imtransform (pre_bleaching, tform, "bicubic",
                                   "size", size (pre_bleaching)(1:2));

  ratio_frap = (im2double (post_activation - reg_pre_activation)
                .* im2double (reg_pre_bleaching - post_bleaching));
  bw_ratio_frap = im2bw_yen (ratio_frap);

  ## Because there's always a bit of stuff, noise, we pick the largest object.
  bw_activated = bwareafilt (bw_ratio_frap, 1);

endfunction

function [montage_img] = create_montage (activation, bleaching, bw_spot)

  ## Montage size is 5 columns.  Each column is a Z stack of:
  ##  1) pre bleach of activation channel
  ##  2) post bleach of activation channel
  ##  3) mask of identified spot
  ##  4) pre-bleach of bleaching channel
  ##  5) post-bleach of bleaching channel

  m_log = cat (4, activation, im2uint8 (bw_spot), bleaching);
  m_log = permute (m_log, [1 2 4 3]);
  m_log = reshape (m_log, [size(m_log)(1:2) 1 prod(size(m_log)(3:end))]);

  h = figure ("visible", "off");
  mh = montage (imadjust (m_log, stretchlim (m_log, 0)),
                "Size", [size(bw_spot)(3) 5]);

  montage_img = get (mh, "cdata");
endfunction

function [rv] = main (pre_fpath, post_fpath, series_fpath, montage_fpath)

  if (nargin != 4)
    error ("usage: PRE_FPATH POST_FPATH SERIES_FPATH MONTAGE_FPATH");
  endif

  [img] = read_lsm_fancy_frap (pre_fpath, post_fpath, series_fpath);
  bw_spot = find_bleach_spot (img);

  [montage_img] = create_montage (img(:,:,:,1:2,1), img(:,:,:,1:2,2), bw_spot);
  imwrite (montage_img, montage_fpath);

  rv = 0;
  return
endfunction

main (argv (){:});
