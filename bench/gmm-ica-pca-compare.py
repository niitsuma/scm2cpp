"""EMGaussianMixture, ParallelFastICA and CovPCA against scikit-learn.

Each is scikit-learn's algorithm written in the subset (gmm.scm,
fastica.scm, pca.scm over sym-eigen.scm) and translated with --blas into
the scm2cpp-learn package.  Both sides start from the same draws
(random_state 0: the same KMeans labels for the mixture, the same
normal start for FastICA), so the iteration counts agree; the script
prints them, the largest difference in the fitted parameters and the
whole fit times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/gmm-ica-pca-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time
import warnings

import numpy as np
from sklearn.decomposition import PCA, FastICA
from sklearn.mixture import GaussianMixture

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
    print(f"{name:<34} {it:>9} {d:>9.1e} {ts:>9.4f} {to:>9.4f} {ts / to:>6.1f}x")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(0)
    print("backend:", m._libfind.gramops_backend())
    print(f"{'estimator, n x p':<34} {'it sk/us':>9} {'max diff':>9}"
          f" {'sklearn s':>9} {'ours s':>9} {'ratio':>7}")
    for n, p, k, sep in [(2000, 5, 4, 3.0), (20000, 10, 8, 3.0), (20000, 10, 8, 1.0),
                         (100000, 20, 5, 3.0)]:
        C = sep * rng.standard_normal((k, p))
        X = np.vstack([C[c] + 0.5 * rng.standard_normal((n // k, p)) @ rng.standard_normal((p, p))
                       for c in range(k)])
        ts, sk = best(lambda: GaussianMixture(k, random_state=0).fit(X), a.best)
        to, us = best(lambda: m.EMGaussianMixture(k, random_state=0).fit(X), a.best)
        d = max(np.abs(sk.weights_ - us.weights_).max(), np.abs(sk.means_ - us.means_).max())
        row(f"GaussianMixture, {X.shape[0]:,} x {p} ({k}{', close' if sep < 2 else ''})", ts, to,
            f"{sk.n_iter_}/{us.n_iter_}", d)
    for n, p in [(5000, 8), (50000, 10), (100000, 30)]:
        t = np.linspace(0, 50, n)
        S = np.column_stack([np.sin((j + 1) * t + j) if j % 3 == 0 else
                             (np.sign(np.sin((j + 2) * t)) if j % 3 == 1 else rng.laplace(size=n))
                             for j in range(p)])
        X = S @ rng.standard_normal((p, p))
        ts, sk = best(lambda: FastICA(random_state=0).fit(X), a.best)
        to, us = best(lambda: m.ParallelFastICA(random_state=0).fit(X), a.best)
        d = np.abs(sk.components_ - us.components_).max() / np.abs(sk.components_).max()
        row(f"FastICA, {n:,} x {p}", ts, to, f"{sk.n_iter_}/{us.n_iter_}", d)
    for n, p in [(1000, 10), (10000, 50), (100000, 50), (20000, 200), (50000, 500)]:
        X = rng.standard_normal((n, p)) @ rng.standard_normal((p, p)) + 3.0
        ts, sk = best(lambda: PCA().fit(X), a.best)
        to, us = best(lambda: m.CovPCA().fit(X), a.best)
        d = max(np.abs(sk.components_ - us.components_).max(),
                np.abs(sk.explained_variance_ - us.explained_variance_).max()
                / sk.explained_variance_.max())
        row(f"PCA ({sk._fit_svd_solver}), {n:,} x {p}", ts, to, "-", d)


if __name__ == "__main__":
    main()
