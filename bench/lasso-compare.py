"""scm2cpp-lasso against other lasso solvers.

    python3 bench/lasso-compare.py [--quick]

Optional competitors are picked up when importable and skipped with a
note when not:

    pip install scikit-learn celer skglm      # CPU solvers
    pip install cuml-cu12                     # RAPIDS cuML (CUDA 12)

Protocol, matching bench/lasso-table.py: a dense design, p=200 columns,
n=1800 rows, and a cross-validation-shaped grid of lambdas solved from
zero -- no warm start across lambdas, which is what a fold costs when
folds cannot share state.  BLAS and OpenMP are pinned to one thread so
CPU rows are one core against one core; GPU rows say so.  Every solver
runs at its own default tolerance except ours, which is asked for
tol=1e-8; the last column reports how far each solver's objective is
from ours at the final (smallest) lambda, so a fast row with a loose
answer is visible as such.

The second table is the warm-started single path, where solvers built
for paths (ours, sklearn's lasso_path, celer's celer_path) show what
warm starting buys.

The R glmnet is the ancestor of this algorithm family; its Python port
(pip install glmnet) no longer builds on current Pythons, so it is
represented here by the coordinate-descent family it defined.
"""
import argparse
import os

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_v, "1")

import time

import numpy as np

from scm2cpp_lasso import CovLasso, cuda_available


def build(nobs, p, nnz=8, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((nobs, p))
    beta = np.zeros(p)
    beta[rng.choice(p, nnz, replace=False)] = rng.standard_normal(nnz) * 2.0
    y = X @ beta + 0.5 * rng.standard_normal(nobs)
    return X, y


def objective(X, y, b, lam):
    r = y - X @ b
    return 0.5 * r @ r / len(y) + lam * np.abs(b).sum()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--nobs", type=int, default=1800)
    ap.add_argument("-p", type=int, default=200)
    args = ap.parse_args()
    ngrid = 256 if args.quick else 4096

    X, y = build(args.nobs, args.p)
    model = CovLasso(X, y)
    lambdas = model.lambda_grid(num=ngrid)
    lam_last = float(lambdas[-1])
    print("p=%d, n=%d, %d lambdas, GPU %s"
          % (args.p, args.nobs, ngrid, "yes" if cuda_available() else "no"))

    rows = []

    def row(name, seconds, beta_last):
        gap = objective(X, y, beta_last, lam_last) - obj_ref
        rows.append((name, seconds, gap))

    # ours first, so every gap is measured against the tightest answer
    t0 = time.perf_counter()
    cpu = model.fit_path_batch(lambdas, force_cpu=True)
    t_cpu = time.perf_counter() - t0
    obj_ref = objective(X, y, cpu[-1], lam_last)
    rows.append(("scm2cpp-lasso, 1 CPU core (tol 1e-8)", t_cpu, 0.0))

    if cuda_available():
        model.fit_path_batch(lambdas[:8])
        t0 = time.perf_counter()
        gpu = model.fit_path_batch(lambdas)
        row("scm2cpp-lasso, GPU, one thread/lambda", time.perf_counter() - t0,
            gpu[-1])

    # each competitor gets one untimed fit first, so that numba/JIT
    # compilation (skglm), solver setup and caches are out of the clock
    from sklearn.linear_model import Lasso
    Lasso(alpha=float(lambdas[0]), fit_intercept=False).fit(X, y)
    t0 = time.perf_counter()
    for lam in lambdas:
        skl = Lasso(alpha=lam, fit_intercept=False, warm_start=False).fit(X, y)
    row("sklearn Lasso.fit per lambda", time.perf_counter() - t0, skl.coef_)

    try:
        from celer import Lasso as CelerLasso
        CelerLasso(alpha=float(lambdas[0]), fit_intercept=False).fit(X, y)
        t0 = time.perf_counter()
        for lam in lambdas:
            cel = CelerLasso(alpha=lam, fit_intercept=False,
                             warm_start=False).fit(X, y)
        row("celer Lasso.fit per lambda", time.perf_counter() - t0, cel.coef_)
    except ImportError:
        print("  (celer not installed; skipped)")

    try:
        from skglm import Lasso as SkglmLasso
        SkglmLasso(alpha=float(lambdas[0]), fit_intercept=False).fit(X, y)
        t0 = time.perf_counter()
        for lam in lambdas:
            skg = SkglmLasso(alpha=lam, fit_intercept=False,
                             warm_start=False).fit(X, y)
        row("skglm Lasso.fit per lambda", time.perf_counter() - t0, skg.coef_)
    except ImportError:
        print("  (skglm not installed; skipped)")

    try:
        import cupy as cp
        from cuml.linear_model import Lasso as CumlLasso
        Xg, yg = cp.asarray(X), cp.asarray(y)   # on the device once
        CumlLasso(alpha=float(lambdas[0]), fit_intercept=False).fit(Xg, yg)
        t0 = time.perf_counter()
        for lam in lambdas:
            cum = CumlLasso(alpha=float(lam), fit_intercept=False).fit(Xg, yg)
        cp.cuda.runtime.deviceSynchronize()
        row("cuML Lasso.fit per lambda, GPU", time.perf_counter() - t0,
            cp.asnumpy(cum.coef_))
    except ImportError:
        print("  (cuML not installed; skipped)")

    print()
    print("cold grid, every lambda from zero:")
    print("| %-42s | %-8s | %-14s |" % ("solver", "time", "objective gap"))
    print("|%s|%s|%s|" % ("-" * 44, "-" * 10, "-" * 16))
    for name, sec, gap in rows:
        print("| %-42s | %6.1f s | %+13.2e |" % (name, sec, gap))

    # ---- the warm single path ----
    warm = model.lambda_grid(num=400)
    print()
    print("warm single path, 400 lambdas:")
    t0 = time.perf_counter()
    ours = model.fit_path(warm)
    print("  scm2cpp-lasso fit_path        %6.3f s" % (time.perf_counter() - t0))
    from sklearn.linear_model import lasso_path
    t0 = time.perf_counter()
    lasso_path(X, y, alphas=warm)
    print("  sklearn lasso_path            %6.3f s" % (time.perf_counter() - t0))
    try:
        from celer import celer_path
        t0 = time.perf_counter()
        celer_path(X, y, pb="lasso", alphas=warm)
        print("  celer celer_path              %6.3f s" % (time.perf_counter() - t0))
    except ImportError:
        pass


if __name__ == "__main__":
    main()
