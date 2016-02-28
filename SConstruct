#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path
import subprocess

env = Environment()

env.Tool('python')
env.PrependENVPath('PYTHONPATH', 'lib-python')

env.Tool('no_shell')

vars = Variables()
vars.Add('OCTAVE', default='octave', help='The Octave interpreter')
vars.Update(env)
Help(vars.GenerateHelpText(env))

AddOption(
  "--verbose",
  dest    = "verbose",
  action  = "store_true",
  default = False,
  help    = "Print LaTeX and BibTeX output."
)

if not env.GetOption("verbose"):
  env.AppendUnique(PDFLATEXFLAGS  = "-interaction=batchmode")
  env.AppendUnique(PDFTEXFLAGS    = "-interaction=batchmode")
  env.AppendUnique(TEXFLAGS       = "-interaction=batchmode")
  env.AppendUnique(LATEXFLAGS     = "-interaction=batchmode")
  env.AppendUnique(BIBTEXFLAGS    = "--terse")  # some ports of BibTeX may use --quiet instead


##
## The Thesis (default target)
##

thesis = env.PDF(target="thesis.pdf", source="thesis.tex")
env.Default(thesis)

figs = []
for f in ["NUI_Galway_BrandMark_B.eps"]:
  figs.append(os.path.join("figs", f))

methods = env.SConscript(dirs="methods", exports=["env"])
software = env.SConscript(dirs="software", exports=["env"])
kill_frap = env.SConscript(dirs="kill-frap", exports=["env"])
fancy_frap = env.SConscript(dirs="fancy-frap", exports=["env"])
h2ax_review = env.SConscript(dirs="h2ax-review", exports=["env"])

env.Depends(thesis, [figs, methods, software, kill_frap, fancy_frap, h2ax_review])


##
## "Configure" - check that we have the required LaTeX packages
##

def CheckLaTeXPackage(context, package):
  context.Message("Checking for LaTeX package %s..." % package)
  is_ok = 0 == subprocess.call(["kpsewhich", package + ".sty"],
                               stdout = open(os.devnull, "wb"))
  context.Result(is_ok)
  return is_ok

def CheckLaTeXClass(context, doc_class):
  context.Message("Checking for LaTeX document class %s..." % doc_class)
  is_ok = 0 == subprocess.call(["kpsewhich", doc_class + ".cls"],
                               stdout = open(os.devnull, "wb"))
  context.Result(is_ok)
  return is_ok

def CheckBibTeXStyle(context, style):
  context.Message("Checking for BibTeX style %s..." % style)
  is_ok = 0 == subprocess.call(["kpsewhich", style + ".bst"],
                               stdout = open(os.devnull, "wb"))
  context.Result(is_ok)
  return is_ok

conf = Configure(
  env,
  custom_tests = {
    "CheckLaTeXClass"   : CheckLaTeXClass,
    "CheckLaTeXPackage" : CheckLaTeXPackage,
    "CheckBibTeXStyle"  : CheckBibTeXStyle,
  },
)

## How the fuck is this not the default in SCons?
if not env.GetOption('help'):
  if not conf.CheckLaTeXClass("memoir"):
    print "Unable to find the LaTeX document class memoir."
    Exit(1)

  if not conf.CheckBibTeXStyle("plainnat"):
    print "Unable to find the BibTeX style plainnat."
    Exit(1)

  latex_package_dependencies = [
    "amsmath",
    "capt-of",
    "color",
    "enumitem",
    "eqparbox",
    "etoolbox",
    "fontenc",
    "fp",
    "graphicx",
    "hyperref",
    "inputenc",
    "intcalc",
    "isodate",
    "kpfonts",
    "natbib",
    "rotating",
    "seqsplit",
    "siunitx",
    "stringstrings",
    "tikz",
    "todonotes",
    "url",
  ]

  for package in latex_package_dependencies:
    if not conf.CheckLaTeXPackage(package):
      print "Unable to find required LaTeX package %s." % package
      Exit(1)

env = conf.Finish()
