#!/usr/bin/env perl
use utf8;

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

## Convert the MTrackJ files to a csv file that we can then save as data
## and handle better in Octave and Python.  We have a single track/foci
## per MTrackJ data file.

use strict;
use warnings;
use 5.010;

sub main
{
  my $fpath = shift;
  open (my $fh, "<", $fpath)
    or die "Unable to open '$fpath' for reading: $!";

  chomp (my $header = <$fh>);
  die "Not a MTrackJ data file"
    if ($header !~ m/MTrackJ 1.5.1 Data File/);

  my $n_tracks = 0;
  my $in_track = 0;

  say "x,y,z,t";
  while (my $line = <$fh>)
    {
      if ($in_track && $line =~ m/^Point (\d+) /)
        {
          die "Failed to parse point coordinates"
            if $line !~ m/Point \d+ ([0-9. ]+)$/;
          my @coordinates = split (" ", $1);

          die "Failed to find 5 dimensions in coordinates"
            if @coordinates != 5;

          ## Coordinates are x, y, z, time, channel.  We do not care
          ## about channel, so remove that.
          say join (",", @coordinates[0..3]);

        }
      elsif ($line =~ m/^Track (\d+) /)
        {
          $in_track = 1;
          $n_tracks++;
          die "More than one track found in '$fpath'"
            if ($1 != 1 || $n_tracks > 1);
        }
    }

  return 0;
}

exit (main (@ARGV));
