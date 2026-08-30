"""The multi-task family against scikit-learn, one protocol.

Single fits (MultiTaskLasso / MultiTaskElasticNet) run at
alpha = 0.1 lambda_max; the CV pair runs cv=5 over the same 100-alpha
grid on both sides (ours hands sklearn the grid, as the single-task
benchmark does).  Every solver keeps its own default tolerance, one
pinned CPU core, best of three runs.  Coefficient agreement is checked
separately at tol=1e-12 and reported as a max absolute difference.

    taskset -c 8-11 python3 bench/multitask-compare.py
"""
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_v, "1")

import time

import numpy as np

from scm2cpp_lasso import CovMultiTaskLasso, CovMultiTaskLassoCV
from sklearn.linear_model import (MultiTaskLasso, MultiTaskElasticNet,
                                  MultiTaskLassoCV, MultiTaskElasticNetCV)


def build(n, p, n_tasks, nnz=8, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((n, p))
    W = np.zeros((p, n_tasks))
    W[rng.choice(p, nnz, replace=False)] = rng.standard_normal((nnz, n_tasks))
    Y = X @ W + 0.1 * rng.standard_normal((n, n_tasks))
    return X, Y


BEST = 3


def best3(f):
    b = 1e9
    for _ in range(BEST):
        t0 = time.perf_counter()
        f()
        b = min(b, time.perf_counter() - t0)
    return b


def single_fits(X, Y):
    m = CovMultiTaskLasso(X, Y)
    alpha = 0.1 * m.lambda_max()
    rows = [
        ("MultiTaskLasso",
         best3(lambda: CovMultiTaskLasso(X, Y).fit(alpha)),
         best3(lambda: MultiTaskLasso(alpha=alpha, fit_intercept=False)
               .fit(X, Y))),
        ("MultiTaskElasticNet",
         best3(lambda: CovMultiTaskLasso(X, Y).fit(alpha, l1_ratio=0.5)),
         best3(lambda: MultiTaskElasticNet(alpha=alpha, l1_ratio=0.5,
                                           fit_intercept=False).fit(X, Y))),
    ]
    for name, ours, sk in rows:
        print("  %-24s ours %6.2f s   sklearn %6.2f s" % (name, ours, sk))


def cv_fits(X, Y, n_jobs=1):
    ours = CovMultiTaskLassoCV(cv=5, num=100, n_jobs=n_jobs)
    t_ours = best3(lambda: ours.fit(X, Y))
    t_sk = best3(lambda: MultiTaskLassoCV(cv=5, alphas=ours.alphas_,
                                          fit_intercept=False).fit(X, Y))
    print("  %-24s ours %6.2f s   sklearn %6.2f s" %
          ("MultiTaskLassoCV", t_ours, t_sk))
    oe = CovMultiTaskLassoCV(cv=5, num=100, l1_ratio=0.5, n_jobs=n_jobs)
    t_oe = best3(lambda: oe.fit(X, Y))
    t_ske = best3(lambda: MultiTaskElasticNetCV(cv=5, alphas=oe.alphas_,
                                                l1_ratio=0.5,
                                                fit_intercept=False)
                  .fit(X, Y))
    print("  %-24s ours %6.2f s   sklearn %6.2f s" %
          ("MultiTaskElasticNetCV", t_oe, t_ske))


def agreement(X, Y):
    m = CovMultiTaskLasso(X, Y)
    alpha = 0.1 * m.lambda_max()
    W = m.fit(alpha, tol=1e-12)
    sk = MultiTaskLasso(alpha=alpha, fit_intercept=False, tol=1e-12,
                        max_iter=100000).fit(X, Y)
    print("  tight-tol agreement: max|dW| = %.1e" %
          np.max(np.abs(W - sk.coef_.T)))


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--nobs", type=int, default=1800)
    ap.add_argument("-p", type=int, default=200)
    ap.add_argument("-t", "--tasks", type=int, default=8)
    ap.add_argument("--cv", action="store_true")
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--best", type=int, default=3)
    args = ap.parse_args()
    global BEST
    BEST = args.best
    X, Y = build(args.nobs, args.p, args.tasks)
    print("n=%d p=%d tasks=%d" % (args.nobs, args.p, args.tasks))
    if args.cv:
        cv_fits(X, Y, n_jobs=args.jobs)
    else:
        single_fits(X, Y)
        agreement(X, Y)


if __name__ == "__main__":
    main()
