# The translator

*[Japanese](translator.ja.md)* · [README](../README.md)

Building and running the translator itself: requirements, the command line and its options, the Scheme subset it accepts, the test suite, the Typed Racket cross-check and the runtime header.  The Python package needs none of this.

## Installation

This is the translator (the Python package alone needs none of it;
see [Installing](../README.md#installing) in the README).  Requirements:

- [Racket](https://racket-lang.org/) 8.x
- [Boost](https://www.boost.org/) headers
- [astyle](http://astyle.sourceforge.net/) - the generated code is indented by
  this external program; without it the output is emitted on a single line
- a C++17 compiler for the generated code.  The regression suite compiles at
  C++17, because Boost.Math has required C++14 since Boost 1.82 and the
  runtime header includes it; `CXXSTD=c++20 ./run-tests.sh` also passes
- optional: CUDA toolkit, for `-P gpu` and `-P thrust`
- optional: Python 3 with numpy, to use the `-M` output

The miniKanren the translator runs on is **not** a separate
requirement: it is bundled as `vendor/rkanren` and registered by the
second command below. See "About the bundled rkanren" if you want to
know what it is.

```console
$ sudo apt-get install racket astyle libboost-all-dev g++
$ git clone https://github.com/niitsuma/scm2cpp.git
$ cd scm2cpp
$ raco link --user vendor/rkanren        # once; no PLTCOLLECTS needed
$ ./run-tests.sh                         # should report PASS=203 FAIL=0 (181 without a CUDA device, 155 without cblas.h, 9 fewer without OpenMP)
```

If you would rather not register a collection, set `PLTCOLLECTS` instead
of running `raco link` -- the trailing colon is required:

```console
$ export PLTCOLLECTS=$PWD/vendor:
```

### About the bundled rkanren

Some of the translator's utility modules are relational and load their
miniKanren even on the Hindley-Milner path, so a miniKanren is needed
for any translation -- and not the one `raco pkg install cKanren` gives
you, whose module re-exports only a constraint core without the layer
this code calls (`nullo`, `never-pairo` and others). `vendor/rkanren`
is that cKanren -- Alvis, Willcock, Carter, Byrd and Friedman's
constraint framework, under its own MIT notice in the directory -- with
its core exchanged for the recursive-miniKanren one: walk and
occurs-check are cycle-safe, unification is equi-recursive, and a
self-referential binding is annotated `(==> x t)` rather than refused
(Niitsuma, Computacion y Sistemas 22(4), 2018). The framework around
that core is untouched, and the original unmodified library is kept in
git history (commit 3c945f9) rather than in the tree.
`vendor/mk-recursive` is the same change applied to plain miniKanren;
the relational type inference runs on it.

## Usage

```console
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++17 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o sample sample.cpp
$ ./sample
```

`scm2cpp-file.scm` writes `sample.hpp` and `sample.cpp`.

### Options

| option | meaning |
|---|---|
| `-t FILE` | type annotation file (see `scm2c.typ`) |
| `-P omp` | emit `#pragma omp parallel for` on the outermost loop whose iterations are shown to be independent (see "Where the directive goes") |
| `-P gpu` | emit OpenMP target-offload directives; arrays become plain arrays |
| `-P acc` | emit OpenACC directives |
| `-P thrust` | rewrite recognised loops as Thrust algorithms; arrays become `thrust::device_vector` |
| `-I NAMES` | rewrite box-sum-from-origin loop nests over the named arrays as summed-area-table queries. NAMES is space-separated tokens, each `NAME` or `NAME:RANK`, or `auto`. The rank (1 for a running total, 2 for an image, and so on) is discovered from the nest itself; `:RANK` only asserts what it should be and rejects the rewrite if it disagrees |
| `--cost OBJ` | what the derivation drivers optimise for: `speed` (default) or `memory`.  Under `memory` the allocated cells decide first and the time cost only breaks ties -- a candidate that trades a table for a loop, profitable to the clock, is then a loss and is left alone |
| `--blas` | emit the contractions (`contract`, numpy's einsum: the Gram the derivation hoists, the memo, the restore, and whatever a hand-written kernel spells as `matmul`) as CBLAS calls -- one `dgemm`, `dgemv` or `dsyrk` each, the transposition flags read off where the summed index sits in each operand, a batch of slabs as a loop of `dgemm` (one `cublasDgemmStridedBatched` under `--cublas`) -- through the binding `bindings/cblas-binding.scm`, the same custom-binding mechanism a user's own C++ goes through, so the three ops are declared, modelled and checked like any other.  The generated header includes `scm2cpp-blas.hpp`; link with `-lopenblas` (or your CBLAS).  Off, each product is the loop nest it always was, so a program never depends on BLAS unless asked; an operand that is an expression is materialised first, and a contraction whose summed index sits in the middle of an operand is left to expand |
| `--cublas` | the same products as cuBLAS calls through `bindings/cublas-binding.scm`: a matrix the function only reads is uploaded once at the head of its `with-arrays` scope (`dmat-upload`), one it writes is copied at each call, and each op runs on the device and copies its result back.  The header includes `scm2cpp-cublas.hpp`; compile with the CUDA include path and link `-lcublas -lcudart` (a plain host compiler suffices; nothing is a kernel).  Worth it only when the product dominates -- the copies are the price |
| `--cuda` | emit every loop the dependence test accepts as parallel (each iteration writes its own elements, a carried scalar is a sum) and whose body computes only on scalars and array elements as a CUDA kernel, one thread per iteration, a sum by an atomic add, launched when the trip count reaches `SCM2CPP_CUDA_MIN` (default 4096) with the host loop below it; the products go to cuBLAS on device arrays (`bindings/cuda-binding.scm`).  Arrays stay on the device across statements: a device statement uploads what the device does not have, a host statement first downloads what the host does not have and then marks what it wrote (`scm2cpp-cuda.hpp`), so an iteration whose host part touches only small arrays never moves the large ones.  Compile with `nvcc -x cu`, link `-lcublas`; `-M` wrappers take each view's length and bring the caller's arrays back before they return |
| `--derive` | derive the covariance form of a coordinate descent from the array shapes its function declares (`with-arrays` at the head of the body: rank two are matrices, rank one are vectors). The residual sweeps are raised to the array algebra, the scratch vector's update (a decrement or an increment) is differenced into a memo maintained by a hoisted Gram matrix, and the residual is restored at the end when the caller reads it (the liveness pass decides). The derived body runs under `(if (< p n) ..)`, p and n read off the declared shape of the matrix whose rows (or columns) update the scratch, with the sweep as written in the else branch: scikit-learn's `precompute='auto'` rule. The scratch may be a vector, a matrix updated a row or a column at a time, or a tensor updated a fiber at a time (its products are written over the matrices the other axes flatten to). The design may be stored either way: p rows of n (`x[j*n+i]`, the sweep walks a row) or n rows of p (`x[i*p+j]`, numpy's C order, the sweep walks a column, `(col x j)`); the products come out with the transposes on the other side (`x' x`, `x' r`, `r -= x d`) and lower to the same BLAS calls. Before that, a product of arrays a loop never writes -- `(matmul (transpose xk) xk)` over columns the loop gathers from such an X, `xk[i,c] = x[i, idx[c]]` -- is formed once as X'X and gathered by the indices instead (`invariant` in the log; see below). A function without a declaration is left alone; a program without one translates byte-identically. `derive: NAME: raise differencing` on stderr reports what fired; `-S` saves the derived program as Scheme |
| `--binding FILE` | map declared operations onto a user-supplied C++ header per FILE; see `examples/custom-template/` |
| `-M` | besides the executable sources, emit `NAME_capi.cpp` (extern "C" wrappers) and `NAME.py` (a ctypes loader), so the translated functions can be called from Python on numpy arrays |
| `--llm-hints CMD` | run CMD with the source on stdin; its stdout is taken as space-separated array names for `-I`. Off unless given -- CMD is not part of Scm2Cpp, typically a wrapper around a locally hosted model |

Environment variables:

| variable | meaning |
|---|---|
| `SCM2CPP_RELATIONAL=1` | relational type inference (also `--inference relational`): the recursive-miniKanren typing relation as a gate: it says on stderr whether it typed the program, and Hindley-Milner realises the types either way (the gate's budget: `SCM2CPP_REL_BUDGET` seconds, default 60) |
| `SCM2CPP_INTEG` | same as `-I` |
| `SCM2CPP_LLM_HINTS` | same as `--llm-hints` |
| `PLTCOLLECTS` | where to find rkanren |

### Where the directive goes

`-P omp`, `-P gpu` and `-P acc` do not simply annotate the outermost loop.
Each candidate is tested for a loop-carried dependence, outermost first, and
the directive goes on the first loop that passes; if none does, the function
is left serial. The test is conservative in one direction: it annotates a
loop only when every write it makes provably lands where no other iteration
of that loop touches, so a loop that could have run in parallel may be left
alone, but one that cannot is not annotated.

What counts as provable:

- every `vector-set!` index is injective in the loop variable -- the index is
  the variable itself, or the row-major `(+ (* i S) rest)` where `rest` does
  not mention `i` and `S` is the extent an inner loop runs to, which is what
  makes the rows disjoint;
- an array the loop writes is not read at some other index, which would be
  another iteration's element;
- a scalar assigned in the loop is either bound inside it, and so private, or
  is only ever updated as `(set! acc (+ acc E))`, in which case the directive
  carries `reduction(+:acc)` instead of the loop being rejected.

On a coordinate descent, for instance, the sweep loop is rejected because a
sweep reads what the one before wrote, the coordinate loop is rejected
because it writes the whole of `c` and reads one element of it, and the
directive lands on the innermost update. A prefix sum, which reads `cs[i]`
and writes `cs[i+1]`, is rejected at every level and stays serial.

Threads are not free, so an annotated loop also carries a guard on its
work: `#pragma omp parallel for if((p*p) > 65536)` for a loop over p rows
each running an inner loop of p, `if(n > 65536)` for a flat one (the
inner count is used when it can be evaluated before the loop). A loop
whose work is a literal below the threshold is left unannotated, and so
is a loop whose trip count cannot be read from its test (`=`, `>=` or `>`
on a variable stepped by one): without a count there is no guard, and an
unguarded directive forks threads on every call however short the loop.
The threshold is `SCM2CPP_OMP_MIN` (default 65536, the work of a 256 x 256
nest; at 1024 a loop of 5000 run every SMO iteration took a fit from
0.4 s to 43 s on a loaded machine); the point of deciding at runtime is
that one translated kernel may be called with a hundred columns and with
a hundred thousand. Under a directive the loop test is written in
OpenMP's canonical form (`i < n`, `k <= l`), which MSVC requires. A
guard that is decided at runtime is not an `if` clause: the loop is
written twice, `if (work > min) { #pragma omp parallel for .. } else
{ .. }`, because a loop under a directive whose `if` is false still runs
through the outlined function with its reductions in memory, and that
cost a serial PCA a fifth of its time.

`./run-tests-omp.sh` checks this the way `run-tests.sh` checks the serial
output: it translates with `-P omp`, compiles with `-fopenmp`, and compares
the result with Racket, several runs per case, since a race need not lose
every time. `run-tests.sh` has an omp round of its own over the kernels
(the SMO solvers, PCA, the mixture, FastICA, L-BFGS, k-means, the F
statistics, DBSCAN), translated with `SCM2CPP_OMP_MIN=1` so that every
accepted loop runs on four threads.

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
### Proposing what to store: `repeat-scan.rkt` and `memo-propose.rkt`

`repeat-scan.rkt` does the part that can be done exactly. A subexpression
with no side effects is a function of its free variables, so two
occurrences agree whenever those variables do -- loop indices included.
It lists every repeated side-effect-free subexpression with what it
depends on, separating the variables that change from one iteration to
the next from the rest, and with `-c CMD` asks a model which are worth a
table. Finding the repeats is mechanical; deciding which to store
depends on how the loops nest and how large the table would be, and that
is the judgement worth asking for. Asked of a lasso over moving
averages, a local model declined every candidate, reasoning that a table
of 30x600 entries costs more to fill than the arithmetic it saves --
which measurement had already borne out. Its limit is the level it works
at: a naive quadratic prefix sum has no repeated subexpression at all,
because the waste there is overlapping ranges rather than a repeated
expression.

`memo-propose.rkt` asks a different question: not "rewrite this shape"
but "what should be stored so that repeated work is shared". It runs the
conversation in stages -- what to keep, then whether the program's own
structure makes keeping it affordable, then the rewritten program -- and
holds the answer to two gates. The first is the familiar one: it must
print what the original printed. The second times the program at several
sizes and requires the cost to grow markedly more slowly, because a
proposal here can be perfectly correct and no faster at all, and only a
timing gate can tell:

```console
$ racket memo-propose.rkt -c "ask-local -n 900" -s "400=400,1600,3200" \
    -o faster.scm kernel.scm
  original: (1.0 5.6 38.5)  (grew 37.4-fold)
  proposed: (0.4 0.4 0.5)   (grew 1.2-fold)
memo-propose: accepted -> faster.scm
```

`-s NAME=A,B,C` names a literal in the program to vary. The second gate
earns its keep: a rewrite that dutifully stores every partial sum in a
table and then recomputes them anyway passes the answer check and is
refused here, told that its cost still grows like the original's.

### Compiling the generated code

| setting | compiler invocation |
|---|---|
| default | `g++ -std=c++17 -include boost/operators.hpp -include boost/optional.hpp` |
| `-P omp` | add `-fopenmp` |
| `-P gpu` | add `-fopenmp -foffload=nvptx-none -fcf-protection=none -fno-stack-protector` |
| `-P thrust` | compile with `nvcc -O2` |

## Supported subset

`define`, `lambda`, `let`, named `let`, `letrec`, `if`, `cond`, `when`,
`unless`, `begin`, `do`, `set!`, `define-macro`, `define-syntax`,
`vector-ref`, `vector-set!`, `vector-length`, `make-vector`, `list`,
`make-list`, `list-ref`, `car`, `cdr`, `cons`, `display`, `newline`,
`string-append`, `not`, `zero?`, the numeric operators and comparisons, the
usual transcendental functions, `delay`/`force` and delayed streams,
`make-hash`, `hash-ref`, `hash-set!`, `hash-has-key?`, `hash-count`.

Not supported: continuations, general tail-call elimination, arbitrary
heap-allocated recursive data beyond the provided list and stream types, and
the parts of R7RS outside the above.

A promise is a memoising callable, and a vector of promises is a lazy
table: `(make-vector n (delay 0))` filled with `(delay ..)` cells whose
bodies force other cells is dynamic programming in dependency order,
each body run once (`probe/promise-table.scm`). Forcing counts as a
write for the constness analysis -- a promise forced through a `const`
reference would compute again on every force -- so a table of promises
is captured by mutable reference.

A hash table holds one key type and one value type, both inferred from
its uses: `(make-hash)` becomes `std::unordered_map<K,V>`, or
`std::map<K,V>` when the key is itself a container. `hash-ref` with a
default is `count ? at : default`, `hash-has-key?` is `count > 0`,
`hash-count` is `size`. Tables cross function calls by reference like
vectors, and `hash-set!` counts as a write. This is memoisation for a
function whose argument is not a small integer index: the table grows
with the calls actually made (`probe/hash-memo.scm` memoises the
Collatz step count over sparse arguments, and keeps a string-keyed
tally). The `define-memo` macro is ordinary `define-macro` source,
`probe/define-memo.scm`, taken by include; note that the memoised
body's statements must stay in statement position, since a
`(begin ..)` bound by `let` would have to become a C++ expression.
`probe/fib.scm` has the two idioms side by side on the one function
everyone knows -- `fib-memo` through the hash table, `fib-lazy`
through a vector of promises -- each body run 41 times for fib(40),
in Racket and in the C++.  Neither is found by a rewrite: the rule
that once turned a tree recursion into a table-filling loop went with
the rule search, and the two shapes are what the subset offers in its
place.

A top-level `(include "file.scm")` stands for the forms of that file, as
Racket's `include` does: the path is relative to the file the form is
written in, and the included file may include others. The splice is
textual and happens before anything reads the program, so the
translator, the oracle, the proposers and `-S` all see one program;
`-M`'s Python loader and the generated C++ do not know the difference.
The lasso kernels under `examples/` share their `soft-threshold` this
way (`examples/kernel-only/soft-threshold.scm`) rather than by copy.
A file is spliced once per program: a second include of it, direct or
through another included file, contributes nothing, so two kernels
that each include `soft-threshold.scm` can themselves be included
side by side (`examples/kernel-only/lasso-auto.scm` takes
`lasso-kernel.scm` and `lasso-cov.scm`).

A Scheme value is mapped to a C++ object of a definite type, and one
consequence is worth stating. Binding a name to a vector aliases it -- the
two names denote one vector, and the translator emits a reference so that
writes through either are seen through both. Re-pointing such a name with
`set!` is where the mapping runs out: a C++ reference cannot be re-pointed,
so the translator falls back to a copy and warns. After `(set! v w)` the two
languages then disagree, Scheme writing through `v` into `w`'s vector where
the C++ writes into a copy. Assign through the elements, or pass the vector
you mean, rather than re-pointing the name.

### The array and fold layer

Every translation unit is seeded with a set of built-in `define-macro`
forms -- `array-macros.scm` is the authoritative reference, and a file
defining a macro of the same name shadows the built-in.  Storage stays
one flat vector per array and every subscript one affine expression, so
the generated C++ is the loop nest the flat kernels write by hand, and
the updating forms expand to exactly the shapes the derivation
(`--derive`) raises -- writing a sweep with them never hides the
algebra from it.

| form | meaning |
|------|---------|
| `(range-for (i n) body ...)`, `(range-for (i a b) body ...)` | loop `i = 0..n-1`, or `a..b-1` |
| `(range-fold ((acc init) (i n)) e)` | fold; `e` yields the next `acc` |
| `(range-sum (i n) e)` | sum of `e`, an unnamed fold |
| `(with-arrays ((a (d0 d1 ...)) ...) body ...)` | declare flat arrays with their shapes |
| `(array-ref a i j)`, `(array-set! a i j v)` | row-major subscript; value last, as in SRFI 25 |
| `(array-inc! a i j e)`, `(array-dec! a i j e)` | `a[i,j] += e` / `-= e` |
| `(array-inc! y e)`, `(array-dec! y e)` | elementwise `y += e` / `-= e` for a vector expression `e` |
| `(array-mul! a i j e)`, `(array-div! a i j e)` | `a[i,j] *= e` / `/= e` |
| `(array-mul! y e)`, `(array-div! y e)` | elementwise `y *= e` / `/= e` for a vector expression or a scalar `e` (a 2-D `y` with a matrix expression or a scalar likewise); with a `(matmul a b)` the product is formed in a temporary of `y`'s shape first, and `--blas` / `--cublas` lower that product as they lower `array-set!`'s |
| `(array-sum e)` | sum of a vector expression |
| `(array-reduce op id e)` | the same fold under `+` `*` `min` `max` with identity `id` |
| `(array-set! s i j (array-sum (box v i j)))` | prefix box sum: `s[i,j]` gets the fold of `v` over `[0,i]x[0,j]` |
| `(array-sum (sub a lo1 hi1 ...))` | sum over the hyperrectangle -- numpy's `a[lo1:hi1, ...].sum()` |
| `(array-dot u v)` | `(array-sum (* u v))` |
| `(array-gather! dst src idx)` | `dst[i] = src[idx[i]]` -- numpy's `dst = src[idx]`; iterations independent, so `-P omp` parallelises them |
| `(array-permute! a idx)` | `a = a[idx]` in place, through a temporary |
| `(row-inc! a i e)`, `(row-dec! a i e)` | row `i` of 2-D `a`, `+= e` / `-= e`; with more indices, `(row-dec! a i j e)`, the fiber `a[i,j,:]` of a rank-3 `a` |
| `(col-inc! a j e)`, `(col-dec! a j e)` | column `j` of 2-D `a`, `+= e` / `-= e` (strided); `(col-dec! a j k e)`, the fiber `a[:,j,k]` |
| `(array-set! y e)` | `y = e` for a vector expression `e`; for a 2-D `y` and a matrix expression `e`, the whole matrix (`array-inc!`/`array-dec!` likewise) |
| `(array-set! g (matmul x (transpose x)))` | the Gram `g = x x'` over the rows of 2-D `x`, numpy's `x @ x.T`; expands to the upper triangle plus its mirror.  `(matmul a (transpose b))` and `(matmul a b)` are the general products |
| `(array-set! c (matmul x v))` | `c = x v` for a vector `v` -- each row's dot product |
| `(array-dec! r (matmul (transpose x) d))` | `r -= x' d` for a vector `d`, a sum of scaled rows (`array-inc!`, `array-set!` likewise); with a matrix expression `d`, `r -= d' x` row by row |
| `(array-set! g (matmul (transpose x) x))` | the Gram of the *columns*, `g = x' x`, for an `x` declared `(n p)` -- the design stored n rows of p, numpy's C order; `(array-dec! r (matmul x d))` is the matching `r -= x d`, for a vector `d` or a matrix expression `d` (the matrix residual stored n rows of T) |
| `(array-set! y (contract (k ..) (i ..) (a la ..) (b lb ..)))` | the contraction, numpy's einsum: `y[i ..] = sum over k .. of a * b`, each operand's axes labelled in order (`(x k i)` is `x` with the summed index on its first axis); `a`, `b` a declared name of any rank or an expression over such names of one shape; `array-inc!` / `array-dec!` for `+=` / `-=`.  Every `matmul` above is a two-index contraction, and this is what `--derive` writes: `(contract (i) (k1 k2) (x k1 i) (x k2 i))` is the Gram, with the operands cut either way and at any rank.  A label that both operands and `y` carry in front, unsummed, is a batch (`(contract (k) (l i j) (e l i k) (e l j k))`: one product per slab `l`) |

A *vector expression* is a declared 1-D name, `(row a j)` (array-curry
at expansion time) or `(col a j)` (the column, strided) -- with more indices, `(row a i j)` / `(col a j k)`, a fiber of a rank-3 array along its last / first axis -- a `(slice u lo hi)` or `(slice u lo hi step)` --
numpy's `u[lo:hi:step]` with the half-open interval -- `(+ - *)` over
vector expressions with scalars broadcasting, or `(scale c v)`, the
scalar multiple named as such.  A *matrix expression* is a declared
2-D name or `(+ - *)` and `(scale c m)` over such.  The expression
tree stays visible until expansion, so the derivation can act on the
algebra: `y -= coef*u` is `(array-dec! y (scale coef u))`, not a fused
primitive hiding its own structure.  The `matmul` forms are what the
derivation writes for the products it hoists, and what `--blas` /
`--cublas` replace by one library call each (the loop nest is the
meaning; the call is the same product from a library).

### Idioms the subset expects

- No union types: "a vector or `#f`" does not translate.  Use a
  preallocated buffer plus a 0/1 flag.
- No heterogeneous pair returns: `(cons vec num)` as a result does not
  translate.  Use an out-parameter plus a scalar return.
- Loops are `do` or named `let`; a loop's non-recursive tail is `#f`
  by convention.
- Plain arrays are flat with explicit index arithmetic
  (`(+ (* i n) j)`) -- or use the array layer above, which expands to
  the same thing.
- Multiplying by `(* 1.0 n)` rather than `n` is the idiom for forcing
  a parameter to a floating type when nothing else constrains it.
- A name that spells a C++ keyword (`new`, `case`, `int` ..) is
  emitted with the suffix `_scm`: `new` becomes `new_scm`.

## Tests

```console
$ raco link --user vendor/rkanren    # once, if you have not already
$ ./run-tests.sh                     # reports PASS=203 FAIL=0 (fewer without cuBLAS, cblas.h or OpenMP); exits non-zero on any failure
$ TIMEOUT=600 ./run-tests.sh /tmp/result.txt      # longer budget, chosen log
```

The suite's 194 checks are the 37 programs listed in `CASES=`, the
`probe/` programs again under `--derive`, `--blas`, `--cublas` and
`--cuda`, the `CASES=` programs again under the relational inference,
and the unit tests.  Each program is translated, compiled,
run, and then **its output is compared against what the same program
prints under Racket**. All four steps
must succeed. The first three only show that the pipeline still works; the
comparison is what shows the translation still means what the Scheme means.

Scheme is the specification, so there are no expected-output files to drift out
of date. `test-oracle.rkt` supplies both halves and can be used on its own:

```console
$ racket test-oracle.rkt run bench/sqrttest.scm        # what Racket prints
$ racket test-oracle.rkt diff racket.out cpp.out       # compare two outputs
```

It reads a program the way the translator's pre-pass does rather than the way
`#lang racket/base` would: `define-macro` is expanded, a one-armed `(if c t)`
is legal, `force` accepts a bare thunk, and `make-promise` takes a thunk and
memoises it as `scm2cpp.hpp` does. Numbers are compared to a relative
tolerance (`SCM2CPP_TOL`, default `1e-5`) because C++ prints six significant
digits where Racket prints all of them -- `2.0` and `2`, or
`3.00009155413138` and `3.00009`, agree; everything else must match exactly.
A number embedded in a larger token (`beta_hat=0.000436075`) is compared as a
number, with the surrounding text matched literally.

The same suite runs on GitHub Actions (`.github/workflows/tests.yml`) on every
push and pull request, by way of the install steps above, so a break in those
instructions shows up there rather than in a reader's first ten minutes.

A case whose `main` prints nothing fails as `FAIL(no output)`: there would be
nothing to compare, and a case that compares equal to anything is the hole
this step exists to close.

Two consequences worth knowing when writing a new case. Scheme integers are
unbounded and C++ `int` is not, so arithmetic that overflows 32 bits makes the
two sides disagree -- by design, and the suite now says so instead of passing
(this is why the sample generators use small multipliers). And a program whose
run time is dominated by a long benchmark loop will be slow under the
interpreter, since the oracle executes the whole program.

### Binding a user's C++ template (`--binding`)

A binding file declares how a header of the user's own is seen from
Scheme: a type constructor for the inference, one entry per operation for
the code generator, a pure Scheme model of each operation, and a test.
With it, `(mat-ref m r j)` translates to `m.at(r,j)`, `m` is typed
`foo::Matrix< double >`, and the header joins the includes; the Scheme
program never mentions C++. Loading a binding executes nothing -- the
declarations are data, and the models run only inside the checking gate:

```console
$ racket binding-check.rkt -I examples/custom-template \
    examples/custom-template/foo-binding.scm
```

runs every `binding-test` twice, once in Racket over the models and once
translated against the real header, compiled and executed, and compares
the output. What the models assert about the header is thereby checked
by running both, to the same standard the derivation is held to; a
header that stores column-major while the model says row-major is caught
as a printed disagreement. `examples/custom-template/` is a complete
worked example.

### Calling the translated functions from Python (`-M`)

`-M` emits two more artifacts next to the usual pair: `NAME_capi.cpp`,
an `extern "C"` wrapper over every translated non-template function --
scalars pass through, array parameters become element pointers
-- and `NAME.py`, a ctypes loader that checks each numpy array's dtype
and size against the declared signature before handing it in. Arrays a
function mutates are mutated in place, so coefficients written by a
solver land in the caller's array:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M kernel.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libkernel.so kernel_capi.cpp
$ python3 -c 'import kernel; kernel.lasso(x, beta, resid, xnorm, 0.02, 20000, 360, 40)'
```

A parameter whose extent no call site pins down comes out as
`std::vector<double>` and crosses as a pointer plus a length; one that a
caller creates with `make-vector` keeps its `std::array<double,N>` and
crosses as a pointer alone. A kernel written to be called from outside,
with no `main` of its own, therefore needs no annotation to be exposed --
see `examples/kernel-only/`. Functions whose signature still does not
cross -- unions, closures, lists -- are skipped and named in a comment
rather than silently. On the
worked example the kernel called this way agrees with scikit-learn's
Lasso to 5e-11.

## Verifying the inference against Typed Racket

The Hindley-Milner pass and the emitter are one implementation; a bug
there produces wrong C++ with no independent witness. `verify-tr.rkt`
turns the inferred types into Typed Racket annotations, writes the
program out as a `typed/racket` module, and lets a second, unrelated
type checker read it:

```console
$ racket verify-tr.rkt prog.scm
OK: Typed Racket agrees (Real level)
```

The check runs at the Real level of the numeric tower, deliberately.
Typed Racket types `(* 2.5 i)` as `Real`, not `Flonum`, and it is right:
Racket's exact zero survives multiplication by a float, so the Flonum
level genuinely does not describe the program's Racket semantics. What
is verified is the structure -- what is a function and what it takes,
what is a vector and of what, where a value is discarded -- and the
int-against-double decision stays with the inference pass, which the
C++ needs it from. A binding pair misread as an application, an argument
list of the wrong length, a scalar where a vector was meant: Typed
Racket rejects all of these outright, which is precisely the class of
front-end bug that once slipped through.

Of the 37 programs in the suite's `CASES=`, 36 check, under either
inference (Hindley-Milner, the default, or `SCM2CPP_RELATIONAL=1`, whose
types Hindley-Milner realises).  The one that does not uses delayed
streams, which have no ground Typed Racket rendering here and are
declared out of scope.  (`--keep` keeps
the generated module beside the source for inspection.)  Hash tables
are rendered as `Mutable-HashTable` -- a `hash-ref` default is handed
over as a thunk, the only failure result Typed Racket types -- and
`memo-call` / `memo-range` have shims, the table keyed by a string as
the C++ keys it by the key's bytes.

## The runtime header

`scm2cpp.hpp` can also be used on its own, without the translator. It gives
Lisp operators over the usual C++ containers, so that `car`, `cdr`, `cons` and
`list-ref` apply to

    std::vector    std::list    std::array    boost::fusion::list

with `std::pair` treated as a cons cell. `eq?`, `eqv?`, `equal?`, `quote` and
the symbol operations are provided as well. `eq?` is address comparison,

```cpp
template<typename T>
bool is_eq(T & x, T & y) { return (&x)==(&y); }
```

`cons` and `cdr` over a uniform sequence answer with a `std::list` copy,
which is the persistent semantics Scheme means; an earlier version handed
back a `boost::ptr_container` view sharing the caller's storage, and that
dependency is gone.

A numeric program gets a smaller header still. When the generated text
stays inside the numeric subset -- no closures, no lists, no promises --
the translator defines `SCM2CPP_MINIMAL`, and the header is then std-only
and compiles with no boost include at all, which is what lets nvcc take
it.

See `usage.cpp`, `list-test.cpp` and `equal-test.cpp` for worked examples.
