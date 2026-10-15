"""LBFGSLogisticRegression and LBFGSHuberRegressor against scikit-learn.

Both are scikit-learn's own algorithm written in the subset: the
objective of LogisticRegression(solver="lbfgs") / HuberRegressor and
scipy's L-BFGS-B run (examples/kernel-only/lbfgs.scm), translated with
--blas into the scm2cpp-lasso package.  On the same data both sides take
the same iterations; the script prints the iteration counts, the
largest coefficient difference and the whole fit times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/lbfgs-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time

import numpy as np
from sklearn.linear_model import HuberRegressor, LogisticRegression

import scm2cpp_lasso as m


def best(f, k):
    t = []
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(0)
    print("backend:", m._libfind.gramops_backend())
    print("LogisticRegression(solver='lbfgs'), C=1, tol=1e-4, max_iter=100")
    print(f"{'n':>7} {'p':>4} {'K':>2} {'it sk/ours':>10} {'max|dcoef|':>11}"
          f" {'sklearn s':>10} {'ours s':>9} {'ratio':>6}")
    for n, p, K in [(500, 20, 2), (5000, 100, 2), (5000, 100, 5),
                    (50000, 200, 2), (50000, 200, 5)]:
        X = rng.standard_normal((n, p))
        W = 0.5 * rng.standard_normal((K, p))
        y = np.argmax(X @ W.T + rng.gumbel(size=(n, K)), 1)
        ts, sk = best(lambda: LogisticRegression().fit(X, y), a.best)
        to, us = best(lambda: m.LBFGSLogisticRegression().fit(X, y), a.best)
        d = max(np.abs(sk.coef_ - us.coef_).max(), np.abs(sk.intercept_ - us.intercept_).max())
        print(f"{n:>7} {p:>4} {K:>2} {sk.n_iter_[0]:>4}/{us.n_iter_[0]:<5} {d:>11.1e}"
              f" {ts:>10.4f} {to:>9.4f} {ts / to:>5.1f}x")
    print("HuberRegressor, epsilon=1.35, alpha=1e-4, tol=1e-5, 5% outliers")
    print(f"{'n':>7} {'p':>4} {'it sk/ours':>13} {'max|dcoef|':>11}"
          f" {'sklearn s':>10} {'ours s':>9} {'ratio':>6}")
    for n, p in [(500, 20), (5000, 100), (50000, 200), (200000, 100)]:
        X = rng.standard_normal((n, p))
        y = X @ rng.standard_normal(p) + 0.3 * rng.standard_normal(n)
        y[: n // 20] += 20.0
        ts, sk = best(lambda: HuberRegressor().fit(X, y), a.best)
        to, us = best(lambda: m.LBFGSHuberRegressor().fit(X, y), a.best)
        d = max(np.abs(sk.coef_ - us.coef_).max(), abs(sk.intercept_ - us.intercept_),
                abs(sk.scale_ - us.scale_))
        print(f"{n:>7} {p:>4} {sk.n_iter_:>7}/{us.n_iter_:<5} {d:>11.1e}"
              f" {ts:>10.4f} {to:>9.4f} {ts / to:>5.1f}x")


if __name__ == "__main__":
    main()
