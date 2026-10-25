"""The GLMs, the cross-validated estimators and Theil-Sen against
scikit-learn.

PoissonRegressor, GammaRegressor and TweedieRegressor are glm.scm under
lbfgs.scm (the package's LBFGS*Regressor); LogisticRegressionCV,
LarsCV, LassoLarsCV and OrthogonalMatchingPursuitCV are the package's
compositions of the translated logistic regression, LARS path and OMP
path, the folds dealt as scikit-learn deals them (KFold /
StratifiedKFold without shuffling); TheilSenRegressor is theilsen.scm
over scikit-learn's own subsets.  Prints iterations or the chosen
parameter on both sides, the largest coefficient difference and the
whole fit times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/glm-cv-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time
import warnings

import numpy as np
from sklearn.linear_model import (GammaRegressor, LarsCV, LassoLarsCV, LogisticRegressionCV,
                                  OrthogonalMatchingPursuitCV, PoissonRegressor,
                                  TheilSenRegressor, TweedieRegressor)

import scm2cpp_learn as m

warnings.simplefilter("ignore")


def best(f, k):
    t = []
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def row(name, ts, to, it, d):
    print(f"{name:<40} {it:>15} {d:>9.1e} {ts:>9.4f} {to:>9.4f} {ts / to:>6.1f}x")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(0)
    print(f"{'estimator, n x p':<40} {'sk / ours':>15} {'max diff':>9}"
          f" {'sklearn s':>9} {'ours s':>9} {'ratio':>7}")
    for n, p in [(2000, 20), (50000, 100)]:
        X = rng.standard_normal((n, p)) / np.sqrt(p)
        w = 0.5 * rng.standard_normal(p)
        mu = np.exp(X @ w + 0.5)
        yp = rng.poisson(mu).astype(float)
        yg = rng.gamma(2.0, mu / 2.0)
        yt = yg * (rng.random(n) < 0.7)
        for name, sk, us, y in [
                ("PoissonRegressor alpha 1e-3", PoissonRegressor(alpha=1e-3),
                 m.LBFGSPoissonRegressor(alpha=1e-3), yp),
                ("GammaRegressor alpha 1e-3", GammaRegressor(alpha=1e-3),
                 m.LBFGSGammaRegressor(alpha=1e-3), yg),
                ("TweedieRegressor power 1.5, alpha 1e-3", TweedieRegressor(power=1.5, alpha=1e-3),
                 m.LBFGSTweedieRegressor(power=1.5, alpha=1e-3), yt)]:
            ts, s = best(lambda: sk.fit(X, y), a.best)
            to, u = best(lambda: us.fit(X, y), a.best)
            d = max(np.abs(s.coef_ - u.coef_).max(), abs(s.intercept_ - u.intercept_))
            row(f"{name}, {n:,} x {p}", ts, to, f"{s.n_iter_}/{u.n_iter_}", d)
    for n, p, k in [(2000, 20, 2), (20000, 50, 3)]:
        X = rng.standard_normal((n, p))
        W = 0.5 * rng.standard_normal((k, p))
        y = np.argmax(X @ W.T + rng.gumbel(size=(n, k)), 1)
        ts, s = best(lambda: LogisticRegressionCV().fit(X, y), 1)
        to, u = best(lambda: m.LBFGSLogisticRegressionCV().fit(X, y), 1)
        d = max(np.abs(s.coef_ - u.coef_).max(), np.abs(s.intercept_ - u.intercept_).max())
        row(f"LogisticRegressionCV, {n:,} x {p} ({k})", ts, to,
            f"C {s.C_[0]:.3g}/{u.C_:.3g}", d)
    for n, p in [(2000, 50), (50000, 200)]:
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[: p // 4] = rng.standard_normal(p // 4)
        y = X @ w + rng.standard_normal(n)
        for name, sk, us in [("LarsCV", LarsCV(), m.GramLarsCV()),
                             ("LassoLarsCV", LassoLarsCV(), m.GramLassoLarsCV())]:
            ts, s = best(lambda: sk.fit(X, y), a.best)
            to, u = best(lambda: us.fit(X, y), a.best)
            row(f"{name}, {n:,} x {p}", ts, to, f"a {s.alpha_:.3g}/{u.alpha_:.3g}",
                np.abs(s.coef_ - u.coef_).max())
        ts, s = best(lambda: OrthogonalMatchingPursuitCV().fit(X, y), a.best)
        to, u = best(lambda: m.GramOMPCV().fit(X, y), a.best)
        row(f"OrthogonalMatchingPursuitCV, {n:,} x {p}", ts, to,
            f"k {s.n_nonzero_coefs_}/{u.n_nonzero_coefs_}", np.abs(s.coef_ - u.coef_).max())
    for n, p in [(50, 2), (1000, 5), (5000, 10)]:
        X = rng.standard_normal((n, p))
        y = X @ rng.standard_normal(p) + 0.3 * rng.standard_normal(n) + 1.0
        y[: n // 10] += 10.0
        ts, s = best(lambda: TheilSenRegressor(random_state=0).fit(X, y), a.best)
        to, u = best(lambda: m.WeiszfeldTheilSen(random_state=0).fit(X, y), a.best)
        row(f"TheilSenRegressor, {n:,} x {p}", ts, to, f"{s.n_iter_}/{u.n_iter_}",
            max(np.abs(s.coef_ - u.coef_).max(), abs(s.intercept_ - u.intercept_)))


if __name__ == "__main__":
    main()
