"""A fast lasso over moving-average features, from Scheme via C++.

The solver is `examples/kernel-only/lasso-cov.scm` in the scm2cpp
repository, translated to C++ and compiled at install time.  It takes
the covariance route: the design matrix is never formed, so a whole
regularization path costs O(p) per coordinate instead of O(n), and the
descent is exactly resumable, which is what lets a path be walked warm
and a batch of lambdas be handed to a GPU.

    from scm2cpp_lasso import TemporalLasso

    model = TemporalLasso(series, wmax=200, nobs=1800)
    path = model.fit_path(y, lambdas)          # warm, sequential
    path = model.fit_path_batch(y, lambdas)    # cold, one thread each

`fit_path_batch` uses CUDA when the package was built with nvcc present
and a device is visible, and falls back to the CPU otherwise; ask
`cuda_available()` if you need to know which you got.
"""
import numpy as np

from ._generated import _loader as _k
from ._libfind import load_batch_lib

__all__ = ["TemporalLasso", "cuda_available"]
__version__ = "0.1.0"

_BATCH = load_batch_lib()


def cuda_available():
    """True when the GPU batch path was built and a device answers."""
    if _BATCH is None:
        return False
    g = np.ones(1)
    c = np.zeros(1)
    b = np.zeros(1)
    lam = np.array([1e9])          # a lambda that zeroes everything
    return 0 == _BATCH.scm2cpp_batch_descend(
        g.ctypes.data_as(_ctypes_p(g)), c.ctypes.data_as(_ctypes_p(c)),
        b.ctypes.data_as(_ctypes_p(b)), lam.ctypes.data_as(_ctypes_p(lam)),
        1, 1, 1.0, 20, 20, 1e-8)


def _ctypes_p(a):
    import ctypes
    return ctypes.POINTER(ctypes.c_double)


class TemporalLasso:
    """Lasso over the moving averages of one series.

    Feature j is the mean of the last j+1 observations, for j in
    0..wmax-1.  The design matrix that would hold them is never built:
    the kernel goes from the series to the Gram matrix through lag
    sums.  Construct once per series, then fit as many targets and
    lambdas as you like.

    Parameters
    ----------
    series : array of length wmax + nobs + 1 or longer
        The base sequence.  Only its prefix sums are kept.
    wmax : int
        The longest candidate window, and so the number of features.
    nobs : int
        Rows in the (never formed) design matrix.
    """

    def __init__(self, series, wmax, nobs):
        series = np.ascontiguousarray(series, dtype=np.float64)
        if series.size < wmax + nobs:
            raise ValueError(
                f"series has {series.size} points; wmax + nobs = "
                f"{wmax + nobs} are needed")
        self.wmax, self.nobs, self.p = int(wmax), int(nobs), int(wmax)
        self.ps = np.ascontiguousarray(np.cumsum(series))
        self.n = self.ps.size
        self._s = np.zeros((self.wmax + 1) * (self.wmax + 1))
        self._pv = np.zeros(self.wmax + 1)
        self.g = np.zeros(self.p * self.p)
        self.c0 = np.zeros(self.p)
        self._fitted_for = None
        _k.build_S(self.ps, self._s, np.zeros(self.n),
                   np.zeros(self.n + 1), self.n, self.nobs, self.wmax)

    # -- the target-dependent half: Gram stays, correlations change --

    def _prepare(self, y):
        y = np.ascontiguousarray(y, dtype=np.float64)
        if y.size != self.nobs:
            raise ValueError(f"y has {y.size} rows; nobs = {self.nobs}")
        key = (y.__array_interface__["data"][0], float(y.sum()))
        if self._fitted_for != key:
            _k.build_P(self.ps, y, self._pv, self.nobs, self.wmax)
            _k.build_G(self._s, self._pv, self.g, self.c0,
                       self.wmax, self.p)
            self._fitted_for = key
        return y

    # ---------------------------- fitting ----------------------------

    def fit_path(self, y, lambdas, tol=1e-8, chunk=20, max_sweeps=100000):
        """Coefficients per lambda, each warm-started from the last.

        Returns an array of shape (len(lambdas), wmax).  Give lambdas
        in descending order: that is what makes the warm start pay.
        """
        self._prepare(y)
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta = np.zeros(self.p)
        c = self.c0.copy()
        out = np.empty((lambdas.size, self.p))
        prev = np.empty(self.p)
        for i, lam in enumerate(lambdas):
            swept = 0
            while swept < max_sweeps:
                prev[:] = beta
                _k.cov_descend(self.g, c, beta, float(lam), chunk,
                               float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(beta - prev)) < tol:
                    break
            out[i] = beta
        return out

    def fit_path_batch(self, y, lambdas, tol=1e-8, chunk=20,
                       max_sweeps=100000, force_cpu=False):
        """Coefficients per lambda, every lambda solved from zero.

        Independent problems, so they go to the GPU together when one
        is available.  This is the shape of a cross-validation grid,
        where warm starting across lambdas is not on offer anyway.
        """
        self._prepare(y)
        lambdas = np.ascontiguousarray(lambdas, dtype=np.float64)
        batch = lambdas.size
        beta = np.zeros((batch, self.p))
        c = np.tile(self.c0, (batch, 1))
        if _BATCH is not None and not force_cpu:
            import ctypes
            dp = ctypes.POINTER(ctypes.c_double)
            g = np.ascontiguousarray(self.g)
            rc = _BATCH.scm2cpp_batch_descend(
                g.ctypes.data_as(dp), c.ctypes.data_as(dp),
                beta.ctypes.data_as(dp), lambdas.ctypes.data_as(dp),
                batch, self.p, float(self.nobs), int(max_sweeps),
                int(chunk), float(tol))
            if rc == 0:
                return beta
            # a device that refused the work is not a reason to fail
        prev = np.empty(self.p)
        for t in range(batch):
            bt, ct = beta[t], c[t]
            swept = 0
            while swept < max_sweeps:
                prev[:] = bt
                _k.cov_descend(self.g, ct, bt, float(lambdas[t]), chunk,
                               float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(bt - prev)) < tol:
                    break
        return beta
