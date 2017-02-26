Data sets used for the results
==============================

This directory is mostly empty due to space constraints. Some of the images
used to generate the results in the thesis are above 600MB in size, and even
the smaller are still too commit to the repository.

Ideally, we would have those images in a public accessible database and
download them during build time. However, HEAnet will be pulling the plug on
our omero server so that won't work. In case of emergency, those files can
be found in the 4big under the `carandraug` directory.

So, for a correct build of the thesis, the following files will needed to
be copied into the `data` directory (the hash in front of their names is the
corresponding md5sum):

* `Image114.lsm` (0a616796e0fbed9cd6783087947c60dc) which will be in a
directory named `2010-04-29 H3 T45E (no cell cycle check) Laser 5 Scan 30ms Interval 0msc Frames 2500 Diameter 20`.
This image will be used to create the FRAPINATOR plots.
