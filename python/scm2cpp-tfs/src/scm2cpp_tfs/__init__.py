"""Temporal feature selection: lasso over moving averages, no design matrix.

Feature j is the mean of the last j+1 observations, for j in
0..wmax-1.  The matrix that would hold those features is never formed,
at any step:

* the Gram matrix comes from the series' prefix sums in O(n p) time,
  where forming X and multiplying it out would cost O(n p^2) time and
  O(n p) space;
* the descent then costs O(p) per coordinate instead of O(n), and is
  exactly resumable, so a path is walked warm and a grid of lambdas
  goes to a GPU at once;
* prediction reads window means straight off the prefix sums, skipping
  every window the penalty dropped -- a sparse fit predicts in time
  proportional to its own support rather than to p.

    from scm2cpp_tfs import TemporalLasso

    model = TemporalLasso(series, wmax=200, nobs=1800)
    path = model.fit_path(y, lambdas)          # warm, sequential
    grid = model.fit_path_batch(y, lambdas)    # cold, GPU if present
    yhat = model.predict(path[-1])             # no design matrix

The solver is Scheme -- examples/kernel-only/lasso-cov.scm and
tfs-predict.scm in the scm2cpp repository -- translated to C++ and
compiled at install time.
"""
import ctypes

import numpy as np

from ._generated import _autocov_loader as _ac
from ._generated import _lasso_cov_loader as _cov
from ._generated import _levinson_loader as _lev
from ._generated import _tfs_predict_loader as _pred
from ._libfind import load_batch_lib

__all__ = ["TemporalLasso", "TemporalRidge", "TemporalAR",
           "cuda_available"]
__version__ = "0.3.0"

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


