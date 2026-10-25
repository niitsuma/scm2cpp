"""The derived lasso kernel against the plain one, through the -M wrappers.

    python3 derived-check.py PLAIN_DIR DERIVED_DIR

Each directory holds lasso_kernel.py and liblasso_kernel.so, built from
lasso-kernel.scm with -M: PLAIN_DIR translated as written (the residual
sweep), DERIVED_DIR with --derive (the Gram form under (if (< p n) ..),
with --blas where a CBLAS is installed).  The suite's derive probes
compare the two on dyadic data through the Racket oracle; this is the
same comparison on a random design through the ctypes loaders, which is
how the scm2cpp-learn package calls the derived kernel.  Both kernels
run to an exact fixed point (tol 0.0), so the paths agree to rounding; the limit
is 1e-9, and a tall and a wide design each run so both branches of the
guard are exercised.  Exit 0 when within the limit.
"""
import importlib.util
import sys
from pathlib import Path

import numpy as np


def load(d):
    spec = importlib.util.spec_from_file_location(
        "lasso_kernel_" + Path(d).name, Path(d) / "lasso_kernel.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def path(mod, X, y, lams, sweeps=100000, tol=0.0):
    n, p = X.shape
    xt = np.ascontiguousarray(X.T)
    beta = np.zeros(p)
    resid = y.copy()
    xnorm = np.einsum("ji,ji->j", xt, xt)
    betas = np.zeros(lams.size * p)
    mod.lasso(xt, beta, resid, xnorm, lams, betas, sweeps, tol, n, p, lams.size)
    return betas.reshape(lams.size, p), resid


def main():
    plain, derived = load(sys.argv[1]), load(sys.argv[2])
    rng = np.random.default_rng(3)
    worst = 0.0
    for n, p in ((400, 30), (30, 60)):
        X = rng.standard_normal((n, p))
        y = X[:, :3] @ np.array([1.0, -0.5, 0.25]) + 0.1 * rng.standard_normal(n)
        lmax = np.max(np.abs(X.T @ y)) / n
        lams = lmax * np.logspace(0, -2, 8)
        b1, r1 = path(plain, X, y, lams)
        b2, r2 = path(derived, X, y, lams)
        d = max(float(np.max(np.abs(b1 - b2))), float(np.max(np.abs(r1 - r2))))
        worst = max(worst, d)
        print("n=%d p=%d  |diff| %.1e  nonzero %d" % (n, p, d, int(np.sum(b2[-1] != 0))))
    print("derived vs plain: worst %.1e" % worst)
    return 0 if worst <= 1e-9 else 1


if __name__ == "__main__":
    sys.exit(main())
