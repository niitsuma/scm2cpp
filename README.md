# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml)

*[Japanese (README.ja.md)](README.ja.md)*

Scm2Cpp translates a subset of Scheme into C++ that a person can read and edit.

Unlike conventional Scheme compilers, which emit C intended only for a machine,
Scm2Cpp gives Scheme values no runtime representation: an integer becomes an
`int`, a vector becomes a `std::array<double,1025>`, and `(car x)` becomes
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

## Example: a fast lasso, from Scheme to pip and the GPU

The repository's flagship product is a lasso solver: written as plain
Scheme (`examples/kernel-only/lasso-cov.scm`), translated to C++,
packaged for pip, and batched onto CUDA -- the same generated
functions at every step.

```console
$ pip install scm2cpp-lasso      # needs a C++17 compiler; Racket not required
```

That command works today: the package is on PyPI as
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/), and what it
installs is the C++ this repository generates from the Scheme, with no
Racket at the far end.

Three of a hundred candidate columns carry the signal; the solver is
asked which, and answers with them and nothing else:

```python
import numpy as np
from scm2cpp_lasso import CovLasso

rng = np.random.default_rng(0)
X = rng.standard_normal((500, 100))          # 500 rows, 100 candidates
beta = np.zeros(100)
beta[[7, 23, 61]] = [2.0, -1.5, 0.8]         # only three of them matter
y = X @ beta + 0.1 * rng.standard_normal(500)

model = CovLasso(X, y)                       # the Gram matrix, built once
path = model.fit_path(model.lambda_grid())   # 100 lambdas, warm-started

fit = path[60]
for j in np.flatnonzero(np.abs(fit) > 1e-6):
    print(f"  x{j:<3} {fit[j]:+.3f}")
```

```console
  x7   +1.965
  x23  -1.474
  x61  +0.770
```

The other 97 are exactly zero -- that is what the penalty is for -- and
the coefficients are the planted ones, shrunk toward zero by it. Two
further calls cover the rest of the interface:

```python
grid = model.fit_path_batch(lambdas)         # every lambda from zero; GPU if present
betas = model.bootstrap(lam, n_boot=500)     # resamples refit as one batch
```

`bench/lasso-table.py` produces the numbers below on an RTX 4090 and
an i9-10900X: an ordinary dense design, p=200 columns, n=1800 rows, a
4096-lambda grid, every lambda solved from zero -- the shape of a
cross-validation grid, where no warm start is available.  Both sides
start from the same design matrix, so building the Gram matrix is
inside the translated kernel's time, and BLAS is pinned to one thread
so that the CPU row is one core against one core.  The translated
kernel is asked for tol=1e-8 against sklearn's default of 1e-4, so the
comparison is conservative: it solves to the tighter tolerance of the
two, and the GPU and CPU answers agree to 1.3e-15.

| solver                                        | time    |
|-----------------------------------------------|---------|
| sklearn `Lasso.fit` per lambda, cold          | 31.9 s  |
| translated cov kernel, 1 CPU core, cold       | 1.3 s   |
| translated cov kernel, GPU, one thread/lambda | 0.2 s   |

On the sequential single-path workload, where warm starting is
available to both sides, the two are level: on a 400-lambda path,
0.058 s against sklearn's 0.078 s at its default tolerance of 1e-4,
and 0.101 s against 0.090 s when both are asked for 1e-8, where the
coefficients agree to 7e-9.  The gap opens where the work is not
sequential, which is what the table above measures.

### Against the other lassos pip can install

`bench/lasso-compare.py` runs the same cold grid against every lasso a
`pip install` can produce here -- scikit-learn 1.9.0, celer 0.7.4,
skglm 0.5, and RAPIDS cuML 26.8 -- each at its own default tolerance
with one untimed warm-up fit (so numba compilation stays off the
clock), cuML's data resident on the device before the clock starts.
The last column is each solver's objective minus ours at the smallest
lambda, so a fast row with a loose answer would be visible as one:

