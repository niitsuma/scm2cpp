"""k-means (Lloyd) against scikit-learn's KMeans(algorithm="lloyd").

    python3 bench/kmeans-compare.py --kernel-dir LABEL=DIR [..]

Each --kernel-dir holds kmeans.py and libkmeans.so built from
examples/kernel-only/kmeans.scm with -M (plainly, --blas or --cublas).
Both sides start from the same k points (init=array, n_init=1), at
tol 1e-4 and 300 iterations at most; ours is given X centred on its
mean and the tol scaled by the mean variance, as KMeans does inside,
and both are timed whole.  The labels must be scikit-learn's; the
iteration counts, the inertia and the largest centre difference are
printed.  Data: make_blobs, cluster_std 3.  One core.
"""
import argparse
import importlib.util
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time
from pathlib import Path

import numpy as np


def load(d):
    spec = importlib.util.spec_from_file_location("km_" + str(abs(hash(d))), Path(d) / "kmeans.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", action="append", default=[])
    args = ap.parse_args()
    from sklearn.cluster import KMeans
    from sklearn.datasets import make_blobs
    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or Path(d).name, load(d)))
    for n, p, k in [(10000, 20, 8), (100000, 20, 16), (100000, 100, 32), (200000, 50, 64)]:
        X, _ = make_blobs(n_samples=n, n_features=p, centers=k, cluster_std=3.0, random_state=0)
        init = X[np.random.default_rng(1).choice(n, k, replace=False)].copy()
        t = time.perf_counter()
        s = KMeans(n_clusters=k, init=init, n_init=1, max_iter=300, tol=1e-4, algorithm="lloyd").fit(X)
        ts = time.perf_counter() - t
        print(f"n={n} p={p} k={k}, one core", flush=True)
        print("  %-26s %8.3f s   iterations %3d   inertia %.10g" % ("sklearn KMeans(lloyd)", ts, s.n_iter_, s.inertia_))
        for label, m in kernels:
            if label == "plain" and n > 10000:
                continue
            t = time.perf_counter()
            mu = X.mean(0)
            Xc = np.ascontiguousarray(X - mu)
            C = np.ascontiguousarray(init - mu)
            lab = np.zeros(n)
            out = np.zeros(1)
            it = m.kmeans(Xc, C, lab, out, 300, 1e-4 * np.mean(np.var(X, axis=0)), 256, n, p, k)
            C += mu
            tt = time.perf_counter() - t
            print("  %-26s %8.3f s   iterations %3d   inertia %.10g   labels identical %s   max |dC| %.1e   %.2fx"
                  % ("kmeans.scm (%s)" % label, tt, it, out[0], np.array_equal(lab.astype(int), s.labels_),
                     np.abs(C - s.cluster_centers_).max(), ts / tt), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
