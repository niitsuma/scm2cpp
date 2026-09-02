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

The solver is Scheme -- examples/kernel-only/tfs-lasso-cov.scm and
tfs-predict.scm in the scm2cpp repository -- translated to C++ and
compiled at install time.
"""
import ctypes

import numpy as np

from ._generated import _autocov_loader as _ac
from ._generated import _lasso_cov_loader as _cov
from ._generated import _levinson_loader as _lev
from ._generated import _rolling_minmax_loader as _roll
from ._generated import _tfs_predict_loader as _pred
from ._libfind import load_batch_lib

__all__ = ["TemporalLasso", "TemporalRidge", "TemporalAR",
           "TemporalLogistic", "TemporalGroupLasso", "cuda_available",
           "rolling_min", "rolling_max", "rolling_sum",
           "rolling_mean", "rolling_std"]
__version__ = "0.7.0"

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
        g.ctypes.data_as(_DP), 1, c.ctypes.data_as(_DP),
        b.ctypes.data_as(_DP), lam.ctypes.data_as(_DP), 1.0, 1, 1, 1.0,
        20, 20, 1e-8)


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
                g.ctypes.data_as(_DP), 1, c.ctypes.data_as(_DP),
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

    def bootstrap_windows(self, y, lam, n_boot=200, block_len=None,
                          seed=None, force_cpu=False, tol=1e-8, chunk=20,
                          max_sweeps=100000):
        """Block residual bootstrap: how stable is the window selection?

        The design is a function of the series, so resampling it would
        sever the features from the target.  What can move is the
        noise: fit once, take the residuals, resample them in circular
        blocks -- respecting their serial dependence -- and refit
        against y* = fitted + resampled residuals.  The Gram matrix is
        shared by every resample, so each one costs a single O(n p)
        cross-product pass, and the descents run as one batch, on the
        GPU one thread per resample.  Returns (betas, freq): the
        (n_boot, wmax) coefficients and each window's selection
        frequency.
        """
        y = np.ascontiguousarray(y, dtype=np.float64)
        rng = np.random.default_rng(seed)
        B = int(n_boot)
        L = int(block_len) if block_len else max(10, int(self.nobs ** 0.5))
        beta_hat = self.fit_path(y, [lam], tol=tol, chunk=chunk,
                                 max_sweeps=max_sweeps)[0]
        fitted = self.predict(beta_hat)
        resid = y - fitted
        n = self.nobs
        n_blocks = int(np.ceil(n / L))
        w = np.arange(1, self.p + 1, dtype=np.float64)
        corrs = np.empty((B, self.p))
        for b in range(B):
            starts = rng.integers(0, n, size=n_blocks)
            idx = (starts[:, None] + np.arange(L)[None, :]).ravel() % n
            ystar = fitted + resid[idx[:n]]
            _cov.build_P(self.ps, np.ascontiguousarray(ystar),
                         self._pv, n, self.wmax)
            corrs[b] = (self._pv[0] - self._pv[1:]) / w
        self._for = None          # _pv was clobbered; drop the cache
        import ctypes
        betas = np.zeros((B, self.p))
        c = np.ascontiguousarray(corrs)
        lams = np.full(B, float(lam))
        g = np.ascontiguousarray(self.g)
        done = False
        if _BATCH is not None and not force_cpu:
            dp = ctypes.POINTER(ctypes.c_double)
            done = 0 == _BATCH.scm2cpp_batch_descend(
                g.ctypes.data_as(dp), 1, c.ctypes.data_as(dp),
                betas.ctypes.data_as(dp), lams.ctypes.data_as(dp),
                1.0, B, self.p, float(n), int(max_sweeps), int(chunk),
                float(tol))
        if not done:
            prev = np.empty(self.p)
            for b in range(B):
                cb, bb, swept = c[b], betas[b], 0
                while swept < max_sweeps:
                    prev[:] = bb
                    _cov.cov_descend(g, cb, bb, float(lam), chunk,
                                     float(n), self.p)
                    swept += chunk
                    if np.max(np.abs(bb - prev)) < tol * max(
                            1.0, float(np.max(np.abs(bb)))):
                        break
        freq = (np.abs(betas) > 1e-9).mean(axis=0)
        return betas, freq

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


def _batch_descend_multi(grams, corrs, lam, nobs, p, tol=1e-8, chunk=20,
                         max_sweeps=100000, l1_ratio=1.0, force_cpu=False,
                         kernel_fn=None):
    """Descend a batch where every problem has its own Gram matrix.

    grams is (B, p*p) and corrs (B, p); one thread per problem on the
    GPU when it is there, the same chunked-tolerance loop on the CPU
    when it is not.  This is the bootstrap's shape: resamples differ
    in their Gram, not just their penalty.
    """
    B = corrs.shape[0]
    import ctypes
    beta = np.zeros((B, p))
    c = np.ascontiguousarray(corrs.copy())
    g = np.ascontiguousarray(grams)
    lams = np.full(B, float(lam))
    if _BATCH is not None and not force_cpu:
        dp = ctypes.POINTER(ctypes.c_double)
        rc = _BATCH.scm2cpp_batch_descend(
            g.ctypes.data_as(dp), int(B), c.ctypes.data_as(dp),
            beta.ctypes.data_as(dp), lams.ctypes.data_as(dp),
            float(l1_ratio), int(B), int(p), float(nobs),
            int(max_sweeps), int(chunk), float(tol))
        if rc == 0:
            return beta
    prev = np.empty(p)
    for b in range(B):
        gb, cb, bb = g[b], c[b], beta[b]
        swept = 0
        while swept < max_sweeps:
            prev[:] = bb
            kernel_fn(gb, cb, bb, float(lam) * l1_ratio,
                      float(lam) * (1.0 - l1_ratio), chunk,
                      float(nobs), p)
            swept += chunk
            if np.max(np.abs(bb - prev)) < tol * max(
                    1.0, float(np.max(np.abs(bb)))):
                break
    return beta


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


class TemporalLogistic:
    """L1-penalized logistic regression over moving-average features.

    The same objective and majorization as ``scm2cpp_lasso``'s
    CovLogistic, with every pass design-free: the fixed quadratic
    G/4 comes from the prefix-sum Gram construction, eta = X beta is
    the prediction kernel reading window means off the prefix sums,
    and the gradient X'(y - mu) is the cross-product builder applied
    to the current residual y - mu.  Nothing ever forms X.
    """

    def __init__(self, series, wmax, nobs):
        self._t = TemporalLasso(series, wmax, nobs)
        self.wmax, self.nobs, self.p = self._t.wmax, self._t.nobs, self._t.p
        t = self._t
        # the y-independent half: S once, then G via a zero target
        # (build_G also assembles c, discarded here)
        zero = np.zeros(nobs)
        _cov.build_P(t.ps, zero, t._pv, t.nobs, t.wmax)
        _cov.build_G(t._s, t._pv, t.g, t.c0, t.wmax, t.p)
        self.g4 = np.ascontiguousarray(t.g / 4.0)

    def _corr(self, v):
        """X'v off the prefix sums: the build_P family, then assembly."""
        t = self._t
        _cov.build_P(t.ps, np.ascontiguousarray(v, dtype=np.float64),
                     t._pv, t.nobs, t.wmax)
        w = np.arange(1, self.p + 1, dtype=np.float64)
        return (t._pv[0] - t._pv[1:]) / w

    def predict_link(self, beta):
        """eta = X beta, read off the prefix sums."""
        return self._t.predict(beta)

    def predict_proba(self, beta):
        """P(y = 1) at each row."""
        return 1.0 / (1.0 + np.exp(-self.predict_link(beta)))

    def lambda_max(self, y):
        y = self._check_y(y)
        return float(np.max(np.abs(self._corr(y - 0.5)))) / self.nobs

    def lambda_grid(self, y, num=50, eps=1e-2):
        return self.lambda_max(y) * np.logspace(0, np.log10(eps), int(num))

    def _check_y(self, y):
        y = np.ascontiguousarray(y, dtype=np.float64)
        if y.size != self.nobs:
            raise ValueError(f"y has {y.size} rows; nobs = {self.nobs}")
        if not np.all((y == 0.0) | (y == 1.0)):
            raise ValueError("y must be 0/1")
        return y

    def fit_path(self, y, lambdas, tol=1e-7, inner_sweeps=200,
                 max_rounds=500):
        """Coefficients per lambda, warm-started down the path."""
        y = self._check_y(y)
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta = np.zeros(self.p)
        out = np.empty((lambdas.size, self.p))
        for i, lam in enumerate(lambdas):
            beta = self._fit_one(y, beta, float(lam), tol, inner_sweeps,
                                 max_rounds)
            out[i] = beta
        return out

    def fit(self, y, lam, **kw):
        """Coefficients at one lambda, from zero."""
        return self._fit_one(self._check_y(y), np.zeros(self.p),
                             float(lam), kw.get("tol", 1e-7),
                             kw.get("inner_sweeps", 200),
                             kw.get("max_rounds", 500))

    def _fit_one(self, y, beta, lam, tol, inner_sweeps, max_rounds):
        beta = beta.copy()
        for _ in range(max_rounds):
            prev = beta.copy()
            mu = 1.0 / (1.0 + np.exp(-self._t.predict(beta)))
            c = np.ascontiguousarray(self._corr(y - mu))
            _cov.cov_descend(self.g4, c, beta, lam, inner_sweeps,
                             float(self.nobs), self.p)
            if np.max(np.abs(beta - prev)) < tol * max(
                    1.0, float(np.max(np.abs(beta)))):
                break
        return beta

    def windows(self, beta, tol=1e-9):
        """The window lengths a fit kept, largest coefficient first."""
        return self._t.windows(beta, tol)


