---
title: 'Scm2Cpp: A Scheme-to-readable-C++ translator with type inference'
tags:
  - Scheme
  - C++
  - source-to-source translation
  - type inference
  - Hindley-Milner
  - program derivation
  - rewrite systems
  - large language models
  - Racket
  - parallel computing
authors:
  - name: Hirotaka Niitsuma
    orcid: 0000-0001-8746-1595
    affiliation: 1
affiliations:
  - name: Osaka Metropolitan University College of Technology, Neyagawa, Osaka, Japan
    index: 1
date: 28 August 2026
bibliography: paper.bib
---

# Summary

Scm2Cpp translates a subset of Scheme into C++ that a person can read and edit.
Conventional Scheme compilers such as Stalin [@siskind:1999], Gambit-C
[@feeley:1998], Chicken and Bigloo [@serrano:1995] treat C as a portable
assembler, emitting continuation-passing, trampolined, garbage-collected and
tagged code that is not intended to be read. Scm2Cpp gives Scheme values no
runtime representation at all: a Scheme integer becomes a C++ `int`, a vector
becomes a `boost::array<double,1025>`, `(car x)` becomes `car(x)`. Types come
from whole-program inference rather than from a uniform boxed representation,
and whatever inference cannot resolve becomes a template parameter of the
target language.

A second layer derives programs by rewriting. From a naive Scheme kernel, the
passes contract repeated sliding-window sums to prefix-sum differences, hoist
loop-invariant subexpressions into precomputed tables and turn batch
recomputation into incremental update, a cost model choosing among candidates.
The derived program is held to the naive one it came from -- it must print the
same numbers, checked both under Racket and through the C++ it translates to --
so a rewrite that is faster and wrong is caught by the step that accepts one
that is faster and right.

A third layer, optional and outside the translator, puts a language model in
the authoring loop: it proposes a rewrite rule or a quantity worth storing,
and a mechanical gate decides whether the proposal survives -- same printed
output, and for a memoisation, cost that grows more slowly with problem size.
The model is never trusted and never consulted during translation, which stays
deterministic; a session yields a rules file or a rewritten kernel a person
can read and keep.

The translator is written in Racket: it reads a Scheme program and an optional
type-annotation file and writes a header and a source file, against a small
header-only runtime that provides the Lisp operations over standard and Boost
containers.

# Statement of need

Readable output is not an aesthetic preference; it is what allows a programmer
to continue optimising after translation. In the benchmark reported with the
earlier versions [@niitsuma:2012; @niitsuma:2013], generated C++ for an FFT ran
comparably to the C emitted by Stalin, and adding OpenMP directives *by hand*
made it faster -- a step that is impossible when the output cannot be read.

The present version turns that argument into a routine operation.
Tail-recursive named `let`, previously compiled into a closure structure with
reference members, now becomes an ordinary `for` loop, so the loops a directive
must annotate actually exist in the output; command-line settings then emit
OpenMP, OpenMP target-offload or OpenACC directives, or rewrite recognised loop
shapes as Thrust algorithms [@bell:2011].

The readability claim is scoped deliberately. It holds for direct translation,
where the emitted C++ mirrors the Scheme's structure and names. The derivation
passes emit machine-generated intermediate names, and their raw output looks
like it; the supported workflow is to treat that as an intermediate result and
re-express the derived algorithm as ordinary Scheme;
`examples/kernel-only/` holds kernels written that way.

The intended users are researchers who prototype numerical algorithms in Scheme
and need C++ they can inspect, tune and parallelise rather than a black-box
executable. The software has been used in the author's own work on image
processing [@niitsuma:2016], for which the delayed-stream support was added.

# State of the field

The closest relative of Scm2Cpp is Aubrey Jaffer's Schlep `scm2c`
[@jaffer:2008], which also translates a subset of Scheme into readable C and
takes its types from an annotation file; Scm2Cpp inherits that file format. The
difference is that Scm2Cpp infers types rather than requiring them to be
declared, and exploits C++ templates for what remains undetermined. Among
compilers that perform whole-program type inference, Stalin is the closest in
spirit, but it consumes the type information internally and emits C for a
machine.

The derivation layer belongs to a different lineage: equality saturation
[@willsey:2021], transform generators such as SPIRAL [@pueschel:2005] and FFTW
[@frigo:2005], the algorithm/schedule split of Halide [@ragankelley:2013], and
self-adjusting computation [@hammer:2014]. It is narrower than all of them and
differently aimed -- one family of sliding-window and prefix-sum rewrites, an
output-comparison oracle in place of a proof or a saturation argument, and
readable Scheme as its product rather than a schedule or a binary. The
covariance-update coordinate descent it derives for the lasso is the classical
algorithm of glmnet [@friedman:2010]; what is contributed is not the algorithm
but its mechanical derivation from the naive program.

