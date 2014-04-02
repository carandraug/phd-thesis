## coding: utf-8
from os import path
import os
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
  path.join ('scripts', 'SConscript'),
  exports = ['env', 'data_dir'],
  variant_dir = results_dir,
  duplicate = 0,
)

figs = SConscript (path.join (figs_dir, 'SConscript'), exports = 'env')
figs = [path.join (figs_dir, f) for f in figs]

Depends (thesis, [figs, results])

##
## Check that we have the required LaTeX packages and classes installed
##

def CheckLaTeXPackage(context, package):
    context.Message("Checking for LaTeX package %s..." % package)
    is_ok = True
    if (subprocess.call(["kpsewhich", "%s.sty" % package],
                        stdout = open(os.devnull, "wb"))):
      is_ok = False
    context.Result(is_ok)
    return is_ok

def CheckLaTeXClass(context, doc_class):
    context.Message("Checking for LaTeX document class %s..." % doc_class)
    is_ok = True
    if (subprocess.call(["kpsewhich", "%s.cls" % doc_class],
                        stdout = open(os.devnull, "wb"))):
      is_ok = False
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
  print "LaTeX document class memoir must be installed."
  Exit(1)

required_packages = [
  "graphicx",
  "url",
  "todonotes",
  "natbib",
  "palatino",
  "seqsplit",
  "eqparbox",
  "capt-of",
  "hyperref",
  "amsmath",
  "enumitem",
  "eqparbox",
  "longtable",
  "tikz",
  "rotating",
  "siunitx",
]
for package in required_packages:
  if not conf.CheckLaTeXPackage(package):
    print "LaTeX package %s must be installed." % package
    Exit(1)

env = conf.Finish()

