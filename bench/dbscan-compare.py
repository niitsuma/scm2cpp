"""DBSCAN by tiled products against scikit-learn's.

    python3 bench/dbscan-compare.py --kernel-dir LABEL=DIR [..]

Each --kernel-dir holds dbscan.py and libdbscan.so built from
examples/kernel-only/dbscan.scm with -M (plainly, --blas or --cublas).
The references are DBSCAN(algorithm="brute"), the same neighbour
search, and DBSCAN() at its default (a tree in low dimension).  Data:
make_blobs, 8 centres.  The labels and the core points must be
scikit-learn's exactly; the times are one core, tiles of 256 x 1024.
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
    spec = importlib.util.spec_from_file_location("db_" + str(abs(hash(d))), Path(d) / "dbscan.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", action="append", default=[])
    args = ap.parse_args()
    from sklearn.cluster import DBSCAN
    from sklearn.datasets import make_blobs
    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or Path(d).name, load(d)))
    for n, p, eps, ms in [(5000, 2, 0.3, 5), (20000, 2, 0.15, 5), (5000, 32, 6.0, 5), (20000, 32, 6.0, 10)]:
        X, _ = make_blobs(n_samples=n, n_features=p, centers=8, cluster_std=1.0, random_state=0)
        X = np.ascontiguousarray(X)
        t = time.perf_counter()
        ref = DBSCAN(eps=eps, min_samples=ms, algorithm="brute").fit(X)
        tb = time.perf_counter() - t
        t = time.perf_counter()
        DBSCAN(eps=eps, min_samples=ms).fit(X)
        ta = time.perf_counter() - t
        print(f"n={n} p={p} eps={eps} min_samples={ms}: {ref.labels_.max() + 1} clusters, "
              f"{(ref.labels_ < 0).sum()} noise", flush=True)
        print("  %-30s %8.3f s" % ("sklearn DBSCAN(algorithm='brute')", tb))
        print("  %-30s %8.3f s" % ("sklearn DBSCAN() default", ta))
        for label, m in kernels:
            if label == "plain" and n > 5000:
                continue
            lab = np.zeros(n)
            core = np.zeros(n)
            t = time.perf_counter()
            m.dbscan(X, lab, core, eps, ms, 256, 1024, n, p)
            tt = time.perf_counter() - t
            same = (np.array_equal(lab.astype(int), ref.labels_)
                    and np.array_equal(np.flatnonzero(core), ref.core_sample_indices_))
            print("  %-30s %8.3f s   labels and core points identical: %s"
                  % ("dbscan.scm (%s)" % label, tt, same), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
