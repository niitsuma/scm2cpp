# scm2cpp-lasso

*[Japanese (README.ja.md)](README.ja.md)*

Lasso by coordinate descent over a Gram matrix, with an optional GPU
path.  The solver is Scheme, translated to C++ by
[scm2cpp](https://github.com/niitsuma/scm2cpp).

```console
$ pip install scm2cpp-lasso
```

Installing needs a C++17 compiler and nothing else.  If `nvcc` is on
the path, the batched GPU solver is built as well; if it is not, the
package installs and works exactly the same, minus that one method.

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
the coefficients are the planted ones, shrunk toward zero by it.

The rest of the interface:

```python
from scm2cpp_lasso import cuda_available

lambdas = model.lambda_grid(num=100)        # from lambda_max down
path = model.fit_path(lambdas)              # warm-started, sequential
grid = model.fit_path_batch(lambdas)        # every lambda from zero
one = model.fit(lambdas[60])                # a single lambda, if you must
print("GPU:", cuda_available())
```

`fit` is the one-element special case of `fit_path` -- the Gram matrix
was built in the constructor, so a whole warm-started path costs barely
more than one penalty, which is why the path is the primary interface.

The objective is scikit-learn's, with `fit_intercept=False`:

    (1 / 2 nobs) ||y - X b||^2 + lam ||b||_1

Penalties are compared against correlations on the features' own
scale, so the useful range of `lam` depends on the data.
`lambda_max()` is the smallest penalty that leaves every coefficient
at zero, and `lambda_grid()` walks down from it -- the construction
scikit-learn uses.  If your columns differ wildly in scale, standardize
them first; this solver does not do it for you.

## Two kernels: `CovLasso` and `DerivedLasso`

Everything above, and the cross-validation, bootstrap and GPU methods
below, runs on one kernel: numpy forms the Gram matrix, and a
hand-written coordinate-descent sweep over it
(`examples/kernel-only/lasso-cov.scm` in the repository, translated to
C++) does the rest.  That is the usable one.

`DerivedLasso` is the other kernel, and it is there to show the
translator's work rather than to be the better estimator.  Its source
is `examples/kernel-only/lasso-design.scm`: the residual-form
coordinate descent -- the algorithm inside scikit-learn's
`Lasso(precompute=False)` -- written as flat loops over X exactly as
numpy holds it (n rows of p, `x[i*p+j]`), the residual copied from y
and the column norms taken inside, with no Gram matrix anywhere in
it.  The translator's `--derive` turns
that into the Gram form: it raises the loops to an array algebra,
notices that the residual is only ever updated by a scaled column and
read in dot products against columns, replaces it by the memo `c =
X'r` kept current through a Gram matrix it hoists in front of the
penalty path, folds the column norms into that Gram's diagonal, folds
the three products into one `dsyrk` and two `dgemv` calls (`--blas`), and puts the whole thing under
`(if (< p n) ..)` with the sweep as written in the else branch --
scikit-learn's `precompute='auto'` rule, derived rather than written.
The C++ of that derivation, as the translator emitted it, is what
`DerivedLasso` calls; numpy prepares nothing -- X and y go in as they
are, no transposed copy, no norms.

```python
from scm2cpp_lasso import DerivedLasso, derived_backend

model = DerivedLasso(X, y)                   # X and y; the kernel builds its own Gram
path = model.fit_path(model.lambda_grid())   # one call, the whole warm-started path
print(derived_backend())                     # 'cublas', 'blas' or 'loops': what this machine built
gpu = DerivedLasso(X, y, backend="cublas")   # insist on one
```

A lambda is done when no coefficient moved by more than `tol`
(absolute, default 1e-8) in a sweep, or at `max_sweeps`; `tol=0.0`
asks for the exact fixed point.  Three translations of the one
derivation are committed and `pip` builds what the machine allows:
`--derive --cublas` where the CUDA toolkit is (the three products on
the device through cuBLAS, X uploaded once per `fit_path` call --
taken by default when a device answers), `--derive --blas` where
`cblas.h` and an OpenBLAS are, and `--derive` alone otherwise, the
same program with its Gram matrix as a scalar loop nest, correct but
slow on large designs.  `check-derived.py` in the package directory runs
the two kernels and scikit-learn on the same path and prints the
differences and the times; on AR(1) designs (rho 0.9), 20 penalties
from lambda_max to 0.01 lambda_max, one core, best of three (load
about 3), whole calls with the Gram matrix wherever it is built:

| n x p                                   | 1,800 x 200 | 5,000 x 1000 | 100,000 x 200 | 100,000 x 500 |
|-----------------------------------------|-------------|--------------|---------------|---------------|
| `DerivedLasso`, cuBLAS (upload included) | 0.003 s     | 0.024 s      | 0.052 s       | 0.11 s        |
| `DerivedLasso`, CBLAS                   | 0.003 s     | 0.076 s      | 0.12 s        | 0.44 s        |
| `CovLasso(X, y).fit_path`, tol 1e-8     | 0.004 s     | 0.080 s      | 0.11 s        | 0.42 s        |
| sklearn `lasso_path(precompute=True)`, tol 1e-4 | 0.005 s     | 0.10 s       | 0.24 s        | 0.76 s        |

The CBLAS run is the same `dsyrk` and the same sweeps as `CovLasso`'s
numpy Gram and path, and times the same; the cuBLAS run is the same
program with the three products on the device, the upload of X
counted, and is 4.2x, 4.5x and 6.7x ahead of scikit-learn at the
three larger shapes -- the figures of the repository's equal-work
table, now reached from the package with nothing in front of the
kernel: the constructor keeps X and y and the kernel takes the
residual and the column norms itself (the norms folded into the Gram
diagonal by the derivation).  Threads change the picture less than one might expect: scikit-learn's
sweeps are single-threaded Cython and only its Gram product scales,
so with 20 BLAS threads `lasso_path` takes 0.051 / 0.227 / 0.450 s on
the three larger shapes, against 0.023 / 0.050 / 0.113 s for the
cuBLAS build (2.2x, 4.5x, 4.0x) and 0.025 / 0.036 / 0.123 s for the
CBLAS build (2.0x, 6.3x, 3.7x), whose `dsyrk` scales with the
threads; the GPU figures do not move.  Against a reference driven to
tol=1e-12, `DerivedLasso` lands within 5e-8 on every backend (its
tolerance is absolute, on one sweep's largest move), `CovLasso`
within 2e-10 (it tests every 20 sweeps and overshoots), and
scikit-learn at its default within 1e-3.

### Deriving it yourself

Everything `DerivedLasso` runs is reproducible from the Scheme with
the translator; this is what `regenerate.sh` does for the package,
spelled out for one kernel (Racket 8 and a C++17 compiler; a CBLAS
for `--blas`, the CUDA toolkit for `--cublas`):

```console
$ git clone https://github.com/niitsuma/scm2cpp && cd scm2cpp
$ raco link --user vendor/rkanren                 # once per machine
$ mkdir /tmp/k && cp examples/kernel-only/lasso-design.scm examples/kernel-only/soft-threshold.scm /tmp/k/
$ racket scm2cpp-file.scm -t scm2c.typ --derive --cublas -M -S /tmp/k/lasso-design.scm
derive: lasso-design: raise differencing merge matmul guard
```

`derive:` on stderr names what fired: the loops raised to the array
algebra, the residual differenced into the memo, the column norms
merged into the Gram diagonal, the products folded to contractions,
the `(if (< p n) ..)` guard.  The run leaves, beside the source,
`lasso-design.hpp` (the derived kernel as C++: one `blas_syrk`, two
`blas_gemv`, the sweep), `lasso-design_capi.cpp` and
`lasso_design.py` (the `-M` C ABI and its ctypes loader -- what the
package's `_loader_derived_*.py` are), and `lasso-design.expanded.scm`
(`-S`: the derived program as Scheme, before C++ -- read this to see
what the derivation did).  `--blas` instead of `--cublas` gives the
CBLAS variant, neither the loop variant.  To call it from numpy
without the package:

```console
$ g++ -O2 -std=c++17 -shared -fPIC -I. -I$CUDA_HOME/include -o /tmp/k/liblasso-design.so \
      /tmp/k/lasso-design_capi.cpp -L$CUDA_HOME/lib64 -lcublas -lcudart   # -lopenblas for --blas
$ cd /tmp/k && python3 -c 'import lasso_design'   # lasso_design.lasso_design(x, y, resid, xnorm, beta, lams, betas, iters, tol, n, p, nlam)
```

(`-M` names the Python module after the file with `-` read as `_`,
and the loader looks for `liblasso-design.so` beside it.)
`examples/kernel-only/README.md` walks through the same `-M` flow on
the row-major kernel, and `python/PACKAGING.md` through turning such
a kernel into a pip package.

## Against the other lassos pip can install

`bench/lasso-compare.py` in the repository runs the same
cross-validation-shaped grid -- 4096 lambdas, each solved from zero,
p=200, n=1800 -- against every lasso a `pip install` produces:
scikit-learn 1.9.1, celer 0.7.4, skglm 0.5, and RAPIDS cuML 26.8.
Every solver runs at its own default tolerance (ours at the tighter
1e-8), each gets one untimed warm-up fit, cuML's data is on the device
before the clock starts, and the last column is each solver's
objective minus ours at the smallest lambda -- a fast row with a loose
answer would show as one:

| solver                                 | time    | objective gap |
|----------------------------------------|---------|---------------|
| scm2cpp-lasso, 1 CPU core (tol 1e-8)   | 0.91 s  | 0             |
| scm2cpp-lasso, GPU, one block/lambda   | 0.044 s | 0             |
| sklearn `Lasso.fit` per lambda         | 9.6 s   | +1.6e-09      |
| celer per lambda                       | 13.5 s  | 0             |
| skglm per lambda                       | 14.5 s  | +2.8e-17      |
| cuML per lambda, GPU                   | 53.6 s  | +9.1e-07      |

(One sitting on an otherwise idle machine, best of three runs; cuML
26.08 on CUDA 12.9.)

celer and skglm are built for very large sparse designs, where their
screening rules dominate; at this size they pay their setup per fit.
cuML parallelises *within* one fit, which wins when a fit is large; at
this size its launch overhead dominates, while our GPU row
parallelises *across* lambdas -- one block of CUDA threads per
penalty, the axis a cross-validation grid actually offers.

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

The elastic net cross-validates the same way: `CovLassoCV(l1_ratio=0.5)`
against `ElasticNetCV(l1_ratio=0.5)` on the same folds and alpha grid
(`bench/lasso-compare.py --cv-only --l1-ratio 0.5`, same conditions,
load under 1):

| n       | p    | CPU    | CUDA   | sklearn `ElasticNetCV` |
|---------|------|--------|--------|------------------------|
| 1,800   | 200  | 0.35 s | 0.02 s | 0.11 s                 |
| 5,000   | 1000 | 1.55 s | 0.26 s | 0.98 s                 |
| 100,000 | 200  | 0.52 s | 0.35 s | 1.76 s                 |
| 100,000 | 500  | 1.38 s | 1.15 s | 4.97 s                 |

The picture is the lasso's: on the CPU, 3.4-3.6x at 100,000 rows and
slower than sklearn at the two small shapes; with CUDA, 3.8-5.5x
everywhere.  The chosen alpha is sklearn's at all four sizes, the
coefficients within 8e-6 (sklearn's default tolerance).

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

## Which method

`fit_path` walks a single path, each lambda starting from the previous
solution -- the descent is exactly resumable, so this costs almost
nothing per lambda after the first.  `fit_path_batch` solves every
lambda from zero, which is what a cross-validation grid needs, where
the folds differ and warm starting across lambdas is not on offer; the
problems are independent, so they go to the GPU together.

Over a 400-lambda path at p=200 and 1800 rows, on an RTX 4090 and an
i9-10900X:

| call                                  | time    |
|---------------------------------------|---------|
| `fit_path` (warm, sequential)         | 0.091 s |
| `fit_path_batch` (GPU)                | 0.047 s |
| `fit_path_batch(force_cpu=True)`      | 0.178 s |

GPU and CPU agree to 2e-14, and the objectives are within 3e-17 of
scikit-learn's `lasso_path` on the same grid.

## Elastic net and ridge

The same Gram matrix serves two more estimators.  `fit_path` and
`fit_path_batch` take `l1_ratio` (scikit-learn's mixing parameter):
the L2 share of the penalty enters only the update's denominator, so
the elastic net runs on the identical machinery, GPU path included,
and `l1_ratio=1` is bit-for-bit the lasso.

`CovRidge` is the closed form: one symmetric eigendecomposition,
then every alpha costs O(p^2), so thousands of alphas cost what one
does.  Its objective matches scikit-learn's `Ridge` with
`fit_intercept=False` (which, unlike the lasso, is not scaled by the
number of rows), and agrees with it to machine precision.

```python
path = model.fit_path(lambdas, l1_ratio=0.5)   # elastic net
ridge = CovRidge(X, y)
betas = ridge.fit_path(ridge.alpha_grid())     # a whole ridge path
```

Measured (`bench/ridge-enet-compare.py` in the repository: AR(1)
designs, 20 penalties, whole calls with the Gram matrix wherever one
is built, one core, best of three):

| n x p                                        | 1,800 x 200 | 5,000 x 1000 | 100,000 x 200 | 100,000 x 500 |
|----------------------------------------------|-------------|--------------|---------------|---------------|
| elastic net, `CovLasso.fit_path(l1_ratio=0.5)`, tol 1e-8 | 0.007 s | 0.092 s | 0.11 s      | 0.40 s        |
| elastic net, sklearn `enet_path(precompute=True)`, tol 1e-4 | 0.005 s | 0.099 s | 0.23 s   | 0.74 s        |
| ridge, `CovRidge.fit_path(alphas)`           | 0.004 s     | 0.21 s       | 0.10 s        | 0.41 s        |
| ridge, sklearn `Ridge(alpha).fit` per alpha  | 0.060 s     | 2.05 s       | 3.37 s        | 11.2 s        |
| ridge, sklearn `RidgeCV(alphas)` (its LOO path) | 0.093 s  | 3.40 s       | 5.38 s        | 19.0 s        |

The elastic net is the same coordinate descent on both sides, so the
two rows differ by the Gram and the warm path, not the sweeps: level
at small n, 1.8-2.2x at 100,000 rows, and ours lands within 2e-10 of
a tight reference where scikit-learn's default tolerance lands within
6e-4.  The ridge rows compare a whole path against what a user
writes -- one `Ridge.fit` per alpha, each forming X'X and solving
afresh, O(np^2 + p^3) every time -- so the gap is the path's: 10-33x,
agreeing to 1e-14.  `RidgeCV` is given for scale (it picks one alpha
by leave-one-out rather than returning the path).  Neither row runs
on the GPU: the ridge is one eigendecomposition and the elastic net's
sweeps are the lasso's; `fit_path_batch(l1_ratio=..)` is the GPU
grid for the elastic net.

## Bayesian ridge

`CovBayesianRidge` is scikit-learn's `BayesianRidge` -- the same model,
the same defaults, the same iteration (MacKay's updates of the noise
precision `alpha_` and the weight precision `lambda_`, stopping when
the posterior mean moves by less than `tol`) -- with the linear
algebra moved into the eigenbasis of the Gram matrix.  scikit-learn
takes the SVD of X once and multiplies by X again in every iteration
for the squared error.  Here X enters once, through X'X (X X' when
n <= p): one eigendecomposition, after which the posterior mean, its
norm and the squared error are sums over the eigenvalues, O(p) per
iteration.  `sigma_` (the posterior covariance) and
`predict(return_std=True)` are there as in scikit-learn.

```python
from scm2cpp_lasso import CovBayesianRidge
m = CovBayesianRidge().fit(X, y)          # fit_intercept=True, as sklearn
mean, std = m.predict(X_new, return_std=True)
```

Measured (`bench/bayesian-ridge-compare.py` in the repository:
Gaussian designs, a sparse truth plus noise, whole fits including
`sigma_`, one core, best of three, sklearn 1.9.1):

| n x p          | `CovBayesianRidge` | sklearn `BayesianRidge` | ratio | iterations (both) | max coefficient difference |
|----------------|--------------------|-------------------------|-------|-------------------|----------------------------|
| 1,800 x 200    | 0.005 s            | 0.026 s                 | 5.2x  | 3                 | 3.6e-15                    |
| 5,000 x 1000   | 0.257 s            | 1.231 s                 | 4.8x  | 4                 | 6.7e-15                    |
| 100,000 x 200  | 0.126 s            | 3.495 s                 | 27.8x | 3                 | 2.8e-14                    |
| 100,000 x 500  | 0.475 s            | 8.909 s                 | 18.8x | 3                 | 1.6e-14                    |
| 500 x 5000     | 0.662 s            | 8.689 s                 | 13.1x | 71                | 1.7e-15                    |

The iteration counts are identical and the coefficients agree to
rounding, so the gap is the linear algebra alone: X'X by one BLAS
product against a full SVD of the tall X, and no pass over X inside
the loop.  At 500 x 5000 scikit-learn takes the full 5000 x 5000 SVD
for `sigma_`; here `sigma_` comes from the 500 x 500 kernel side by
the Woodbury identity.  This estimator is numpy, not translated code:
the eigendecomposition is LAPACK's either way.

## Classifiers and SVRs: `LinearSVM`, `KernelSVM`, `LinearSVR`, `KernelSVR`, `L1LogisticRegression`

Three classifiers and two regressors, each the algorithm scikit-learn runs, written out
in the Scheme subset and translated plainly (no derivation; the C++
is committed under `_generated/classifiers*`):

| class | algorithm | scikit-learn counterpart |
|---|---|---|
| `LinearSVM` | liblinear's dual coordinate descent for the hinge loss (random order, shrinking) | `LinearSVC(loss="hinge", dual=True, fit_intercept=False)` |
| `KernelSVM` | libsvm's SMO (WSS3, shrinking, the bias) over the whole kernel matrix | `SVC` (`kernel="rbf"`, `"linear"` or `"precomputed"`) |
| `L1LogisticRegression` | liblinear's newGLMNET (Newton over coordinate descent, line search) | `LogisticRegression(l1_ratio=1, solver="liblinear", fit_intercept=False)` |
| `LinearSVR` | liblinear's dual coordinate descent for the epsilon-insensitive loss (random order, shrinking) | `LinearSVR(loss="epsilon_insensitive", dual=True, fit_intercept=False)` |
| `KernelSVR` | the same SMO as `KernelSVM`, set up as libsvm's epsilon-SVR (2n variables) | `SVR` (`kernel="rbf"`, `"linear"` or `"precomputed"`) |

```python
from scm2cpp_lasso import LinearSVM, KernelSVM, L1LogisticRegression
LinearSVM(C=1.0).fit(X, y).predict(X_new)
KernelSVM(C=1.0, gamma="scale").fit(X, y).decision_function(X_new)
L1LogisticRegression(C=0.1).fit(X, y).predict_proba(X_new)
```

The classifiers take two classes (the second of `classes_` is the
positive one), and `tol` / `max_iter` mean what they mean in scikit-learn.
`KernelSVM` and `KernelSVR` build the kernel matrix in numpy and keep all of it,
n x n doubles (800 MB at n = 10,000), where `SVC` computes rows on
demand through a cache; that is its price.

Measured with `check-classifiers.py` (in this directory): the same
problem and stopping rule on both sides, one core, best of three,
sklearn 1.9.1, load average under 2. Ours includes building the kernel
matrix (`KernelSVM`) or transposing X into columns
(`L1LogisticRegression`):

| problem | ours | scikit-learn | ratio | objective (ours / sklearn) | same predictions |
|---|---|---|---|---|---|
| `LinearSVM`, 5,000 x 200 | 0.379 s | 0.598 s | 1.6x | 1541.06 / 1541.29 | 99.5% |
| `LinearSVM`, 100,000 x 200 | 23.0 s | 41.7 s | 1.8x | 34503.5 / 34500.7 | 98.9% |
| `LinearSVM`, 2,000 x 20,000 | 0.975 s | 1.894 s | 1.9x | 0.052484 / 0.052428 | 100% |
| `KernelSVM` rbf, 2,000 x 50 | 0.068 s | 0.139 s (precomputed 0.081 s) | 2.1x (1.2x) | -1065.5026 / -1065.5026 | 100% |
| `KernelSVM` rbf, 5,000 x 50 | 0.501 s | 1.032 s (precomputed 0.588 s) | 2.1x (1.2x) | -2628.1422 / -2628.1422 | 100% |
| `KernelSVM` rbf, 10,000 x 50 | 2.12 s | 4.15 s (precomputed 2.61 s) | 2.0x (1.2x) | -4994.9982 / -4994.9982 | 100% |
| `L1LogisticRegression`, 5,000 x 200, C=0.1 | 0.064 s | 0.103 s | 1.6x | 61.676698 / 61.676708 | 100% |
| `L1LogisticRegression`, 20,000 x 500, C=0.05 | 1.20 s | 2.23 s | 1.9x | 106.77913 / 106.77915 | 100% |
| `L1LogisticRegression`, 100,000 x 200, C=0.05 | 9.06 s | 18.7 s | 2.1x | 349.61154 / 349.61216 | 100% |

The regressors, from the same script (C = 1, epsilon 0.1):

| problem | ours | scikit-learn | ratio | agreement |
|---|---|---|---|---|
| `LinearSVR`, 5,000 x 200 | 1.32 s | 2.53 s | 1.9x | both at the 1,000-sweep cap; objective 779.99 / 790.72 |
| `LinearSVR`, 20,000 x 500 | 22.1 s | 36.6 s | 1.7x | both at the cap; objective 3741.4 / 3712.2 |
| `KernelSVR` rbf, 1,000 x 10 | 0.023 s | 0.043 s | 1.9x | iterations 2,172 / 2,177; predictions within 4e-4 |
| `KernelSVR` rbf, 3,000 x 10 | 0.246 s | 0.332 s | 1.3x | iterations 7,471 / 7,581; within 5e-4 |
| `KernelSVR` rbf, 6,000 x 10 | 1.18 s | 1.38 s | 1.2x | iterations 16,805 / 16,630; within 5e-4 |

`LinearSVR` on these data does not reach its tolerance in 1,000 sweeps on
either side, and at the cap the random order alone moves the objective
by about 1% (scikit-learn's own seeds give 776-789 at 5,000 x 200);
with 20,000 sweeps both land on 728.58.  `KernelSVR`'s gain shrinks
with n here because the 10 features make each kernel row cheap for
libsvm to compute, while ours reads the rows of a matrix of n^2
doubles; the predictions agree to within scikit-learn's tolerance.

The objectives agree to the stopping tolerance on both sides, not to
rounding. The linear SVM on tall data stops at the 1,000-sweep cap on
both sides, so there the two land a hair apart and 1% of the
predictions differ. The gain is the same in all three: the same
algorithm, run as dense loops that vectorise, against libsvm's and
liblinear's sparse rows. The classifiers are compiled at `-O3` with
`-fstrict-overflow`: Python's build flags carry
`-fno-strict-overflow`, which keeps the compiler from treating the
flat index `i*p + j` as an induction variable and makes the linear
SVM 25% slower.

## NMF: `CDNMF`

`CDNMF` is scikit-learn's `NMF(solver="cd")` -- Frobenius loss, no
regularization, no shuffling -- as the translator derives it.
`examples/kernel-only/nmf-cd.scm` writes the half step with the
residual R = X - W H and no Gram matrix. `--derive` memoises R H' over
the hoisted H H' and distributes the residual through the memo, so the
compiled half step is scikit-learn's `XHt - W HHt` with R never formed.
Like `DerivedLasso`, it is built in three variants (`nmf_backend()`
says which is taken: cublas when a device answers, else blas, else
loops).

```python
from scm2cpp_lasso import CDNMF
model = CDNMF(n_components=20, random_state=0)   # init="random", as sklearn's
W = model.fit_transform(X)                       # H in model.components_
```

`init="random"` draws the start as scikit-learn does, so the same seed
gives the same W and H. scikit-learn's default `"nndsvda"` is not
offered; pass `init="custom"` with its W and H for that start.
Measured with `check-classifiers.py --only nmf` against
`NMF(solver="cd", init="random")` from the same seed, tol 1e-4, at most
200 iterations, one core:

| n x p, k | `CDNMF` cuBLAS | `CDNMF` BLAS | sklearn | iterations | max \|H - H_sklearn\| |
|---|---|---|---|---|---|
| 1,000 x 500, 10 | 0.441 s (0.6x) | 0.212 s (1.15x) | 0.244 s | 200 / 200 | 1.3e-13 |
| 5,000 x 2,000, 20 | 7.01 s (1.6x) | 8.27 s (1.36x) | 11.25 s | 200 / 200 | 4.1e-12 |
| 20,000 x 1,000, 30 | 16.9 s (1.8x) | 20.6 s (1.46x) | 30.1 s | 200 / 200 | 2.4e-12 |

The iterates are scikit-learn's to rounding. The cuBLAS variant pays
from the middle size on; at 1,000 x 500 its transfers cost more than
the products save, and `backend="blas"` is the faster choice there.

## Graphical lasso and RANSAC: `CDGraphicalLasso`, `LinearRANSAC`

Two more of scikit-learn's algorithms, written out in the Scheme subset
and translated plainly.

- `CDGraphicalLasso` is `GraphicalLasso(mode="cd")`: `_graphical_lasso`
  with `enet_coordinate_descent_gram` inside it, its two matrix-vector
  products as dgemv. `alpha`, `tol`, `enet_tol`, `max_iter` and
  `assume_centered` mean what they mean in scikit-learn. scikit-learn's
  `costs_` (a log-determinant every iteration) is not computed.
- `LinearRANSAC` is `RANSACRegressor` around `LinearRegression`, with
  the same defaults. With scikit-learn installed, the subsets are drawn
  exactly as it draws them, so `random_state` gives scikit-learn's fit.

```python
from scm2cpp_lasso import CDGraphicalLasso, LinearRANSAC
prec = CDGraphicalLasso(alpha=0.1).fit(X).precision_
fit = LinearRANSAC(random_state=0).fit(X, y)       # fit.coef_, fit.inlier_mask_
```

Measured through the package, one core, best of three, against
scikit-learn on the same data (an AR(1) design with n = 20p for the
graphical lasso, 100 iterations on both sides; a linear model with
outliers for RANSAC, max_trials 1000):

| problem | ours | scikit-learn | ratio | agreement |
|---|---|---|---|---|
| `CDGraphicalLasso`, p = 50 | 0.0069 s | 0.306 s | 44.5x | 100 / 100 iterations, precision to 1.8e-14 |
| `CDGraphicalLasso`, p = 200 | 0.286 s | 1.62 s | 5.7x | precision to 2.6e-14 |
| `CDGraphicalLasso`, p = 800 | 33.9 s | 43.8 s | 1.3x | precision to 5.0e-14 |
| `LinearRANSAC`, 10,000 x 5 | 0.0254 s | 0.0916 s | 3.6x | 98 / 98 trials, same inliers |
| `LinearRANSAC`, 100,000 x 10 | 0.153 s | 0.241 s | 1.6x | 97 / 97 trials, same inliers |
| `LinearRANSAC`, 20,000 x 20 | 0.470 s | 1.19 s | 2.5x | 1,000 / 1,000 trials, same inliers |

Both gains are mostly scikit-learn's Python between its compiled steps:
the per-column bookkeeping of the graphical lasso, and the per-trial
validation and fitting of RANSAC. They shrink as the compiled part
grows (the graphical lasso at large p).

## SGD, OMP and LARS: `SGDLinearClassifier`, `SGDLinearRegressor`, `GramOMP`, `GramLars`, `GramLassoLars`

scikit-learn's own algorithms, translated:

- `SGDLinearClassifier` and `SGDLinearRegressor` are
  `SGDClassifier` / `SGDRegressor` at their defaults, run by
  `_plain_sgd` with the points in order. Against
  `shuffle=False` the weights are bit-identical. scikit-learn's
  shuffling generator is not reproduced.
- `GramOMP` is `OrthogonalMatchingPursuit` over the Gram matrix (its
  route for n > p, taken here always; X'X and X'y by dsyrk and dgemv).
- `GramLars` and `GramLassoLars` are `Lars` and `LassoLars` over the
  Gram (their route for n > p, taken here always; the Gram formed in
  numpy).

```python
from scm2cpp_lasso import SGDLinearClassifier, GramOMP, GramLassoLars
SGDLinearClassifier().fit(X, y).predict(X_new)
GramOMP(n_nonzero_coefs=10).fit(X, y).coef_
GramLassoLars(alpha=0.01).fit(X, y).coef_
```

Each gives scikit-learn's coefficients, to the bit for SGD and to 1e-15
for the rest, with the same number of epochs or steps. The speed is the
repository README's table: 1.0-3.3x for SGD, 1.1-2.8x for OMP and
1.2-5.0x for LARS, largest on small problems, where scikit-learn's
Python between steps dominates.

## Logistic regression with L1

`CovLogistic` solves L1-penalized logistic regression by
majorization: the logistic Hessian is bounded by X'X/4, so the
quadratic term is the same Gram matrix, fixed once, and each outer
round costs one gradient pass before handing the majorizer to the
same coordinate descent the lasso uses.  Objectives agree with
scikit-learn's `LogisticRegression(penalty="l1",
fit_intercept=False)` at `C = 1/(n lam)` to 9e-15.

## Group lasso

`CovGroupLasso` penalizes whole groups -- `lam * sum_g sqrt(|g|)
||b_g||` -- so correlated features enter or leave together.  Block
coordinate descent on the same Gram machinery: each block visit is
one majorized proximal step (the group's Gram block dominated by its
top eigenvalue, found once), descending monotonically.  With size-one
groups it reduces exactly to the lasso -- verified against sklearn to
9e-16 -- and at convergence the group KKT conditions hold to 2e-12.

## Bootstrap on the GPU

`bootstrap` draws pairs-bootstrap resamples and refits them all at
one lambda.  Each resample's Gram matrix is `X' diag(m) X` for its
multiplicity counts `m`, written as `Xs' Xs` with `Xs = diag(sqrt m) X`
so that numpy hands it to the symmetric rank-k product (`dsyrk`,
half the flops of `X' (diag(m) X)`) -- one BLAS call -- and because
the problems are independent, the descents run as one batch: on the
GPU, one block of threads per resample, each reading its own Gram
matrix.  The products are the cost: at n=5000, p=1000 a hundred
resamples took 18.1 s as general products and 11.2 s as `dsyrk`,
descents included.

```python
betas = model.bootstrap(lam, n_boot=500, seed=0)   # (500, p)
freq = (abs(betas) > 1e-9).mean(axis=0)            # selection frequency
```

Requires constructing the model from `X, y` (a Gram matrix alone
cannot be resampled by rows).  GPU and CPU agree to machine
precision.

## A design with structure

When the design matrix has structure, forming X'X the general way is
the wrong move.  `kernel` exposes the translated functions directly,
and [`scm2cpp-tfs`](https://pypi.org/project/scm2cpp-tfs/) does exactly
that for moving-average designs: it builds the Gram matrix from a
series' prefix sums in O(n p) time, never forming the design.  That
package stands alone -- it carries its own copy of this descent -- so
neither installs the other.

## Where this comes from

The C++ this compiles is committed to `python/scm2cpp-lasso/` in the
scm2cpp repository.  `CovLasso` and the rest run on the translation of
`examples/kernel-only/lasso-cov.scm`, a covariance-update sweep
written by hand at the Gram level; `DerivedLasso` runs on the
translation of `examples/kernel-only/lasso-design.scm`, the naive
residual-form descent over X as numpy holds it, with the translator's `--derive --blas`
deriving the same covariance form from it.  The two are the same
sweep over the same `dsyrk`, and they time the same.  To refresh the
committed C++ after changing the Scheme, run `regenerate.sh` -- that
step, and only that step, needs Racket.

## License

MIT, the same as scm2cpp.
