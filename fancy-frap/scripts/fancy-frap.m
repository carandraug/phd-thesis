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
    t(t_idx) = m.getPlaneDeltaT (series_idx, plane_idx).value ();
    ## Do not forget to add the time from when we started
    t(t_idx) += t(3);
  endfor

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

  dists = pdist2 (pre_cen, post_cen);

  ## Hopefully this wouldn't happen but if one region dissappears
  ## (or a new one appears), between pre and post bleach, we need
  ## to remove the extra ones.  We do this by pairing them up to
  ## the closest ones, and then leaving only the closest pair.

  if (rows (dists) > columns (dists))
    [min_dists, pairs] = min (dists, [], 2);
    min_dist_pairs = accumarray (pairs(:), min_dists , [], @min);
    [~, rows_to_keep] = max (min_dist_pairs' == min_dists, [], 1);

    dists = dists(rows_to_keep, :);
    pre_cen = pre_cen(rows_to_keep, :);

  elseif (rows (dists) < columns (dists))
    [min_dists, pairs] = min (dists, [], 1);
    min_dist_pairs = accumarray (pairs(:), min_dists , [], @min);
    [~, cols_to_keep] = max (min_dist_pairs == min_dists, [], 2);

    dists = dists(:, cols_to_keep);
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


  ## Use channel being bleached to get the transformation, and then
  ## transform the channel being activated.  The reason is that the
  ## channel being bleached has loads of other stuff being bleached
  ## due to the imaging which will appear in "pre-post".  On the other
  ## hand, the channel being activated is "post-pre" so we really only
  ## get the bleach spot.
  tform = pre_bleach_transform_structure (pre_bleaching, post_bleaching);

  ## Nice! imtransform() works with 3D images.  It is a bit odd though,
  ## how size only takes the first 2 dimensions.
  reg_pre_activation = imtransform (pre_activation, tform, "bicubic",
                                    "size", size (pre_activation)(1:2));

  ## In theory we should only get the bleach spot.  However, it seems
  ## there's crap, big blobs of crap, on the cytoplasm that fluorescece
  ## on the green channel and move quite fast.  This usually means that
  ## the cells are not very happy (no shit! They've been in PBS and in
  ## the microscope for a while now!).  The point though is that just
  ## subtracting the images will find these blobs.

  ## While there is movement of those blobs of crap, much faster than the
  ## rest which we use for registration, there's still a temporal overlap
  ## of theose objects.  So we can just remove elements that have an overlap
  ## object on the pre bleach.

  bw_activation_diff = im2bw_yen (post_activation - reg_pre_activation);
  marker = (im2bw_yen (reg_pre_activation) & bw_activation_diff);
  bw_activated = (bw_activation_diff & ! imreconstruct (marker, bw_activation_diff));

  ## Just in case there's something left, there's always a bit of speckle
  ## noise, we pick the largest object.
  bw_activated = bwareafilt (bw_activated, 1);

endfunction

function main (pre_fpath, post_fpath, post_series_fpath)

  if (nargin != 3)
    error ("usage: pre_fpath post_fpath post_series_path");
  endif

  [img, t_deltas] = read_lsm_fancy_frap (pre_fpath, post_fpath,
                                         post_series_fpath);

  bw_spot = find_bleach_spot (img);


endfunction

main (argv (){:});
