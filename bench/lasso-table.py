"""Reproduce the timing table at the head of README.

    python3 bench/lasso-table.py [--quick]

Needs scm2cpp-lasso, scikit-learn and numpy installed:

    pip install scm2cpp-lasso scikit-learn

The comparison is a cross-validation grid: every lambda solved from
zero, which is what a fold of cross-validation costs when the folds
cannot share a warm start.  scikit-learn is called the way that
workload calls it -- Lasso(alpha=...).fit(X, y) once per lambda --
against the translated covariance kernel on the CPU and against the
CUDA batch kernel, one block of threads per lambda.  --quick shrinks the grid so
the script finishes in under a minute; the table in README is the full
run.

Both sides are given the same design matrix and start from it, so the
translated kernel's time includes building its Gram matrix.  BLAS and
OpenMP are pinned to one thread, so what is compared is one core
against one core -- the GPU row is the exception, and says so.

The last rows are the sequential single-path workload, where warm
starting is available to both sides, and are the fair comparison for a
single fit rather than a grid.  They are printed at three tolerances,
because the answer depends on which one is asked for: at
scikit-learn's default the two are level, and at tighter tolerances
the translated kernel's chunked descent costs more, sweeping in blocks
where sklearn checks after every pass.
"""
import argparse
import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_v, "1")

import time

import numpy as np

from scm2cpp_lasso import CovLasso, cuda_available


def build(nobs, p, nnz=8, seed=0):
    """A dense design and a sparse target built from a few columns."""
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((nobs, p))
    beta = np.zeros(p)
    beta[rng.choice(p, nnz, replace=False)] = rng.standard_normal(nnz) * 2.0
    y = X @ beta + 0.5 * rng.standard_normal(nobs)
    return X, y


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true",
                    help="256 lambdas instead of 4096")
    ap.add_argument("--nobs", type=int, default=1800)
    ap.add_argument("-p", type=int, default=200)
    args = ap.parse_args()
    ngrid = 256 if args.quick else 4096

    X, y = build(args.nobs, args.p)
    lambdas = CovLasso(X, y).lambda_grid(num=ngrid)
    print("p=%d columns, n=%d rows, %d lambdas, GPU %s"
          % (args.p, args.nobs, ngrid, "yes" if cuda_available() else "no"))

    rows = []

    from sklearn.linear_model import Lasso, lasso_path
    t0 = time.perf_counter()
    for lam in lambdas:
        Lasso(alpha=lam, fit_intercept=False, warm_start=False).fit(X, y)
    rows.append(("sklearn Lasso.fit per lambda, cold", time.perf_counter() - t0))
    # Lasso's default is precompute=False; 'auto' (the default of
    # lasso_path and LassoCV) takes the Gram route when n > p, and a
    # cold fit then rebuilds the Gram each time.  The class accepts
    # only True/False, so the choice is spelled out.
    pre = args.nobs > args.p
    t0 = time.perf_counter()
    for lam in lambdas:
        Lasso(alpha=lam, fit_intercept=False, warm_start=False,
              precompute=pre).fit(X, y)
    rows.append(("sklearn, precompute=%s ('auto'), cold" % pre,
                 time.perf_counter() - t0))

    # The translated kernel is asked for tol=1e-8 against sklearn's
    # default of 1e-4, so the comparison is conservative: it solves to
    # the tighter tolerance of the two.  Its time starts at the design
    # matrix, so building the Gram matrix is inside it.
    t0 = time.perf_counter()
    cpu = CovLasso(X, y).fit_path_batch(lambdas, force_cpu=True)
    rows.append(("translated cov kernel, 1 CPU core, cold",
                 time.perf_counter() - t0))

    if cuda_available():
        CovLasso(X, y).fit_path_batch(lambdas[:8])     # warm the context
        t0 = time.perf_counter()
        gpu = CovLasso(X, y).fit_path_batch(lambdas)
        rows.append(("translated cov kernel, GPU, one block/lambda",
                     time.perf_counter() - t0))
        print("GPU against CPU, largest coefficient difference: %.2e"
              % np.abs(gpu - cpu).max())

    print()
    print("| %-45s | %-7s |" % ("solver", "time"))
    print("|%s|%s|" % ("-" * 47, "-" * 9))
    for name, sec in rows:
        print("| %-45s | %s |" % (name, ("%5.1f s" % sec) if sec >= 1
                                  else ("%5.3f s" % sec)))

    warm = CovLasso(X, y).lambda_grid(num=400)
    print()
    print("warm single path, 400 lambdas, same tolerance asked of both:")
    for tol in (1e-4, 1e-6, 1e-8):
        model = CovLasso(X, y)
        model.fit_path(warm[:3], tol=tol)              # warm the module
        t0 = time.perf_counter()
        ours = model.fit_path(warm, tol=tol)
        t_ours = time.perf_counter() - t0
        t0 = time.perf_counter()
        _, theirs, _ = lasso_path(X, y, alphas=warm, tol=tol)
        t_theirs = time.perf_counter() - t0
        print("  tol %.0e: translated %.3f s, sklearn lasso_path %.3f s, "
              "coefficients agree to %.1e"
              % (tol, t_ours, t_theirs, np.abs(ours - theirs.T).max()))


if __name__ == "__main__":
    main()
