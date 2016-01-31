#!/usr/bin/env python
# -*- coding: utf-8 -*-

## Copyright (C) 2011-2016 Carnë Draug <carandraug+dev@gmail.com>
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License as
## published by the Free Software Foundation; either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
## General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, see
## <http:##www.gnu.org/licenses/>.

"""SCons tool for scripting languages
"""

import os
import os.path
import modulefinder

import SCons.Script
import SCons.Errors


##
## Scanner
##

def python_scanner(node, env, path=[]):
  """This python scanner has several issues:

    1. it does not work when using SConscript on subdirectories.  This
      is because PYTHONPATH is meant to be used from the root of the
      project because that's when the Builder works.  However, the
      scanner runs on the subdirectory so the path may not actually
      exist.
    2. PYTHONPATH needs to be a colo separate list for python but here
      we need a list of paths.
  """
  finder = modulefinder.ModuleFinder(path=[env['ENV']['PYTHONPATH']])
  finder.run_script(str(node))

  deps = []
  for m in finder.modules.values():
    m_path = m.__file__
    if m_path:
      deps.append(m_path)

  return env.File(deps)


def python_output(env, script, source, target, args=[]):
  script = env.File(script)
  c = env.Command(target, source, SCRIPT=script, ARGS=args,
                  action='$PYTHON $SCRIPT $SOURCE $ARGS > $TARGET')
  env.Depends(c, [script, python_scanner(script, env)])
  return c


def generate(env):
  vars = SCons.Script.Variables()
  vars.Add('PYTHON', default='python', help='The python interpreter')
  vars.Add('PYTHONPATH', help='colon separate list of paths')
  vars.Update(env)
  SCons.Script.Help(vars.GenerateHelpText(env))

  scanner = SCons.Script.Scanner(python_scanner, skeys=['.py'])
  env.Append(SCANNERS=scanner)

  env.AddMethod(python_output, "PythonOutput")

def exists(env):
  return True