class TemporalLasso:
    """Lasso over the moving averages of one series.

    Construct once per series -- the lag sums are built here, and they
    do not depend on the target -- then fit as many targets and
    lambdas as you like.

    Parameters
    ----------
    series : array of length at least wmax + nobs
        The base sequence.  Only its prefix sums are kept.
    wmax : int
        The longest candidate window, and so the number of features.
    nobs : int
        Rows in the design matrix that is never formed.

    The objective is scikit-learn's, with ``fit_intercept=False``:
    ``(1 / 2 nobs) ||y - X b||^2 + lam ||b||_1``.
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
        self._for = None
        _cov.build_S(self.ps, self._s, np.zeros(self.n),
                     np.zeros(self.n + 1), self.n, self.nobs, self.wmax)

    # ------------------------- target-dependent -------------------------

    def _prepare(self, y):
        """Cross-products and the Gram matrix, rebuilt only for a new y."""
        y = np.ascontiguousarray(y, dtype=np.float64)
        if y.size != self.nobs:
            raise ValueError(f"y has {y.size} rows; nobs = {self.nobs}")
        key = (y.__array_interface__["data"][0], float(y.sum()))
        if self._for != key:
            _cov.build_P(self.ps, y, self._pv, self.nobs, self.wmax)
            _cov.build_G(self._s, self._pv, self.g, self.c0,
                         self.wmax, self.p)
            self._for = key
        return y


    # ------------------------- choosing lambdas -------------------------

    def lambda_max(self, y, l1_ratio=1.0):
        """The smallest penalty that leaves every coefficient at zero.

        Above it the solution is exactly zero, so a path that starts
        here starts where the first coefficient is about to enter --
        which is the only scale-free place to start, since the penalty
        is compared against correlations on the features' own scale.
        """
        self._prepare(y)
        return float(np.max(np.abs(self.c0))) / (self.nobs * l1_ratio)

    def lambda_grid(self, y, num=100, eps=1e-3, l1_ratio=1.0):
        """A log-spaced path from lambda_max down to eps * lambda_max.

        The same construction scikit-learn uses, and the same default
        ratio; give the result to fit_path, which expects descending
        lambdas.
        """
        hi = self.lambda_max(y, l1_ratio)
        return hi * np.logspace(0, np.log10(eps), int(num))

    # ---------------------------- fitting ----------------------------

    def fit_path(self, y, lambdas, tol=1e-8, chunk=20, max_sweeps=100000,
                 l1_ratio=1.0):
        """Coefficients per lambda, each warm-started from the last.

        Returns an array of shape (len(lambdas), wmax).  Give lambdas
        in descending order: that is what makes the warm start pay.
        """
        self._prepare(y)
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta, c = np.zeros(self.p), self.c0.copy()
        prev = np.empty(self.p)
        out = np.empty((lambdas.size, self.p))
        for i, lam in enumerate(lambdas):
            swept = 0
            while swept < max_sweeps:
                prev[:] = beta
                _cov.enet_descend(self.g, c, beta,
                                    float(lam) * l1_ratio,
                                    float(lam) * (1.0 - l1_ratio), chunk,
                                    float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(beta - prev)) < tol * _scale(beta):
                    break
            out[i] = beta
        return out

    def fit_path_batch(self, y, lambdas, tol=1e-8, chunk=20,
                       max_sweeps=100000, force_cpu=False, l1_ratio=1.0):
        """Coefficients per lambda, every lambda solved from zero.

        Independent problems, so they go to the GPU together when one
        is available -- the shape of a cross-validation grid, where
        warm starting across lambdas is not on offer anyway.
        """
        self._prepare(y)
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
                _cov.enet_descend(self.g, ct, bt,
                                    float(lambdas[t]) * l1_ratio,
                                    float(lambdas[t]) * (1.0 - l1_ratio), chunk,
                                    float(self.nobs), self.p)
                swept += chunk
                if np.max(np.abs(bt - prev)) < tol * _scale(bt):
                    break
        return beta

    def fit(self, y, lam, **kw):
        """Coefficients at one lambda."""
        return self.fit_path(y, [lam], **kw)[0]

    # --------------------------- using a fit ---------------------------

    def predict(self, beta):
        """Fitted values, read off the prefix sums.

        Costs one pass over the rows times the number of windows the
        fit actually kept, so a sparse solution is cheap; no design
        matrix is formed here either.
        """
        beta = np.ascontiguousarray(beta, dtype=np.float64)
        if beta.size != self.p:
            raise ValueError(f"beta has {beta.size} entries; p = {self.p}")
        yhat = np.zeros(self.nobs)
        _pred.tfs_predict(self.ps, beta, yhat, self.nobs, self.wmax, self.p)
        return yhat

    def score(self, y, beta):
        """The coefficient of determination of a fit on this series."""
        y = np.ascontiguousarray(y, dtype=np.float64)
        r = y - self.predict(beta)
        ss = ((y - y.mean()) ** 2).sum()
        return 1.0 - (r @ r) / ss if ss > 0 else float("nan")

    def windows(self, beta, tol=1e-9):
        """The window lengths a fit kept, longest coefficient first."""
        beta = np.asarray(beta)
        keep = np.flatnonzero(np.abs(beta) > tol)
        return (keep[np.argsort(-np.abs(beta[keep]))] + 1).tolist()


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


class TemporalRidge:
    """Ridge over the moving averages of one series.

    The same design-free construction as TemporalLasso -- the Gram
    matrix comes from the series' prefix sums in O(n p) -- followed by
    the closed-form ridge solve: one eigendecomposition, then O(p^2)
    per alpha.  The objective matches scikit-learn's ``Ridge`` with
    ``fit_intercept=False``.
    """

    def __init__(self, series, wmax, nobs):
        self._t = TemporalLasso(series, wmax, nobs)
        self.wmax, self.nobs, self.p = self._t.wmax, self._t.nobs, self._t.p
        self._ridge = None
        self._for = None

    def _solver(self, y):
        self._t._prepare(y)
        if self._for != self._t._for:
            self._ridge = CovRidge(gram=self._t.g, corr=self._t.c0)
            self._for = self._t._for
        return self._ridge

    def alpha_grid(self, y, num=100, eps=1e-6):
        """A descending grid from the top eigenvalue of the Gram."""
        return self._solver(y).alpha_grid(num=num, eps=eps)

    def fit(self, y, alpha):
        """Coefficients at one alpha."""
        return self._solver(y).fit(alpha)

    def fit_path(self, y, alphas):
        """Coefficients per alpha, shape (len(alphas), wmax)."""
        return self._solver(y).fit_path(alphas)

    def predict(self, beta):
        """Fitted values off the prefix sums; no design matrix."""
        return self._t.predict(beta)

    def score(self, y, beta):
        """The coefficient of determination of a fit on this series."""
        return self._t.score(y, beta)


class TemporalAR:
    """An autoregressive model of one series, by Yule-Walker.

    AR(p) predicts the next value from the last p:

        x_t = phi_1 x_{t-1} + ... + phi_p x_{t-p} + e_t

    and the least-squares phi solve R phi = r, where every entry of
    the lagged design's Gram matrix collapses onto the p+1
    autocovariances -- the same collapse the moving-average Gram rides
    in TemporalLasso.  The autocovariances cost one O(n p) pass
    (translated kernel), and Levinson-Durbin solves the Toeplitz
    system in O(p^2), producing on the way the reflection
    coefficients -- the partial autocorrelations, `pacf` -- and every
    order's prediction-error power, so one fit at max_order prices
    all the smaller models too.

    The series is demeaned first, as Yule-Walker expects; forecasts
    add the mean back.
    """

    def __init__(self, series, max_order, demean=True):
        x = np.ascontiguousarray(series, dtype=np.float64)
        if x.size <= max_order:
            raise ValueError(
                f"series has {x.size} points; more than max_order = "
                f"{max_order} are needed")
        self.mean = float(x.mean()) if demean else 0.0
        self.x = x - self.mean
        self.n = x.size
        self.max_order = int(max_order)
        self.r = np.zeros(self.max_order + 1)
        _ac.autocov(self.x, self.r, self.n, self.max_order)
        phi = np.zeros(self.max_order)
        work = np.zeros(self.max_order)
        self.pacf = np.zeros(self.max_order)
        self._errs = np.zeros(self.max_order)
        _lev.levinson(self.r, phi, work, self.pacf, self._errs,
                      self.max_order)
        self._phi_max = phi
        self.order_ = None
        self.phi_ = None

    def acf(self):
        """Autocorrelations at lags 0..max_order."""
        return self.r / self.r[0]

    def sigma2(self):
        """Innovation variance at each order 1..max_order."""
        return self._errs / self.n

    def _criterion(self, which):
        m = np.arange(1, self.max_order + 1)
        ll = self.n * np.log(self._errs / self.n)
        pen = 2.0 * (m + 1) if which == "aic" else np.log(self.n) * (m + 1)
        return ll + pen

    def select_order(self, criterion="aic"):
        """The order minimizing AIC or BIC over 1..max_order.

        Free: the error powers of every order fell out of the one
        Levinson recursion already run.
        """
        return int(np.argmin(self._criterion(criterion))) + 1

    def fit(self, order=None, criterion="aic"):
        """Coefficients of the chosen order; also kept on the object.

        With no order given, the criterion chooses one.  Returns phi
        of length `order`.
        """
        if order is None:
            order = self.select_order(criterion)
        order = int(order)
        if not 1 <= order <= self.max_order:
            raise ValueError(f"order must be in 1..{self.max_order}")
        phi = np.zeros(order)
        work = np.zeros(order)
        pacf = np.zeros(order)
        errs = np.zeros(order)
        _lev.levinson(self.r, phi, work, pacf, errs, order)
        self.order_, self.phi_ = order, phi
        self.sigma2_ = float(errs[-1] / self.n)
        return phi

    def forecast(self, steps, phi=None):
        """The next `steps` values, each fed back for the following one.

        Uses the last fitted coefficients unless phi is given.
        """
        if phi is None:
            if self.phi_ is None:
                self.fit()
            phi = self.phi_
        phi = np.asarray(phi, dtype=np.float64)
        p = phi.size
        hist = list(self.x[-p:])
        out = np.empty(int(steps))
        for t in range(int(steps)):
            v = float(np.dot(phi, hist[::-1][:p]))
            out[t] = v
            hist.append(v)
            hist = hist[-p:]
        return out + self.mean
