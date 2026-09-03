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

__all__ = ["CovLasso", "CovRidge", "CovLogistic", "CovGroupLasso",
           "CovMultiTaskLasso", "CovMultiTaskLassoCV",
           "cuda_available", "kernel"]
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
            self.X, self.y = X, y


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

    def fit(self, lam, **kw):
        """Coefficients at one lambda.

        A single penalty is the one-element special case of the path:
        the Gram matrix was built in the constructor, so this costs one
        descent and nothing per row -- and a warm-started path over a
        whole grid costs barely more, which is why fit_path is the
        primary interface rather than this convenience.
        """
        return self.fit_path([lam], **kw)[0]

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


    def bootstrap(self, lam, n_boot=200, l1_ratio=1.0, seed=None,
                  force_cpu=False, **kw):
        """Pairs-bootstrap coefficients at one lambda, (n_boot, p).

        Each resample draws rows with replacement; its Gram matrix is
        X' diag(m) X with the multiplicity counts m, formed as Xs' Xs
        for Xs = diag(sqrt m) X so that numpy takes the symmetric
        rank-k product (dsyrk, half the flops of a general product)
        -- one BLAS call per resample -- and the descents run as one
        batch: on the GPU one block of threads per resample over its
        own Gram, since the problems are independent.  Needs the
        design matrix, so it is unavailable when the model was built
        from a Gram matrix alone.
        """
        if not hasattr(self, "X"):
            raise ValueError("bootstrap needs X; construct from X and y")
        rng = np.random.default_rng(seed)
        B = int(n_boot)
        grams = np.empty((B, self.p * self.p))
        corrs = np.empty((B, self.p))
        for b in range(B):
            m = rng.multinomial(self.nobs,
                                np.full(self.nobs, 1.0 / self.nobs))
            Xs = self.X * np.sqrt(m)[:, None]
            grams[b] = (Xs.T @ Xs).ravel()
            corrs[b] = self.X.T @ (m * self.y)
        lams = (np.ascontiguousarray(lam, dtype=np.float64)
                if np.ndim(lam) else np.full(B, float(lam)))
        if not force_cpu:
            beta = _grid_descend(grams, corrs, lams, self.p, 0,
                                 l1_ratio=l1_ratio, nobs=float(self.nobs),
                                 **kw)
            if beta is not None:
                return beta
        return _batch_descend_multi(grams, corrs, lams, self.nobs, self.p,
                                    l1_ratio=l1_ratio, force_cpu=True,
                                    kernel_fn=kernel.enet_descend, **kw)

    def fit_path_batch(self, lambdas, tol=1e-8, chunk=20,
                       max_sweeps=100000, force_cpu=False, l1_ratio=1.0):
        """Coefficients per lambda, every lambda solved from zero.

        Independent problems, so they go to the GPU together when one
        is available: one launch, one block of threads per lambda, all
        sharing this Gram matrix.  This is the shape of a
        cross-validation grid, where warm starting across lambdas is
        not on offer anyway.
        """
        lambdas = np.ascontiguousarray(lambdas, dtype=np.float64)
        batch = lambdas.size
        if not force_cpu:
            beta = _grid_descend(self.g[None, :], self.c0[None, :], lambdas,
                                 self.p, 0, tol=tol, chunk=chunk,
                                 max_sweeps=max_sweeps, l1_ratio=l1_ratio,
                                 nobs=float(self.nobs))
            if beta is not None:
                return beta
            # a device that refused the work is not a reason to fail
        beta = np.zeros((batch, self.p))
        c = np.tile(self.c0, (batch, 1))
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


def _batch_descend_multi(grams, corrs, lam, nobs, p, tol=1e-8, chunk=20,
                         max_sweeps=100000, l1_ratio=1.0, force_cpu=False,
                         kernel_fn=None):
    """Descend a batch where every problem has its own Gram matrix.

    grams is (B, p*p) and corrs (B, p); one thread per problem on the
    GPU when it is there (the kernel before 0.7.0, kept for the
    comparison in bench/cv-grid-designs.py), the same chunked-tolerance
    loop on the CPU when it is not -- which is what the bootstrap
    falls back to.
    """
    B = corrs.shape[0]
    import ctypes
    beta = np.zeros((B, p))
    c = np.ascontiguousarray(corrs.copy())
    g = np.ascontiguousarray(grams)
    # lam may be one penalty for every thread or one per thread; the
    # kernel always reads a per-thread array
    lams = (np.ascontiguousarray(lam, dtype=np.float64)
            if np.ndim(lam) else np.full(B, float(lam)))
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
        lam_b = float(lams[b])
        swept = 0
        while swept < max_sweeps:
            prev[:] = bb
            kernel_fn(gb, cb, bb, lam_b * l1_ratio,
                      lam_b * (1.0 - l1_ratio), chunk,
                      float(nobs), p)
            swept += chunk
            if np.max(np.abs(bb - prev)) < tol * max(
                    1.0, float(np.max(np.abs(bb)))):
                break
    return beta


