#!/bin/sh

## This script helps bootstrap the project.  It downloads the data
## required before calling SCons.
##
## Copyright (C) 2017 David Miguel Susano Pinto
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the
## Free Software Foundation; either version 3 of the License, or (at your
## option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; see the file COPYING.  If not, see
## <http://www.gnu.org/licenses/>.

set -e # do not ignore failures

zenodo_url()
{
  printf "https://zenodo.org/record/377035/files/$1"
}

##
## kill-frap, we do not need to check the md5sum since scons will do that.
##

KILLFRAP_FILES=" \
  test8_R3D.dv \
  New_L1_Sum.lsm \
  Horse_confluent_H2B-GFP_01_08_R3D_D3D.dv \
  HeLa_H3_1A5_01_6_R3D_D3D.dv \
  HeLa_H2B-PAGFP_01_12_R3D_D3D.dv \
"
for FILE in $KILLFRAP_FILES; do
  wget $(zenodo_url $FILE) \
    -O "kill-frap/data/$FILE"
done

## Do not use spaces on filenames ever again.
wget $(zenodo_url H4%%20R45H_L3_Sum.lsm) \
  -O "kill-frap/data/H4 R45H_L3_Sum.lsm"


##
## software chapter
##

SOFTWARE_FILES=" \
  Location8Cell1.lsm \
  Image114.lsm \
"
for FILE in $SOFTWARE_FILES; do
  wget $(zenodo_url $FILE) \
    -O "software/data/$FILE"
done


##
## For the histone sequences, we need to check the md5sum ourselves
##

wget $(zenodo_url sequences-homo-sapiens.tar.gz) \
  -O sequences-homo-sapiens.tar.gz

MD5=$(md5sum sequences-homo-sapiens.tar.gz | cut -d" " -f1)
if [ $MD5 != "8d1c4843f07f85bb58d01f813c477c1b" ]; then
  echo "md5sum of sequences file do not match" 1>&2
  exit 1
fi

wget $(zenodo_url sequences-mus-musculus.tar.gz) \
  -O sequences-mus-musculus.tar.gz

MD5=$(md5sum sequences-mus-musculus.tar.gz | cut -d" " -f1)
if [ $MD5 != "3d5cde70647cb69bcdd67a9c9f930a4a" ]; then
  echo "md5sum of sequences file do not match" 1>&2
  exit 1
fi

tar -xzf sequences-mus-musculus.tar.gz
tar -xzf sequences-homo-sapiens.tar.gz


##
## Methods.  Lesson learned, do not use spaces again for filenames
##

wget $(zenodo_url clone%%20check%%20H2B%%202P3_Tube_001.fcs) \
  -O "methods/data/clone check H2B 2P3_Tube_001.fcs"
wget $(zenodo_url H2B%%2011_Tube_001.fcs) \
  -O "methods/data/H2B 11_Tube_001.fcs"
wget $(zenodo_url WT_Tube_001.fcs) \
  -O "methods/data/WT_Tube_001.fcs"


##
## Check if SCons is available and then exit with a nice message
##

if ! command -v scons > /dev/null; then
  echo "SCons is not installed but will be needed for the build"
fi

echo "bootstrap done.  Now you can run 'scons'."
