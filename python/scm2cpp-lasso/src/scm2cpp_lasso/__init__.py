"""Lasso by coordinate descent over a Gram matrix, from Scheme via C++.

The solver is `examples/kernel-only/lasso-cov.scm` in the scm2cpp
repository, translated to C++ and compiled at install time.  It takes
the covariance route: given X'X and X'y, each coordinate step costs
O(p) instead of O(n), so a whole regularization path is cheap once the
Gram matrix exists.  The descent is exactly resumable, which is what
lets a path be walked warm and a batch of lambdas be handed to a GPU.

    from scm2cpp_lasso import CovLasso

    model = CovLasso(X, y)                     # forms the Gram matrix
    path = model.fit_path(lambdas)             # warm, sequential
    grid = model.fit_path_batch(lambdas)       # cold, one thread each

`fit_path_batch` uses CUDA when the package was built with nvcc present
and a device is visible, and falls back to the CPU otherwise; ask
`cuda_available()` if you need to know which you got.

Designs with structure need not form X'X the general way.  `kernel`
exposes the translated functions directly, and `scm2cpp-tfs` uses them
to build the Gram matrix of a moving-average design in O(n p) time and
no design matrix at all.
"""
import ctypes

import numpy as np

from ._generated import _loader as kernel
from ._libfind import load_batch_lib

__all__ = ["CovLasso", "CovRidge", "cuda_available", "kernel"]
__version__ = "0.2.0"

_BATCH = load_batch_lib()
_DP = ctypes.POINTER(ctypes.c_double)


def _scale(beta):
    """What `tol` is measured against.

    An absolute test on the coefficients is a trap when the features
    are large: the Gram diagonal is then large too, every sweep moves
    each coefficient by very little, and the descent declares victory
    a long way from the solution.  Measuring the move against the size
    of the coefficients themselves makes the test mean the same thing
    at any scale, and falls back to absolute when they are still near
    zero.
    """
    m = float(np.max(np.abs(beta))) if beta.size else 0.0
    return m if m > 1.0 else 1.0


def cuda_available():
    """True when the GPU batch path was built and a device answers."""
    if _BATCH is None:
        return False
    g, c, b = np.ones(1), np.zeros(1), np.zeros(1)
    lam = np.array([1e9])          # a lambda that zeroes everything
    return 0 == _BATCH.scm2cpp_batch_descend(
        g.ctypes.data_as(_DP), c.ctypes.data_as(_DP), b.ctypes.data_as(_DP),
        lam.ctypes.data_as(_DP), 1.0, 1, 1, 1.0, 20, 20, 1e-8)


class CovLasso:
    """Lasso over a design given by its Gram matrix.

    Either hand it the design and the target, in which case X'X and
    X'y are formed here, or hand it a Gram matrix and correlations
    somebody else built more cheaply.

    Parameters
    ----------
    X : array (nobs, p), optional
        The design matrix.
    y : array (nobs,), optional
        The target.
    gram : array (p, p) or (p*p,), optional
        X'X, if it is already known.
    corr : array (p,), optional
        X'y, likewise.
    nobs : int, optional
        Rows behind `gram`; required when passing one, since the
        penalty is scaled by it as scikit-learn's alpha is.

    The objective is the usual one, matching scikit-learn's `Lasso`
    with `fit_intercept=False`:

        (1 / 2 nobs) ||y - X b||^2 + lam ||b||_1
    """

    def __init__(self, X=None, y=None, *, gram=None, corr=None, nobs=None):
        if gram is not None:
            if corr is None or nobs is None:
                raise ValueError("gram needs corr and nobs alongside it")
            g = np.ascontiguousarray(gram, dtype=np.float64).ravel()
            c = np.ascontiguousarray(corr, dtype=np.float64)
            p = c.size
            if g.size != p * p:
                raise ValueError(f"gram is {g.size} entries; expected {p*p}")
            self.p, self.nobs, self.g, self.c0 = p, int(nobs), g, c
        else:
            if X is None or y is None:
                raise ValueError("pass X and y, or gram, corr and nobs")
            X = np.ascontiguousarray(X, dtype=np.float64)
            y = np.ascontiguousarray(y, dtype=np.float64)
            if X.ndim != 2 or y.ndim != 1 or X.shape[0] != y.size:
                raise ValueError(
                    f"X is {X.shape} and y is {y.shape}; expected (n, p) "
                    "and (n,)")
            self.nobs, self.p = X.shape
            self.g = np.ascontiguousarray((X.T @ X).ravel())
            self.c0 = np.ascontiguousarray(X.T @ y)


    # ------------------------- choosing lambdas -------------------------

    def lambda_max(self, l1_ratio=1.0):
        """The smallest penalty that leaves every coefficient at zero.

        Above it the solution is exactly zero, so a path that starts
        here starts where the first coefficient is about to enter --
        which is the only scale-free place to start, since the penalty
        is compared against correlations on the features' own scale.
        """
        
        return float(np.max(np.abs(self.c0))) / (self.nobs * l1_ratio)

    def lambda_grid(self, num=100, eps=1e-3, l1_ratio=1.0):
        """A log-spaced path from lambda_max down to eps * lambda_max.

        The same construction scikit-learn uses, and the same default
        ratio; give the result to fit_path, which expects descending
        lambdas.
        """
        hi = self.lambda_max(l1_ratio)
        return hi * np.logspace(0, np.log10(eps), int(num))

    # ---------------------------- fitting ----------------------------

    def fit_path(self, lambdas, tol=1e-8, chunk=20, max_sweeps=100000,
                 l1_ratio=1.0):
        """Coefficients per lambda, each warm-started from the last.

        Returns an array of shape (len(lambdas), p).  Give lambdas in
        descending order: that is what makes the warm start pay.
        """
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta, c = np.zeros(self.p), self.c0.copy()
        prev = np.empty(self.p)
        out = np.empty((lambdas.size, self.p))
        for i, lam in enumerate(lambdas):
            swept = 0
            while swept < max_sweeps:
                prev[:] = beta
                kernel.enet_descend(self.g, c, beta,
                                    float(lam) * l1_ratio,
                                    float(lam) * (1.0 - l1_ratio), chunk,
                                    float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(beta - prev)) < tol * _scale(beta):
                    break
            out[i] = beta
        return out

    def fit_path_batch(self, lambdas, tol=1e-8, chunk=20,
                       max_sweeps=100000, force_cpu=False, l1_ratio=1.0):
        """Coefficients per lambda, every lambda solved from zero.

        Independent problems, so they go to the GPU together when one
        is available.  This is the shape of a cross-validation grid,
        where warm starting across lambdas is not on offer anyway.
        """
        lambdas = np.ascontiguousarray(lambdas, dtype=np.float64)
        batch = lambdas.size
        beta = np.zeros((batch, self.p))
        c = np.tile(self.c0, (batch, 1))
        if _BATCH is not None and not force_cpu:
            g = np.ascontiguousarray(self.g)
            rc = _BATCH.scm2cpp_batch_descend(
                g.ctypes.data_as(_DP), c.ctypes.data_as(_DP),
                beta.ctypes.data_as(_DP), lambdas.ctypes.data_as(_DP),
                float(l1_ratio), batch, self.p, float(self.nobs),
                int(max_sweeps), int(chunk), float(tol))
            if rc == 0:
                return beta
            # a device that refused the work is not a reason to fail
        prev = np.empty(self.p)
        for t in range(batch):
            bt, ct, swept = beta[t], c[t], 0
            while swept < max_sweeps:
                prev[:] = bt
                kernel.enet_descend(self.g, ct, bt,
                                    float(lambdas[t]) * l1_ratio,
                                    float(lambdas[t]) * (1.0 - l1_ratio), chunk,
                                    float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(bt - prev)) < tol * _scale(bt):
                    break
        return beta


