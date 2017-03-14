#!/usr/local/bin/octave -qf
##
## Copyright (C) 2014-2016 Carnë Draug <carandraug+dev@gmail.com>
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

yx_pixelsize = [0.0644]; # micron
yx_scalebar = [10 1]; # height and width in microns

montage_size = [2 5];

if (numel (argv ()) != 2)
  error ("Requires exactly 2 arguments")
endif

img = imread_dv (argv (){1});

## the image has been deconvolved so we need to trim the borders
img = img(31:end-30,31:end-30,:,:);

## the image is mostly black, this is the only cell, so we crop it
img = imcrop (img, [150 51 360 500]);

## Scale to the min and max of the whole scale for display.
img = imadjust (img, stretchlim (img(:), 0));

## Add a scalebar only to the pre bleach frames, top left corner.
bar_length = round (yx_scalebar ./ yx_pixelsize); # in pixels
bar_color = getrangefromclass (img)(2);
img(25:25+bar_length(1), 25:25+bar_length(2), :, 1) = bar_color;

mont_img = montage_cdata (img,
  "Size", montage_size,
  "MarginWidth", 10,
  "Indices", 1:10
);
imwrite (mont_img, argv (){2});