| solver                                 | time    | objective gap |
|----------------------------------------|---------|---------------|
| scm2cpp-lasso, 1 CPU core (tol 1e-8)   | 0.9 s   | 0             |
| scm2cpp-lasso, GPU, one thread/lambda  | 0.2 s   | 0             |
| sklearn `Lasso.fit` per lambda         | 12.5 s  | +1.6e-09      |
| celer per lambda                       | 17.3 s  | 0             |
| skglm per lambda                       | 16.4 s  | +2.8e-17      |
| cuML per lambda, GPU                   | 57.5 s  | +9.1e-07      |

Two honest notes.  celer and skglm are built for a different regime --
very large, sparse designs, where their screening rules dominate; at
p=200 dense they pay their setup per fit and never get to shine.  And
cuML parallelises *within* one fit, which wins when one fit is large;
at this size its per-fit launch overhead dominates, while our GPU row
parallelises *across* lambdas -- one CUDA thread per penalty -- which
is the axis a cross-validation grid actually offers.  The R glmnet,
ancestor of this whole algorithm family, has no Python port that still
builds; it is represented by the family it defined.

`CovLassoCV` is scikit-learn's `LassoCV` over this machinery -- same
grid construction, same contiguous folds, same minimum-mean-MSE choice
-- with two structural savings.  A fold's training Gram is a
*subtraction* (the Gram is additive over rows, so G - Xf'Xf costs one
fold's work where rebuilding costs four folds'), and once the Grams
exist nothing downstream ever touches the n rows again -- which is why
the gap grows with n.  On the GPU every fold and every alpha can run
as one thread of a single launch; that launch replicates each fold's
Gram per alpha, so the default picks a side by the replication's size
-- CUDA under 512 MB, the CPU warm path above it (`force_cpu` and
`force_gpu` override).  Measured at cv=5, 100 alphas, one CPU core,
sklearn 1.9.0, best of three runs:

| n       | p    | CPU    | CUDA (forced) | sklearn `LassoCV` |
|---------|------|--------|---------------|-------------------|
| 1,800   | 200  | 0.13 s | 0.20 s        | 0.09 s            |
| 5,000   | 1000 | 1.4 s  | 6.0 s         | 1.0 s             |
| 100,000 | 200  | 0.39 s | 0.40 s        | 2.1 s             |
| 100,000 | 500  | 1.2 s  | 1.6 s         | 5.5 s             |

The CUDA column is honest about what CV offers a GPU: cv x 100 = 500
independent problems tie the warm CPU path where the replication is
small and lose where it is gigabytes -- 500 threads do not fill a
device the way `fit_path_batch`'s thousands do, so the CV win is
structural (the Gram subtraction and the warm path), not the GPU's,
and the default never takes the 6.0 s cell (the heuristic already sits
on the CPU side there).  Large n is where the machinery pays: nothing
downstream of the Grams touches the 100,000 rows again.  At n=5,000,
p=1000 sklearn's raw-X descent is genuinely faster than our Gram-heavy
path.  CPU and CUDA choose the same alpha everywhere and agree to
1e-14; against sklearn the pick is exact at n=5,000 and one grid step
apart on a near-tie elsewhere (mean-MSE relative gap at most 2.6e-4),
and sklearn at tol=1e-10 picks our alpha at every size.

`CovMultiTaskLasso` and `CovMultiTaskLassoCV` are the multi-task
family over the same machinery: scikit-learn's `MultiTaskLasso`,
`MultiTaskElasticNet` (through `l1_ratio`), `MultiTaskLassoCV` and
`MultiTaskElasticNetCV`.  The penalty ties each feature's row of W
together across tasks, so the coordinate update becomes a block soft
threshold on the row's L2 norm; C = X'Y - GW is maintained per task
exactly as the single-task C is, and nothing downstream of the Grams
touches the n rows -- the kernel is the same translated Scheme
(`mt-descend`).  Folds are independent and both the descent (ctypes)
and the products (BLAS) release the GIL, so `n_jobs` threads scale the
CV across folds; the default is sequential, as scikit-learn's
`n_jobs=None` is, and the benchmark pins BLAS to one thread on both
sides either way.  Same protocol as above, 8 tasks; single fits at
alpha = 0.1 lambda_max; the CV pairs share the 100-alpha grid:

