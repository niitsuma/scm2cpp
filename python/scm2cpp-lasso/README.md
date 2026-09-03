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

## Against the other lassos pip can install

`bench/lasso-compare.py` in the repository runs the same
cross-validation-shaped grid -- 4096 lambdas, each solved from zero,
p=200, n=1800 -- against every lasso a `pip install` produces:
scikit-learn 1.9.0, celer 0.7.4, skglm 0.5, and RAPIDS cuML 26.8.
Every solver runs at its own default tolerance (ours at the tighter
1e-8), each gets one untimed warm-up fit, cuML's data is on the device
before the clock starts, and the last column is each solver's
objective minus ours at the smallest lambda -- a fast row with a loose
answer would show as one:

| solver                                 | time    | objective gap |
|----------------------------------------|---------|---------------|
| scm2cpp-lasso, 1 CPU core (tol 1e-8)   | 0.9 s   | 0             |
| scm2cpp-lasso, GPU, one thread/lambda  | 0.2 s   | 0             |
| sklearn `Lasso.fit` per lambda         | 12.5 s  | +1.6e-09      |
| celer per lambda                       | 17.3 s  | 0             |
| skglm per lambda                       | 16.4 s  | +2.8e-17      |
| cuML per lambda, GPU                   | 57.5 s  | +9.1e-07      |

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
one CPU core, sklearn 1.9.0, best of three runs, whole estimator
including the Grams:

| n       | p    | CPU    | CUDA   | sklearn `LassoCV` |
|---------|------|--------|--------|-------------------|
| 1,800   | 200  | 0.36 s | 0.03 s | 0.23 s            |
| 5,000   | 1000 | 3.9 s  | 0.39 s | 2.7 s             |
| 100,000 | 200  | 0.75 s | 0.60 s | 3.9 s             |
| 100,000 | 500  | 2.0 s  | 1.8 s  | 12.6 s            |

(This table was taken on a machine sharing its cores with other jobs,
load 14 on 20 threads, so its absolute times run some 2-3x above the
tables earlier in this README; the ratios are the point.)  The grid
launch itself takes 9 ms at n=1,800 and 64 ms at n=5,000, p=1000; at
n=100,000 the CUDA column is nearly all Gram products, which the CPU
path pays as well.  Large n is where the machinery pays either way:
nothing downstream of the Grams touches the 100,000 rows again.  At
n=5,000, p=1000 sklearn's raw-X descent beats our Gram-heavy CPU path,
and the GPU makes up the difference seven times over.  CPU and CUDA
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
| MultiTaskLasso        | 100,000 | 200 | 0.15 s | --              | --        | 0.80 s  |
| MultiTaskLasso        | 100,000 | 500 | 0.53 s | --              | --        | 1.9 s   |
| MultiTaskLassoCV      | 1,800   | 200 | 1.5 s  | 0.33 s          | 0.08 s    | 0.51 s  |
| MultiTaskLassoCV      | 100,000 | 200 | 1.6 s  | 0.62 s          | 1.7 s     | 76 s    |
| MultiTaskElasticNetCV | 1,800   | 200 | 1.6 s  | 0.51 s          | 0.10 s    | 1.0 s   |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 s  | 0.68 s          | 1.9 s     | 164 s   |

(`MultiTaskElasticNet` single fits time the same as `MultiTaskLasso`'s.
The CUDA column was timed on the busier day of the `CovLassoCV` table
above, when the sequential CPU rows read 1.5 / 2.0 / 1.6 / 2.1 s and
sklearn's 0.56 / 114 / 0.99 / 241 s.)  At n=1,800 our sequential CV
is slower than sklearn's: the default tol=1e-8 runs more sweeps than
sklearn's 1e-4 dual-gap stop, and at that size there are no rows to
save -- and the GPU grid takes the whole thing in a tenth of a second.
At n=100,000 the Gram route is 48x and 100x ahead, essentially
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
multiplicity counts `m` -- one BLAS product -- and because the
problems are independent, the descents run as one batch: on the GPU,
one block of threads per resample, each reading its own Gram matrix.

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
scm2cpp repository, translated from
`examples/kernel-only/lasso-cov.scm`.  That repository also derives the
covariance-update solver automatically from a naive one by finite
differencing; this package is the derived kernel, packaged.  To refresh
the committed C++ after changing the Scheme, run `regenerate.sh` --
that step, and only that step, needs Racket.

## License

MIT, the same as scm2cpp.
