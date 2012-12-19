paper = PDF(target = 'thesis.pdf', source = 'thesis.tex')

## FIXME we should probably have this on each directory and have Scons retrieve
##       it from there (common.mk, module.mk, Makefile.am style)
Depends(paper, ['chapters/fancy-frap.tex',
                'chapters/frap.tex',
                'chapters/histone-catalogue.tex',
                'chapters/intro.tex',
                'chapters/methods.tex',
                'chapters/octave.tex',])
Decider('content')  # same as MD5