| estimator             | n       | p   | ours   | ours `n_jobs=5` | sklearn |
|-----------------------|---------|-----|--------|-----------------|---------|
| MultiTaskLasso        | 100,000 | 200 | 0.15 s | --              | 0.80 s  |
| MultiTaskLasso        | 100,000 | 500 | 0.53 s | --              | 1.9 s   |
| MultiTaskLassoCV      | 1,800   | 200 | 1.5 s  | 0.33 s          | 0.51 s  |
| MultiTaskLassoCV      | 100,000 | 200 | 1.6 s  | 0.62 s          | 76 s    |
| MultiTaskElasticNetCV | 1,800   | 200 | 1.6 s  | 0.51 s          | 1.0 s   |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 s  | 0.68 s          | 164 s   |

(`MultiTaskElasticNet` single fits time the same as `MultiTaskLasso`'s.)
At n=1,800 our sequential CV is slower than sklearn's: the default
tol=1e-8 runs more sweeps than sklearn's 1e-4 dual-gap stop, and at
that size there are no rows to save.  At n=100,000 the Gram route is
48x and 100x ahead, essentially unchanged from n=1,800 in absolute
time.  Coefficients agree with scikit-learn's to 1e-15 at tight
tolerance, and the CV pair picks the same alpha with coefficients to
1e-13.

#### Trading the speed back for memory

Everything above buys its time with a p x p Gram matrix.  The other
choice is `examples/kernel-only/lasso-kernel.scm`: residual-form
coordinate descent that keeps one n-vector beyond X and reads a
column of X twice per coordinate -- the algorithm inside
scikit-learn's `Lasso(precompute=False)`, and the program a memory
objective would keep, since the covariance rewrite is exactly the
step that allocates the p x p block.  The two are one program at two
ends of a derivation: `--derive` turns `lasso-kernel.scm` into the
Gram form.  The kernel declares its shapes (`(with-arrays ((x (p n))
(resid (n)) ..) ..)` at the head of the body, which changes nothing in
the plain translation); the derivation raises the flat loops to the
array algebra, sees the residual updated by a scaled row of X and read
only in the dot product against another row, and replaces the residual
by the memo `c = X'r` maintained through a Gram matrix.  Since the
kernel skips the residual update of a coordinate that did not move, and
stops after a sweep in which none did, both come through untouched to
the update of `c` and to the sweep loop of the derived form.  The
loop nests the differencing hoists are folded to whole-array
products (`derive: lasso: raise differencing matmul`): the Gram
`(array-set! g (matmul x (transpose x)))`, the memo's build
`(array-set! c (matmul x resid))`, and the residual's restore
`(array-dec! resid (matmul (transpose x) (- beta b0)))` -- for the
multi-task kernel the matrix forms of the same three.  Each expands
to its loop nest (the Gram to the upper triangle and its mirror), and
`--blas` replaces each by one CBLAS call -- `dsyrk`, the same product
the package hands to BLAS -- so the derived kernel then runs at the
package's speed (table below; without `--blas` it is correct but forms
the Gram matrix with a scalar loop nest, and that O(np^2) dominates).
`--cublas` does the same through cuBLAS, the design matrix uploaded
once.  The kernel
takes a path of penalties, each fit warm-started from the last, and
that too the derivation sees: the sweep it differences is the whole
loop over penalties, so the Gram matrix is built once in front of it
and `c` is carried across the warm starts, as the package does.  `-S`
alongside `--derive` writes the derived program to
`lasso-kernel.expanded.scm`, plain Scheme the translator accepts again;
the tree keeps that file beside the kernel, to read against the
hand-written `lasso-cov.scm`.
`bench/lasso-memory-compare.py` puts the
two forms against scikit-learn's two forms at *equal work*: columns
AR(1)-correlated (rho 0.9) so that the descent takes a realistic
number of sweeps, scikit-learn's own convergence deciding that number
S, and every row then running exactly S sweeps at the same lambda
(0.01 lambda_max), one CPU core, X already in each side's layout.
`bench/resid-cd.cu` is the residual form with the two length-n loops
of a coordinate step spread across one GPU, a grid barrier between
them; it is hand-written for the measurement, not translator output.

