"""The --cuda translation against the CPU build and scikit-learn.

FastICA, the Gaussian mixture and the L-BFGS fits (logistic regression,
its CV, Poisson, Huber) are the same Scheme kernels as the package's CPU
estimators, translated with --cuda: their parallel loops become CUDA
kernels and their products cuBLAS calls on arrays that stay on the
device across statements.  The package takes that build when a device
answers and the problem has a million entries or more;
SCM2CPP_NO_DEVICE=1 forces the CPU build.  Prints the iterations on the
three sides, the largest difference between the CPU and device results,
and the whole fit times (best of --best).

BLAS and OpenMP are pinned to one thread here; pin the process too
(taskset -c 0-3 python bench/cuda-compare.py).
"""
import os
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[v] = "1"
import argparse
import time
import warnings

import numpy as np
from sklearn.decomposition import FastICA
from sklearn.linear_model import (HuberRegressor, LogisticRegression, LogisticRegressionCV,
                                  PoissonRegressor)
from sklearn.mixture import GaussianMixture

import scm2cpp_lasso as m

warnings.simplefilter("ignore")


def best(f, k):
    t = []
    for _ in range(k):
        t0 = time.perf_counter()
        r = f()
        t.append(time.perf_counter() - t0)
    return min(t), r


def on_cpu(f):
    os.environ["SCM2CPP_NO_DEVICE"] = "1"
    try:
        return f()
    finally:
        del os.environ["SCM2CPP_NO_DEVICE"]


def its(o):
    it = o.n_iter_
    return int(np.max(it)) if hasattr(it, "shape") else int(it)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=2)
    a = ap.parse_args()
    from scm2cpp_lasso._libfind import gpu_built
    print("device build:", gpu_built(), " device:", m.cuda_available())
    print(f"{'estimator, n x p':<36} {'it sk/cpu/dev':>14} {'cpu-dev':>8} "
          f"{'sklearn s':>9} {'cpu s':>8} {'device s':>9} {'sk/dev':>7}")
    rng = np.random.default_rng(0)
    cases = []
    n, p = 200000, 100
    X = rng.standard_normal((n, p)) / 10
    w = rng.standard_normal(p)
    yb = (X @ w + rng.logistic(size=n) > 0).astype(int)
    cases.append(("LogisticRegression", X, yb, LogisticRegression, m.LBFGSLogisticRegression,
                  "coef_"))
    yc = rng.poisson(np.exp(0.5 * X @ w)).astype(float)
    cases.append(("PoissonRegressor (alpha 1e-3)", X, yc, lambda: PoissonRegressor(alpha=1e-3),
                  lambda: m.LBFGSPoissonRegressor(alpha=1e-3), "coef_"))
    yh = X @ w + 0.3 * rng.standard_normal(n)
    yh[: n // 20] += 10.0
    cases.append(("HuberRegressor", X, yh, HuberRegressor, m.LBFGSHuberRegressor, "coef_"))
    cases.append(("LogisticRegressionCV", X, yb, LogisticRegressionCV,
                  m.LBFGSLogisticRegressionCV, "coef_"))
    t = np.linspace(0, 50, n)
    S = np.column_stack([np.sin((j + 1) * t + j) if j % 2 else rng.laplace(size=n)
                         for j in range(20)])
    Xi = S @ rng.standard_normal((20, 20))
    cases.append(("FastICA", Xi, None, lambda: FastICA(random_state=0),
                  lambda: m.ParallelFastICA(random_state=0), "components_"))
    C = 1.5 * rng.standard_normal((8, 20))
    Xg = np.vstack([C[k] + 0.5 * rng.standard_normal((25000, 20)) for k in range(8)])
    cases.append(("GaussianMixture (8)", Xg, None, lambda: GaussianMixture(8, random_state=0),
                  lambda: m.EMGaussianMixture(8, random_state=0), "means_"))
    for name, Xc, y, sk, us, attr in cases:
        fit = (lambda e: e.fit(Xc, y)) if y is not None else (lambda e: e.fit(Xc))
        ts, s = best(lambda: fit(sk()), 1)
        tc, c = best(lambda: on_cpu(lambda: fit(us())), a.best)
        fit(us())
        tg, g = best(lambda: fit(us()), a.best)
        d = np.abs(getattr(c, attr) - getattr(g, attr)).max() / max(
            1.0, np.abs(getattr(c, attr)).max())
        print(f"{name + f', {Xc.shape[0]:,} x {Xc.shape[1]}':<36} "
              f"{f'{its(s)}/{its(c)}/{its(g)}':>14} {d:>8.0e} {ts:>9.3f} {tc:>8.3f} "
              f"{tg:>9.3f} {ts / tg:>6.1f}x")


if __name__ == "__main__":
    main()
