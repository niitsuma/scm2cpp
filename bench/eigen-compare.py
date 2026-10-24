"""The estimators built on one eigenproblem against scikit-learn's:
GramRidgeCV against RidgeCV (cv=None, leave-one-out by GCV), tall and
wide, few alphas and many.  Each row prints the alpha chosen by both,
the largest coefficient difference, and the whole fit times (best of
--best).

--threads 1 pins BLAS and OpenMP to one thread (run it under taskset
-c 0 as well); --threads all leaves every library its defaults.
"""
import argparse
import os
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--threads", choices=["1", "all"], default="1")
ap.add_argument("--best", type=int, default=3)
a = ap.parse_args()
if a.threads == "1":
    for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
        os.environ[v] = "1"

import time
import numpy as np
from sklearn.linear_model import RidgeCV
import scm2cpp_lasso as m
from scm2cpp_lasso._libfind import gramops_backend


def best_of(f):
    t = []
    for _ in range(a.best):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


rng = np.random.default_rng(0)
print(f"threads={a.threads}  gramops={gramops_backend()}  package {m.__version__}")
print(f"{'case':44s} {'alpha sk/ours':>16s} {'coef diff':>9s} {'sklearn':>8s} {'ours':>8s} {'ratio':>6s}")
for n, p, na in [(200_000, 200, 3), (200_000, 200, 50), (20_000, 500, 50), (2_000, 5_000, 50)]:
    X = rng.standard_normal((n, p)) + 1.0
    y = X[:, :10] @ rng.standard_normal(10) + rng.standard_normal(n)
    alphas = np.logspace(-2, 4, na)
    ts, s = best_of(lambda: RidgeCV(alphas=alphas).fit(X, y))
    to, o = best_of(lambda: m.GramRidgeCV(alphas=alphas).fit(X, y))
    case = f"RidgeCV, {n:,} x {p:,}, {na} alphas"
    print(f"{case:44s} {s.alpha_:7.3g}/{o.alpha_:<8.3g} {np.abs(s.coef_ - o.coef_).max():9.1e} "
          f"{ts:8.3f} {to:8.3f} {ts / to:5.1f}x")
    sys.stdout.flush()
