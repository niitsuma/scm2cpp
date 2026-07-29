---
title: 'Scm2Cpp: A Scheme-to-readable-C++ translator with type inference'
tags:
  - Scheme
  - C++
  - source-to-source translation
  - type inference
  - Hindley-Milner
  - Racket
  - parallel computing
authors:
  - name: Hirotaka Niitsuma
    orcid: 0000-0001-8746-1595
    affiliation: 1
affiliations:
  - name: Osaka Metropolitan University College of Technology, Neyagawa, Osaka, Japan
    index: 1
date: 29 July 2026
bibliography: paper.bib
---

# Summary

Scm2Cpp translates a subset of Scheme into C++ that a person can read and edit.
Conventional Scheme compilers such as Stalin [@siskind:1999], Gambit-C
[@feeley:1998], Chicken and Bigloo [@serrano:1995] treat C as a portable
assembler: their output is continuation-passing, trampolined,
garbage-collected and tagged, and it is not intended to be read. Scm2Cpp takes
the opposite position. It gives Scheme values no runtime representation at all,
so that a Scheme integer becomes a C++ `int`, a Scheme vector becomes a
`boost::array<double,1025>`, and `(car x)` becomes `car(x)`. The types are
supplied by whole-program type inference rather than by a uniform boxed
representation, and whatever inference cannot resolve is delegated to the type
system of the target language as a template parameter.

The translator is written in Racket. It reads a Scheme program together with an
optional type-annotation file and writes a header and a source file. A small
header-only runtime provides the Lisp operations (`car`, `cdr`, `cons`,
`list-ref`, `eq?`, `equal?`, delayed streams) over standard and Boost
containers.

# Statement of need

Readable output is not an aesthetic preference; it is what allows a programmer
to continue optimising after translation. In the benchmark reported with the
original version, the generated C++ for an FFT ran at a speed comparable to the
C emitted by Stalin, and adding OpenMP directives *by hand* to that generated
code made it faster than Stalin. That step is impossible when the output cannot
be read.

The present version turns this argument from an anecdote into a routine
operation. Tail-recursive named `let`, which was previously compiled into a
closure structure with reference members, is now compiled into an ordinary
`for` loop, so the loops that a directive must annotate actually exist in the
output. Command-line settings then emit OpenMP, OpenMP target-offload or
OpenACC directives, or rewrite recognised loop shapes as Thrust algorithms
[@bell:2011] for the sequential dependencies that a directive cannot express.

The intended users are researchers who prototype numerical algorithms in Scheme
and need C++ they can inspect, tune and parallelise, rather than a black-box
executable. The software has been used in the authors' own work on image
processing, where the relation between integral images and delayed streams is
studied [@niitsuma:2016], and the delayed-stream support described below was
added for that purpose.

# State of the field

The closest relative of Scm2Cpp is Aubrey Jaffer's Schlep `scm2c`
[@jaffer:2008], which also translates a subset of Scheme into readable C and
takes its types from an annotation file; Scm2Cpp inherits that file format. The
difference is that Scm2Cpp infers types rather than requiring them to be
declared, and exploits C++ templates for what remains undetermined. Among
compilers that perform whole-program type inference, Stalin is the closest in
spirit, but it consumes the type information internally and emits C for a
machine.

# Functionality

```
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++11 -include boost/operators.hpp -include boost/optional.hpp sample.cpp
```

Options select the type inference (Hindley-Milner by default, the earlier
relational implementation behind an environment variable) and the parallel back
end (`-P omp`, `-P gpu`, `-P acc`, `-P thrust`).

The type inference was reimplemented as algorithm W. The relational
implementation it replaces enumerates all solutions and does not terminate on
programs containing several similarly shaped recursive functions; the new one
infers such a program in TODO seconds. Delayed streams are
supported through a nominal recursive type, since the type of `(cons a
(delay b))` contains itself and a structural treatment is rejected by the occurs
check.

A regression suite translates twenty programs, compiles each result and runs it,
comparing the output.

# Acknowledgements

The runtime borrows the type-annotation format of Schlep, and the FFT benchmark
originates in the Gabriel benchmark suite.

# References
