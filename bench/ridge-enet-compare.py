"""The elastic net and the ridge against scikit-learn, whole calls.

    python3 bench/ridge-enet-compare.py [--nobs N] [-p P] [--num K] [--best B]

Run in the venv the package is installed in.  Two paths of K
penalties over an AR(1) design (rho 0.9), each timed as a whole call
with the Gram matrix wherever one is built, one CPU core, best of B:

  elastic net, l1_ratio 0.5
    CovLasso(X, y).fit_path(lams, l1_ratio=0.5)   warm-started, over the Gram
    sklearn enet_path(precompute=True)            the same algorithm in sklearn
  ridge
    CovRidge(X, y).fit_path(alphas)               one eigendecomposition, then O(p^2) per alpha
    sklearn Ridge(alpha).fit per alpha            what a user writes: one solve per alpha
    sklearn RidgeCV(alphas, cv=None)              sklearn's own path, by its efficient LOO

Agreement is measured against a tight reference (enet_path at
tol=1e-12; the ridge closed form) and printed beside each time.
The lasso rows are in check-derived.py and the README tables; this
script covers the two other penalties the package carries.
"""
import argparse
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import sys
import time

import numpy as np

from scm2cpp_learn import CovLasso, CovRidge


def ar1_design(rng, n, p, rho=0.9):
    X = np.empty((n, p))
    X[:, 0] = rng.standard_normal(n)
    s = np.sqrt(1 - rho * rho)
    for j in range(1, p):
        X[:, j] = rho * X[:, j - 1] + s * rng.standard_normal(n)
    return X


def best_of(fn, k):
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
    ap.add_argument("--best", type=int, default=3)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    from sklearn.linear_model import enet_path, Ridge, RidgeCV

    n, p = args.nobs, args.p
    rng = np.random.default_rng(args.seed)
    X = ar1_design(rng, n, p)
    beta = np.zeros(p)
    beta[rng.choice(p, 5, replace=False)] = rng.standard_normal(5)
    y = X @ beta + 0.5 * rng.standard_normal(n)
    print(f"n={n} p={p}, {args.num} penalties, best of {args.best}, one core")

    # ---- elastic net, l1_ratio 0.5 ----
    l1 = 0.5
    lams = CovLasso(X, y).lambda_grid(num=args.num, eps=1e-2, l1_ratio=l1)
    _, ref, _ = enet_path(X, y, l1_ratio=l1, alphas=lams, precompute=True,
                          tol=1e-12, max_iter=1000000)
    ref = ref.T
    ours, t_ours = best_of(lambda: CovLasso(X, y).fit_path(lams, l1_ratio=l1, tol=1e-8), args.best)
    skl, t_skl = best_of(lambda: enet_path(X, y, l1_ratio=l1, alphas=lams, precompute=True,
                                           max_iter=100000)[1].T, args.best)
    print("elastic net (l1_ratio 0.5)")
    print("  CovLasso(X, y).fit_path(l1_ratio=0.5), tol 1e-8   %7.3f s   |diff vs tol 1e-12| %.1e"
          % (t_ours, np.max(np.abs(ours - ref))))
    print("  sklearn enet_path(precompute=True), tol 1e-4      %7.3f s   |diff vs tol 1e-12| %.1e"
          % (t_skl, np.max(np.abs(skl - ref))))

    # ---- ridge ----
    alphas = CovRidge(X, y).alpha_grid(num=args.num, eps=1e-4)
    G = X.T @ X
    c0 = X.T @ y
    ref_r = np.stack([np.linalg.solve(G + a * np.eye(p), c0) for a in alphas])
    ours_r, t_r = best_of(lambda: CovRidge(X, y).fit_path(alphas), args.best)

    def ridge_each():
        return np.stack([Ridge(alpha=a, fit_intercept=False).fit(X, y).coef_ for a in alphas])
    skl_r, t_each = best_of(ridge_each, args.best)

    def ridge_cv():
        m = RidgeCV(alphas=alphas, fit_intercept=False).fit(X, y)
        return m.coef_
    _, t_cv = best_of(ridge_cv, args.best)
    print("ridge")
    print("  CovRidge(X, y).fit_path(alphas)                     %7.3f s   |diff vs solve| %.1e"
          % (t_r, np.max(np.abs(ours_r - ref_r))))
    print("  sklearn Ridge(alpha).fit, one per alpha             %7.3f s   |diff vs solve| %.1e"
          % (t_each, np.max(np.abs(skl_r - ref_r))))
    print("  sklearn RidgeCV(alphas, cv=None), the LOO path      %7.3f s   (picks one alpha)"
          % t_cv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
