"""SGD, OMP and LARS against scikit-learn's.

    python3 bench/sgd-omp-lars-compare.py --sgd-dir DIR --omp-dir DIR --lars-dir DIR

Each directory holds the -M build of examples/kernel-only/sgd.scm,
omp.scm (built with --blas) or lars.scm.  Both sides run
scikit-learn's algorithm on the same data, one core:

  SGDClassifier / SGDRegressor at their defaults with shuffle=False
    (the kernel visits the points in order), against sgd.scm;
  OrthogonalMatchingPursuit (n > p, its Gram route), against omp.scm
    on the centred data, X'X and X'y formed inside;
  Lars(n_nonzero_coefs=p/5) and LassoLars(alpha=0.01) (n > p, the Gram
    route), against lars.scm on the centred Gram formed in numpy.

The ours side includes the centring (and, for LARS, the Gram).  The
coefficient differences and the iteration counts are printed.
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


def load(d, base):
    spec = importlib.util.spec_from_file_location(base + str(abs(hash(d))), Path(d) / (base + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def timed(fn):
    t = time.perf_counter()
    out = fn()
    return out, time.perf_counter() - t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sgd-dir", required=True)
    ap.add_argument("--omp-dir", required=True)
    ap.add_argument("--lars-dir", required=True)
    args = ap.parse_args()
    from sklearn.linear_model import (SGDClassifier, SGDRegressor, OrthogonalMatchingPursuit,
                                      Lars, LassoLars)
    warnings.simplefilter("ignore")
    sgd, omp, lars = load(args.sgd_dir, "sgd"), load(args.omp_dir, "omp"), load(args.lars_dir, "lars")
    print("SGD (shuffle=False), one core")
    for n, p in [(10000, 20), (100000, 50), (50000, 500)]:
        rng = np.random.default_rng(0)
        X = rng.standard_normal((n, p))
        w0 = rng.standard_normal(p)
        yc = np.where(X @ w0 + 0.5 * rng.standard_normal(n) > 0, 1.0, -1.0)
        yr = X @ w0 + 0.5 * rng.standard_normal(n)
        for name, sk, y, args_ in [("SGDClassifier", SGDClassifier, yc, (0, 0, 1, 1e-4, 0.0, 0.5, 0.1)),
                                   ("SGDRegressor", SGDRegressor, yr, (1, 1, 1, 1e-4, 0.01, 0.25, 0.1))]:
            s, ts = timed(lambda: sk(shuffle=False).fit(X, y))
            w = np.zeros(p)
            o = np.zeros(1)
            ep, tt = timed(lambda: sgd.sgd(X, y, w, o, *args_, 1000, 1e-3, 5, 1, n, p))
            print("  %-14s %7d x %-4d  sklearn %7.3f s  sgd.scm %7.3f s  %4.1fx   epochs %d / %d   max |dw| %.1e"
                  % (name, n, p, ts, tt, ts / tt, ep, s.n_iter_, np.abs(w - s.coef_.ravel()).max()), flush=True)
    print("OMP and LARS over the Gram (n > p), one core")
    for n, p in [(2000, 100), (10000, 500), (20000, 1000)]:
        rng = np.random.default_rng(0)
        X = rng.standard_normal((n, p))
        w = np.zeros(p)
        w[rng.choice(p, p // 10, replace=False)] = 2.0 * rng.standard_normal(p // 10)
        y = X @ w + 0.5 * rng.standard_normal(n) + 1.0
        s, ts = timed(lambda: OrthogonalMatchingPursuit().fit(X, y))
        def ours_omp():
            xm, ym = X.mean(0), y.mean()
            c = np.zeros(p)
            k = omp.omp(np.ascontiguousarray(X - xm), y - ym, c, np.zeros(1), 0,
                        max(int(0.1 * p), 1), n, p)
            return c, k
        (c, k), tt = timed(ours_omp)
        print("  %-14s %7d x %-4d  sklearn %7.3f s  omp.scm  %7.3f s  %4.1fx   columns %d / %d   max |dcoef| %.1e"
              % ("OMP", n, p, ts, tt, ts / tt, k, s.n_iter_, np.abs(c - s.coef_).max()), flush=True)
        for name, est, meth, alpha, mi in [("Lars", Lars(n_nonzero_coefs=p // 5), 0, 0.0, p // 5),
                                           ("LassoLars", LassoLars(alpha=0.01), 1, 0.01, 500)]:
            s, ts = timed(lambda: est.fit(X, y))
            def ours_lars():
                xm, ym = X.mean(0), y.mean()
                Xc = X - xm
                G = np.ascontiguousarray(Xc.T @ Xc)
                c = np.zeros(p)
                it = lars.lars(G, Xc.T @ (y - ym), c, np.zeros(1), np.zeros(1), 0, float(n), alpha,
                               meth, mi, np.finfo(float).eps, p)
                return c, it
            (c, it), tt = timed(ours_lars)
            print("  %-14s %7d x %-4d  sklearn %7.3f s  lars.scm %7.3f s  %4.1fx   steps %d / %d   max |dcoef| %.1e"
                  % (name, n, p, ts, tt, ts / tt, it, s.n_iter_, np.abs(c - s.coef_).max()), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