def _grid_descend(grams, corrs, lams, p, ntask, tol=1e-8, chunk=20,
                  max_sweeps=100000, l1_ratio=1.0, nobs=1.0):
    """A batch of cold descents on the GPU, one block per problem.

    grams is (n_grams, p*p), corrs (n_grams, width) with width p or
    p*ntask, and lams the penalties of the batch in Gram-major order:
    problem i uses Gram i // (batch // n_grams).  Every problem starts
    from zero and nothing is replicated: a cross-validation grid of cv
    folds by num penalties moves cv Gram matrices, a fit_path_batch
    one, a bootstrap one per resample.  Returns (batch, width), or
    None when the GPU path is not there or declined the shape, in
    which case the caller runs its CPU path.
    """
    fn = getattr(_BATCH, "scm2cpp_cv_descend", None) if _BATCH else None
    if fn is None:
        return None
    n_grams, batch = corrs.shape[0], lams.size
    if batch % n_grams:
        return None
    width = p * (ntask if ntask > 0 else 1)
    g = np.ascontiguousarray(grams, dtype=np.float64)
    c = np.ascontiguousarray(np.repeat(corrs, batch // n_grams, axis=0),
                             dtype=np.float64)
    w = np.zeros((batch, width))
    lams = np.ascontiguousarray(lams, dtype=np.float64)
    rc = fn(g.ctypes.data_as(_DP), int(n_grams), c.ctypes.data_as(_DP),
            w.ctypes.data_as(_DP), lams.ctypes.data_as(_DP),
            float(l1_ratio), int(batch), int(p), int(ntask), float(nobs),
            int(max_sweeps), int(chunk), float(tol), 1, 1)
    return w if rc == 0 else None


class CovLassoCV:
    """Cross-validated lasso, scikit-learn's LassoCV semantics.

    The lambda grid comes from the full data (lambda_max down, the
    sklearn construction), the folds are contiguous splits in order
    (sklearn's KFold default), and validation error is one matrix
    product per fold.  alpha_ minimises the mean validation MSE, ties
    going to the larger penalty as in scikit-learn, and coef_ is the
    refit on all rows at alpha_.

    With a GPU the whole grid -- cv folds by num penalties, each from
    zero -- is one launch with one block of threads per problem, the
    fold's Gram matrix shared by its problems; on the CPU each fold's
    path is walked warm.  force_cpu picks the CPU path; force_gpu is
    accepted for compatibility (the GPU is now taken whenever it is
    there and force_cpu is not set).

    Attributes after fit: alphas_, mse_path_ (num, cv), alpha_, coef_.
    """

    def __init__(self, cv=5, num=100, eps=1e-3, tol=1e-8, l1_ratio=1.0,
                 force_cpu=False, force_gpu=False, n_jobs=1):
        self.cv = int(cv)
        self.num = int(num)
        self.eps = float(eps)
        self.tol = float(tol)
        self.l1_ratio = float(l1_ratio)
        self.force_cpu = force_cpu
        # Folds are independent, the descent is a ctypes call and the
        # products are BLAS calls, both of which release the GIL, so
        # plain threads scale the CPU path across folds. Default 1:
        # sequential, like scikit-learn's n_jobs=None.
        self.n_jobs = int(n_jobs)
        self.force_gpu = force_gpu

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        n = len(y)
        full = CovLasso(X, y)
        self.alphas_ = full.lambda_grid(num=self.num, eps=self.eps,
                                        l1_ratio=self.l1_ratio)
        # contiguous folds in row order, sizes as even as they come --
        # sklearn's KFold(shuffle=False)
        bounds = np.linspace(0, n, self.cv + 1).astype(int)
        self.mse_path_ = np.empty((self.num, self.cv))
        G = full.g.reshape(full.p, full.p)
        if cuda_available() and not self.force_cpu:
            done = self._fit_gpu(X, y, full, G, bounds, n)
            if done is not None:
                return done

        def one_fold(k):
            lo, hi = bounds[k], bounds[k + 1]
            Xf, yf = X[lo:hi], y[lo:hi]
            # The Gram is additive over rows, so a fold's training Gram
            # is a subtraction: G_full - Xf'Xf costs O(n_fold p^2) where
            # rebuilding from the complement costs O((n - n_fold) p^2).
            # Over five folds that is the whole Gram work twice instead
            # of four times, and the Gram is the dominant O(n p^2) step.
            m = CovLasso(gram=(G - Xf.T @ Xf).ravel(),
                         corr=full.c0 - Xf.T @ yf,
                         nobs=n - (hi - lo))
            # The warm-started path: after the Gram, each lambda resumes
            # where the previous stopped and costs O(p) per moving
            # coordinate. That warm path is what makes searching the
            # alpha grid cheap -- the grid costs barely more than its
            # hardest single alpha.
            path = m.fit_path(self.alphas_, tol=self.tol,
                              l1_ratio=self.l1_ratio)
            resid = Xf @ path.T - yf[:, None]
            self.mse_path_[:, k] = np.mean(resid * resid, axis=0)

        if self.n_jobs > 1:
            from concurrent.futures import ThreadPoolExecutor
            with ThreadPoolExecutor(max_workers=self.n_jobs) as ex:
                list(ex.map(one_fold, range(self.cv)))
        else:
            for k in range(self.cv):
                one_fold(k)
        return self._finish(full)

    def _fit_gpu(self, X, y, full, G, bounds, n):
        # Every fold and every alpha is an independent problem, so all of
        # them go to the device as one batch, one block per problem,
        # the problems of a fold sharing its Gram on the device.  Fold
        # sizes may differ by a row; the kernel only ever uses lam
        # through the product lam * nobs, so each problem's nobs is
        # absorbed into its lambda and nobs is passed as 1 -- exact,
        # not approximate.  Returns None when the device declined, and
        # the CPU path takes over.
        p_ = full.p
        num, cv = self.num, self.cv
        grams = np.empty((cv, p_ * p_))
        corrs = np.empty((cv, p_))
        nobs_k = np.empty(cv)
        for k in range(cv):
            lo, hi = bounds[k], bounds[k + 1]
            Xf, yf = X[lo:hi], y[lo:hi]
            grams[k] = (G - Xf.T @ Xf).ravel()
            corrs[k] = full.c0 - Xf.T @ yf
            nobs_k[k] = n - (hi - lo)
        lams = (np.tile(self.alphas_, cv) * np.repeat(nobs_k, num))
        betas = _grid_descend(grams, corrs, lams, p_, 0, tol=self.tol,
                              l1_ratio=self.l1_ratio)
        if betas is None:
            return None
        betas = betas.reshape(cv, num, p_)
        for k in range(cv):
            lo, hi = bounds[k], bounds[k + 1]
            resid = X[lo:hi] @ betas[k].T - y[lo:hi, None]
            self.mse_path_[:, k] = np.mean(resid * resid, axis=0)
        return self._finish(full)

    def _finish(self, full):
        mean = self.mse_path_.mean(axis=1)
        # alphas_ descends, so argmin's first hit is the larger penalty
        self.alpha_ = float(self.alphas_[int(np.argmin(mean))])
        self.coef_ = full.fit(self.alpha_, tol=self.tol,
                              l1_ratio=self.l1_ratio)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_


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


class CovLogistic:
    """L1-penalized logistic regression, by majorization over the Gram.

    The objective is

        (1/n) sum_i [log(1 + exp(eta_i)) - y_i eta_i] + lam ||b||_1

    with eta = X b and y in {0,1} -- scikit-learn's ``LogisticRegression``
    with ``penalty="l1"``, ``fit_intercept=False`` and ``C = 1/(n lam)``.

    The logistic Hessian is bounded by X'X / 4 (Bohning's bound), so
    instead of reweighting the Gram matrix every round -- which would
    cost O(n p^2) each time and break the design-free construction --
    the quadratic term is fixed at G/4 once and only the gradient
    moves.  Each outer round costs one pass for eta and one for
    X'(y - mu), then hands the majorizer to the same coordinate
    descent the lasso uses: warm-started, exactly resumable, and with
    the pleasant identity that the working correlations are exactly
    X'(y - mu).  Majorization descends monotonically to the optimum
    of this convex problem.
    """

    def __init__(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        if X.ndim != 2 or y.ndim != 1 or X.shape[0] != y.size:
            raise ValueError(
                f"X is {X.shape} and y is {y.shape}; expected (n, p) "
                "and (n,)")
        if not np.all((y == 0.0) | (y == 1.0)):
            raise ValueError("y must be 0/1")
        self.X, self.y = X, y
        self.nobs, self.p = X.shape
        self.g4 = np.ascontiguousarray((X.T @ X).ravel() / 4.0)

    def _grad_corr(self, beta):
        mu = 1.0 / (1.0 + np.exp(-(self.X @ beta)))
        return self.X.T @ (self.y - mu)

    def lambda_max(self):
        """The smallest penalty keeping every coefficient at zero.

        At beta = 0 the gradient is X'(y - 1/2); the penalty must beat
        its largest entry, scaled as the objective is.
        """
        return float(np.max(np.abs(self.X.T @ (self.y - 0.5)))) / self.nobs

    def lambda_grid(self, num=50, eps=1e-2):
        """A log-spaced descending path from lambda_max."""
        return self.lambda_max() * np.logspace(0, np.log10(eps), int(num))

    def fit_path(self, lambdas, tol=1e-7, inner_sweeps=200,
                 max_rounds=500):
        """Coefficients per lambda, warm-started down the path."""
        lambdas = np.asarray(lambdas, dtype=np.float64)
        beta = np.zeros(self.p)
        out = np.empty((lambdas.size, self.p))
        for i, lam in enumerate(lambdas):
            beta = self._fit_one(beta, float(lam), tol, inner_sweeps,
                                 max_rounds)
            out[i] = beta
        return out

    def fit(self, lam, **kw):
        """Coefficients at one lambda, from zero."""
        return self._fit_one(np.zeros(self.p), float(lam),
                             kw.get("tol", 1e-7),
                             kw.get("inner_sweeps", 200),
                             kw.get("max_rounds", 500))

    def _fit_one(self, beta, lam, tol, inner_sweeps, max_rounds):
        beta = beta.copy()
        for _ in range(max_rounds):
            prev = beta.copy()
            # the majorizer at beta: quadratic G/4, working
            # correlations exactly X'(y - mu)
            c = np.ascontiguousarray(self._grad_corr(beta))
            kernel.cov_descend(self.g4, c, beta, lam, inner_sweeps,
                               float(self.nobs), self.p)
            if np.max(np.abs(beta - prev)) < tol * max(
                    1.0, float(np.max(np.abs(beta)))):
                break
        return beta


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


class CovMultiTaskLasso:
    """Multi-task lasso and elastic net over a design's Gram matrix.

    The penalty ties each feature's row of W together across tasks --
    the row enters or leaves for every task at once -- matching
    scikit-learn's ``MultiTaskLasso`` / ``MultiTaskElasticNet`` with
    ``fit_intercept=False``:

        (1/2n)||Y - XW||^2_F + alpha l1_ratio sum_j ||W_j||_2
                             + (alpha/2)(1 - l1_ratio) ||W||^2_F

    The covariance route carries over unchanged: the solver keeps
    C = X'Y - G W per task, so a row's block update is O(p T) and never
    touches the n rows.  Coefficients are (p, n_tasks) -- the transpose
    of scikit-learn's ``coef_``.
    """

    def __init__(self, X=None, Y=None, *, gram=None, corr=None, nobs=None):
        if gram is not None:
            if corr is None or nobs is None:
                raise ValueError("gram needs corr and nobs alongside it")
            c = np.ascontiguousarray(corr, dtype=np.float64)
            if c.ndim != 2:
                raise ValueError("corr must be (p, n_tasks)")
            self.p, self.n_tasks = c.shape
            g = np.ascontiguousarray(gram, dtype=np.float64).ravel()
            if g.size != self.p * self.p:
                raise ValueError(f"gram is {g.size} entries; expected p*p")
            self.nobs, self.g, self.c0 = int(nobs), g, c.ravel()
        else:
            if X is None or Y is None:
                raise ValueError("pass X and Y, or gram, corr and nobs")
            X = np.ascontiguousarray(X, dtype=np.float64)
            Y = np.ascontiguousarray(Y, dtype=np.float64)
            if Y.ndim != 2 or X.shape[0] != Y.shape[0]:
                raise ValueError(
                    f"X is {X.shape} and Y is {Y.shape}; expected (n, p) "
                    "and (n, n_tasks)")
            self.nobs, self.p = X.shape
            self.n_tasks = Y.shape[1]
            self.g = np.ascontiguousarray((X.T @ X).ravel())
            self.c0 = np.ascontiguousarray((X.T @ Y).ravel())
            self.X, self.Y = X, Y

    def lambda_max(self, l1_ratio=1.0):
        """The smallest penalty that zeroes every row of W.

        The single-task |X_j'y| becomes the L2 norm of the row X_j'Y:
        below it the block soft threshold leaves the row at zero.
        """
        C = self.c0.reshape(self.p, self.n_tasks)
        return (float(np.max(np.linalg.norm(C, axis=1)))
                / (self.nobs * l1_ratio))

    def lambda_grid(self, num=100, eps=1e-3, l1_ratio=1.0):
        """Log-spaced from lambda_max down, as the single-task grid is."""
        hi = self.lambda_max(l1_ratio)
        return hi * np.logspace(0, np.log10(eps), int(num))

    def fit(self, lam, **kw):
        """Coefficients (p, n_tasks) at one penalty."""
        return self.fit_path([lam], **kw)[0]

    def fit_path(self, lambdas, tol=1e-8, chunk=20, max_sweeps=100000,
                 l1_ratio=1.0):
        """Coefficients per lambda, warm-started; (len(lambdas), p, n_tasks).

        Give lambdas in descending order, as with the single-task path.
        """
        lambdas = np.asarray(lambdas, dtype=np.float64)
        pt = self.p * self.n_tasks
        W, c = np.zeros(pt), self.c0.copy()
        prev = np.empty(pt)
        out = np.empty((lambdas.size, self.p, self.n_tasks))
        for i, lam in enumerate(lambdas):
            swept = 0
            while swept < max_sweeps:
                prev[:] = W
                kernel.mt_descend(self.g, c, W,
                                  float(lam) * l1_ratio,
                                  float(lam) * (1.0 - l1_ratio), chunk,
                                  float(self.nobs), self.p, self.n_tasks)
                swept += chunk
                if np.max(np.abs(W - prev)) < tol * _scale(W):
                    break
            out[i] = W.reshape(self.p, self.n_tasks)
        return out

    def fit_path_batch(self, lambdas, tol=1e-8, chunk=20,
                       max_sweeps=100000, force_cpu=False, l1_ratio=1.0):
        """Coefficients per lambda, every lambda solved from zero.

        (len(lambdas), p, n_tasks).  On the GPU one block per lambda,
        all sharing this Gram; the CPU fallback is the cold loop.
        """
        lambdas = np.ascontiguousarray(lambdas, dtype=np.float64)
        pt = self.p * self.n_tasks
        if not force_cpu:
            W = _grid_descend(self.g[None, :], self.c0[None, :], lambdas,
                              self.p, self.n_tasks, tol=tol, chunk=chunk,
                              max_sweeps=max_sweeps, l1_ratio=l1_ratio,
                              nobs=float(self.nobs))
            if W is not None:
                return W.reshape(lambdas.size, self.p, self.n_tasks)
        out = np.empty((lambdas.size, pt))
        prev = np.empty(pt)
        for i, lam in enumerate(lambdas):
            W, c, swept = np.zeros(pt), self.c0.copy(), 0
            while swept < max_sweeps:
                prev[:] = W
                kernel.mt_descend(self.g, c, W, float(lam) * l1_ratio,
                                  float(lam) * (1.0 - l1_ratio), chunk,
                                  float(self.nobs), self.p, self.n_tasks)
                swept += chunk
                if np.max(np.abs(W - prev)) < tol * _scale(W):
                    break
            out[i] = W
        return out.reshape(lambdas.size, self.p, self.n_tasks)


class CovMultiTaskLassoCV:
    """scikit-learn's ``MultiTaskLassoCV`` (``MultiTaskElasticNetCV``
    with ``l1_ratio``) over the covariance machinery.

    Same construction as ``CovLassoCV``: the grid from the full data,
    contiguous folds, each fold's training Gram a subtraction from the
    full one, the whole path walked warm per fold, alpha_ by minimum
    mean validation MSE (over samples and tasks) with ties to the
    larger penalty, refit on all rows.  With a GPU the grid is one
    launch, one block per (fold, penalty) problem, as in CovLassoCV.

    Attributes after fit: alphas_, mse_path_ (num, cv), alpha_, coef_
    (p, n_tasks).
    """

    def __init__(self, cv=5, num=100, eps=1e-3, tol=1e-8, l1_ratio=1.0,
                 force_cpu=False, force_gpu=False, n_jobs=1):
        self.cv = int(cv)
        self.num = int(num)
        self.eps = float(eps)
        self.tol = float(tol)
        self.l1_ratio = float(l1_ratio)
        self.force_cpu = force_cpu
        self.force_gpu = force_gpu
        # Same fold-thread parallelism as CovLassoCV; default sequential.
        self.n_jobs = int(n_jobs)

    def fit(self, X, Y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        Y = np.ascontiguousarray(Y, dtype=np.float64)
        n = X.shape[0]
        full = CovMultiTaskLasso(X, Y)
        self.alphas_ = full.lambda_grid(num=self.num, eps=self.eps,
                                        l1_ratio=self.l1_ratio)
        bounds = np.linspace(0, n, self.cv + 1).astype(int)
        self.mse_path_ = np.empty((self.num, self.cv))
        G = full.g.reshape(full.p, full.p)
        C = full.c0.reshape(full.p, full.n_tasks)
        if cuda_available() and not self.force_cpu:
            done = self._fit_gpu(X, Y, full, G, C, bounds, n)
            if done is not None:
                return done

        def one_fold(k):
            lo, hi = bounds[k], bounds[k + 1]
            Xf, Yf = X[lo:hi], Y[lo:hi]
            m = CovMultiTaskLasso(gram=(G - Xf.T @ Xf).ravel(),
                                  corr=C - Xf.T @ Yf,
                                  nobs=n - (hi - lo))
            path = m.fit_path(self.alphas_, tol=self.tol,
                              l1_ratio=self.l1_ratio)
            # all validation residuals in one product: (nf, num, T)
            resid = np.tensordot(Xf, path, axes=([1], [1])) - Yf[:, None, :]
            self.mse_path_[:, k] = np.mean(resid * resid, axis=(0, 2))

        if self.n_jobs > 1:
            from concurrent.futures import ThreadPoolExecutor
            with ThreadPoolExecutor(max_workers=self.n_jobs) as ex:
                list(ex.map(one_fold, range(self.cv)))
        else:
            for k in range(self.cv):
                one_fold(k)
        return self._finish(full)

    def _fit_gpu(self, X, Y, full, G, C, bounds, n):
        # The grid as one launch, the fold's Gram shared by its
        # problems and nobs absorbed into each problem's lambda as in
        # CovLassoCV; None when the device declined.
        p_, T = full.p, full.n_tasks
        num, cv = self.num, self.cv
        grams = np.empty((cv, p_ * p_))
        corrs = np.empty((cv, p_ * T))
        nobs_k = np.empty(cv)
        for k in range(cv):
            lo, hi = bounds[k], bounds[k + 1]
            Xf, Yf = X[lo:hi], Y[lo:hi]
            grams[k] = (G - Xf.T @ Xf).ravel()
            corrs[k] = (C - Xf.T @ Yf).ravel()
            nobs_k[k] = n - (hi - lo)
        lams = np.tile(self.alphas_, cv) * np.repeat(nobs_k, num)
        W = _grid_descend(grams, corrs, lams, p_, T, tol=self.tol,
                          l1_ratio=self.l1_ratio)
        if W is None:
            return None
        W = W.reshape(cv, num, p_, T)
        for k in range(cv):
            lo, hi = bounds[k], bounds[k + 1]
            resid = (np.tensordot(X[lo:hi], W[k], axes=([1], [1]))
                     - Y[lo:hi, None, :])
            self.mse_path_[:, k] = np.mean(resid * resid, axis=(0, 2))
        return self._finish(full)

    def _finish(self, full):
        mean = self.mse_path_.mean(axis=1)
        self.alpha_ = float(self.alphas_[int(np.argmin(mean))])
        self.coef_ = full.fit(self.alpha_, tol=self.tol,
                              l1_ratio=self.l1_ratio)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_
