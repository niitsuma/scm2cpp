"""Calling the translated covariance lasso from Python.

Build the module first:

    racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/tfs-lasso-cov.scm
    g++ -O2 -std=c++17 -shared -fPIC -I. -o libtfs-lasso-cov.so tfs-lasso-cov_capi.cpp

which writes tfs_lasso_cov.py beside the library -- a ctypes loader with one
function per translated definition.  Array arguments are passed as
pointers into the caller's numpy buffers, so the kernel reads and writes
them in place: nothing is copied at the boundary, and an array a
function writes comes back written.

The class below is the whole point of the covariance route.  The design
matrix is never formed: build_S turns the base series into lag sums,
build_P into cross-products with the target, and build_G assembles the
Gram matrix and the initial correlations from those.  Everything after
that costs O(p) per coordinate rather than O(n), so a whole
regularization path is cheap once the Gram matrix exists -- and because
cov_descend resumes exactly where it left off, the path can be walked
warm, each lambda starting from the previous solution.

    python3 examples/kernel-only/tfs-fast-lasso.py
"""
import sys
import time

import numpy as np

sys.path.insert(0, ".")
import tfs_lasso_cov as lc


class TemporalLasso:
    """Lasso over moving-average features of one series.

    Feature j is the mean of the last j+1 observations, for j in
    0..wmax-1, so the design matrix would be nobs x wmax -- but it is
    never built.  Fit once, then walk as many lambdas as you like.
    """

    def __init__(self, series, wmax, nobs):
        self.wmax, self.nobs, self.p = wmax, nobs, wmax
        ps = np.ascontiguousarray(np.cumsum(series, dtype=np.float64))
        self.ps, self.n = ps, ps.size
        self._s = np.zeros((wmax + 1) * (wmax + 1))
        self._pv = np.zeros(wmax + 1)
        self.g = np.zeros(self.p * self.p)
        self.c0 = np.zeros(self.p)
        lc.build_S(ps, self._s, np.zeros(self.n), np.zeros(self.n + 1),
                   self.n, nobs, wmax)

    def fit_path(self, y, lambdas, tol=1e-8, chunk=20, cap=100000):
        """Coefficients for each lambda, warm-started down the path."""
        lc.build_P(self.ps, np.ascontiguousarray(y, dtype=np.float64),
                   self._pv, self.nobs, self.wmax)
        lc.build_G(self._s, self._pv, self.g, self.c0, self.wmax, self.p)
        beta, c = np.zeros(self.p), self.c0.copy()
        out = np.empty((len(lambdas), self.p))
        for i, lam in enumerate(lambdas):
            prev = beta.copy()
            swept = 0
            while swept < cap:
                # the kernel is exactly resumable: passing beta and c
                # back in continues the descent where it stopped
                lc.cov_descend(self.g, c, beta, float(lam), chunk,
                               float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(beta - prev)) < tol:
                    break
                prev[:] = beta
            out[i] = beta
        return out


def main():
    wmax, nobs = 200, 1800
    rng = np.random.default_rng(7)
    x = rng.standard_normal(nobs + wmax + 1)

    # a target built from two window lengths the fit is not told about
    ps = np.cumsum(x)
    t = wmax + np.arange(nobs)
    y = 2.0 * (ps[t] - ps[t - 5]) / 5.0 - 1.5 * (ps[t] - ps[t - 20]) / 20.0

    model = TemporalLasso(x, wmax, nobs)
    # far enough down the path to separate the two windows that matter:
    # moving averages of a random walk at neighbouring lengths are very
    # nearly collinear, so a path that stops early spreads their weight
    # over the neighbours instead of picking them out
    lambdas = 0.5 * 0.99 ** np.arange(400)

    t0 = time.perf_counter()
    path = model.fit_path(y, lambdas)
    ours = time.perf_counter() - t0

    beta = path[-1]
    picked = np.argsort(-np.abs(beta))[:5] + 1
    print(f"strongest windows at the end of the path: "
          f"{sorted(picked.tolist())}  (the target was built from 5 and 20)")
    print(f"scm2cpp path of {len(lambdas)} lambdas: {ours:.3f}s")

    try:
        from sklearn.linear_model import lasso_path
    except ImportError:
        return
    w = np.arange(1, wmax + 1)[:, None]
    X = ((ps[t[None, :]] - ps[t[None, :] - w]) / w).T.copy()
    t0 = time.perf_counter()
    _, coefs, _ = lasso_path(X, y, alphas=lambdas, max_iter=100000, tol=1e-8)
    sk = time.perf_counter() - t0

    def objective(b, lam):
        r = y - X @ b
        return 0.5 * r @ r / nobs + lam * np.abs(b).sum()

    gaps = [objective(path[i], lambdas[i]) - objective(coefs.T[i], lambdas[i])
            for i in range(0, len(lambdas), 20)]
    assert max(gaps) < 1e-9, gaps
    print(f"sklearn lasso_path (same grid, warm):  {sk:.3f}s")
    print(f"objective gap vs sklearn: max {max(gaps):+.2e} "
          f"(negative means ours is lower)")


if __name__ == "__main__":
    main()