# ----------------------- rolling statistics -----------------------
#
# Statistics of every window of a series, for one window length or a
# whole batch of them at once.  Sum, mean and std ride prefix sums --
# a numpy one-liner each, stated as such -- while min and max use the
# translated monotone-deque kernel, O(n) per window where re-scanning
# costs O(n w).  Output follows pandas: same length as the input,
# NaN over the first w-1 rows; a list of windows gives one row per
# window.

def _as_windows(windows):
    if np.isscalar(windows):
        return [int(windows)], True
    return [int(w) for w in windows], False


def _check(x, ws):
    x = np.ascontiguousarray(x, dtype=np.float64)
    for w in ws:
        if not 1 <= w <= x.size:
            raise ValueError(f"window {w} outside 1..{x.size}")
    return x


def _minmax(fn, x, windows):
    ws, single = _as_windows(windows)
    x = _check(x, ws)
    n = x.size
    q = np.zeros(n, dtype=np.int32)
    out = np.full((len(ws), n), np.nan)
    for k, w in enumerate(ws):
        valid = np.zeros(n - w + 1)
        fn(x, q, valid, n, w)
        out[k, w - 1:] = valid
    return out[0] if single else out


def rolling_min(x, windows):
    """Minimum over each trailing window; pandas-shaped output."""
    return _minmax(_roll.rolling_min, x, windows)


