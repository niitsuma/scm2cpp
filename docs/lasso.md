# The lasso in detail

*[Japanese](lasso.ja.md)* · [README](../README.md)

The lasso solver that the README's first example introduces: the kernels, the comparisons with every lasso pip can install, cross-validation, the GPU batch, memory, and calling it from Python.

## Example: a fast lasso, from Scheme to pip and the GPU

The first example in detail is the lasso solver: written as plain
Scheme (`examples/kernel-only/lasso-cov.scm`, the descent over a Gram
matrix; `tfs-lasso-cov.scm` adds the Gram matrix of a moving-average
design, built without forming the design), translated to C++,
packaged for pip, and batched onto CUDA -- the same generated
functions at every step.  The `tfs-` prefix marks what is specific to
that time-series design; the rest takes any Gram matrix.

```console
$ pip install scm2cpp-learn      # needs a C++17 compiler; Racket not required
```

That command works today: the package is on PyPI as
[scm2cpp-learn](https://pypi.org/project/scm2cpp-learn/), and what it
installs is the C++ this repository generates from the Scheme, with no
Racket at the far end.

Three of a hundred candidate columns carry the signal; the solver is
asked which, and answers with them and nothing else:

```python
import numpy as np
from scm2cpp_learn import CovLasso

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
| sklearn `Lasso.fit` per lambda, cold          | 15.2 s  |
| sklearn, `precompute=True` (the `'auto'` choice at n > p), cold | 18.0 s |
| translated cov kernel, 1 CPU core, cold       | 0.95 s  |
| translated cov kernel, GPU, one block/lambda  | 0.045 s |

(scikit-learn 1.9.1, an otherwise idle machine.  `Lasso`'s default is `precompute=False`; the
`'auto'` of `lasso_path` and `LassoCV` takes the Gram route at this
n > p, which a cold fit pays for by rebuilding the Gram every time,
so it is the slower of the two here.)

On the sequential single-path workload, where warm starting is
available to both sides, the two are level: on a 400-lambda path,
0.057 s against sklearn's 0.053 s at its default tolerance of 1e-4,
and 0.071 s against 0.057 s when both are asked for 1e-8, where the
coefficients agree to 7e-9.  The gap opens where the work is not
sequential, which is what the table above measures.

### Against the other lassos pip can install

`bench/lasso-compare.py` runs the same cold grid against every lasso a
`pip install` can produce here -- scikit-learn 1.9.1, celer 0.7.4,
skglm 0.5, and RAPIDS cuML 26.8 -- each at its own default tolerance
with one untimed warm-up fit (so numba compilation stays off the
clock), cuML's data resident on the device before the clock starts.
The last column is each solver's objective minus ours at the smallest
lambda, so a fast row with a loose answer would be visible as one:

| solver                                 | time    | objective gap |
|----------------------------------------|---------|---------------|
| scm2cpp-learn, 1 CPU core (tol 1e-8)   | 0.91 s  | 0             |
| scm2cpp-learn, GPU, one block/lambda   | 0.044 s | 0             |
| sklearn `Lasso.fit` per lambda         | 9.6 s   | +1.6e-09      |
| sklearn, `precompute=True` (the `'auto'` choice at n > p) | 11.6 s | +1.6e-09 |
| celer per lambda                       | 13.5 s  | 0             |
| skglm per lambda                       | 14.5 s  | +2.8e-17      |
| cuML per lambda, GPU                   | 53.6 s  | +9.1e-07      |

One sitting, best of three runs, on an otherwise idle machine (load
2 on 20 threads; scikit-learn 1.9.1, celer 0.7.4, skglm 0.5, cuML
26.08 on CUDA 12.9, all in one venv).  `Lasso`'s own
default is `precompute=False`, and `'auto'` (the default of
`lasso_path` and `LassoCV`) would take the Gram route at this
n > p, which for a *cold* fit means rebuilding the p x p Gram from
the n rows every time -- so per cold fit it is 1.2x slower, not
faster, and the objective is the same.  The `Lasso` class accepts
only `True`/`False`, so the script spells the choice out.

Two honest notes.  celer and skglm are built for a different regime --
very large, sparse designs, where their screening rules dominate; at
p=200 dense they pay their setup per fit and never get to shine.  And
cuML parallelises *within* one fit, which wins when one fit is large;
at this size its per-fit launch overhead dominates, while our GPU row
parallelises *across* lambdas -- one block of CUDA threads per
penalty -- which is the axis a cross-validation grid actually offers.  The R glmnet,
ancestor of this whole algorithm family, has no Python port that still
builds; it is represented by the family it defined.

`CovLassoCV` is scikit-learn's `LassoCV` over this machinery -- same
grid construction, same contiguous folds, same minimum-mean-MSE choice
-- with two structural savings.  A fold's training Gram is a
*subtraction* (the Gram is additive over rows, so G - Xf'Xf costs one
fold's work where rebuilding costs four folds'), and once the Grams
exist nothing downstream ever touches the n rows again -- which is why
the gap grows with n.  With a GPU the whole grid is one launch: one
*block* of threads per (fold, alpha) cell, the fold's Gram read in
place (cv Gram matrices on the device, not cv x 100), thread 0 of the
block doing the coordinate step and the block spreading the O(p)
update of the correlations.  cv x 100 = 500 cells are too few
problems to fill a device one thread each, and a block per problem is
what turns that count into enough parallel work; `bench/cv-grid-designs.py`
times the alternatives (one thread per cell, warm runs of several
alphas per thread or block) side by side, and the block per cell wins
at every size tried.  The GPU is the default when a device answers
(`force_cpu` takes the warm CPU path).  Measured at cv=5, 100 alphas,
one CPU core, sklearn 1.9.1, best of three runs, whole estimator
including the Grams:

| n       | p    | CPU    | CUDA   | sklearn `LassoCV` |
|---------|------|--------|--------|-------------------|
| 1,800   | 200  | 0.21 s | 0.02 s | 0.10 s            |
| 5,000   | 1000 | 1.48 s | 0.25 s | 0.90 s            |
| 100,000 | 200  | 0.49 s | 0.34 s | 1.72 s            |
| 100,000 | 500  | 1.32 s | 1.09 s | 4.82 s            |

(Taken on an otherwise idle machine, load 2-3 on 20 threads.  sklearn's
`LassoCV` at its default `precompute='auto'` takes the Gram route at
every size here, n > p, rebuilding each fold's Gram from that fold's
rows where we subtract it from the whole.)  The grid
launch itself takes 9 ms at n=1,800 and 64 ms at n=5,000, p=1000; at
n=100,000 the CUDA column is nearly all Gram products, which the CPU
path pays as well.  Large n is where the machinery pays either way:
nothing downstream of the Grams touches the 100,000 rows again.  At
n=5,000, p=1000 sklearn's raw-X descent beats our Gram-heavy CPU path,
and the GPU makes up the difference three and a half times over.  CPU and CUDA
choose the same alpha everywhere and agree to 1e-14; against sklearn
the pick is exact at n=5,000 and one grid step apart on a near-tie
elsewhere (mean-MSE relative gap at most 2.6e-4), and sklearn at
tol=1e-10 picks our alpha at every size.

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
sides either way.  With a GPU the CV grid is one launch exactly as
`CovLassoCV`'s is, a block per (fold, alpha) cell with the p x T
coefficient block in shared memory (`force_cpu` opts out).  Same
protocol as above, 8 tasks; single fits at alpha = 0.1 lambda_max;
the CV pairs share the 100-alpha grid:

| estimator             | n       | p   | ours   | ours `n_jobs=5` | ours CUDA | sklearn |
|-----------------------|---------|-----|--------|-----------------|-----------|---------|
| MultiTaskLasso        | 100,000 | 200 | 0.14 s | --              | --        | 0.76 s  |
| MultiTaskLasso        | 100,000 | 500 | 0.53 s | --              | --        | 1.7 s   |
| MultiTaskLassoCV      | 1,800   | 200 | 1.4 s  | 0.51 s          | 0.07 s    | 0.42 s  |
| MultiTaskLassoCV      | 100,000 | 200 | 1.6 s  | 0.64 s          | 1.3 s     | 74 s    |
| MultiTaskElasticNetCV | 1,800   | 200 | 1.4 s  | 0.49 s          | 0.08 s    | 0.75 s  |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 s  | 0.68 s          | 1.3 s     | 162 s   |

(`MultiTaskElasticNet` single fits time the same as `MultiTaskLasso`'s;
every column was taken in one sitting on the idle machine of the
`CovLassoCV` table above, sklearn 1.9.1.  scikit-learn has no Gram
route for its multi-task estimators -- its path code sets
`precompute=False` for 2-D targets, "No Gram variant of multi-task
exists right now" -- so its column is raw-X descent at every n, which
is why it grows with n where `LassoCV`'s did not.)  At n=1,800 our sequential CV
is slower than sklearn's: the default tol=1e-8 runs more sweeps than
sklearn's 1e-4 dual-gap stop, and at that size there are no rows to
save -- and the GPU grid takes the whole thing in a tenth of a second.
At n=100,000 the Gram route is 46x and 100x ahead, essentially
unchanged from n=1,800 in absolute time; the CUDA column there is
the Gram products, the same ones the CPU path forms.  Coefficients agree with scikit-learn's to 1e-15 at tight
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
stops after a sweep in which none moved by more than `tol`, both come through untouched to
the update of `c` and to the sweep loop of the derived form.  The
loop nests the differencing hoists are folded to whole-array
contractions (`derive: lasso: raise differencing matmul guard`),
numpy's einsum with every index named on the axis it runs over: the
Gram `(array-set! g (contract (i) (k1 k2) (x k1 i) (x k2 i)))`, the
memo's build `(array-set! c (contract (i) (k) (x k i) (resid i)))`,
and the residual's restore
`(array-dec! resid (contract (j) (i) ((- beta b0) j) (x j i)))` -- for the
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
The derived form is not taken unconditionally.  It trades the
residual, n cells (a row of X long), for the memo `c = X'r`, p cells,
plus a p x p Gram built in O(np^2), and that pays only when p < n.
The shapes come from the declaration: X is `(p n)`, so the derivation
puts the derived body under `(if (< p n) ..)` and keeps the sweep as
written in the else branch (`guard` in the log).  This is the rule of
scikit-learn's `precompute='auto'` (Gram when `n_samples >
n_features`), derived from the plain coordinate descent rather than
written by hand; `probe/derive-lasso-wide.scm` (p > n) checks the
else branch of the derived translations.  The layout of X is not
fixed either: `probe/derive-lasso-col.scm` stores it n rows of p
(numpy's C order), so the sweep walks a column, `(col x j)`, and the
derivation produces the same memo and guard with `x' x`, `x' r` and
`r -= x d` in place of the three products above, lowered to the same
`dsyrk` and `dgemv` with the transposition flags flipped; the
multi-task kernel stored that way (`probe/derive-mt-col.scm`, the
residual n rows of T updated a column at a time) derives to `R'X`,
`X'X` and `R -= X (W - W0)` likewise.  Nor is the rank fixed:
`probe/derive-mt3.scm` lays the tasks out as an `nb x nt` grid, so
the coefficients are `p x nb x nt`, the residual `n x nb x nt`, and
a task's residual is a fiber `R[:,b,t]`; the derivation memoises
`C[b,t,j] = X[:,j] . R[:,b,t]` (an `nb x nt x p` table), keeps the
`p x nb x nt` snapshot for the restore, and writes the memo build and
the restore as the matrix products they are once the other axes are
flattened together -- `R'X` with `R` read as `n x (nb nt)`, `R -= X
(W - W0)` with `W` read as `p x (nb nt)` -- under a nested scope that
redeclares the rank-3 names as those matrices, so `--blas` sees two
`dgemm` calls.  The same holds for `x += a`:
a residual kept as `X beta - y` and updated by `r += x_j (bnew - old)`
raises to `array-inc!`, and the differencing moves the memo by `+G d`
and restores by adding `X'(beta - b0)` back
(`probe/derive-lasso-inc.scm`); a sweep that both adds to and
subtracts from the same scratch is left alone.
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
| sklearn `Lasso(precompute=False)`             | 0.006 s     | 0.13 s       | 1.05 s        | 1.9 s         |
| `lasso-kernel.scm`, `-O3 -march=native`       | 0.016 s     | 0.26 s       | 1.44 s        | 2.5 s         |
| `lasso-kernel.scm`, same plus `-ffast-math`   | 0.005 s     | 0.13 s       | 1.09 s        | 1.9 s         |
| residual form on the GPU (`resid-cd.cu`)      | 0.034 s     | 0.17 s       | 0.88 s        | 1.5 s         |
| sklearn `Lasso(precompute=True)`              | 0.002 s     | 0.069 s      | 0.11 s        | 0.42 s        |
| `CovLasso`, Gram build included               | 0.002 s     | 0.067 s      | 0.10 s        | 0.40 s        |
| `lasso-kernel.scm --derive`, products as loops | 0.032 s   | 3.0 s        | 3.0 s         | 18.6 s        |
| `lasso-kernel.scm --derive --blas`, `-lopenblas` | 0.002 s  | 0.067 s      | 0.11 s        | 0.42 s        |
| `lasso-kernel.scm --derive --cublas`, upload included | 0.002 s | 0.019 s   | 0.049 s       | 0.11 s        |
| `lasso-auto.scm --blas`, hand-written Gram route | 0.002 s | 0.067 s      | 0.11 s        | 0.42 s        |
| `lasso-auto.scm --cublas`, upload included    | 0.001 s     | 0.019 s      | 0.047 s       | 0.105 s       |
| extra memory, residual form / Gram form       | 14 KB / 312 KB | 39 KB / 8 MB | 781 KB / 312 KB | 781 KB / 2 MB |

Every row is one sitting on an otherwise idle machine (load about
1, each row the best of three runs, the whole script run twice).  The
derived kernel with `--blas`, the hand-written `lasso-auto.scm
--blas` (`cov-descend` of `lasso-cov.scm` behind the same three
products written as matmul forms, see below) and the package's
`CovLasso` are the same sweep loop over the same `dsyrk`, and they
time the same on every shape: the derivation saves the writing of
the three products, not time.  `--cublas` is 3-4x faster again with
the upload of X counted, and the loop-nest Gram of the plain
`--derive` row is 45x behind BLAS at the largest shape.

`examples/kernel-only/lasso-auto.scm` makes the choice scikit-learn's
`precompute='auto'` makes, by hand: with more observations than
features (`n > p`) it builds the Gram matrix and runs `cov-descend` of
`lasso-cov.scm` over it, otherwise `lasso` of `lasso-kernel.scm`
carries the residual -- both taken by include, so the file is the
choice and the Gram preparation and nothing else.  Its three products
are written as the `matmul` forms directly, so `--blas` / `--cublas`
lower them as they lower the derived kernel's.  It is what
`lasso-kernel.scm --derive` now produces, written by hand (the
derivation emits the same `n > p` branch, above), kept as the
reference the derived kernel is read against, and translated without
`--derive`, which would only add a second, redundant guard inside
its residual route.  The residual route is kept exactly where
`n <= p`, where the O(np^2) Gram build is not paid for by the O(p^2)
sweeps it buys.  Against
`lasso_path(precompute='auto')` on the same AR(1) designs -- 20
penalties from lambda_max to 0.01 lambda_max, 50 sweeps each on both
sides, `-O3 -march=native`, one core -- the coefficients agree to
1.5e-10 on every shape and the times are:

| n x p (route)            | sklearn `lasso_path` | `lasso-auto.scm` | `--blas` | `--cublas` |
|--------------------------|----------------------|------------------|----------|------------|
| 1,800 x 200 (Gram)       | 0.017 s              | 0.038 s          | 0.029 s  | 0.28 s (context creation) |
| 5,000 x 1,000 (Gram)     | 0.21 s               | 5.2 s            | 0.17 s   | 0.069 s    |
| 100,000 x 500 (Gram)     | 1.4 s                | 28 s             | 0.49 s   | 0.18 s     |
| 200 x 1,800 (residual)   | 0.17 s               | 0.36 s           | 0.35 s   | 0.35 s     |
| 1,000 x 5,000 (residual) | 6.5 s                | 11 s             | 11 s     | 11 s       |
| 2,000 x 20,000 (residual)| 55 s                 | 83 s             | 84 s     | 85 s       |

On the Gram side this is the derived kernel's story again (the
product is the whole cost, and BLAS or the device takes it); on the
residual side there is no product to lower, so the three columns are
one program, 1.5-2x behind scikit-learn for the reason given below --
the strict sequential dot product against a BLAS `ddot` -- and with
`-ffast-math` added, as for `lasso-kernel.scm`, the same two shapes
take 0.11 s and 6.9 s against scikit-learn's 0.13 s and 6.4 s.
`probe/auto-lasso.scm` runs both routes on small dyadic data in the
suite, plainly, with `--blas` and with `--cublas`.

