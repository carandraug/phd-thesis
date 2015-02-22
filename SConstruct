#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path
import subprocess

env = Environment ()
thesis = env.PDF (
  target = "thesis.pdf",
  source = "thesis.tex",
)

figs_dir    = 'figs'
data_dir    = 'data'
results_dir = 'results'

results = SConscript (
  os.path.join ('scripts', 'SConscript'),
  exports = ['env', 'data_dir'],
  variant_dir = results_dir,
  duplicate = 0,
)

figs = SConscript (os.path.join (figs_dir, 'SConscript'), exports = 'env')
figs = [os.path.join (figs_dir, f) for f in figs]

Depends (thesis, [figs, results])

##
## Check that we have the required LaTeX packages and classes installed
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

conf = Configure(
  env,
  custom_tests = {
    "CheckLaTeXClass"   : CheckLaTeXClass,
    "CheckLaTeXPackage" : CheckLaTeXPackage,
  },
)

if not conf.CheckLaTeXClass("memoir"):
  print "Unable to find the LaTeX document class memoir."
  Exit(1)

for package in ["graphicx", "url", "todonotes", "natbib", "palatino",
                "seqsplit", "eqparbox", "capt-of", "hyperref", "amsmath",
                "enumitem", "eqparbox", "longtable", "tikz", "rotating",
                "siunitx", "textgreek"]:
  if not conf.CheckLaTeXPackage(package):
    print "Unable to find required LaTeX package %s." % package
    Exit(1)

env = conf.Finish()