def rolling_max(x, windows):
    """Maximum over each trailing window; pandas-shaped output."""
    return _minmax(_roll.rolling_max, x, windows)


def rolling_sum(x, windows):
    """Sum over each trailing window, off one prefix pass."""
    ws, single = _as_windows(windows)
    x = _check(x, ws)
    ps = np.concatenate(([0.0], np.cumsum(x)))
    out = np.full((len(ws), x.size), np.nan)
    for k, w in enumerate(ws):
        out[k, w - 1:] = ps[w:] - ps[:-w]
    return out[0] if single else out


def rolling_mean(x, windows):
    """Mean over each trailing window, off one prefix pass."""
    ws, single = _as_windows(windows)
    r = rolling_sum(x, ws)
    r /= np.asarray(ws, dtype=np.float64)[:, None]
    return r[0] if single else r


def rolling_std(x, windows, ddof=1):
    """Standard deviation over each trailing window.

    Two prefix passes, over the globally centered series -- variance
    is shift-invariant, and centering first is what keeps the
    sum-of-squares formula from cancelling itself on data with a
    large mean.

    Precision: min and max are exact and sum and mean agree with
    pandas to 1e-9; std inherits the rounding of prefix sums over the
    whole series, so a window whose own variance is tiny can be off
    by around 1e-6 relative.  If those windows matter, pandas'
    per-window online algorithm is the right tool for that column.
    """
    ws, single = _as_windows(windows)
    x = _check(x, ws)
    xc = x - x.mean()
    p1 = np.concatenate(([0.0], np.cumsum(xc)))
    p2 = np.concatenate(([0.0], np.cumsum(xc * xc)))
    out = np.full((len(ws), x.size), np.nan)
    for k, w in enumerate(ws):
        if w <= ddof:
            continue
        s1 = p1[w:] - p1[:-w]
        s2 = p2[w:] - p2[:-w]
        v = (s2 - s1 * s1 / w) / (w - ddof)
        out[k, w - 1:] = np.sqrt(np.maximum(v, 0.0))
    return out[0] if single else out


