#!/usr/bin/env python
# -*- coding: utf-8 -*-

## Copyright (C) 2017 Carnë Draug <carandraug+dev@gmail.com>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Ideally we would identify the locations α strands automatically
## from the pdf file but I couldn't figure out how to do that.  So the
## numbers below are copied from the figures on RCSB PDB website.

class SecondaryStructure(object):
    def __init__(self, length, hfd_helices, other_helices,color):
        self.length = length
        self.hfd_helices = hfd_helices
        self.other_helices = other_helices
        self.color = color

    def midpoint(self):
        """From start of sructure to center of alpha2 helix.
        """
        a2 = self.hfd_helices['2']
        return ((a2[0] -1) + ((a2[1] - a2[0] -1) / 2.0))

## H2A (total length = 130):
##  α helix     18 --  22
##  α helix     28 --  36  α1
##  β strand    43 --  44
##  α helix     47 --  73  α2
##  β strand    78 --  79
##  α helix     81 --  89  α3
##  α helix     92 --  97
##  β strand   101 -- 103
##  α helix    114 -- 116
h2a = SecondaryStructure(130, {'1' : (28, 36), '2' : (47, 73),
                               '3' : (81, 89)},
                         [(18, 22), (92, 97), (114, 116)],
                         color="cyan")

## H2B (total length = 126):
##  α helix     39 --  49  α1
##  β strand    54 --  55
##  α helix     57 --  84  α2
##  β strand    89 --  90
##  α helix     92 -- 102  α3
##  α helix    105 -- 123
h2b = SecondaryStructure(126, {'1' : (39, 49), '2' : (57, 84),
                               '3' : (92, 102)},
                         [(105, 123)],
                         color="gray")

## H3 (total length = 136):
##  β strand     3 --   6
##  β strand    20 --  21
##  α helix     46 --  57
##  α helix     65 --  74  α1
##  β strand    84 --  85
##  α helix     87 -- 114  α2
##  β strand   119 -- 120
##  α helix    122 -- 132  α3
h3 = SecondaryStructure(136, {'1' : (65, 74), '2' : (87, 114),
                              '3' : (122, 132)},
                        [(46, 57)],
                        color="yellow")

## H4 (total length = 103):
##  β strand     5 --   6
##  β strand    21 --  22
##  α helix     27 --  29
##  α helix     32 --  41  α1
##  β strand    46 --  47
##  α helix     51 --  76  α2
##  β strand    81 --  82
##  α helix     84 --  93  α3
##  β strand    97 --  99
h4 = SecondaryStructure(103, {'1' : (32, 41), '2' : (51, 76),
                              '3' : (84, 93)},
                        [(27, 29)],
                        color="blue")

def figure_lengths(histones):
    left_side = max([h.midpoint() for h in histones])
    right_side = max([h.length - h.midpoint() for h in histones])
    return left_side, right_side

def main():
    histones = [h4, h3, h2b, h2a]
    left_side, right_side = figure_lengths(histones)
    figure_length = left_side + right_side
    print "\\begin{tikzpicture}[scale=\\textwidth/%.1fcm]" % figure_length

    ## We specify both text height and text depth so that the baseline
    ## of all labels align properly.
    print "\\tikzset{label/.style={font=\\scriptsize,text height=1.5ex,text depth=.25ex}}"

    ## We draw rectangles below the text node instead of specifying
    ## minimum width and fill on the node, because the actual width
    ## shows up wrong (slightly smaller) than drawing a rectangle.
    ## We also specify the height of the rectangles and the space
    ## between histones.  Not sure how to go around and make it all
    ## relative to something.
    box_height = 5
    box_half = box_height / 2.0
    line_spacing = 1
    y = 0
    for h in histones:
        offset = left_side - h.midpoint()
        print ("\\draw (%.1f, %i) -- (%.1f, %i);"
               % (offset, y, offset + h.length, y))
        for num, pos in h.hfd_helices.items():
            box_x_center = offset + pos[0] + ((pos[1] - pos[0]) / 2.0)
            print ("\\fill[color=%s] (%.1f, %.1f) rectangle (%.1f, %.1f);"
                   % (h.color, pos[0] + offset, y - box_half, pos[1] + offset,
                      y + box_half))
            print ("\\node at (%.1f, %.1f) [label] {\\textalpha%s};"
                   % (box_x_center, y, num))
        y += box_height + line_spacing

    print "\\end{tikzpicture}"

if __name__ == "__main__":
    main()