The proposer tools meet two further lines. Ruler [@nandi:2021] infers rewrite
rules by equality saturation over a bounded term space and is sound by
construction; the proposers give that up to reach rules outside any enumerable
space, and buy safety back with an execution gate. Language models have also
been applied to compiler optimisation directly [@cummins:2023], predicting a
pass sequence or emitting optimised code. The difference here is where the
model sits: it produces a candidate, never the answer, and never runs inside
the translator, so the deterministic pipeline is unaffected by what it does or
does not know.

# Functionality

```
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++17 -include boost/operators.hpp -include boost/optional.hpp sample.cpp
```

Options select the type inference (`--inference hm` or `relational`), the
parallel back end (`-P omp`, `-P gpu`, `-P acc`, `-P thrust`), and `-N` for a
plain translation with every optimisation off.

The default inference is algorithm W [@milner:1978]. Delayed streams are
supported through a nominal recursive type, since the type of
`(cons a (delay b))` contains itself and a structural treatment is rejected by
the occurs check.

The relational inference is a Hindley-Milner typing relation in miniKanren,
over a core whose occurs check names a self-referential binding, `(==> x t)`,
instead of refusing it -- the recursive-miniKanren change [@niitsuma:2018],
with unification made equi-recursive so that two rollings of one infinite type
meet. Run forwards it types the subset; run backwards it enumerates terms of a
given type, which is the direction the proposer tools want in a gate. And it
derives the recursive types algorithm W has to be handed: the integer stream
comes back as `mu T. pair num (promise T)` from the program alone, and a
conversion lands the derived type on the same nominal `scm2cpp-stream` the
emitter already renders, refusing an unguarded recursion -- a circular list as
plain data -- which has no C++ value of finite size. The relation settles
shapes only; widths are realised by the widening pass on either route, which
is what leaves `square` a template until some call site says double. Under
`--inference relational` the suite passes whole, and the original relational
implementation remains as the fallback when the relation exceeds its time
budget.

The derivation passes are exercised end to end: a naive least-squares kernel
over trailing moving averages is rewritten into the covariance-update form,
its Gram matrix assembled from prefix sums in O(np) without forming the design
matrix, and a penalty grid solved by coordinate descent on it. The derived
kernels -- lasso and elastic net, ridge, L1 logistic regression, group lasso,
Yule-Walker autoregression, rolling statistics -- are translated to C++ and
published on PyPI as `scm2cpp-lasso` and `scm2cpp-tfs`, each carrying its
generated C++, so installation needs a compiler but not Racket; the worked
example in the repository README runs against the published package as
written. A CUDA kernel solves the grid
with one thread per penalty; the timings, the hardware and the script that
reproduces them are in the repository README.

Three authoring tools ask a language model where to look and then refuse to
take its word for it. `rule-propose.rkt` asks for a rewrite rule in the
optimiser's format and runs the rule's own self-test, handing a failing
attempt back as evidence. `memo-propose.rkt` asks which quantity to store -- a
memo table, a prefix sum, a Gram matrix -- and holds the answer to two gates,
because such a proposal can be perfectly correct and no faster: same numbers,
and a running time that grows more slowly as a size parameter is varied.
`repeat-scan.rkt` lists the effect-free subexpressions a program computes more
than once, leaving the model only the judgment of which repeat is worth a
table. The failure mode the gates exist for is plausible arithmetic,
not invented syntax: asked for the covariance-update lasso, a local model
derived it correctly and then miscounted the precomputation's growth -- every
number it printed was right, and only a timing gate can see that. The model is
a shell command answering a prompt on stdin; local or hosted serves equally,
and none is needed to build or run anything else here.

A regression suite of 44 checks runs 11 unit tests -- the rewrite passes, and
the typing relation in both its directions --
translates 31 programs and compiles and executes each one against the output of
the same program under Racket -- Scheme is the specification, so there are no
expected-output files to drift -- and finishes by building the Python package
and the CUDA kernel. It runs in continuous integration from a fresh clone.

# Acknowledgements

The runtime borrows the type-annotation format of Schlep, and the FFT benchmark
originates in the Gabriel benchmark suite. Parts of the implementation and
documentation were developed with the assistance of Claude (Anthropic); the
design decisions and the verification of the results are the author's.

# References
