"""Every GPU path of scm2cpp_lasso against its CPU path.

    python3 python/scm2cpp-lasso/check-gpu.py

Run in the venv the package is installed in, after a reinstall.  Each
line names a path and the largest difference from the CPU answer;
exits 1 when any exceeds 1e-12 (the GPU kernels do the same
arithmetic in the same order, so the differences are rounding in the
Gram products at most).  Without a device it says so and exits 0.
"""
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import sys

import numpy as np

from scm2cpp_lasso import (CovLasso, CovLassoCV, CovMultiTaskLasso,
                           CovMultiTaskLassoCV, cuda_available,
                           _grid_descend)

LIMIT = 1e-12
worst = 0.0


def report(name, diff):
    global worst
    worst = max(worst, diff)
    print("  %-56s %.1e %s" % (name, diff, "" if diff <= LIMIT else "FAIL"))


def main():
    if not cuda_available():
        print("no CUDA device; nothing to check")
        return 0
    rng = np.random.default_rng(1)
    n, p, T = 1200, 150, 4
    X = rng.standard_normal((n, p))
    B = np.zeros((p, T))
    B[rng.choice(p, 6, replace=False)] = rng.standard_normal((6, T))
    Y = X @ B + 0.3 * rng.standard_normal((n, T))
    y = Y[:, 0]

    for l1 in (1.0, 0.5):
        a = CovLassoCV(cv=5, num=60, l1_ratio=l1, force_cpu=True).fit(X, y)
        b = CovLassoCV(cv=5, num=60, l1_ratio=l1).fit(X, y)
        report("CovLassoCV l1_ratio=%.1f mse_path_" % l1,
               np.abs(a.mse_path_ - b.mse_path_).max()
               + (0.0 if a.alpha_ == b.alpha_ else 1.0))
        report("CovLassoCV l1_ratio=%.1f coef_" % l1,
               np.abs(a.coef_ - b.coef_).max())
        a = CovMultiTaskLassoCV(cv=5, num=60, l1_ratio=l1,
                                force_cpu=True).fit(X, Y)
        b = CovMultiTaskLassoCV(cv=5, num=60, l1_ratio=l1).fit(X, Y)
        report("CovMultiTaskLassoCV l1_ratio=%.1f mse_path_" % l1,
               np.abs(a.mse_path_ - b.mse_path_).max()
               + (0.0 if a.alpha_ == b.alpha_ else 1.0))
        report("CovMultiTaskLassoCV l1_ratio=%.1f coef_" % l1,
               np.abs(a.coef_ - b.coef_).max())
        m = CovMultiTaskLasso(X, Y)
        lam = m.lambda_grid(num=50, l1_ratio=l1)
        a = m.fit_path_batch(lam, force_cpu=True, l1_ratio=l1)
        b = m.fit_path_batch(lam, l1_ratio=l1)
        report("CovMultiTaskLasso.fit_path_batch l1_ratio=%.1f" % l1,
               np.abs(a - b).max())
        report("  ... against the warm fit_path",
               np.abs(m.fit_path(lam, l1_ratio=l1) - b).max())
        m = CovLasso(X, y)
        lam = m.lambda_grid(num=200, l1_ratio=l1)
        a = m.fit_path_batch(lam, force_cpu=True, l1_ratio=l1)
        b = m.fit_path_batch(lam, l1_ratio=l1)
        report("CovLasso.fit_path_batch l1_ratio=%.1f" % l1,
               np.abs(a - b).max())

    # the bootstrap: one Gram per thread
    m = CovLasso(X, y)
    lam = 0.1 * m.lambda_max()
    a = m.bootstrap(lam, n_boot=64, seed=3, force_cpu=True)
    b = m.bootstrap(lam, n_boot=64, seed=3)
    report("CovLasso.bootstrap", np.abs(a - b).max())

    # a shape too wide for the block kernel's shared memory takes the
    # one-thread-per-problem fallback
    p2, T2 = 400, 20
    X2 = rng.standard_normal((500, p2))
    Y2 = rng.standard_normal((500, T2))
    m = CovMultiTaskLasso(X2, Y2)
    lam = m.lambda_grid(num=8)
    a = m.fit_path_batch(lam, force_cpu=True)
    b = m.fit_path_batch(lam)
    report("multi-task fallback kernel (p=%d, %d tasks)" % (p2, T2),
           np.abs(a - b).max())

    # the shared-Gram cold grid through the block kernel, against the
    # one-thread-per-lambda kernel fit_path_batch uses
    m = CovLasso(X, y)
    lam = m.lambda_grid(num=1024)
    a = m.fit_path_batch(lam)
    b = _grid_descend(m.g[None, :], m.c0[None, :], lam, p, 0,
                      nobs=float(n))
    report("block kernel on one shared Gram, 1024 lambdas",
           np.abs(a - b).max())

    print("worst %.1e: %s" % (worst, "ok" if worst <= LIMIT else "FAIL"))
    return 0 if worst <= LIMIT else 1


if __name__ == "__main__":
    sys.exit(main())
