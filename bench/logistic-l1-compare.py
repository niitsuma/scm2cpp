"""L1-regularized logistic regression against scikit-learn's liblinear.

    python3 bench/logistic-l1-compare.py --kernel-dir DIR [--shape N,P,C ..] [--best B]

--kernel-dir holds logistic_l1.py and liblogistic_l1.so built from
examples/kernel-only/logistic-l1.scm with -M: liblinear's
solve_l1r_lr (newGLMNET) whole, the code that
LogisticRegression(l1_ratio=1, solver="liblinear", fit_intercept=False)
runs, translated plainly.  Both minimise sum |w_j| + C sum log(1 +
exp(-y_i w.x_i)) at tol 1e-4 with at most 100 Newton iterations; the
time of ours includes the transpose of X into columns, which liblinear
also does inside.  The objective, the number of nonzeros and the
Newton iterations are printed beside the times (the iterations may
differ by one or two: the two random orders are different streams).

Rows: Gaussian designs, a 5% sparse truth, labels from its sign plus
noise.  BLAS and OpenMP pinned to one thread; best of B.
"""
import argparse
import importlib.util
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time
import warnings
from pathlib import Path

import numpy as np


def load(d, base):
    spec = importlib.util.spec_from_file_location(base, Path(d) / (base + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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
    ap.add_argument("--kernel-dir", required=True)
    ap.add_argument("--shape", action="append", default=[])
    ap.add_argument("--best", type=int, default=3)
    args = ap.parse_args()
    from sklearn.linear_model import LogisticRegression
    k = load(args.kernel_dir, "logistic_l1")
    warnings.simplefilter("ignore")

    def objective(w, X, y, C):
        return float(np.abs(w).sum() + C * np.logaddexp(0.0, -y * (X @ w)).sum())

    print("%-22s %9s %9s %6s %24s %10s %10s" % ("n x p, C", "ours", "sklearn", "ratio",
                                               "objective (ours/sklearn)", "nonzeros", "Newton it"))
    for spec in args.shape or ["1000,50,1.0", "5000,200,0.1", "20000,500,0.05", "100000,200,0.05"]:
        n, p, C = spec.split(",")
        n, p, C = int(n), int(p), float(C)
        rng = np.random.default_rng(0)
        X = rng.standard_normal((n, p))
        q = max(1, p // 20)
        b = np.zeros(p)
        b[rng.choice(p, q, replace=False)] = 2.0 * rng.standard_normal(q)
        y = np.where(X @ b + 0.5 * rng.standard_normal(n) > 0, 1.0, -1.0)

        def ours():
            xc = np.ascontiguousarray(X.T)
            w = np.zeros(p)
            it = k.logistic_l1(xc, y, w, C, 1e-4, 100, 1, n, p)
            return w, it

        def skl():
            return LogisticRegression(l1_ratio=1.0, solver="liblinear", C=C, tol=1e-4,
                                      max_iter=100, fit_intercept=False).fit(X, y)

        (w, it), ta = best_of(ours, args.best)
        m, ts = best_of(skl, args.best)
        ws = m.coef_.ravel()
        print("%-22s %8.3fs %8.3fs %5.1fx %11.8g / %-11.8g %4d / %-4d %3d / %-3d"
              % ("%d x %d, %g" % (n, p, C), ta, ts, ts / ta, objective(w, X, y, C),
                 objective(ws, X, y, C), np.count_nonzero(w), np.count_nonzero(ws),
                 it, int(np.ravel(m.n_iter_)[0])), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
