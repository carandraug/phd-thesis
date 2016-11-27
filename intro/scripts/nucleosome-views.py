#!/usr/bin/python
# -*- coding: utf-8 -*-

## Copyright (C) 2016 Carnë Draug
##
## Sapphire is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## Sapphire is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, see <http://www.gnu.org/licenses/>.

import sys

def setup_2cv5():
  ## selections for 2cv5 pdb
  cmd.select("H2A_top",     "chain C")
  cmd.select("H2B_top",     "chain D")

  cmd.select("H2A_bottom",  "chain G")
  cmd.select("H2B_bottom",  "chain H")

  cmd.select("H3_right",    "chain A")
  cmd.select("H4_right",    "chain B")

  cmd.select("H3_left",     "chain E")
  cmd.select("H4_left",     "chain F")

  cmd.select("H2A", "H2A_top or H2A_bottom")
  cmd.select("H2B", "H2B_top or H2B_bottom")
  cmd.select("H3",  "H3_left or H3_right")
  cmd.select("H4",  "H4_left or H4_right")
  cmd.select("DNA", "chain I or chain J")

  ## Andrew's palette (CA = alpha carbon)
  cmd.color("cyan",   "H2A and name CA")
  cmd.color("gray",   "H2B and name CA")
  cmd.color("yellow", "H3 and name CA")
  cmd.color("blue",   "H4 and name CA")


## We want the view of H2A, H2B, and the H2A-H2B dimers to be
## exactly the same.  This allow us to place them side by side
## and the dimer, and see how they fit on one another.
def set_H2A_H2B_view():
  cmd.set_view('''
      -0.586763382,   -0.776555598,    0.229342759,\
       0.181445614,    0.149943516,    0.971866965,\
      -0.789109588,    0.611896336,    0.052913163,\
       0.006812718,   -0.000527412, -183.440139771,\
      30.896894455,   19.665111542,   57.929908752,\
    -502.546875000,  869.908813477,  -20.000000000''')
  cmd.ray(300, 500)

def set_H3_H4_view():
  cmd.set_view('''
       0.839876473,   -0.352466851,    0.412677944,\
       0.326860875,   -0.278449327,   -0.903084040,\
       0.433210075,    0.893399477,   -0.118660636,\
      -0.003059018,   -0.001732945, -222.018493652,\
       3.171439171,   25.884944916,   32.959381104,\
    -163.193908691,  607.508605957,  -20.000000000''')
  cmd.ray(300, 500)

def set_nucleosome_top_view():
  cmd.rotate('x', angle=90)
  cmd.translate([0, -4, 0])
  cmd.move('z', -5)
  cmd.ray(1000, 1000)

def set_nucleosome_side_view():
  cmd.rotate('z', angle=-90)
  cmd.rotate('x', angle=180)
  cmd.ray(600, 1000)

def set_octamer_side_view():
  cmd.rotate('z', angle=-90)
  cmd.rotate('x', angle=180)
  cmd.ray(600, 1000)

def set_tetramer_side_view():
  cmd.rotate('z', angle=-90)
  cmd.rotate('x', angle=180)
  cmd.ray(600, 1000)


def draw_H2A():
  cmd.show("cartoon", "H2A_bottom")
  set_H2A_H2B_view()

def draw_H2B():
  cmd.show("cartoon", "H2B_bottom")
  set_H2A_H2B_view()

def draw_H2A_H2B_dimer():
  cmd.show("cartoon", "H2A_bottom")
  cmd.show("cartoon", "H2B_bottom")
  set_H2A_H2B_view()

def draw_H3():
  cmd.show("cartoon", "H3_left")
  set_H3_H4_view()

def draw_H4():
  cmd.show("cartoon", "H4_left")
  set_H3_H4_view()

def draw_H3_H4_dimer():
  cmd.show("cartoon", "H3_left")
  cmd.show("cartoon", "H4_left")
  set_H3_H4_view()

def draw_nucleosome_top():
  cmd.show("cartoon", "all")
  set_nucleosome_top_view()

def draw_nucleosome_side():
  cmd.show("cartoon", "all")
  set_nucleosome_side_view()

def draw_octamer_side():
  cmd.show("cartoon", "H2A or H2B or H3 or H4")
  set_nucleosome_side_view()

def draw_tetramer_side():
  cmd.show("cartoon", "H3 or H4")
  set_nucleosome_side_view()


def main(pdb_fpath, view_name, png_fpath):
  cmd.load(pdb_fpath)

  ## Maybe overkill but I guess this could be used to support multiple
  ## structures.  Not really our case though.
  setups = {'2cv5' : setup_2cv5}
  for obj_name in cmd.get_names("objects"):
    setup_func = setups.get(obj_name)
    if not setup_func:
      sys.exit('unknown object with name %s', obj_name)
    else:
      setup_func()

  cmd.hide("all")

  cmd.set('cartoon_cylindrical_helices', '1') # solid cylinders instead of ribbon helices
  cmd.set('ray_opaque_background', 0) # transparent background
  cmd.set('ray_trace_color', 'black') # outline colour
  cmd.set('ray_trace_mode', 3) # 3 = quantized color + black outline

  views = {
    'H2A' : draw_H2A,
    'H2B' : draw_H2B,
    'H3'  : draw_H3,
    'H4'  : draw_H4,
    'H2A-H2B' : draw_H2A_H2B_dimer,
    'H3-H4'   : draw_H3_H4_dimer,
    'nucleosome-top' : draw_nucleosome_top,
    'nucleosome-side' : draw_nucleosome_side,
    'octamer-side' : draw_octamer_side,
    'tetramer-side' : draw_tetramer_side,
  }
  view_func = views.get(view_name)
  if not setup_func:
    sys.exit('unknown view with name %s', view_name)
  else:
    view_func()

  cmd.png(png_fpath)


if __name__ == "pymol":
  main(*sys.argv[1:])
