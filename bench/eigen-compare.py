"""The estimators built on one eigenproblem against scikit-learn's:
GramRidgeCV against RidgeCV (cv=None, leave-one-out by GCV), tall and
wide, few alphas and many; GramKernelPCA against KernelPCA (the rbf
kernel with a few components, where scikit-learn takes ARPACK and the
package subspace iteration, and with many, both dense; the linear
kernel, the package through X'X); GramLDA against
LinearDiscriminantAnalysis (each solver).  Each row prints what the two agree
on (the chosen alpha and the coefficients, or the eigenvalues and the
transformed data) and the whole fit times (best of --best).

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
from sklearn.decomposition import KernelPCA
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
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

print(f"{'case':44s} {'eig diff':>16s} {'Xt diff':>9s} {'sklearn':>8s} {'ours':>8s} {'ratio':>6s}")
for n, p, c, kernel in [(3_000, 20, 5, "rbf"), (6_000, 20, 5, "rbf"), (3_000, 20, 50, "rbf"),
                        (5_000, 50, 10, "linear")]:
    X = rng.standard_normal((n, p))
    ts, s = best_of(lambda: KernelPCA(c, kernel=kernel, random_state=0).fit(X))
    to, o = best_of(lambda: m.GramKernelPCA(c, kernel=kernel).fit(X))
    ev = np.abs(s.eigenvalues_ - o.eigenvalues_).max() / s.eigenvalues_.max()
    xt = np.abs(s.transform(X[:100]) - o.transform(X[:100])).max()
    case = f"KernelPCA({kernel}), {n:,} x {p}, {c} components"
    print(f"{case:44s} {ev:16.1e} {xt:9.1e} {ts:8.3f} {to:8.3f} {ts / to:5.1f}x")
    sys.stdout.flush()

print(f"{'case':44s} {'coef diff':>16s} {'same pred':>9s} {'sklearn':>8s} {'ours':>8s} {'ratio':>6s}")
for n, p, k, solver in [(200_000, 100, 5, "svd"), (50_000, 500, 10, "svd"),
                        (200_000, 100, 5, "lsqr"), (200_000, 100, 5, "eigen")]:
    y = rng.integers(0, k, n)
    X = rng.standard_normal((n, p)) + 0.1 * y[:, None]
    ts, s = best_of(lambda: LinearDiscriminantAnalysis(solver=solver).fit(X, y))
    to, o = best_of(lambda: m.GramLDA(solver=solver).fit(X, y))
    cd = np.abs(s.coef_ - o.coef_).max() / np.abs(s.coef_).max()
    same = bool(np.all(s.predict(X[:2000]) == o.predict(X[:2000])))
    case = f"LDA({solver}), {n:,} x {p}, {k} classes"
    print(f"{case:44s} {cd:16.1e} {str(same):>9s} {ts:8.3f} {to:8.3f} {ts / to:5.1f}x")
    sys.stdout.flush()