| solver (S = 43 / 35 / 44 / 29 sweeps)         | 1,800 x 200 | 5,000 x 1000 | 100,000 x 200 | 100,000 x 500 |
|-----------------------------------------------|-------------|--------------|---------------|---------------|
| sklearn `Lasso(precompute=False)`             | 0.014 s     | 0.38 s       | 1.8 s         | 2.8 s         |
| `lasso-kernel.scm`, `-O3 -march=native`       | 0.023 s     | 0.39 s       | 2.2 s         | 3.6 s         |
| `lasso-kernel.scm`, same plus `-ffast-math`   | 0.010 s     | 0.26 s       | 1.7 s         | 2.8 s         |
| residual form on the GPU (`resid-cd.cu`)      | 0.034 s     | 0.17 s       | 0.90 s        | 1.5 s         |
| sklearn `Lasso(precompute=True)`              | 0.005 s     | 0.13 s       | 0.17 s        | 0.60 s        |
| `CovLasso`, Gram build included               | 0.005 s     | 0.12 s       | 0.15 s        | 0.50 s        |
| `lasso-kernel.scm --derive`, products as loops | 0.035 s   | 4.7 s        | 4.5 s         | 28 s          |
| `lasso-kernel.scm --derive --blas`, `-lopenblas` | 0.002 s  | 0.094 s      | 0.16 s        | 0.58 s        |
| `lasso-kernel.scm --derive --cublas`, upload included | 0.002 s | 0.032 s   | 0.061 s       | 0.16 s        |
| extra memory, residual form / Gram form       | 14 KB / 312 KB | 39 KB / 8 MB | 781 KB / 312 KB | 781 KB / 2 MB |

The three `--derive` rows are from a later run of the same script, in
which `CovLasso` measured 0.002 / 0.108 / 0.155 / 0.51 s and
`Lasso(precompute=True)` 0.004 / 0.099 / 0.175 / 0.60 s: the derived
kernel with `--blas` sits between the hand-written package and
scikit-learn on every shape, 50x faster than its own loop nests at the
largest, and `--cublas` is 3-4x faster again with the upload of X
counted.

