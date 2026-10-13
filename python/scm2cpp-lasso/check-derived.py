"""DerivedLasso against CovLasso and scikit-learn, and how long each takes.

    python3 python/scm2cpp-lasso/check-derived.py [--nobs N] [-p P] [--num K]

Run in the venv the package is installed in.  DerivedLasso is the
translator's derivation of the residual-form kernel (lasso-kernel.scm
--derive --blas); CovLasso is the hand-written Gram-route sweep; both
solve scikit-learn's objective, so on a path of K penalties all three
must land on the same coefficients.  The reference is sklearn's
lasso_path(precompute=True) driven to tol=1e-12 (untimed); the timed
rows are DerivedLasso and CovLasso at tol=1e-8 -- the same test, the
largest coefficient move of a sweep, absolute in the derived kernel
and relative to max(1, max|beta|) in CovLasso -- and lasso_path at
its default tol=1e-4 on the duality gap.  Expected: the two package
routes within 1e-7 of the reference; the script exits 1 above 1e-5.
A second, wide design (p > n) runs the else branch of the derived
kernel's (if (< p n) ..) guard, the sweep as written.

Times are whole calls -- the Gram matrix included where one is built
-- on one core, best of three.  They are the package-level version of
the README's equal-work table, not a replacement for it: the sweeps
counts differ by solver here.
"""
import argparse
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import sys
import time

import numpy as np

from scm2cpp_lasso import CovLasso, DerivedLasso, derived_backend, cuda_available
from scm2cpp_lasso import _DERIVED

LIMIT = 1e-5


def ar1_design(rng, n, p, rho=0.9):
    X = np.empty((n, p))
    X[:, 0] = rng.standard_normal(n)
    s = np.sqrt(1 - rho * rho)
    for j in range(1, p):
        X[:, j] = rho * X[:, j - 1] + s * rng.standard_normal(n)
    return X


def best_of(fn, k=3):
    best = None
    for _ in range(k):
        t = time.perf_counter()
        out = fn()
        dt = time.perf_counter() - t
        best = dt if best is None else min(best, dt)
    return out, best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nobs", type=int, default=5000)
    ap.add_argument("-p", type=int, default=200)
    ap.add_argument("--num", type=int, default=20)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--wide", action="store_true",
                    help="also the 60 x 150 design (the residual route)")
    args = ap.parse_args()
    try:
        from sklearn.linear_model import lasso_path
    except ImportError:
        lasso_path = None
    print("derived kernel backends built:", sorted(_DERIVED), "default:", derived_backend())
    worst = 0.0
    shapes = [(args.nobs, args.p)] + ([(60, 150)] if args.wide else [])
    for n, p in shapes:
        rng = np.random.default_rng(args.seed)
        X = ar1_design(rng, n, p)
        beta = np.zeros(p)
        beta[rng.choice(p, 5, replace=False)] = rng.standard_normal(5)
        y = X @ beta + 0.5 * rng.standard_normal(n)
        lams = DerivedLasso(X, y).lambda_grid(num=args.num, eps=1e-2)
        route = "Gram route (p < n)" if p < n else "residual route (p >= n)"
        print(f"n={n} p={p} {args.num} lambdas, {route}")

        if lasso_path is not None:
            _, ref, _ = lasso_path(X, y, alphas=lams, precompute=True,
                                   tol=1e-12, max_iter=1000000)
            ref = ref.T
        else:
            ref = None

        # constructor and path timed apart: DerivedLasso's constructor
        # lays X out column-major and takes the column norms and its
        # path builds the Gram inside the kernel; CovLasso's constructor
        # is the Gram (numpy) and its path the sweeps alone
        backends = [b for b in ("cublas", "blas", "loops")
                    if b in _DERIVED and (b != "cublas" or cuda_available())]
        rows = [(f"DerivedLasso, {b}", (lambda b=b: DerivedLasso(X, y, backend=b)),
                 lambda m: m.fit_path(lams, tol=1e-8)) for b in backends]
        rows.append(("CovLasso(X, y)", lambda: CovLasso(X, y),
                     lambda m: m.fit_path(lams, tol=1e-8)))
        for name, make, run in rows:
            m, t_make = best_of(make)
            out, t_run = best_of(lambda: run(m))
            line = f"  {name:22s} {t_make:7.3f} s + .fit_path(tol=1e-8) {t_run:7.3f} s = {t_make + t_run:7.3f} s"
            if ref is not None:
                d = float(np.max(np.abs(out - ref)))
                worst = max(worst, d)
                line += f"   |diff vs tol 1e-12| {d:.1e}"
            print(line)
        if lasso_path is not None:
            out, t = best_of(lambda: lasso_path(X, y, alphas=lams, precompute=True,
                                                max_iter=100000)[1].T)
            d = float(np.max(np.abs(out - ref)))
            print(f"  {'sklearn lasso_path(precompute=True), tol 1e-4':50s} {t:7.3f} s   |diff vs tol 1e-12| {d:.1e}")
        if ref is None:
            print("  sklearn not installed: times only, no reference")
    print("worst difference %.1e %s" % (worst, "" if worst <= LIMIT else "FAIL"))
    return 0 if worst <= LIMIT else 1


if __name__ == "__main__":
    sys.exit(main())
