"""The package against scikit-learn and Intel's sklearnex on the
estimators both accelerate.

sklearnex (scikit-learn-intelex, oneDAL underneath) replaces some
scikit-learn estimators with its own; of those, these have a
counterpart here: LogisticRegression (lbfgs), Ridge, PCA, SVC, SVR,
and RFE around Ridge.  Its estimators are imported from sklearnex
directly rather than patched in, so the same process times scikit-learn
itself too.  Each row prints the iterations where the estimator has
them, the largest difference of the coefficients (or components, or
decision values) from scikit-learn's, and the whole fit times (best
of --best).

--threads 1 pins BLAS, OpenMP and oneDAL's TBB to one thread (run it
under taskset -c 0 as well); --threads all leaves every library its
defaults (sklearnex and scikit-learn's BLAS then use every core, and so
does the package: its classifiers and gramops run their loops under
OpenMP and their products in the BLAS they were built against).
The device column is the package's
default (the device build where one answers and the problem is large);
the CPU column forces SCM2CPP_NO_DEVICE=1.
"""
import argparse
import os
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--best", type=int, default=2)
ap.add_argument("--threads", choices=["1", "all"], default="1")
a = ap.parse_args()
if a.threads == "1":
    for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "TBB_NUM_THREADS"):
        os.environ[v] = "1"

import time
import warnings

import numpy as np
from sklearn.decomposition import PCA
from sklearn.feature_selection import RFE
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.svm import SVC, SVR

import sklearnex
from sklearnex.decomposition import PCA as XPCA
from sklearnex.linear_model import LogisticRegression as XLogisticRegression
from sklearnex.linear_model import Ridge as XRidge
from sklearnex.svm import SVC as XSVC
from sklearnex.svm import SVR as XSVR

import scm2cpp_learn as m

warnings.simplefilter("ignore")
if a.threads == "1":
    try:
        import daal4py
        daal4py.daalinit(1)
    except Exception:
        pass


def best(f, k):
    t = []
    r = None
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def on_cpu(f):
    os.environ["SCM2CPP_NO_DEVICE"] = "1"
    try:
        return f()
    finally:
        del os.environ["SCM2CPP_NO_DEVICE"]


def its(o):
    it = getattr(o, "n_iter_", None)
    if it is None:
        return "-"
    return str(int(np.max(it))) if hasattr(it, "shape") else str(int(it))


def main():
    print(f"threads={a.threads}  sklearnex {getattr(sklearnex, '__version__', '?')}  "
          f"device: {m.cuda_available()}")
    print(f"{'estimator, n x p':<34} {'it sk/x/ours':>13} {'x-sk':>7} {'ours-sk':>7} "
          f"{'sklearn':>8} {'sklearnex':>9} {'ours cpu':>8} {'ours dev':>8} {'sk/ours':>7} {'x/ours':>7}")
    rng = np.random.default_rng(0)
    rows = []

    n, p = 200000, 100
    X = rng.standard_normal((n, p)) / 10
    w = rng.standard_normal(p)
    yb = (X @ w + rng.logistic(size=n) > 0).astype(int)
    rows.append(("LogisticRegression", X, yb,
                 lambda: LogisticRegression().fit(X, yb),
                 lambda: XLogisticRegression().fit(X, yb),
                 lambda: m.LBFGSLogisticRegression().fit(X, yb),
                 lambda o: o.coef_.ravel()))

    n, p = 200000, 200
    Xr = rng.standard_normal((n, p))
    yr = Xr @ rng.standard_normal(p) + rng.standard_normal(n)
    rows.append(("Ridge (alpha 1, no intercept)", Xr, yr,
                 lambda: Ridge(alpha=1.0, fit_intercept=False).fit(Xr, yr),
                 lambda: XRidge(alpha=1.0, fit_intercept=False).fit(Xr, yr),
                 lambda: _Coef(m.CovRidge(Xr, yr).fit(1.0)),
                 lambda o: np.ravel(o.coef_)))

    for n, p in ((100000, 50), (50000, 500)):
        Xp = rng.standard_normal((n, p)) @ rng.standard_normal((p, p))
        rows.append((f"PCA (10 components)", Xp, None,
                     lambda Xp=Xp: PCA(10, svd_solver="covariance_eigh").fit(Xp),
                     lambda Xp=Xp: XPCA(10).fit(Xp),
                     lambda Xp=Xp: m.CovPCA(10).fit(Xp),
                     lambda o: np.abs(o.components_).ravel()))

    n, p = 5000, 20
    Xs = rng.standard_normal((n, p))
    ys = (np.sin(Xs[:, 0]) + Xs[:, 1] ** 2 + 0.3 * rng.standard_normal(n) > 1).astype(int)
    rows.append(("SVC (rbf)", Xs, ys,
                 lambda: SVC().fit(Xs, ys),
                 lambda: XSVC().fit(Xs, ys),
                 lambda: m.KernelSVM().fit(Xs, ys),
                 lambda o: o.decision_function(Xs[:200])))
    yv = np.sin(Xs[:, 0]) + Xs[:, 1] ** 2 + 0.3 * rng.standard_normal(n)
    rows.append(("SVR (rbf)", Xs, yv,
                 lambda: SVR().fit(Xs, yv),
                 lambda: XSVR().fit(Xs, yv),
                 lambda: m.KernelSVR().fit(Xs, yv),
                 lambda o: o.predict(Xs[:200])))

    n, p = 20000, 200
    Xf = rng.standard_normal((n, p))
    yf = Xf[:, :10] @ rng.standard_normal(10) + rng.standard_normal(n)
    rows.append(("RFE(Ridge), 20 kept", Xf, yf,
                 lambda: RFE(Ridge(alpha=1.0), n_features_to_select=20).fit(Xf, yf),
                 lambda: RFE(XRidge(alpha=1.0), n_features_to_select=20).fit(Xf, yf),
                 lambda: m.GramRFE(1.0, n_features_to_select=20).fit(Xf, yf),
                 lambda o: o.ranking_.astype(float)))

    for name, Xc, _, sk, x, us, val in rows:
        ts, s = best(sk, 1)
        tx, xo = best(x, a.best)
        tc, c = best(lambda: on_cpu(us), a.best)
        td, d = best(us, a.best)
        ref = val(s)
        scale = max(1.0, np.abs(ref).max())
        dx = np.abs(val(xo) - ref).max() / scale
        dc = np.abs(val(c) - ref).max() / scale
        t_ours = min(tc, td)
        print(f"{name + f', {Xc.shape[0]:,} x {Xc.shape[1]}':<34} "
              f"{its(s) + '/' + its(xo) + '/' + its(c):>13} {dx:>7.0e} {dc:>7.0e} "
              f"{ts:>8.3f} {tx:>9.3f} {tc:>8.3f} {td:>8.3f} {ts / t_ours:>6.1f}x {tx / t_ours:>6.1f}x",
              flush=True)


class _Coef:
    def __init__(self, coef):
        self.coef_ = np.asarray(coef)


if __name__ == "__main__":
    main()