class CovGroupLasso:
    """Group lasso over a design given by its Gram matrix.

    The objective groups the penalty:

        (1/2n) ||y - X b||^2 + lam * sum_g w_g ||b_g||_2

    with the usual weights w_g = sqrt(|g|), so whole groups enter or
    leave together.  Block coordinate descent runs on the Gram matrix
    exactly as the lasso's coordinate descent does -- the working
    correlations c = X'y - G b are maintained across visits -- and
    each block visit is one majorized proximal step: the group's Gram
    block is dominated by its top eigenvalue L_g (found once), and the
    resulting subproblem has the group soft-threshold in closed form.
    Majorization descends monotonically; a group of size one reduces
    exactly to the lasso's coordinate update.

    ``groups`` is a list of index arrays, a partition of 0..p-1.
    """

    def __init__(self, X=None, y=None, *, gram=None, corr=None,
                 nobs=None, groups=None):
        if gram is not None:
            if corr is None or nobs is None:
                raise ValueError("gram needs corr and nobs alongside it")
            g = np.ascontiguousarray(gram, dtype=np.float64)
            c = np.ascontiguousarray(corr, dtype=np.float64)
            self.p = c.size
            self.G = g.reshape(self.p, self.p)
            self.c0, self.nobs = c, int(nobs)
        else:
            if X is None or y is None:
                raise ValueError("pass X and y, or gram, corr and nobs")
            X = np.ascontiguousarray(X, dtype=np.float64)
            y = np.ascontiguousarray(y, dtype=np.float64)
            self.nobs, self.p = X.shape
            self.G = X.T @ X
            self.c0 = X.T @ y
        if groups is None:
            raise ValueError("groups is required")
        self.groups = [np.asarray(g, dtype=np.intp) for g in groups]
        seen = np.concatenate(self.groups)
        if sorted(seen.tolist()) != list(range(self.p)):
            raise ValueError("groups must partition 0..p-1")
        self.wg = np.array([np.sqrt(len(g)) for g in self.groups])
        # the majorizer per group: its Gram block's top eigenvalue
        self.Lg = np.array(
            [float(np.linalg.eigvalsh(self.G[np.ix_(g, g)])[-1])
             for g in self.groups])

    def lambda_max(self):
        """The smallest penalty at which every group stays zero."""
        return max(float(np.linalg.norm(self.c0[g])) / (self.nobs * w)
                   for g, w in zip(self.groups, self.wg))

    def lambda_grid(self, num=50, eps=1e-2):
        """A log-spaced descending path from lambda_max."""
        return self.lambda_max() * np.logspace(0, np.log10(eps), int(num))

    def fit_path(self, lambdas, tol=1e-8, max_sweeps=10000):
        """Coefficients per lambda, warm-started down the path."""
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta = np.zeros(self.p)
        c = self.c0.copy()
        out = np.empty((lambdas.size, self.p))
        for i, lam in enumerate(lambdas):
            beta, c = self._fit_one(beta, c, float(lam), tol, max_sweeps)
            out[i] = beta
        return out

    def fit(self, lam, **kw):
        """Coefficients at one lambda, from zero."""
        b, _ = self._fit_one(np.zeros(self.p), self.c0.copy(), float(lam),
                             kw.get("tol", 1e-8),
                             kw.get("max_sweeps", 10000))
        return b

    def _fit_one(self, beta, c, lam, tol, max_sweeps):
        thr = lam * self.nobs
        for _ in range(max_sweeps):
            moved = 0.0
            for g, w, L in zip(self.groups, self.wg, self.Lg):
                bg = beta[g]
                z = bg + c[g] / L
                nz = float(np.linalg.norm(z))
                scale = max(0.0, 1.0 - thr * w / (L * nz)) if nz > 0 else 0.0
                nb = scale * z
                d = nb - bg
                dmax = float(np.max(np.abs(d))) if d.size else 0.0
                if dmax > 0.0:
                    c -= self.G[:, g] @ d
                    beta[g] = nb
                    moved = max(moved, dmax)
            if moved < tol * max(1.0, float(np.max(np.abs(beta)))):
                break
        return beta, c

    def objective(self, y_or_none, beta, lam):
        """The penalized objective, up to the constant ||y||^2/(2n).

        Computable from the Gram alone: (1/2n)(b'Gb - 2 c0'b) plus the
        penalty; add ||y||^2/(2n) yourself if you want the absolute
        value.
        """
        quad = 0.5 * (beta @ self.G @ beta) - self.c0 @ beta
        pen = sum(w * float(np.linalg.norm(beta[g]))
                  for g, w in zip(self.groups, self.wg))
        return quad / self.nobs + lam * pen


