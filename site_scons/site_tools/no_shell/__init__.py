#!/usr/bin/env python
# -*- coding: utf-8 -*-

## Copyright (C) 2015-2016 Carnë Draug <carandraug+dev@gmail.com>
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

"""SCons tool to avoid the shell in commands.
"""

import subprocess

import SCons.Script

## NoShellCommand
##
## Do not involve the shell in the command.  Same syntax as the Command
## builder, but each element in "action" is one of the arguments for the
## final command.
##
## "target" and "source" are ignored by NoShellCommand and need to appear
## defined again in "action".  Use of $TARGET and $SOURCE is not supported
## (the whole point of this builder is to perform no escaping whatsoever).

def no_shell_command(target, source, env):
  args = [str(x) for x in env['action']]
  return subprocess.call(args)

def no_shell_command_strfunc(target, source, env):
  args = env['action']
  return "$ %s %s" % (args[0], " ".join(["'%s'" % (arg) for arg in args[1:]]))

## NoShellOutput
##
## Same as NoShellCommand with the difference that the output of "action"
## is redirected to "target"

def no_shell_output(target, source, env):
  args = [str(x) for x in env['action']]
  with open(str(target), "w") as outfile:
    return subprocess.call(args, stdout=outfile)

def no_shell_output_strfunc(target, source, env):
  args = env['action']
  args_str = " ".join(["'%s'" % (arg) for arg in args[1:]])
  return "$ %s %s > %s" % (args[0], args_str, target)


def generate(env):

  no_shell_command_action = SCons.Script.Action(no_shell_command,
                                                strfunction=no_shell_command_strfunc)
  no_shell_command_bld = SCons.Script.Builder(action=no_shell_command_action)
  env.Append(BUILDERS={'NoShellCommand' : no_shell_command_bld})

  no_shell_output_action = SCons.Script.Action(no_shell_output,
                                               strfunction=no_shell_output_strfunc)
  no_shell_output_bld = SCons.Script.Builder(action=no_shell_output_action)
  env.Append(BUILDERS={'NoShellOutput' : no_shell_output_bld})

def exists(env):
  return True