So the memory-lean form runs at scikit-learn's speed, as it should --
same algorithm -- with two conditions that the measurement made
visible.  The kernel must skip the residual update of a coordinate
that did not move (scikit-learn does; most coordinates of a sparse
solution are such; the kernel now does, and it was 1.5-2.5x slower
before), and the compiler must be allowed to reorder the dot
product's additions: the translator writes the strict sequential sum,
which gcc will not vectorise, while scikit-learn's BLAS `ddot` never
promised that order.  The GPU buys the residual form 1.6-1.9x over
scikit-learn from n=5,000 up and loses at n=1,800, where two grid
barriers per coordinate cost more than the 1,800 multiplications they
fence -- a coordinate step is a reduction, and the barrier is the
price the CPU never pays.  And the Gram form stays 10x ahead of
either at n=100,000 for 312 KB to 8 MB: on a single fit our Gram form
and scikit-learn's `precompute=True` are the same speed (the CV wins
above are the Gram subtraction and the warm path, not this kernel).
All rows agree with the scikit-learn reference to 1e-15 (the two Gram
rows to 1e-13, the order of the Gram's summation differing).

How each piece works is below: the Python packaging under "Installing
the solvers from PyPI", the boundary-free `-M` interface under
"Calling the fast lasso from Python", and the CUDA profile under
"Running on the GPU".

## Installation

Requirements:

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
$ ./run-tests.sh                         # should report PASS=54 FAIL=0
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
| `--blas` | emit the whole-array products (`matmul`: the Gram `g = X X'` the derivation hoists, `c = X r`, `r -= X' d`, and the general `a b'`, `a b`, `r -= d' x`) as CBLAS calls (`dsyrk`, `dgemv`, `dgemm`) through the binding `bindings/cblas-binding.scm` -- the same custom-binding mechanism a user's own C++ goes through, so the ops are declared, modelled and checked like any other.  The generated header includes `scm2cpp-blas.hpp`; link with `-lopenblas` (or your CBLAS).  Off, each product is the loop nest it always was, so a program never depends on BLAS unless asked; a product operand that is an expression is materialised first, and a product shape the binding does not declare is left to expand |
| `--cublas` | the same products as cuBLAS calls through `bindings/cublas-binding.scm`: a matrix the function only reads is uploaded once at the head of its `with-arrays` scope (`dmat-upload`), one it writes is copied at each call, and each op runs on the device and copies its result back.  The header includes `scm2cpp-cublas.hpp`; compile with the CUDA include path and link `-lcublas -lcudart` (a plain host compiler suffices; nothing is a kernel).  Worth it only when the product dominates -- the copies are the price |
| `--derive` | derive the covariance form of a coordinate descent from the array shapes its function declares (`with-arrays` at the head of the body: rank two are matrices, rank one are vectors). The residual sweeps are raised to the array algebra, the scratch vector's update is differenced into a memo maintained by a hoisted Gram matrix, and the residual is restored at the end when the caller reads it (the liveness pass decides). A function without a declaration is left alone; a program without one translates byte-identically. `derive: NAME: raise differencing` on stderr reports what fired; `-S` saves the derived program as Scheme |
| `--binding FILE` | map declared operations onto a user-supplied C++ header per FILE; see `examples/custom-template/` |
| `-M` | besides the executable sources, emit `NAME_capi.cpp` (extern "C" wrappers) and `NAME.py` (a ctypes loader), so the translated functions can be called from Python on numpy arrays |
| `--llm-hints CMD` | run CMD with the source on stdin; its stdout is taken as space-separated array names for `-I`. Off unless given -- CMD is not part of Scm2Cpp, typically a wrapper around a locally hosted model |

Environment variables:

| variable | meaning |
|---|---|
| `SCM2CPP_RELATIONAL=1` | relational type inference (also `--inference relational`): the recursive-miniKanren typing relation, with the original relational derivation as its fallback |
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

Threads are not free, so an annotated loop also carries a guard:
`#pragma omp parallel for if(p > 1024)`. A loop whose trip count is a
literal below the threshold is left unannotated instead. The threshold is
`SCM2CPP_OMP_MIN` (default 1024); the point of deciding at runtime is that
one translated kernel may be called with a hundred columns and with a
hundred thousand.

`./run-tests-omp.sh` checks this the way `run-tests.sh` checks the serial
output: it translates with `-P omp`, compiles with `-fopenmp`, and compares
the result with Racket, several runs per case, since a race need not lose
every time.

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
tally). The `define-memo` macro there is ordinary `define-macro`
source; note that the memoised body's statements must stay in
statement position, since a `(begin ..)` bound by `let` would have to
become a C++ expression.

