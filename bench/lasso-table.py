"""Reproduce the timing table at the head of README.

    python3 bench/lasso-table.py [--quick]

Needs scm2cpp-tfs, scikit-learn and numpy installed:

    pip install scm2cpp-tfs scikit-learn

The comparison is a cross-validation grid: every lambda solved from
zero, which is what a fold of cross-validation costs when the folds
cannot share a warm start.  sklearn is called the way that workload
calls it -- Lasso(alpha=...).fit(X, y) once per lambda -- against the
translated covariance kernel on one CPU core and against the CUDA
batch kernel, one thread per lambda.  --quick shrinks the grid so the
script finishes in under a minute; the table in README is the full
run.

The last rows are the sequential single-path workload, where warm
starting is available to both sides, and are the fair comparison for a
single fit rather than a grid.  They are printed at three tolerances,
because the answer depends on which one is asked for: at
scikit-learn's default the two are level, and at tighter tolerances
the translated kernel's chunked descent costs more, sweeping in blocks
where sklearn checks after every pass.
"""
import argparse
import time

import numpy as np

from scm2cpp_tfs import TemporalLasso, cuda_available


def build(wmax, nobs, seed=0):
    """A series and a target built from two of its trailing windows."""
    rng = np.random.default_rng(seed)
    series = rng.standard_normal(nobs + wmax + 1)
    ps = np.cumsum(series)
    t = wmax + np.arange(nobs)
    y = (2.0 * (ps[t] - ps[t - 5]) / 5.0
         - 1.5 * (ps[t] - ps[t - 60]) / 60.0
         + 0.05 * rng.standard_normal(nobs))
    return series, y


def design(series, wmax, nobs):
    """The moving-average design matrix, for sklearn's benefit only."""
    ps = np.concatenate(([0.0], np.cumsum(series)))
    t = wmax + np.arange(nobs)
    w = np.arange(1, wmax + 1)
    return (ps[t[:, None] + 1] - ps[t[:, None] + 1 - w[None, :]]) / w[None, :]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true",
                    help="256 lambdas instead of 4096")
    ap.add_argument("--wmax", type=int, default=200)
    ap.add_argument("--nobs", type=int, default=1800)
    args = ap.parse_args()
    ngrid = 256 if args.quick else 4096

    series, y = build(args.wmax, args.nobs)
    model = TemporalLasso(series, args.wmax, args.nobs)
    lambdas = model.lambda_grid(y, num=ngrid)
    print("p=%d windows, n=%d rows, %d lambdas, GPU %s"
          % (args.wmax, args.nobs, ngrid, "yes" if cuda_available() else "no"))

    rows = []

    from sklearn.linear_model import Lasso, lasso_path
    X = design(series, args.wmax, args.nobs)
    t0 = time.perf_counter()
    for lam in lambdas:
        Lasso(alpha=lam, fit_intercept=False, warm_start=False).fit(X, y)
    rows.append(("sklearn Lasso.fit per lambda, cold", time.perf_counter() - t0))

    # The translated kernel is asked for tol=1e-8 here against sklearn's
    # default of 1e-4, so the comparison is conservative: it is solving
    # to a tighter tolerance than the solver it is timed against.
    t0 = time.perf_counter()
    cpu = model.fit_path_batch(y, lambdas, force_cpu=True)
    rows.append(("translated cov kernel, 1 CPU core, cold",
                 time.perf_counter() - t0))

    if cuda_available():
        model.fit_path_batch(y, lambdas[:8])          # warm the context
        t0 = time.perf_counter()
        gpu = model.fit_path_batch(y, lambdas)
        rows.append(("translated cov kernel, GPU, one thread/lambda",
                     time.perf_counter() - t0))
        print("GPU against CPU, largest coefficient difference: %.2e"
              % np.abs(gpu - cpu).max())

    print()
    print("| %-45s | %-7s |" % ("solver", "time"))
    print("|%s|%s|" % ("-" * 47, "-" * 9))
    for name, sec in rows:
        print("| %-45s | %5.1f s |" % (name, sec))

    # The other workload: one path, warm started, which is what both
    # sides are built for.  400 lambdas, the length README quotes, and
    # the same tolerance asked of both.
    warm = model.lambda_grid(y, num=400)
    print()
    print("warm single path, 400 lambdas, same tolerance asked of both:")
    for tol in (1e-4, 1e-6, 1e-8):
        model.fit_path(y, warm[:3], tol=tol)           # warm the module
        t0 = time.perf_counter()
        ours = model.fit_path(y, warm, tol=tol)
        t_ours = time.perf_counter() - t0
        t0 = time.perf_counter()
        _, theirs, _ = lasso_path(X, y, alphas=warm, tol=tol)
        t_theirs = time.perf_counter() - t0
        print("  tol %.0e: translated %.3f s, sklearn lasso_path %.3f s, "
              "coefficients agree to %.1e"
              % (tol, t_ours, t_theirs, np.abs(ours - theirs.T).max()))


if __name__ == "__main__":
    main()
