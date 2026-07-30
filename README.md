# Scm2Cpp

Scm2Cpp translates a subset of Scheme into C++ that a person can read and edit.

Unlike conventional Scheme compilers, which emit C intended only for a machine,
Scm2Cpp gives Scheme values no runtime representation: an integer becomes an
`int`, a vector becomes a `boost::array<double,1025>`, and `(car x)` becomes
`car(x)`. Types come from whole-program inference; what inference cannot pin
down becomes a C++ template parameter.

```scheme
(define (square x) (* x x))
(define (average x y) (/ (+ x y) 2.0))
(define (improve guess x) (average guess (/ x guess)))
```

becomes

```cpp
double square( double x )                 { return (x*x) ; }
double average( double x, double y )      { return ((x+y)/2.0) ; }
double improve( double guess, double x )  { return average(guess,double((x/guess))) ; }
```

## Installation

Requirements:

- [Racket](https://racket-lang.org/) 8.x
- [cKanren](https://github.com/calvis/cKanren) (only for the legacy inference)
- [Boost](https://www.boost.org/) headers
- [astyle](http://astyle.sourceforge.net/) - the generated code is indented by
  this external program; without it the output is emitted on a single line
- a C++11 compiler
- optional: CUDA toolkit, for `-P gpu` and `-P thrust`

```console
$ sudo apt-get install racket astyle libboost-all-dev
$ git clone https://github.com/niitsuma/scm2cpp.git
$ cd scm2cpp
$ export PLTCOLLECTS=/path/to/cKanren/parent:      # trailing colon required
```

## Usage

```console
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++11 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o sample sample.cpp
$ ./sample
```

`scm2cpp-file.scm` writes `sample.hpp` and `sample.cpp`.

### Options

| option | meaning |
|---|---|
| `-t FILE` | type annotation file (see `scm2c.typ`) |
| `-P omp` | emit `#pragma omp parallel for` on outermost loops |
| `-P gpu` | emit OpenMP target-offload directives; arrays become plain arrays |
| `-P acc` | emit OpenACC directives |
| `-P thrust` | rewrite recognised loops as Thrust algorithms; arrays become `thrust::device_vector` |
| `-I NAMES` | rewrite box-sum-from-origin loop nests over the named arrays as summed-area-table queries. NAMES is space-separated tokens, each `NAME` or `NAME:RANK`, or `auto`. The rank (1 for a running total, 2 for an image, and so on) is discovered from the nest itself; `:RANK` only asserts what it should be and rejects the rewrite if it disagrees |
| `-R` | rewrite loop nests and recursions by rule search before translation: the prefix-sum, separable-box-sum and tabulation rules below |
| `--rules FILE` | load extra rewrite rules from FILE (implies `-R`); each is self-tested before use |
| `--llm-hints CMD` | run CMD with the source on stdin; its stdout is taken as space-separated array names for `-I`. Off unless given -- CMD is not part of Scm2Cpp, typically a wrapper around a locally hosted model |

Environment variables:

| variable | meaning |
|---|---|
| `SCM2CPP_RELATIONAL=1` | use the original relational (cKanren) type inference instead of Hindley-Milner |
| `SCM2CPP_INTEG` | same as `-I` |
| `SCM2CPP_LLM_HINTS` | same as `--llm-hints` |
| `PLTCOLLECTS` | where to find cKanren |

### The integral-image rewrite and `--llm-hints`

`-I` rewrites a loop nest that computes, for every index `i1,...,ik` up to
an array's own extent on each axis, the sum of the array over the box from
the origin `(0,...,0)` to `(i1,...,ik)` -- an O(n^(2k)) computation for rank
`k` -- into one O(n^k) build of a summed-area table followed by O(n^k)
queries. The rank is not given; it is discovered from how many axes the
nest actually has, so the same option covers a running total over a plain
sequence (`k=1`), a 2D image (`k=2`), a 3D volume, and so on, over square or
rectangular extents alike. It fires only when that exact shape is
recognised, so naming the wrong array, or one whose nest does not match,
just leaves the code unchanged; naming a rank that disagrees with what is
actually found (`v:2` on a nest with three axes) likewise leaves it
unchanged:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -I v sample.scm       # hint by hand
$ racket scm2cpp-file.scm -t scm2c.typ -I "v w" sample.scm   # more than one
$ racket scm2cpp-file.scm -t scm2c.typ -I v:2 sample.scm     # assert the rank
$ racket scm2cpp-file.scm -t scm2c.typ -I auto sample.scm    # try every array
```

`--llm-hints` proposes the `-I` argument instead of requiring it by hand.
CMD is run with the program's source on standard input and is expected to
print, on standard output, the space-separated names (optionally `NAME:RANK`)
of arrays it believes are only read through box sums from the origin -- or
nothing. CMD is any command that speaks that contract; Scm2Cpp does not
ship one. A one-line wrapper around an OpenAI-compatible endpoint is enough:

```python
#!/usr/bin/env python3
# llm-hint-cmd -- reads the source on stdin, prints array names on stdout
import sys
from openai import OpenAI

client = OpenAI(base_url="http://localhost:4000/v1", api_key="...")
resp = client.chat.completions.create(
    model="qwen3.6",
    messages=[
        {"role": "system", "content":
         "Some arrays are written first and afterwards only read inside a "
         "loop nest that sums, for every index up to the array's own extent "
         "on each axis, every element from the origin to that index -- a "
         "box sum from the origin, of whatever rank the array has. Reply "
         "with ONLY the space-separated names of those arrays, or nothing."},
        {"role": "user", "content": sys.stdin.read()},
    ],
    max_tokens=100,
)
print(resp.choices[0].message.content)
```

```console
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints ./llm-hint-cmd sample.scm
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints "ask-local -n 100" sample.scm
```

### Rule search (`-R`)

`-R` runs a source-to-source rewriter before translation. The rules are
values -- a left pattern, a right template, a side condition -- applied by
one generic engine that matches them against every subterm through
unification and keeps any rewrite that lowers a static cost, so the order
in which rules are written does not matter. Three rules ship:

| rule | rewrite | cost |
|---|---|---|
| `scan-lemma-1d` | re-summing every prefix of an array becomes one running accumulation | O(n^2) to O(n) |
| `boxsum-2d-separable` | re-summing every box of a square array becomes a row-prefix pass and an in-place column-prefix pass | O(n^4) to O(n^2) |
| `tabulate-recursion` | a pure unary tree recursion on `(- n k)` becomes a bottom-up table fill, its self-calls becoming table reads | exponential to O(n) |

A rule is used only after passing its own embedded test: both sides of a
small program pair are run and their output compared, and a rule that
fails is dropped with a message.

`--rules FILE` adds rules from a file, written by hand or proposed by a
language model. An external rule is deliberately less expressive than a
built-in one -- its right side is a template rather than a procedure, and
its side condition is drawn from a fixed vocabulary
(`(distinct ?a ?b)`, `(symbol ?x)`, `(number ?x)`, `(zero ?x)`) -- so
reading a rules file never executes anything the file says. The embedded
test is mandatory and is the gate: a proposed rule whose two sides
disagree on its own test is dropped before it can touch any program.

```scheme
(rule gauss-sum
  (lhs (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
         (set! ?ACC (+ ?ACC ?I))))
  (rhs (set! ?ACC (+ ?ACC (quotient (* ?N (- ?N 1)) 2))))
  (when (distinct ?I ?ACC) (symbol ?ACC))
  (test (define (main)
          (let ((n 25) (acc 7))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc i)))
            (display acc) (newline)))
        (main)))
``` `-R` and `-I` overlap on the box-sum
shapes but are not the same: `-I` covers any rank and rectangular
extents and can share one table across several nests, while `-R` also
covers recursion, and its output is plain Scheme, so it needs no runtime
support and composes with everything downstream.

When several statements of one sequence are box-sum nests over the same
array and the analysis can show the span between them is write-free for
that array -- no `set!`, no `vector-set!`, no call that reaches it through
a parameter some function writes to -- one table is built at the first
nest and shared by the rest. A write in between simply keeps the nests
separate, each with its own table. The same per-function write analysis
also marks container parameters a function never writes as `const ... &`
in the generated signature.

If CMD is not found, or prints nothing usable, translation proceeds as
though `--llm-hints` had not been given. In either case the proposal is
only ever a hint: an array it names is rewritten only when the box-sum
shape is actually recognised, so a wrong proposal changes nothing, and the
result is expected to be checked like any other build -- `./run-tests.sh`
translates, compiles and runs every regression case regardless of which
options were used to generate it.

### Compiling the generated code

| setting | compiler invocation |
|---|---|
| default | `g++ -std=c++11 -include boost/operators.hpp -include boost/optional.hpp` |
| `-P omp` | add `-fopenmp` |
| `-P gpu` | add `-fopenmp -foffload=nvptx-none -fcf-protection=none -fno-stack-protector` |
| `-P thrust` | compile with `nvcc -O2` |

## Supported subset

`define`, `lambda`, `let`, named `let`, `letrec`, `if`, `cond`, `when`,
`unless`, `begin`, `do`, `set!`, `define-macro`, `define-syntax`,
`vector-ref`, `vector-set!`, `vector-length`, `make-vector`, `list`,
`make-list`, `list-ref`, `car`, `cdr`, `cons`, `display`, `newline`,
`string-append`, `not`, `zero?`, the numeric operators and comparisons, the
usual transcendental functions, `delay`/`force` and delayed streams.

Not supported: continuations, general tail-call elimination, arbitrary
heap-allocated recursive data beyond the provided list and stream types, and
the parts of R7RS outside the above.

## Tests

```console
$ ./run-tests.sh
```

Each test program is translated, the result is compiled and run, and the output
is recorded. The suite covers twenty programs and all of them pass.

## The runtime header

`scm2cpp.hpp` can also be used on its own, without the translator. It gives
Lisp operators over the usual C++ containers, so that `car`, `cdr`, `cons` and
`list-ref` apply to

    std::vector    std::list    boost::ptr_list    boost::fusion::list

with `std::pair` treated as a cons cell. `eq?`, `eqv?`, `equal?`, `quote` and
the symbol operations are provided as well. `eq?` is address comparison,

```cpp
template<typename T>
bool is_eq(T & x, T & y) { return (&x)==(&y); }
```

which is why `cons(T, std::list<T>)` yields `boost::ptr_list<T>`: the view
`uniform_sequence_to_boost_ptr_sequence_view` maps a list to a ptr_list, which
has push_front, whereas a vector maps to a ptr_vector, which does not.

See `usage.cpp`, `list-test.cpp` and `equal-test.cpp` for worked examples.

## Documentation

- `CHANGES.ja.md` - a record of the modifications made to the historical code
  base, with the reason for each
- `ideal/stream-ideal-new.cpp` - the intended shape of the generated code for
  delayed streams, written by hand

## Contributing

See `CONTRIBUTING.md`.

## License

MIT License; see `LICENSE`.

Several files derive from Aubrey Jaffer's Schlep and SLIB, and from utilities
published in Paul Graham's *On Lisp*. These remain under their own permissive
terms, which are reproduced in full at the head of each file. `NOTICE` records
the provenance and the measured extent of the derivation. Redistributors must
honour those conditions in addition to the MIT terms.

## Citing

A paper describing the design is in preparation and is not in this repository
yet. Until it appears, cite the repository and the commit you used;
machine-readable metadata is in `CITATION.cff`.
