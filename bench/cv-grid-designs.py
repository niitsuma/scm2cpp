"""The cross-validation grid on the GPU: the designs, side by side.

    python3 bench/cv-grid-designs.py [--nobs N] [-p P] [--spans 1 5 10]

A CV grid is cv folds by num penalties (5 x 100 here), every cell a
descent from zero over its fold's Gram matrix.  Four ways to run it:

    CPU warm      each fold's path walked warm on one core (CovLassoCV
                  with force_cpu) -- the whole estimator, Grams included
    old GPU       one thread per cell, the fold's Gram replicated once
                  per cell (cv * num Gram matrices moved to the device);
                  the design before 0.7.0, timed as the whole estimator
    thread/run    one thread per run of `span` consecutive penalties of
                  a fold, walked warm; the Gram indexed by fold, no
                  copies.  span = 1 is the old kernel minus the copies
    block/run     one block of threads per run: thread 0 does the
                  coordinate step, the block spreads the O(p) update
                  of the correlations.  span = 1 is what CovLassoCV
                  launches

The kernel rows time the launch alone (Grams formed once, outside the
clock) and check the coefficients against the CPU's warm path.  Warm
runs (span > 1) do less arithmetic in total but hand the device fewer
independent problems, and at every size tried they lose to span = 1:
the device has blocks to spare, and a warm descent still sweeps all p
coordinates.
"""
import argparse
import ctypes
import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_v, "1")

import time

import numpy as np

import scm2cpp_lasso
from scm2cpp_lasso import CovLasso, CovLassoCV, cuda_available


def build(nobs, p, nnz=8, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((nobs, p))
    beta = np.zeros(p)
    beta[rng.choice(p, nnz, replace=False)] = rng.standard_normal(nnz) * 2.0
    y = X @ beta + 0.5 * rng.standard_normal(nobs)
    return X, y


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nobs", type=int, default=5000)
    ap.add_argument("-p", type=int, default=1000)
    ap.add_argument("--spans", type=int, nargs="+", default=[1, 5, 10])
    ap.add_argument("--best", type=int, default=2)
    args = ap.parse_args()
    if not cuda_available():
        print("no CUDA device; nothing to compare")
        return
    cv, num, tol = 5, 100, 1e-8
    X, y = build(args.nobs, args.p)
    nobs, p = X.shape
    print("n=%d p=%d cv=%d num=%d" % (nobs, p, cv, num))

    def best(f):
        b = 1e9
        for _ in range(args.best):
            t0 = time.perf_counter()
            f()
            b = min(b, time.perf_counter() - t0)
        return b

    rows = []
    rows.append(("CPU warm, whole estimator",
                 best(lambda: CovLassoCV(cv=cv, num=num,
                                         force_cpu=True).fit(X, y)), None))

    # the grid as CovLassoCV._fit_gpu forms it: Grams by fold, the
    # penalties scaled by each fold's row count so nobs is 1
    full = CovLasso(X, y)
    alphas = full.lambda_grid(num=num)
    G = full.g.reshape(p, p)
    bounds = np.linspace(0, nobs, cv + 1).astype(int)
    grams = np.empty((cv, p * p))
    corrs = np.empty((cv, p))
    nk = np.empty(cv)
    t0 = time.perf_counter()
    for k in range(cv):
        lo, hi = bounds[k], bounds[k + 1]
        grams[k] = (G - X[lo:hi].T @ X[lo:hi]).ravel()
        corrs[k] = full.c0 - X[lo:hi].T @ y[lo:hi]
        nk[k] = nobs - (hi - lo)
    t_gram = time.perf_counter() - t0
    lams = np.ascontiguousarray(np.tile(alphas, cv) * np.repeat(nk, num))
    ref = np.empty((cv, num, p))
    t0 = time.perf_counter()
    for k in range(cv):
        m = CovLasso(gram=grams[k], corr=corrs[k], nobs=int(nk[k]))
        ref[k] = m.fit_path(alphas, tol=tol)
    t_ref = time.perf_counter() - t0
    print("  (the fold Grams take %.3f s, the CPU warm paths %.3f s)"
          % (t_gram, t_ref))

    # the old design: replicated Grams, one cold thread per cell
    def old():
        gr = np.repeat(grams, num, axis=0)
        cr = np.repeat(corrs, num, axis=0)
        return scm2cpp_lasso._batch_descend_multi(
            gr, cr, lams, 1.0, p, tol=tol,
            kernel_fn=scm2cpp_lasso.kernel.enet_descend)
    gb = cv * num * p * p * 8 / 2**20
    rows.append(("old GPU, replicated Grams (%.0f MB), cold threads" % gb,
                 best(old), np.abs(old().reshape(cv, num, p) - ref).max()))

    lib = scm2cpp_lasso._BATCH
    DP = ctypes.POINTER(ctypes.c_double)

    def launch(mode, span):
        c = np.ascontiguousarray(np.repeat(corrs, num, axis=0))
        w = np.zeros((cv * num, p))
        rc = lib.scm2cpp_cv_descend(
            grams.ctypes.data_as(DP), cv, c.ctypes.data_as(DP),
            w.ctypes.data_as(DP), lams.ctypes.data_as(DP), 1.0, cv * num,
            p, 0, 1.0, 100000, 20, tol, span, mode)
        if rc != 0:
            raise RuntimeError("scm2cpp_cv_descend returned %d" % rc)
        return w.reshape(cv, num, p)

    for mode, name in ((0, "thread/run"), (1, "block/run")):
        for s in args.spans:
            if num % s:
                continue
            try:
                w = launch(mode, s)
            except RuntimeError as e:
                rows.append(("%s span=%d: %s" % (name, s, e), None, None))
                continue
            rows.append(("%s, span=%d, kernel alone" % (name, s),
                         best(lambda: launch(mode, s)),
                         np.abs(w - ref).max()))

    print()
    print("| %-52s | %-9s | %-10s |" % ("design", "time", "max|db|"))
    print("|%s|%s|%s|" % ("-" * 54, "-" * 11, "-" * 12))
    for name, sec, err in rows:
        print("| %-52s | %s | %s |"
              % (name, ("%7.3f s" % sec) if sec is not None else "   --    ",
                 ("%.1e   " % err) if err is not None else "    --    "))


if __name__ == "__main__":
    main()