A top-level `(include "file.scm")` stands for the forms of that file, as
Racket's `include` does: the path is relative to the file the form is
written in, and the included file may include others. The splice is
textual and happens before anything reads the program, so the
translator, the oracle, the proposers and `-S` all see one program;
`-M`'s Python loader and the generated C++ do not know the difference.
The lasso kernels under `examples/` share their `soft-threshold` this
way (`examples/kernel-only/soft-threshold.scm`) rather than by copy.

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
| `(array-sum e)` | sum of a vector expression |
| `(array-reduce op id e)` | the same fold under `+` `*` `min` `max` with identity `id` |
| `(array-set! s i j (array-sum (box v i j)))` | prefix box sum: `s[i,j]` gets the fold of `v` over `[0,i]x[0,j]` |
| `(array-sum (sub a lo1 hi1 ...))` | sum over the hyperrectangle -- numpy's `a[lo1:hi1, ...].sum()` |
| `(array-dot u v)` | `(array-sum (* u v))` |
| `(array-gather! dst src idx)` | `dst[i] = src[idx[i]]` -- numpy's `dst = src[idx]`; iterations independent, so `-P omp` parallelises them |
| `(array-permute! a idx)` | `a = a[idx]` in place, through a temporary |
| `(row-inc! a i e)`, `(row-dec! a i e)` | row `i` of 2-D `a`, `+= e` / `-= e` |
| `(array-set! y e)` | `y = e` for a vector expression `e`; for a 2-D `y` and a matrix expression `e`, the whole matrix (`array-inc!`/`array-dec!` likewise) |
| `(array-set! g (matmul x (transpose x)))` | the Gram `g = x x'` over the rows of 2-D `x`, numpy's `x @ x.T`; expands to the upper triangle plus its mirror.  `(matmul a (transpose b))` and `(matmul a b)` are the general products |
| `(array-set! c (matmul x v))` | `c = x v` for a vector `v` -- each row's dot product |
| `(array-dec! r (matmul (transpose x) d))` | `r -= x' d` for a vector `d`, a sum of scaled rows (`array-inc!`, `array-set!` likewise); with a matrix expression `d`, `r -= d' x` row by row |

A *vector expression* is a declared 1-D name, `(row a j)` (array-curry
at expansion time), a `(slice u lo hi)` or `(slice u lo hi step)` --
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
- Generated identifiers are not escaped against C++ keywords: name a
  variable `bnew`, not `new`.

## Tests

```console
$ raco link --user vendor/rkanren    # once, if you have not already
$ ./run-tests.sh                     # reports PASS=54 FAIL=0; exits non-zero on any failure
$ TIMEOUT=600 ./run-tests.sh /tmp/result.txt      # longer budget, chosen log
```

Each of the 31 programs is translated, compiled, run, and then **its output is
compared against what the same program prints under Racket**. All four steps
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

## Installing the solvers from PyPI

The solvers have packages of their own, so a Python user needs neither
Racket nor this repository:

```console
$ pip install scm2cpp-lasso     # lasso over a Gram matrix, any design
$ pip install scm2cpp-tfs       # moving-average feature selection
```