class CovRidge:
    """Ridge regression over a design given by its Gram matrix.

    The objective matches scikit-learn's ``Ridge`` with
    ``fit_intercept=False``:

        ||y - X b||^2 + alpha ||b||^2

    (note: unlike the lasso objective, scikit-learn does not scale this
    one by the number of rows), so the solution is
    ``b = (X'X + alpha I)^{-1} X'y``.

    The design matrix enters only through X'X and X'y, so the
    constructor takes either the design or a Gram matrix somebody built
    more cheaply.  One symmetric eigendecomposition is done on first
    use, O(p^3); every alpha after that costs O(p^2), which is what
    makes a whole path cheap.
    """

    def __init__(self, X=None, y=None, *, gram=None, corr=None):
        if gram is not None:
            if corr is None:
                raise ValueError("gram needs corr alongside it")
            g = np.ascontiguousarray(gram, dtype=np.float64).ravel()
            c = np.ascontiguousarray(corr, dtype=np.float64)
            p = c.size
            if g.size != p * p:
                raise ValueError(f"gram is {g.size} entries; expected {p*p}")
            self.p, self.g, self.c0 = p, g, c
        else:
            if X is None or y is None:
                raise ValueError("pass X and y, or gram and corr")
            X = np.ascontiguousarray(X, dtype=np.float64)
            y = np.ascontiguousarray(y, dtype=np.float64)
            if X.ndim != 2 or y.ndim != 1 or X.shape[0] != y.size:
                raise ValueError(
                    f"X is {X.shape} and y is {y.shape}; expected (n, p) "
                    "and (n,)")
            self.p = X.shape[1]
            self.g = np.ascontiguousarray((X.T @ X).ravel())
            self.c0 = np.ascontiguousarray(X.T @ y)
        self._eig = None

    def _eigen(self):
        if self._eig is None:
            w, Q = np.linalg.eigh(self.g.reshape(self.p, self.p))
            self._eig = (w, Q, Q.T @ self.c0)
        return self._eig

    def alpha_grid(self, num=100, eps=1e-6):
        """A log-spaced path from the top eigenvalue of X'X downward.

        At ``alpha`` around the largest eigenvalue the fit is heavily
        shrunk; by ``eps`` times it the fit is essentially least
        squares.  Descending, like the lasso grids.
        """
        w, _, _ = self._eigen()
        hi = float(w.max())
        return hi * np.logspace(0, np.log10(eps), int(num))

    def fit(self, alpha):
        """Coefficients at one alpha."""
        w, Q, qc = self._eigen()
        return Q @ (qc / (w + float(alpha)))

    def fit_path(self, alphas):
        """Coefficients per alpha, shape (len(alphas), p).

        After the one eigendecomposition this is a single dense
        product, so thousands of alphas cost what one does.
        """
        w, Q, qc = self._eigen()
        alphas = np.asarray(alphas, dtype=np.float64)
        return (Q @ (qc[:, None] / (w[:, None] + alphas[None, :]))).T
