"""The estimators that take a scipy.sparse X against scikit-learn's on
the same CSR matrix: GramLasso and GramElasticNet against Lasso and
ElasticNet (scikit-learn's sparse coordinate descent; both sides to
tol 1e-10 on the coefficients' scale), GramRidge against Ridge (its
default solver on a sparse X), GramLinearRegression against
LinearRegression (lsqr at tol 1e-6 there, exact here), and
GramTruncatedSVD against TruncatedSVD (randomized, the default, and
arpack, exact, which the package's answer matches).  The package forms
X'X once by csr-gram, on threads, and the rest is p x p.  Each row
prints what the two agree on and the whole fit times (best of --best).

--threads 1 pins BLAS, OpenMP and the package's threads to one (run it
under taskset -c 0 as well); --threads all leaves every library its
defaults.
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
import warnings
import numpy as np
import scipy.sparse as sp
from sklearn.decomposition import TruncatedSVD
from sklearn.linear_model import Lasso, ElasticNet, Ridge, LinearRegression
import scm2cpp_learn as m
from scm2cpp_learn._libfind import gramops_backend

warnings.simplefilter("ignore")


def best_of(f):
    t = []
    for _ in range(a.best):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


rng = np.random.default_rng(0)
print(f"threads={a.threads}  gramops={gramops_backend()}  package {m.__version__}")
print(f"{'case':52s} {'diff':>9s} {'sklearn':>8s} {'ours':>8s} {'ratio':>6s}")
for n, p, d in [(200_000, 200, 0.05), (100_000, 1_000, 0.01), (50_000, 2_000, 0.005)]:
    X = sp.random(n, p, density=d, format="csr", random_state=1, data_rvs=rng.standard_normal)
    y = X[:, :20] @ rng.standard_normal(20) + 0.1 * rng.standard_normal(n)
    shape = f"{n:,} x {p:,}, {d:g} dense"
    for name, sk, ours in [
            ("Lasso", lambda: Lasso(alpha=1e-3, tol=1e-10, max_iter=100_000),
             lambda: m.GramLasso(alpha=1e-3, tol=1e-10)),
            ("ElasticNet", lambda: ElasticNet(alpha=1e-3, tol=1e-10, max_iter=100_000),
             lambda: m.GramElasticNet(alpha=1e-3, tol=1e-10)),
            ("Ridge", lambda: Ridge(alpha=1.0), lambda: m.GramRidge(alpha=1.0)),
            ("LinearRegression", LinearRegression, m.GramLinearRegression)]:
        ts, s = best_of(lambda: sk().fit(X, y))
        to, o = best_of(lambda: ours().fit(X, y))
        cd = np.abs(s.coef_ - o.coef_).max() / max(np.abs(s.coef_).max(), 1e-300)
        print(f"{name + ', ' + shape:52s} {cd:9.1e} {ts:8.3f} {to:8.3f} {ts / to:5.1f}x")
        sys.stdout.flush()
    for algo in ("randomized", "arpack"):
        ts, s = best_of(lambda: TruncatedSVD(10, algorithm=algo, random_state=0).fit(X))
        to, o = best_of(lambda: m.GramTruncatedSVD(10).fit(X))
        sd = np.abs(s.singular_values_ - o.singular_values_).max() / s.singular_values_[0]
        print(f"{'TruncatedSVD(' + algo + '), ' + shape:52s} {sd:9.1e} {ts:8.3f} {to:8.3f} {ts / to:5.1f}x")
        sys.stdout.flush()