Both are published:
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/) and
[scm2cpp-tfs](https://pypi.org/project/scm2cpp-tfs/). The worked
example at the head of this file runs against the published package as
written.

```python
from scm2cpp_lasso import CovLasso
model = CovLasso(X, y)
path = model.fit_path(model.lambda_grid())

from scm2cpp_tfs import TemporalLasso
model = TemporalLasso(series, wmax=200, nobs=1800)
path = model.fit_path(y, model.lambda_grid(y))
yhat = model.predict(path[-1])           # no design matrix, ever
```

The C++ each compiles is committed under `python/`, generated from
`examples/kernel-only/` by that package's `regenerate.sh` -- so
installing needs a C++17 compiler and nothing else, and only
regenerating needs the translator.  `nvcc` at install time additionally
builds a batched GPU path, where one CUDA thread owns one lambda;
without it the packages install and work the same, minus that one
method.  `python/` is where such packages live, one directory each, and
`python/README.md` says what distinguishes them.

## Calling the fast lasso from Python

`-M` emits an `extern "C"` wrapper and a ctypes loader beside the
library, so a translated kernel is importable:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/lasso-cov.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o liblasso-cov.so lasso-cov_capi.cpp
```

No boost include is needed: a numeric kernel gets the minimal runtime.
Array arguments are passed as pointers into the caller's numpy buffers
-- the parameters are `scm2cpp::span` views -- so the kernel reads and
writes them in place and nothing is copied at the boundary.

`examples/kernel-only/fast-lasso.py` wraps the four generated functions
in a small class.  The design matrix is never formed: `build_S` turns
the base series into lag sums, `build_P` into cross-products with the
target, `build_G` assembles the Gram matrix, and `cov_descend` then
costs O(p) per coordinate instead of O(n).  Because the descent resumes
exactly where it stopped, a whole regularization path is walked warm,
each lambda starting from the previous solution:

```python
model = TemporalLasso(series, wmax=200, nobs=1800)   # Gram built once
path = model.fit_path(y, lambdas)                    # one row per lambda
```

```console
$ python3 examples/kernel-only/fast-lasso.py
strongest windows at the end of the path: [1, 2, 4, 5, 20]  (the target was built from 5 and 20)
scm2cpp path of 400 lambdas: 0.107s
sklearn lasso_path (same grid, warm):  0.095s
objective gap vs sklearn: max +1.67e-16 (negative means ours is lower)
```

Warm against warm the two are neck and neck, on solutions that agree to
rounding.  The gap opens where the work is not sequential -- a
cross-validation grid, where each fold starts cold -- which is what the
GPU section below measures.

## Running on the GPU, measured against sklearn

Generated code whose text stays inside the numeric subset gets the
minimal runtime (`SCM2CPP_MINIMAL`): no boost headers, C++17, and
device-safe functions marked `__host__ __device__` under nvcc.  Array
parameters are `scm2cpp::span` views -- one pointer, implicit from
`std::vector` or `std::array` on the host, from a raw device pointer in
a kernel -- so the same translated functions compile with g++ and nvcc
unchanged.

`cuda/batch-lasso.cu` runs the translated covariance-update lasso
(`examples/kernel-only/lasso-cov.scm`) as a batched regularization
path: one CUDA thread per lambda, coordinate descent sequential inside
each problem, every thread sweeping in chunks until its largest
coefficient move falls below tolerance.  `cuda/compare-sklearn.py`
rebuilds the same problem in numpy and times scikit-learn on the same
grid, checking solutions by objective value rather than trusting wall
clocks.

The numbers are in the example at the top of this README: cold
against cold the translated kernel is ~22x sklearn on one core and
the GPU batch another ~10x on top, at objective parity, with the
sklearn-cold row estimated from 256 fits.  The check `run-tests.sh`
runs where nvcc and a device exist uses a small instance of the same
program.

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

Of the regression suite's thirty-one programs, thirty check; the one
that does not uses delayed streams, which have no ground Typed Racket
rendering here and are declared out of scope (`--keep` keeps the
generated module beside the source for inspection).

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

## Documentation

- `CHANGES.ja.md` - a record of the modifications made to the historical code
  base, with the reason for each
- `ideal/stream-ideal-new.cpp` - the intended shape of the generated code for
  delayed streams, written by hand

## Contributing

See `CONTRIBUTING.md`.

## License

MIT License; see `LICENSE`, which carries the MIT terms and nothing else.

Several files derive from Aubrey Jaffer's Schlep and SLIB, and from utilities
published in Paul Graham's *On Lisp*; `vendor/rkanren` is a bundled
third-party library. These remain under their own permissive terms, which are
reproduced in full at the head of each file. Those conditions are additional
to the MIT terms and are recorded in `NOTICE`, together with the provenance
and the measured extent of each derivation -- not in `LICENSE`, so that the
licence file stays identifiable as plain MIT. Redistributors must honour them
in addition to the MIT terms.

## Citing

A paper describing the design is in preparation and is not in this repository
yet. Until it appears, cite the repository and the commit you used;
machine-readable metadata is in `CITATION.cff`.