class TemporalGroupLasso:
    """Group lasso over moving-average windows, in bands.

    Neighbouring windows of a series are nearly collinear -- the mean
    of the last 19 observations says almost what the mean of the last
    20 does -- so selecting them one at a time splits weight
    arbitrarily among neighbours.  Grouping consecutive windows into
    bands and penalizing each band's norm as a whole selects
    timescales instead of individual lengths: a band enters or leaves
    together.  The Gram matrix is the same design-free construction
    as everything here; the descent is CovGroupLasso's.

    ``bands`` is either an integer band width, or a list of window
    counts summing to wmax.
    """

    def __init__(self, series, wmax, nobs, bands=5):
        self._t = TemporalLasso(series, wmax, nobs)
        self.wmax, self.nobs, self.p = self._t.wmax, self._t.nobs, self._t.p
        if np.isscalar(bands):
            sizes = [int(bands)] * (self.p // int(bands))
            rest = self.p - sum(sizes)
            if rest:
                sizes.append(rest)
        else:
            sizes = [int(b) for b in bands]
            if sum(sizes) != self.p:
                raise ValueError(f"bands sum to {sum(sizes)}; wmax = {self.p}")
        edges = np.cumsum([0] + sizes)
        self.groups = [np.arange(a, b) for a, b in zip(edges[:-1], edges[1:])]
        self._solver = None
        self._for = None

    def _prep(self, y):
        self._t._prepare(y)
        if self._for != self._t._for:
            self._solver = CovGroupLasso(gram=self._t.g, corr=self._t.c0,
                                         nobs=self.nobs, groups=self.groups)
            self._for = self._t._for
        return self._solver

    def lambda_max(self, y):
        return self._prep(y).lambda_max()

    def lambda_grid(self, y, num=50, eps=1e-2):
        return self._prep(y).lambda_grid(num=num, eps=eps)

    def fit_path(self, y, lambdas, **kw):
        """Coefficients per lambda, warm-started down the path."""
        return self._prep(y).fit_path(lambdas, **kw)

    def fit(self, y, lam, **kw):
        """Coefficients at one lambda, from zero."""
        return self._prep(y).fit(lam, **kw)

    def bands_selected(self, beta, tol=1e-9):
        """The (first window, last window) of each band a fit kept."""
        out = []
        for g in self.groups:
            if float(np.max(np.abs(beta[g]))) > tol:
                out.append((int(g[0]) + 1, int(g[-1]) + 1))
        return out

    def predict(self, beta):
        """Fitted values off the prefix sums; no design matrix."""
        return self._t.predict(beta)
