"""CovBayesianRidge against scikit-learn's BayesianRidge, whole fits.

    python3 bench/bayesian-ridge-compare.py [--shape N,P ..] [--best B]

Run in the venv the package is installed in.  Both fit the same model
with the same iteration (MacKay's updates of alpha and lambda,
scikit-learn's defaults, fit_intercept=True) and both compute the
posterior covariance sigma_; the difference is the linear algebra.
BayesianRidge takes the SVD of X once (the full one when n < p) and
multiplies by X every iteration for the squared error; CovBayesianRidge
takes X'X (X X' when n <= p) once, one eigendecomposition, and iterates
over its eigenvalues.  BLAS and OpenMP are pinned to one thread;
best of B.  Printed beside the times: the iteration counts and the
largest coefficient difference.
"""
import argparse
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time

import numpy as np

from scm2cpp_lasso import CovBayesianRidge


def best_of(fn, k):
    best, out = None, None
    for _ in range(k):
        t = time.perf_counter()
        out = fn()
        dt = time.perf_counter() - t
        best = dt if best is None else min(best, dt)
    return out, best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shape", action="append", default=[])
    ap.add_argument("--best", type=int, default=3)
    args = ap.parse_args()
    from sklearn.linear_model import BayesianRidge
    rng = np.random.default_rng(0)
    print("%-16s %10s %10s %7s %12s %10s" % ("n x p", "ours", "sklearn", "ratio", "iterations", "max|dcoef|"))
    for spec in args.shape or ["1800,200", "5000,1000", "100000,200", "100000,500", "500,5000"]:
        n, p = map(int, spec.split(","))
        X = rng.standard_normal((n, p))
        b = rng.standard_normal(p) * (rng.random(p) < 0.1)
        y = X @ b + 0.5 * rng.standard_normal(n) + 3.0
        a, ta = best_of(lambda: CovBayesianRidge().fit(X, y), args.best)
        s, ts = best_of(lambda: BayesianRidge().fit(X, y), args.best)
        print("%-16s %9.3fs %9.3fs %6.1fx %5d / %-5d %10.1e"
              % ("%d x %d" % (n, p), ta, ts, ts / ta, a.n_iter_, s.n_iter_,
                 float(np.abs(a.coef_ - s.coef_).max())), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
