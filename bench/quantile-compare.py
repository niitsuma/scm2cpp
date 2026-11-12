"""FrischNewtonQuantileRegressor against scikit-learn's QuantileRegressor
(--solver, by default "highs" as scikit-learn's own default; "highs-ds"
and "highs-ipm" are HiGHS's dual simplex and interior point codes): the
same linear program, there by HiGHS through scipy's linprog, here by
the Frisch-Newton interior point method
(examples/kernel-only/quantile.scm).  The data are a linear model with
Student t(3) noise.  Each row prints the difference of the objectives
(mean check loss plus alpha |coef|_1, at each side's coefficients,
relative to it), the largest difference of the coefficients, the
interior point iterations and the whole fit times (best of --best; one
run of scikit-learn where it takes more than --once seconds).

--threads 1 pins BLAS, OpenMP and the package's threads to one (run it
under taskset -c 0 as well); --threads all leaves every library its
defaults.  --big adds 100,000 x 100 (long on the scikit-learn side).
"""
import argparse
import os

ap = argparse.ArgumentParser()
ap.add_argument("--threads", choices=["1", "all"], default="1")
ap.add_argument("--best", type=int, default=3)
ap.add_argument("--once", type=float, default=5.0)
ap.add_argument("--big", action="store_true")
ap.add_argument("--solver", default="highs")
a = ap.parse_args()
if a.threads == "1":
    for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
        os.environ[v] = "1"

import time
import warnings
import numpy as np
from sklearn.linear_model import QuantileRegressor
import scm2cpp_learn as m
from scm2cpp_learn._libfind import gramops_backend

warnings.simplefilter("ignore")


def timed(f, best):
    t0 = time.perf_counter()
    r = f()
    t = time.perf_counter() - t0
    if t <= a.once:
        for _ in range(best - 1):
            t0 = time.perf_counter()
            r = f()
            t = min(t, time.perf_counter() - t0)
    return t, r


def objective(est, X, y, q, alpha):
    r = y - est.predict(X)
    return float(np.mean(np.where(r < 0, (q - 1) * r, q * r)) + alpha * np.abs(est.coef_).sum())


rng = np.random.default_rng(0)
print(f"threads={a.threads}  solver={a.solver}  gramops={gramops_backend()}  package {m.__version__}")
print(f"{'case':44s} {'objective':>9s} {'coef':>8s} {'iter':>4s} {'sklearn':>9s} {'ours':>8s} {'ratio':>6s}")
cases = [(1_000, 20, 0.5, 0.0), (5_000, 20, 0.5, 0.0), (20_000, 20, 0.5, 0.0),
         (20_000, 20, 0.9, 0.0), (20_000, 20, 0.5, 0.01), (20_000, 100, 0.5, 0.0),
         (20_000, 100, 0.1, 0.005)]
if a.big:
    cases.append((100_000, 100, 0.5, 0.0))
for n, p, q, alpha in cases:
    X = rng.standard_normal((n, p))
    beta = rng.standard_normal(p) * (rng.random(p) < 0.5)
    y = X @ beta + 1.0 + rng.standard_t(3, n)
    ts, sk = timed(lambda: QuantileRegressor(quantile=q, alpha=alpha, solver=a.solver).fit(X, y),
                   a.best)
    to, ours = timed(lambda: m.FrischNewtonQuantileRegressor(quantile=q, alpha=alpha).fit(X, y),
                     a.best)
    fs, fo = objective(sk, X, y, q, alpha), objective(ours, X, y, q, alpha)
    dc = max(float(np.abs(sk.coef_ - ours.coef_).max()), abs(sk.intercept_ - ours.intercept_))
    case = f"{n:,} x {p}, quantile {q:g}, alpha {alpha:g}"
    print(f"{case:44s} {(fo - fs) / fs:9.1e} {dc:8.1e} {ours.n_iter_:4d} {ts:8.2f}s {to:7.3f}s"
          f" {ts / to:5.0f}x")
