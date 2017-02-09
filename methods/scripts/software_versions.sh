#!/bin/sh

set -e

if [ -z ${OCTAVE+x} ]; then
  OCTAVE=octave
fi
if [ -z ${PERL+x} ]; then
  PERL=perl
fi

print_latex_new_command ()
{
  printf "\\\newcommand{\\$1}{$2}\n"
}

print_latex_new_command \
  "OctaveVersion" \
  `$OCTAVE --eval 'printf (version)'`

print_latex_new_command \
  "OctaveImageVersion" \
  `$OCTAVE --eval 'printf (ver ("image").Version)'`

print_latex_new_command \
  "OctaveOptimVersion" \
  `$OCTAVE --eval 'printf (ver ("optim").Version)'`

print_latex_new_command \
  "OctaveSignalVersion" \
  `$OCTAVE --eval 'printf (ver ("signal").Version)'`

print_latex_new_command \
  "OctaveStatisticsVersion" \
  `$OCTAVE --eval 'printf (ver ("statistics").Version)'`

print_latex_new_command \
  "OctaveBioformatsVersion" \
  `$OCTAVE --eval 'printf (ver ("bioformats").Version)'`
