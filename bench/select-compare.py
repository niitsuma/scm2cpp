"""Feature selection and the device's Gram against scikit-learn.

f_regression / f_classif / SelectKBest / RFE are fscore.scm and rfe.scm
translated into the scm2cpp-lasso package; f_regression takes many
targets in one call (X'Y one product, on the device when one answers),
where scikit-learn is called once per target.  The second table is the
Gram-route estimators whose X'X the package now forms on the device
(gram.scm --cublas) when one answers and the product is large, against
the same estimators forced onto the CPU and against scikit-learn.
Prints the agreement and the whole call times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/select-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time
import warnings

import numpy as np
from sklearn.decomposition import PCA
from sklearn.feature_selection import RFE, SelectKBest, f_classif, f_regression
from sklearn.linear_model import LassoLarsCV, LassoLarsIC, LinearRegression, Ridge

import scm2cpp_lasso as m

warnings.simplefilter("ignore")


def best(f, k):
    t = []
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def row(name, ts, to, note):
    print(f"{name:<44} {ts:>9.4f} {to:>9.4f} {ts / to:>7.1f}x  {note}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(0)
    print("device:", m.cuda_available())
    print(f"{'call, n x p':<44} {'sklearn s':>9} {'ours s':>9} {'ratio':>8}  agreement")
    for n, p, q in [(100000, 500, 1), (20000, 1000, 100), (100000, 200, 200)]:
        X = rng.standard_normal((n, p))
        Y = X[:, :5] @ rng.standard_normal((5, q)) + rng.standard_normal((n, q))
        k = 1 if q > 1 else a.best
        ts, F0 = best(lambda: np.column_stack([f_regression(X, Y[:, j])[0] for j in range(q)]), k)
        to, (F1, _) = best(lambda: m.f_regression(X, Y if q > 1 else Y[:, 0]), k)
        d = np.abs(F1.reshape(p, q) - F0).max() / np.abs(F0).max()
        row(f"f_regression, {n:,} x {p}, {q} target(s)", ts, to, f"F to {d:.0e}")
    for n, p, c in [(100000, 500, 10)]:
        X = rng.standard_normal((n, p))
        y = rng.integers(0, c, n)
        X[:, 0] += y
        ts, s = best(lambda: SelectKBest(f_classif, k=20).fit(X, y), a.best)
        to, u = best(lambda: m.SelectKBest("f_classif", k=20).fit(X, y), a.best)
        same = (s.get_support() == u.get_support()).all()
        row(f"SelectKBest(f_classif), {n:,} x {p}", ts, to, "same features" if same else "DIFF")
    for n, p, alpha in [(5000, 100, 1.0), (50000, 300, 1.0), (20000, 500, 0.0)]:
        X = rng.standard_normal((n, p))
        y = X[:, :20] @ rng.standard_normal(20) + rng.standard_normal(n)
        est = Ridge(alpha=alpha) if alpha > 0 else LinearRegression()
        ts, s = best(lambda: RFE(est, n_features_to_select=10).fit(X, y), 1)
        to, u = best(lambda: m.GramRFE(alpha, n_features_to_select=10).fit(X, y), a.best)
        same = (s.ranking_ == u.ranking_).all()
        row(f"RFE({'Ridge' if alpha else 'LinearRegression'}), {n:,} x {p}", ts, to,
            f"{'same ranking' if same else 'DIFF'}, coef to {np.abs(s.estimator_.coef_ - u.coef_).max():.0e}")
    print()
    print(f"{'Gram on the device, n x p':<44} {'sklearn s':>9} {'cpu s':>9} {'device s':>9}")
    for n, p in [(200000, 100), (100000, 300)]:
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[: p // 4] = rng.standard_normal(p // 4)
        y = X @ w + rng.standard_normal(n)
        for name, sk, us in [("LassoLarsIC", LassoLarsIC(), m.GramLassoLarsIC()),
                             ("LassoLarsCV", LassoLarsCV(), m.GramLassoLarsCV())]:
            ts, _ = best(lambda: sk.fit(X, y), 1)
            os.environ["SCM2CPP_NO_DEVICE"] = "1"
            tc, _ = best(lambda: us.fit(X, y), a.best)
            del os.environ["SCM2CPP_NO_DEVICE"]
            tg, _ = best(lambda: us.fit(X, y), a.best)
            print(f"{name + f', {n:,} x {p}':<44} {ts:>9.4f} {tc:>9.4f} {tg:>9.4f}")
    for n, p in [(50000, 500), (200000, 300)]:
        X = rng.standard_normal((n, p))
        ts, _ = best(lambda: PCA().fit(X), a.best)
        tc, _ = best(lambda: m.CovPCA(backend="cpu").fit(X), a.best)
        tg, _ = best(lambda: m.CovPCA().fit(X), a.best)
        print(f"{f'PCA, {n:,} x {p}':<44} {ts:>9.4f} {tc:>9.4f} {tg:>9.4f}")


if __name__ == "__main__":
    main()
