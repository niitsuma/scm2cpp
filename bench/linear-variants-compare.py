"""Perceptron, the passive-aggressive SGD steps, ARDRegression,
LassoLarsIC and LinearSVC(penalty="l1") against scikit-learn.

Each is scikit-learn's algorithm translated into the scm2cpp-lasso
package: sgd.scm's perceptron and pa1/pa2 options (SGDPerceptron,
SGDLinearClassifier/Regressor), ard.scm (CovARDRegression, the kept
Gram hoisted and not), lars.scm's recorded path (GramLassoLarsIC) and
svm-l1.scm (L1LinearSVM, liblinear's solve_l1r_l2_svc with its own
random order, so it agrees to the tolerance).  SGD runs with
shuffle=False on both sides.  Prints iterations, the largest
coefficient difference and the whole fit times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/linear-variants-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time
import warnings

import numpy as np
from sklearn.linear_model import (ARDRegression, LassoLarsIC, Perceptron, SGDClassifier,
                                  SGDRegressor)
from sklearn.svm import LinearSVC

import scm2cpp_lasso as m

warnings.simplefilter("ignore")


def best(f, k):
    t = []
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def row(name, ts, to, it, d):
    print(f"{name:<40} {it:>11} {d:>9.1e} {ts:>9.4f} {to:>9.4f} {ts / to:>6.1f}x")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(0)
    print(f"{'estimator, n x p':<40} {'it sk/us':>11} {'max diff':>9}"
          f" {'sklearn s':>9} {'ours s':>9} {'ratio':>7}")
    for n, p in [(10000, 20), (100000, 50)]:
        X = rng.standard_normal((n, p))
        w0 = rng.standard_normal(p)
        yc = np.where(X @ w0 + 0.5 * rng.standard_normal(n) > 0, 1, -1)
        yr = X @ w0 + 0.3 * rng.standard_normal(n)
        for name, sk, us, y in [
                ("Perceptron", Perceptron(shuffle=False), m.SGDPerceptron(), yc),
                ("SGDClassifier pa1 (PassiveAggressive)",
                 SGDClassifier(loss="hinge", penalty=None, learning_rate="pa1", eta0=1.0,
                               shuffle=False),
                 m.SGDLinearClassifier(loss="hinge", penalty=None, learning_rate="pa1",
                                       eta0=1.0), yc),
                ("SGDRegressor eps-insensitive pa1",
                 SGDRegressor(loss="epsilon_insensitive", penalty=None, learning_rate="pa1",
                              eta0=1.0, shuffle=False),
                 m.SGDLinearRegressor(loss="epsilon_insensitive", penalty=None,
                                      learning_rate="pa1", eta0=1.0), yr)]:
            ts, s = best(lambda: sk.fit(X, y), a.best)
            to, u = best(lambda: us.fit(X, y), a.best)
            d = max(np.abs(s.coef_.ravel() - u.coef_).max(),
                    abs(float(np.ravel(s.intercept_)[0]) - u.intercept_))
            row(f"{name}, {n:,} x {p}", ts, to, f"{s.n_iter_}/{u.n_iter_}", d)
    for n, p in [(2000, 50), (20000, 100), (100000, 200)]:
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[: p // 5] = 3.0 * rng.standard_normal(p // 5)
        y = X @ w + 0.5 * rng.standard_normal(n) + 1.0
        ts, s = best(lambda: ARDRegression().fit(X, y), a.best)
        for hoist in (False, True):
            to, u = best(lambda: m.CovARDRegression(hoist=hoist).fit(X, y), a.best)
            row(f"ARDRegression{' (hoisted Gram)' if hoist else ''}, {n:,} x {p}", ts, to,
                f"{s.n_iter_}/{u.n_iter_}", np.abs(s.coef_ - u.coef_).max())
    for n, p in [(5000, 100), (50000, 200), (200000, 100)]:
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[: p // 4] = rng.standard_normal(p // 4)
        y = X @ w + rng.standard_normal(n)
        for crit in ("aic", "bic"):
            ts, s = best(lambda: LassoLarsIC(criterion=crit).fit(X, y), a.best)
            to, u = best(lambda: m.GramLassoLarsIC(crit).fit(X, y), a.best)
            row(f"LassoLarsIC {crit}, {n:,} x {p}", ts, to, f"{s.n_iter_}/{u.n_iter_}",
                np.abs(s.coef_ - u.coef_).max())
    for n, p in [(5000, 100), (100000, 50)]:
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[: p // 5] = rng.standard_normal(p // 5)
        y = np.where(X @ w + 0.3 * rng.standard_normal(n) + 0.2 > 0, 1, -1)
        ts, s = best(lambda: LinearSVC(penalty="l1", dual=False, random_state=0).fit(X, y), 1)
        to, u = best(lambda: m.L1LinearSVM().fit(X, y), 1)
        Xb = np.hstack([X, np.ones((n, 1))])
        ws, wu = np.r_[s.coef_.ravel(), s.intercept_], np.r_[u.coef_, u.intercept_]
        obj = lambda v: np.abs(v).sum() + (np.maximum(0, 1 - y * (Xb @ v)) ** 2).sum()
        row(f"LinearSVC l1 (objective rel. diff), {n:,} x {p}", ts, to,
            f"{s.n_iter_}/{u.n_iter_}", abs(obj(wu) - obj(ws)) / obj(ws))


if __name__ == "__main__":
    main()
