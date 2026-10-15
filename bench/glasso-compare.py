"""The graphical lasso against scikit-learn's GraphicalLasso.

    python3 bench/glasso-compare.py --kernel-dir LABEL=DIR [..] [--p P ..]

Each --kernel-dir holds graphical_lasso.py and libgraphical_lasso.so
built from examples/kernel-only/graphical-lasso.scm with -M (plainly,
or with --blas: its two matrix-vector products as dgemv).  Both sides
run scikit-learn's algorithm -- _graphical_lasso in mode "cd" with
enet_coordinate_descent_gram inside -- at alpha 0.1, tol and enet_tol
1e-4, at most 100 iterations, on the empirical covariance of n = 20 p
draws of an AR(1) series (rho 0.5, standardized: a tridiagonal true
precision).  The iteration counts and the largest precision difference
are printed beside the times; BLAS pinned to one thread.
"""
import argparse
import importlib.util
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time
import warnings
from pathlib import Path

import numpy as np


def load(d):
    spec = importlib.util.spec_from_file_location("gl_" + str(abs(hash(d))), Path(d) / "graphical_lasso.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", action="append", default=[])
    ap.add_argument("--p", action="append", type=int, default=[])
    args = ap.parse_args()
    from sklearn.covariance import GraphicalLasso, empirical_covariance
    warnings.simplefilter("ignore")
    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or Path(d).name, load(d)))
    for p in args.p or [50, 100, 200, 400, 800]:
        n = 20 * p
        rng = np.random.default_rng(0)
        X = np.empty((n, p))
        X[:, 0] = rng.standard_normal(n)
        for j in range(1, p):
            X[:, j] = 0.5 * X[:, j - 1] + np.sqrt(0.75) * rng.standard_normal(n)
        X = (X - X.mean(0)) / X.std(0)
        emp = np.ascontiguousarray(empirical_covariance(X))
        t = time.perf_counter()
        s = GraphicalLasso(alpha=0.1, tol=1e-4, enet_tol=1e-4, max_iter=100).fit(X)
        ts = time.perf_counter() - t
        print(f"p={p}, n={n}, alpha 0.1, one core", flush=True)
        print("  %-36s %9.4f s   iterations %3d" % ("sklearn GraphicalLasso", ts, s.n_iter_), flush=True)
        for label, m in kernels:
            C = np.zeros((p, p))
            P = np.zeros((p, p))
            t = time.perf_counter()
            it = m.graphical_lasso(emp, C, P, 0.1, 100, 1e-4, 1e-4, p)
            tt = time.perf_counter() - t
            print("  %-36s %9.4f s   iterations %3d   max |dPrecision| %.1e   %.1fx"
                  % ("graphical-lasso.scm (%s)" % label, tt, it, np.abs(P - s.precision_).max(), ts / tt),
                  flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
