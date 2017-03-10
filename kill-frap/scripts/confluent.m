#!/usr/local/bin/octave -qf
##
## Copyright (C) 2014-2017 Carnë Draug <carandraug+dev@gmail.com>
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

yx_pixelsize = [0.1074080]; # micron
yx_scalebar = [1 10]; # height and width in microns

if (numel (argv ()) != 2)
  error ("Requires exactly 2 arguments")
endif

fpath = argv (){1};
f_out = argv (){2};

montage_size = [2 4]; # total of 8 panels (2 rows by 4 columns)

## The image file 512MB, and even though the images are uint8,
## Magick++ will read it as uint16 or uint32, it it was build with
## that quantum-depth.  There might be other things in play since even
## imfinfo() seems to make it run out of memory.  Anyway, we only need
## part of the frames and image.  So:
##
##   * pick one frame every 17 frames to get a figure showing the cell every
##     25 minutes (time interval is 90 seconds).
##
##   * start on frame 15 (last pre-bleach) and then show frame 16
##     (first post-bleach).  We could automate this by finding max
##     diff between frames.
##
##   * show only 24 frames so it fits nicely in a rectangular montage.
##
##   * The image is too large, show only a small region enough to make
##     the point.

pixel_region = {105, 429, 378, 414}; # x_init, y_init, width, height

reader = bfGetReader (fpath);
n_planes = reader.getImageCount ();
if (n_planes != 466)
  error ("we were expecting an image with 466 time points");
endif
planes_idx = [15:50:365];

img = bfGetPlane (reader, planes_idx(1), pixel_region{:});
img = postpad (img, numel (planes_idx), 0, 4);
for idx = 2:numel(planes_idx)
  img(:,:,:,idx) = bfGetPlane (reader, planes_idx(idx), pixel_region{:});
endfor

## We only want to show the nuclei moving so we will show their nuclei
## only.  Showing the grayscale image adds too much and the message,
## that cells move even when confluent, is lost.  It would require
## that we explain what half nuclear FRAP is and why we tried to do
## it.
##
## So smooth the image with gaussian, then threshold.

for i=1:size(img, 4)
  img(:,:,:,i) = imfilter (img(:,:,:,i), fspecial ("gaussian"));
endfor
bw = im2bw (img, graythresh (img, "intermodes"));
bw = imfill (bw, ones (3), "holes");
bw = bwareaopen (bw, 100, ones (3));
bw = imclose (bw, strel ("disk", 1, 0));
bw = imfill (bw, ones (3), "holes");

## Add a scalebar only to the pre bleach frames, top left corner.
bar_length = round (yx_scalebar ./ yx_pixelsize); # in pixels
bar_color = getrangefromclass (img)(1);
bw(10:10+bar_length(1), 30:30+bar_length(2), :, 1) = bar_color;

mont_img = montage_cdata (bw,
  "Size", montage_size,
  "MarginWidth", 10
);

imwrite (mont_img, f_out);
