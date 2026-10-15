"""NMF by coordinate descent, derived, against scikit-learn's.

    python3 bench/nmf-compare.py --kernel-dir LABEL=DIR [..] [--shape N,P,K ..]

Each --kernel-dir holds nmf_cd.py and libnmf_cd.so built from
examples/kernel-only/nmf-cd.scm with -M: plainly (the residual form as
written), or with --derive --blas / --derive --cublas, where the half
step becomes scikit-learn's form (the memo X HT - W HT'HT, R never
formed).  The reference is NMF(solver="cd", init="custom", tol=1e-4,
max_iter=200) from the same W and H, Frobenius loss, no
regularization, no shuffling: the same iteration on both sides, so the
iteration counts and the factors are printed beside the times.  Data:
|A B| plus a little noise, A n x k and B k x p Gaussian.  BLAS pinned
to one thread; the plain build is skipped above 3e6 entries.
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
    spec = importlib.util.spec_from_file_location("nmf_" + str(abs(hash(d))), Path(d) / "nmf_cd.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", action="append", default=[])
    ap.add_argument("--shape", action="append", default=[])
    args = ap.parse_args()
    from sklearn.decomposition import NMF
    warnings.simplefilter("ignore")
    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or Path(d).name, load(d)))
    for spec in args.shape or ["1000,500,10", "5000,2000,20", "20000,1000,30"]:
        n, p, k = map(int, spec.split(","))
        rng = np.random.default_rng(0)
        X = np.abs(rng.standard_normal((n, k)) @ rng.standard_normal((k, p))) + 0.1 * rng.random((n, p))
        W0 = rng.random((n, k))
        H0 = rng.random((k, p))
        print(f"n={n} p={p} k={k}, 200 iterations at most, tol 1e-4, one core", flush=True)
        t = time.perf_counter()
        s = NMF(n_components=k, solver="cd", init="custom", tol=1e-4, max_iter=200)
        Ws = s.fit_transform(X, W=W0.copy(), H=H0.copy())
        ts = time.perf_counter() - t
        print("  %-34s %8.3f s   iterations %3d   |X - WH| %.8g"
              % ("sklearn NMF(solver='cd')", ts, s.n_iter_, np.linalg.norm(X - Ws @ s.components_)), flush=True)
        for label, m in kernels:
            if label == "plain" and n * p > 3e6:
                continue
            W = W0.copy()
            HT = np.ascontiguousarray(H0.T)
            t = time.perf_counter()
            XT = np.ascontiguousarray(X.T)
            it = m.nmf(X, XT, W, HT, 200, 1e-4, n, p, k)
            tt = time.perf_counter() - t
            print("  %-34s %8.3f s   iterations %3d   |X - WH| %.8g   max |W - W_sklearn| %.1e   %.2fx"
                  % ("nmf-cd.scm (%s)" % label, tt, it, np.linalg.norm(X - W @ HT.T),
                     np.abs(W - Ws).max(), ts / tt), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
