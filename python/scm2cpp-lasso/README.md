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

```python
import numpy as np
from scm2cpp_lasso import CovLasso, cuda_available

model = CovLasso(X, y)                      # forms X'X and X'y
lambdas = model.lambda_grid(num=100)        # from lambda_max down

path = model.fit_path(lambdas)              # warm-started, sequential
grid = model.fit_path_batch(lambdas)        # every lambda from zero
print("GPU:", cuda_available())
```

The objective is scikit-learn's, with `fit_intercept=False`:

    (1 / 2 nobs) ||y - X b||^2 + lam ||b||_1

Penalties are compared against correlations on the features' own
scale, so the useful range of `lam` depends on the data.
`lambda_max()` is the smallest penalty that leaves every coefficient
at zero, and `lambda_grid()` walks down from it -- the construction
scikit-learn uses.  If your columns differ wildly in scale, standardize
them first; this solver does not do it for you.

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
one thread per resample, each reading its own Gram matrix.

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
