"""Does a language model rediscover the CV optimizations?

    python3 bench/cv-hints-experiment.py

The hand-written CovLassoCV rests on two structural ideas: the Gram
matrix is a sufficient statistic that is additive over rows (so a
fold's training Gram is a subtraction), and the alpha grid warm-starts.
This experiment asks whether a local language model, shown only the
NAIVE implementation and a docstring stating the library's cost model,
proposes the same restructuring -- the question the repository's
memo-propose tool exists to ask ("which quantity is worth storing").

The model (a locally hosted open-weights model, reached through a shell command; any
model on stdin works) was asked for at most four one-line optimization
hints.  It answered, verbatim:

  1. Reuse the full-dataset Gram matrix and correlation vector by
     computing them once outside the loop, since coordinate descent
     only requires these sufficient statistics rather than the raw
     data rows.
  2. Exploit the additive property of the Gram matrix to derive
     fold-specific statistics by subtracting the validation fold's
     contribution from the global totals, avoiding redundant O(n p^2)
     matrix multiplications for each fold.
  3. Replace independent `fit` calls with `fit_path` to warm-start
     solutions across the alpha grid, leveraging the fact that
     solutions for adjacent regularization strengths are similar and
     require fewer coordinate descent sweeps.
  4. Batch the computation of all alphas for a given fold using
     `fit_path_batch` or similar vectorized solvers if available, to
     minimize Python loop overhead and enable internal parallelization
     of the independent alpha solves.

Hints 1-3, implemented below exactly as stated and nothing more, are
the hand optimization.  Measured at n=100000, p=200, cv=5, 100 alphas,
one CPU core, every variant choosing the same alpha:

  A  naive (no sharing)      3.96 s
  B  the model's hints       0.44 s
  C  hand-optimized CPU      0.44 s
  D  hand-optimized CUDA     0.52 s

The gate is the same as everywhere else in this repository: the model
proposes, the measurement decides, and agreement on the selected alpha
is the correctness check.  At this size the CUDA path pays its launch
overhead; its regime is many alphas at moderate p, measured in the
README's tables.
"""
import os, time
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import numpy as np
from scm2cpp_lasso import CovLasso, CovLassoCV

n, p, cv, num = 100_000, 200, 5, 100
rng = np.random.default_rng(1)
X = rng.standard_normal((n, p))
b = np.zeros(p); b[rng.choice(p, 10, replace=False)] = rng.standard_normal(10) * 2
y = X @ b + 0.5 * rng.standard_normal(n)
alphas = CovLasso(X, y).lambda_grid(num=num)
bounds = [n * k // cv for k in range(cv + 1)]


def naive():
    mse = np.zeros((num, cv))
    for k in range(cv):
        lo, hi = bounds[k], bounds[k + 1]
        mask = np.ones(n, bool); mask[lo:hi] = False
        m = CovLasso(X[mask], y[mask])
        for i, a in enumerate(alphas):
            r = X[lo:hi] @ m.fit(float(a)) - y[lo:hi]
            mse[i, k] = np.mean(r * r)
    return alphas[int(np.argmin(mse.mean(axis=1)))]


def llm_hinted():
    full = CovLasso(X, y)                                   # hint 1
    G = full.g.reshape(p, p)
    mse = np.zeros((num, cv))
    for k in range(cv):
        lo, hi = bounds[k], bounds[k + 1]
        Xf, yf = X[lo:hi], y[lo:hi]
        m = CovLasso(gram=(G - Xf.T @ Xf).ravel(),          # hint 2
                     corr=full.c0 - Xf.T @ yf, nobs=n - (hi - lo))
        path = m.fit_path(alphas)                           # hint 3
        r = Xf @ path.T - yf[:, None]
        mse[:, k] = np.mean(r * r, axis=0)
    return alphas[int(np.argmin(mse.mean(axis=1)))]


for name, fn in [("A naive (no sharing)", naive),
                 ("B the model's hints", llm_hinted),
                 ("C hand-optimized CPU",
                  lambda: CovLassoCV(cv=cv, num=num, force_cpu=True).fit(X, y).alpha_),
                 ("D hand-optimized CUDA",
                  lambda: CovLassoCV(cv=cv, num=num).fit(X, y).alpha_)]:
    fn()
    t0 = time.perf_counter(); a = fn()
    print("%-24s %6.2f s   alpha=%.6g" % (name, time.perf_counter() - t0, float(a)))