So the memory-lean form runs at scikit-learn's speed, as it should --
same algorithm -- with two conditions that the measurement made
visible.  The kernel must skip the residual update of a coordinate
that did not move (scikit-learn does; most coordinates of a sparse
solution are such; the kernel now does, and it was 1.5-2.5x slower
before), and the compiler must be allowed to reorder the dot
product's additions: the translator writes the strict sequential sum,
which gcc will not vectorise, while scikit-learn's BLAS `ddot` never
promised that order.  The GPU buys the residual form 1.2-1.3x over
scikit-learn at n=100,000 and loses below, where two grid
barriers per coordinate cost more than the multiplications they
fence -- a coordinate step is a reduction, and the barrier is the
price the CPU never pays.  And the Gram form stays 5-10x ahead of
either at n=100,000 for 312 KB to 2 MB: on a single fit our Gram form
and scikit-learn's `precompute=True` are the same speed (the CV wins
above are the Gram subtraction and the warm path, not this kernel).
All rows agree with the scikit-learn reference to 1e-15 (the two Gram
rows to 1e-13, the order of the Gram's summation differing).

How each piece works is below: the Python packaging under "Installing
the solvers from PyPI", the boundary-free `-M` interface under
"Calling the fast lasso from Python", and the CUDA profile under
"Running on the GPU".

## Installing the solvers from PyPI

The solvers have packages of their own, so a Python user needs neither
Racket nor this repository:

```console
$ pip install scm2cpp-learn     # lasso over a Gram matrix, any design
$ pip install scm2cpp-tfs       # moving-average feature selection
```

Both are published:
[scm2cpp-learn](https://pypi.org/project/scm2cpp-learn/) and
[scm2cpp-tfs](https://pypi.org/project/scm2cpp-tfs/). The worked
example at the head of this file runs against the published package as
written.

```python
from scm2cpp_learn import CovLasso
model = CovLasso(X, y)
path = model.fit_path(model.lambda_grid())

from scm2cpp_learn import DerivedLasso     # the derivation's own C++, X and y in
path = DerivedLasso(X, y).fit_path(model.lambda_grid())

from scm2cpp_tfs import TemporalLasso
model = TemporalLasso(series, wmax=200, nobs=1800)
path = model.fit_path(y, model.lambda_grid(y))
yhat = model.predict(path[-1])           # no design matrix, ever
```

The C++ each compiles is committed under `python/`, generated from
`examples/kernel-only/` by that package's `regenerate.sh` -- so
installing needs a C++17 compiler and nothing else, and only
regenerating needs the translator.  `nvcc` at install time additionally
builds a batched GPU path, where one block of CUDA threads owns one
problem of a batch (a lambda, a resample, a cell of a CV grid);
without it the packages install and work the same, minus that one
method.  `python/` is where such packages live, one directory each, and
`python/README.md` says what distinguishes them.

## Calling the fast lasso from Python

`-M` emits an `extern "C"` wrapper and a ctypes loader beside the
library, so a translated kernel is importable:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/tfs-lasso-cov.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libtfs-lasso-cov.so tfs-lasso-cov_capi.cpp
```

No boost include is needed: a numeric kernel gets the minimal runtime.
Array arguments are passed as pointers into the caller's numpy buffers
-- the parameters are `scm2cpp::span` views -- so the kernel reads and
writes them in place and nothing is copied at the boundary.

`examples/kernel-only/tfs-fast-lasso.py` wraps four of the generated
functions in a small class.  The design matrix is never formed: `build_S` turns
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
$ python3 examples/kernel-only/tfs-fast-lasso.py
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
(`examples/kernel-only/tfs-lasso-cov.scm`) as a batched regularization
path: one CUDA thread per lambda, coordinate descent sequential inside
each problem, every thread sweeping in chunks until its largest
coefficient move falls below tolerance.  `cuda/compare-sklearn.py`
rebuilds the same problem in numpy and times scikit-learn on the same
grid, checking solutions by objective value rather than trusting wall
clocks.

The numbers are in the table at the top of this page: cold
against cold, over all 4,096 penalties, the translated kernel is about
16x scikit-learn on one core (0.95 s against 15.2 s) and the GPU batch
about another 21x on top (0.045 s, about 340x scikit-learn), the
translated side solving to the tighter tolerance.  The check `run-tests.sh`
runs where nvcc and a device exist uses a small instance of the same
program.
