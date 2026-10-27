"""Lasso by coordinate descent over a Gram matrix, from Scheme via C++.

The solver is `examples/kernel-only/lasso-cov.scm` in the scm2cpp
repository, translated to C++ and compiled at install time.  It takes
the covariance route: given X'X and X'y, each coordinate step costs
O(p) instead of O(n), so a whole regularization path is cheap once the
Gram matrix exists.  The descent is exactly resumable, which is what
lets a path be walked warm and a batch of lambdas be handed to a GPU.

    from scm2cpp_learn import CovLasso

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
import os
import warnings

import numpy as np

from ._generated import _loader as kernel
from ._libfind import load_batch_lib, derived_backends, nmf_backends
from ._compat import (BaseEstimator, ClassifierMixin, RegressorMixin, TransformerMixin,
                      DensityMixin, Tagged, fit_xy, fit_x, pred_x, classes_of,
                      check_is_fitted, as_csr, _issparse)

# the derived kernel's variants that were built, each bound to its own
# library: {'cublas': module, 'blas': module, 'loops': module}
_DERIVED = {}
for _v in derived_backends():
    try:
        _DERIVED[_v] = __import__("scm2cpp_learn._generated._loader_derived_" + _v,
                                  fromlist=["lasso"])
    except ImportError:
        pass

__all__ = ["GramLasso", "GramElasticNet", "GramRidge", "GramRidgeCV", "CovLasso", "CovRidge", "CovBayesianRidge", "CovLogistic", "CovGroupLasso",
           "LinearSVM", "KernelSVM", "LinearSVR", "KernelSVR", "L1LogisticRegression",
           "CDNMF", "nmf_backend", "CDGraphicalLasso", "LinearRANSAC",
           "SGDLinearClassifier", "SGDLinearRegressor", "SGDPerceptron", "GramOMP", "GramLars", "GramLassoLars", "GramLassoLarsIC",
           "LBFGSLogisticRegression", "LBFGSHuberRegressor", "LBFGSLogisticRegressionCV",
           "LBFGSPoissonRegressor", "LBFGSGammaRegressor", "LBFGSTweedieRegressor",
           "GramLarsCV", "GramLassoLarsCV", "GramOMPCV",
           "EMGaussianMixture", "CovPCA", "GramKernelPCA", "GramLDA", "GramTruncatedSVD", "GramPLSRegression", "GramPLSCanonical", "GramCCA", "GramPLSSVD", "GramFactorAnalysis", "GramLinearRegression", "ParallelFastICA", "CovARDRegression",
           "L1LinearSVM", "WeiszfeldTheilSen", "f_regression", "f_classif", "SelectKBest",
           "SelectPercentile", "GramRFE",
           "CovMultiTaskLasso", "CovMultiTaskLassoCV", "DerivedLasso",
           "GramLogisticRegression", "GramGroupLasso", "GramMultiTaskLasso",
           "GramMultiTaskElasticNet", "DesignLasso",
           "cuda_available", "derived_backend", "kernel"]
__version__ = "0.20.0"

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


class DerivedLasso:
    """Lasso from the design matrix, by the kernel the translator derived.

    CovLasso above is the usable one: numpy forms the Gram matrix, a
    hand-written sweep (lasso-cov.scm) runs over it, and cross-
    validation, bootstrap and the GPU grid all feed that sweep their
    own Gram matrices.  This class exists to show the translator's
    work instead.  Its kernel is examples/kernel-only/lasso-design.scm
    -- the residual-form coordinate descent, the algorithm inside
    scikit-learn's Lasso(precompute=False), written as flat loops over
    X as numpy holds it (n rows of p), the residual and the column
    norms taken inside, no Gram matrix in sight -- translated with
    --derive and --blas:
    the translator raised the loops to the array algebra, replaced the
    residual by the memo c = X'r kept current through a Gram matrix it
    hoisted in front of the penalty path, folded the column norms into
    that Gram's diagonal, folded the products into one dsyrk and two
    dgemv calls, and put the result under (if (< p n) ..)
    with the original sweep in the else branch -- scikit-learn's
    precompute='auto' rule, derived.  Nothing in it is written at the Gram level by hand, and numpy
    prepares nothing: X and y go in as they are.

    Three variants of the same derivation can be built: 'cublas'
    (--derive --cublas: the products on the device, X uploaded once per
    fit_path call), 'blas' (--derive --blas, CBLAS) and 'loops'
    (--derive alone: the Gram a scalar loop nest, much slower on large
    designs).  backend=None takes the best one this machine built and
    can run -- cublas only when a device answers -- and
    derived_backend() says which that is; backend='blas' etc. insists.

    The constructor only checks shapes and keeps X (C-contiguous, as
    numpy makes it) and y; everything else happens inside fit_path.

    Convergence is the kernel's: a sweep in which no coefficient moved
    by more than tol (absolute) ends the fit at that lambda, max_sweeps
    bounds it; tol=0.0 asks for the exact fixed point.  Same objective
    as CovLasso.
    """

    def __init__(self, X, y, backend=None):
        if backend is None:
            backend = derived_backend()
            if backend is None:
                raise ImportError(
                    "scm2cpp_learn: the derived kernel was not built; "
                    "reinstall the package (pip install --force-reinstall "
                    "scm2cpp-learn)")
        elif backend not in _DERIVED:
            raise ValueError(f"derived kernel backend {backend!r} is not built; "
                             f"built: {sorted(_DERIVED)}")
        self.backend = backend
        self._kernel = _DERIVED[backend]
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        if X.ndim != 2 or y.ndim != 1 or X.shape[0] != y.size:
            raise ValueError(
                f"X is {X.shape} and y is {y.shape}; expected (n, p) and (n,)")
        self.nobs, self.p = X.shape
        self.X, self.y = X, y
        self._c0 = None

    @property
    def c0(self):
        # X'y, needed only to place the penalty grid
        if self._c0 is None:
            self._c0 = self.X.T @ self.y
        return self._c0

    def lambda_max(self):
        return float(np.max(np.abs(self.c0))) / self.nobs

    def lambda_grid(self, num=100, eps=1e-3):
        hi = self.lambda_max()
        return hi * np.logspace(0, np.log10(eps), int(num))

    def fit(self, lam, **kw):
        return self.fit_path([lam], **kw)[0]

    def fit_path(self, lambdas, tol=1e-8, max_sweeps=100000):
        """Coefficients per lambda, warm-started, shape (len(lambdas), p).

        One call into the derived kernel: it takes the residual and
        the column norms (folded into the Gram's diagonal when p < n),
        builds the Gram matrix, walks the penalties, and leaves the
        coefficient at each in a row of the result.  tol is the largest move of
        one coefficient in a sweep below which that lambda is done.  The
        kernel's value, the sweeps run over the whole path, is kept as
        n_iter_.
        """
        lams = np.ascontiguousarray(lambdas, dtype=np.float64).ravel()
        beta = np.zeros(self.p)
        resid = np.empty(self.nobs)      # filled by the kernel from y
        xnorm = np.empty(self.p)         # the column norms, taken inside
        betas = np.zeros(lams.size * self.p)
        self.n_iter_ = int(self._kernel.lasso_design(
            self.X, self.y, resid, xnorm, beta, lams, betas, int(max_sweeps), float(tol),
            self.nobs, self.p, lams.size))
        return betas.reshape(lams.size, self.p)


class DesignLasso(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``Lasso`` interface over DerivedLasso: fit(X, y)
    centres the data when ``fit_intercept`` and runs the derived kernel
    at one penalty ``alpha``, same objective as GramLasso.  ``tol`` is
    the kernel's (the largest absolute move of one coefficient in a
    sweep), ``max_iter`` its sweep cap and ``backend`` DerivedLasso's.

    Attributes after fit: coef_, intercept_, n_iter_ (the sweeps the
    kernel ran), n_features_in_.
    """

    def __init__(self, alpha=1.0, *, fit_intercept=True, tol=1e-8, max_iter=100000,
                 backend=None):
        self.alpha, self.fit_intercept, self.tol, self.max_iter = alpha, fit_intercept, tol, max_iter
        self.backend = backend

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        Xc, yc, xm, ym = _centered(X, y, self.fit_intercept)
        m = DerivedLasso(Xc, yc, backend=self.backend)
        self.coef_ = m.fit(float(self.alpha), tol=float(self.tol), max_sweeps=int(self.max_iter))
        self.n_iter_ = m.n_iter_
        self.intercept_ = float(ym - xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


def derived_backend():
    """The derived kernel variant DerivedLasso takes by default: 'cublas'
    when built and a device answers, else 'blas', else 'loops'; None
    when none was built."""
    for v in ("cublas", "blas", "loops"):
        if v in _DERIVED and (v != "cublas" or cuda_available()):
            return v
    return None


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


class CovLassoCV(Tagged, RegressorMixin, BaseEstimator):
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
        # Folds are independent, the descent is a ctypes call and the
        # products are BLAS calls, both of which release the GIL, so
        # plain threads scale the CPU path across folds. Default 1:
        # sequential, like scikit-learn's n_jobs=None.
        self.cv, self.num, self.eps, self.tol = cv, num, eps, tol
        self.l1_ratio, self.force_cpu, self.force_gpu = l1_ratio, force_cpu, force_gpu
        self.n_jobs = n_jobs

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n = len(y)
        cv, num = int(self.cv), int(self.num)
        tol, l1_ratio = float(self.tol), float(self.l1_ratio)
        full = CovLasso(X, y)
        self.alphas_ = full.lambda_grid(num=num, eps=float(self.eps),
                                        l1_ratio=l1_ratio)
        # contiguous folds in row order, sizes as even as they come --
        # sklearn's KFold(shuffle=False)
        bounds = np.linspace(0, n, cv + 1).astype(int)
        self.mse_path_ = np.empty((num, cv))
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
            path = m.fit_path(self.alphas_, tol=tol, l1_ratio=l1_ratio)
            resid = Xf @ path.T - yf[:, None]
            self.mse_path_[:, k] = np.mean(resid * resid, axis=0)

        if int(self.n_jobs) > 1:
            from concurrent.futures import ThreadPoolExecutor
            with ThreadPoolExecutor(max_workers=int(self.n_jobs)) as ex:
                list(ex.map(one_fold, range(cv)))
        else:
            for k in range(cv):
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
        num, cv = int(self.num), int(self.cv)
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
        betas = _grid_descend(grams, corrs, lams, p_, 0, tol=float(self.tol),
                              l1_ratio=float(self.l1_ratio))
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
        self.coef_ = full.fit(self.alpha_, tol=float(self.tol),
                              l1_ratio=float(self.l1_ratio))
        self.intercept_ = 0.0 if self.coef_.ndim == 1 else np.zeros(self.coef_.shape[1])
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_


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
            self.g = np.ascontiguousarray(_gram(X).ravel())
            self.c0 = np.ascontiguousarray(_gram_xy(X, y))
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
        """Coefficients at one alpha: one solve of X'X + alpha I while no
        path has needed the eigendecomposition (at p = 200 a few
        milliseconds against eigh's tenth of a second), through it after."""
        if self._eig is None and float(alpha) > 0.0:
            b = _ridge_solve(self.g.reshape(self.p, self.p), self.c0, float(alpha))
            if b is not None:
                return b
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


def _centered(X, y, fit_intercept):
    # the data the intercept-free solvers see: centred when an intercept
    # is fitted (scikit-learn's _preprocess_data), as they are otherwise
    if not fit_intercept:
        return X, y, np.zeros(X.shape[1]), np.zeros(y.shape[1:]) if y.ndim > 1 else 0.0
    xm, ym = X.mean(axis=0), y.mean(axis=0)
    return np.ascontiguousarray(X - xm), y - ym, xm, ym


def _centered_gram(X, y, fit_intercept):
    """(Xc'Xc, Xc'yc, xm, ym) for the centred data Xc, yc, without
    forming Xc: X'X - n xm xm' and X'y - n xm ym, which saves the copy
    of X (as long as the Gram product itself on 20000 x 200 rows, where
    it took the intercept from free to twice the fit).  The correction
    cancels digits when a column's mean is large against its spread,
    about (mean / sd)^2 ulps, so a column with mean over 100 sd (or no
    spread at all) sends the whole fit through the centred copy.  A
    sparse X (CSR) takes the correction always -- centring would fill
    it in -- with X'X by csr-gram and X'y by csr-mm."""
    n = X.shape[0]
    if _issparse(X):
        G, c = _sparse_gram(X), _dot(X, y, transpose=True)
        if not fit_intercept:
            return G, c, np.zeros(X.shape[1]), np.zeros(y.shape[1:]) if y.ndim > 1 else 0.0
        xm, ym = _sparse_mean(X), y.mean(axis=0)
        G -= np.outer(xm, n * xm)
        c -= np.multiply.outer(n * xm, ym)
        return G, c, xm, ym
    G, c = _gram(X), _gram_xy(X, y)
    if not fit_intercept:
        return G, c, np.zeros(X.shape[1]), np.zeros(y.shape[1:]) if y.ndim > 1 else 0.0
    xm, ym = X.mean(axis=0), y.mean(axis=0)
    nm2 = n * xm * xm
    if np.all(np.diagonal(G) - nm2 > 1e-4 * nm2):
        G -= np.outer(xm, n * xm)
        c -= np.multiply.outer(n * xm, ym)
        return G, c, xm, ym
    Xc, yc = np.ascontiguousarray(X - xm), y - ym
    return Xc.T @ Xc, Xc.T @ yc, xm, ym


class GramElasticNet(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``ElasticNet(precompute=True)`` interface over
    CovLasso: fit(X, y) centres the data when ``fit_intercept``, forms
    the Gram matrix once and runs the covariance sweep at ``alpha``,

        (1 / 2 n) ||y - X b - b0||^2 + alpha l1_ratio ||b||_1
                  + (alpha / 2)(1 - l1_ratio) ||b||^2.

    ``tol`` is CovLasso's (the largest coefficient move in a sweep,
    relative to the coefficients' size) and ``max_iter`` its sweep cap.
    For a whole path or a grid, CovLasso itself (fit_path,
    fit_path_batch) is the faster interface.

    A scipy.sparse X is taken: X'X by csr-gram, its intercept by the
    n xm xm' correction (as scikit-learn's sparse coordinate descent
    keeps X uncentred too).

    Attributes after fit: coef_, intercept_, n_features_in_.
    """
    _sparse = True

    def __init__(self, alpha=1.0, *, l1_ratio=0.5, fit_intercept=True, tol=1e-8,
                 max_iter=100000):
        self.alpha, self.l1_ratio, self.fit_intercept = alpha, l1_ratio, fit_intercept
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        G, c, xm, ym = _centered_gram(X, y, self.fit_intercept)
        g = np.ascontiguousarray(G.ravel())
        c = np.ascontiguousarray(c)
        lam, r = float(self.alpha), float(self.l1_ratio)
        tol, cap = float(self.tol), int(self.max_iter)
        beta, prev = np.zeros(p), np.empty(p)
        swept = 0
        # CovLasso.fit_path's loop at one lambda, counting the sweeps
        while swept < cap:
            chunk = min(20, cap - swept)
            prev[:] = beta
            kernel.enet_descend(g, c, beta, lam * r, lam * (1.0 - r), chunk, float(n), p)
            swept += chunk
            if np.max(np.abs(beta - prev)) < tol * _scale(beta):
                break
        self.coef_, self.n_iter_ = beta, swept
        self.intercept_ = float(ym - xm @ self.coef_)
        return self

    def predict(self, X):
        X = pred_x(self, X)
        return (_dot(X, self.coef_) if _issparse(X) else X @ self.coef_) + self.intercept_


class GramLasso(GramElasticNet):
    """scikit-learn's ``Lasso(precompute=True)`` interface over CovLasso:
    GramElasticNet with l1_ratio 1.

    Attributes after fit: coef_, intercept_, n_features_in_.
    """

    def __init__(self, alpha=1.0, *, fit_intercept=True, tol=1e-8, max_iter=100000):
        self.alpha, self.fit_intercept, self.tol, self.max_iter = alpha, fit_intercept, tol, max_iter

    @property
    def l1_ratio(self):
        return 1.0


class GramRidge(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``Ridge`` interface over the Gram matrix:
    (X'X + alpha I) b = X'y on the centred data by one Cholesky solve
    (least squares when alpha is 0 and X'X singular), y one target or
    several (coef_ then (n_targets, p), as Ridge has it).  For many
    alphas, CovRidge's fit_path is the faster interface.  A scipy.sparse
    X is taken (csr-gram, the intercept by the n xm xm' correction).

    Attributes after fit: coef_, intercept_, n_features_in_.
    """
    _multi_output = True
    _sparse = True

    def __init__(self, alpha=1.0, *, fit_intercept=True):
        self.alpha, self.fit_intercept = alpha, fit_intercept

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, multi_output=True)
        p = X.shape[1]
        A, b, xm, ym = _centered_gram(X, y, self.fit_intercept)
        coef = _ridge_solve(A, b, float(self.alpha))
        if coef is None:
            A.flat[::p + 1] += float(self.alpha)
            try:
                coef = np.linalg.solve(A, b)
            except np.linalg.LinAlgError:
                coef = np.linalg.lstsq(A, b, rcond=None)[0]
        self.coef_ = coef.T if coef.ndim > 1 else coef
        self.intercept_ = ym - xm @ coef
        if np.ndim(self.intercept_) == 0:
            self.intercept_ = float(self.intercept_)
        return self

    def predict(self, X):
        X = pred_x(self, X)
        return (_dot(X, self.coef_.T) if _issparse(X) else X @ self.coef_.T) + self.intercept_


class GramRidgeCV(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``RidgeCV`` with ``cv=None``: the alpha whose
    leave-one-out mean squared error is least, every alpha from one
    eigenproblem (``examples/kernel-only/ridge-gcv.scm``).  With the hat
    matrix H = Z diag(1 / (lam + alpha)) Z' (plus 1/n with an
    intercept), the leave-one-out residual is (y - yhat) / (1 - diag H),
    and diag H and yhat at every alpha are two products.  Z comes from
    the eigenvectors of Xc'Xc (``gcv_mode="svd"``, the default when
    n > p, X'X by dsyrk) or of Xc Xc' (``"eigen"``, the default
    otherwise; as scikit-learn's, it takes e = c / diag G^-1 for
    c = G^-1 y, G = Xc Xc' + 11' + alpha I with the intercept's
    eigenvalue unpenalised, so that a small alpha, where H tends to I,
    loses no digits to 1 - diag H); the eigenproblem is LAPACK's dsyevd where the BLAS
    build is here.  Only ``cv=None`` and ``scoring=None`` are taken.

    Attributes after fit: alpha_, best_score_ (minus the mean squared
    leave-one-out error), coef_, intercept_, cv_results_ (with
    ``store_cv_results``: the squared errors, (n, n_alphas) or
    (n, n_targets, n_alphas)), n_features_in_.
    """
    _multi_output = True

    def __init__(self, alphas=(0.1, 1.0, 10.0), *, fit_intercept=True, scoring=None,
                 cv=None, gcv_mode=None, store_cv_results=False, alpha_per_target=False):
        self.alphas, self.fit_intercept, self.scoring, self.cv = alphas, fit_intercept, scoring, cv
        self.gcv_mode, self.store_cv_results = gcv_mode, store_cv_results
        self.alpha_per_target = alpha_per_target

    def fit(self, X, y):
        if self.cv is not None or self.scoring is not None:
            raise ValueError("GramRidgeCV takes cv=None and scoring=None only "
                             "(leave-one-out by GCV, mean squared error)")
        if self.gcv_mode not in (None, "auto", "svd", "eigen"):
            raise ValueError(f"gcv_mode={self.gcv_mode!r}: expected None, 'auto', 'svd' or 'eigen'")
        alphas = np.ascontiguousarray(np.atleast_1d(np.asarray(self.alphas, dtype=np.float64)))
        if alphas.ndim != 1 or alphas.size == 0 or not np.all(alphas > 0.0):
            raise ValueError(f"alphas={self.alphas!r}: expected positive values")
        X, y = fit_xy(self, X, y, multi_output=True)
        n, p = X.shape
        Y = y.reshape(n, -1)
        t = Y.shape[1]
        k = _gramops_kernels()
        if self.fit_intercept:
            xm, ym = X.mean(axis=0), Y.mean(axis=0)
        else:
            xm, ym = np.zeros(p), np.zeros(t)
        yc = np.ascontiguousarray(Y - ym)
        mode = self.gcv_mode if self.gcv_mode in ("svd", "eigen") else ("svd" if n > p else "eigen")
        if mode == "svd":
            G = _gram(X)
            Xs, xs = X, xm
            nm2 = n * xm * xm
            if self.fit_intercept and not np.all(np.diagonal(G) - nm2 > 1e-4 * nm2):
                # a column whose mean dwarfs its spread: the correction
                # X'X - n xm xm' would cancel its digits (_centered_gram)
                Xs, xs = np.ascontiguousarray(X - xm), np.zeros(p)
                G = _gram(Xs)
            else:
                G -= np.outer(xm, n * xm)
            m = p
            V, lam, Z, R = np.zeros((p, p)), np.zeros(p), np.zeros((n, p)), np.zeros((p, t))
            k.ridge_gcv_primal(Xs, xs, yc, np.ascontiguousarray(G), V, lam, Z, R, n, p, t)
        else:
            Xc = np.ascontiguousarray(X - xm)
            K = _gram(np.ascontiguousarray(Xc.T))
            if self.fit_intercept:
                K += 1.0
            V, lam, R = np.zeros((n, n)), np.zeros(n), np.zeros((n, t))
            drop = k.ridge_gcv_dual(K, V, lam, yc, R, n, t, int(bool(self.fit_intercept)))
        na = alphas.size
        mse = np.zeros((na, t))
        loo = np.zeros((n, t, na)) if self.store_cv_results else np.zeros(1)
        store = int(bool(self.store_cv_results))
        if mode == "svd":
            k.ridge_gcv_scan(Z, lam, R, yc, alphas, 1.0 / n if self.fit_intercept else 0.0,
                             mse, loo, store, n, m, t, na)
        else:
            k.ridge_gcv_scan_dual(V, lam, R, alphas, drop, mse, loo, store, n, t, na)
        if self.alpha_per_target and t > 1:
            best = np.argmin(mse, axis=0)
            al = alphas[best]
            self.alpha_ = al
            self.best_score_ = -mse[best, np.arange(t)]
        else:
            best = int(np.argmin(mse.mean(axis=1)))
            al = np.full(t, alphas[best])
            self.alpha_ = float(alphas[best])
            self.best_score_ = float(-mse[best].mean())
        if mode == "svd":
            coef = V @ (R / (lam[:, None] + al[None, :]))
        else:
            # (Xc Xc' + alpha I)^-1 yc by the eigenvectors, then Xc' of
            # it; yc has no part along 1, so the 11' added changes nothing
            w = 1.0 / (lam[:, None] + al[None, :])
            if drop >= 0:
                w[drop] = 0.0
            coef = Xc.T @ (V @ (R * w))
        if y.ndim == 1:
            self.coef_ = coef[:, 0]
            self.intercept_ = float(ym[0] - xm @ coef[:, 0])
            if self.alpha_per_target:
                self.alpha_ = float(np.ravel(self.alpha_)[0])
                self.best_score_ = float(np.ravel(self.best_score_)[0])
        else:
            self.coef_ = coef.T
            self.intercept_ = ym - xm @ coef
        if self.store_cv_results:
            self.cv_results_ = loo[:, 0, :] if y.ndim == 1 else loo
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_.T + self.intercept_


class CovBayesianRidge(Tagged, RegressorMixin, BaseEstimator):
    """Bayesian ridge regression, scikit-learn's ``BayesianRidge``,
    with the linear algebra in the eigenbasis of the Gram matrix.

    The model, the defaults (``max_iter=300``, ``tol=1e-3``, the four
    gamma hyperpriors at 1e-6, ``alpha`` starting at ``1/var(y)``,
    ``lambda`` at 1) and the iteration are scikit-learn's: MacKay's
    updates of the noise precision ``alpha`` and the weight precision
    ``lambda``, the posterior mean recomputed after each, a stop when
    the mean moves by less than ``tol`` in L1.  What differs is where
    the work goes.  scikit-learn takes the SVD of X once and then, per
    iteration, multiplies by X again for the squared error, O(n p).
    Here, for n > p, X enters once, through X'X and X'y: one symmetric
    eigendecomposition, after which the posterior mean, its squared
    norm and the squared error are sums over the p eigenvalues, O(p) per
    iteration.  For n <= p the same is done with the n x n kernel
    matrix X X'.  With ``fit_intercept`` the data are centred, as in
    scikit-learn, and the Gram is centred in place.

    Attributes after fit: coef_, intercept_, alpha_, lambda_, sigma_
    (the posterior covariance of the weights, p x p), n_iter_.
    """

    def __init__(self, *, max_iter=300, tol=1e-3, alpha_1=1e-6,
                 alpha_2=1e-6, lambda_1=1e-6, lambda_2=1e-6,
                 alpha_init=None, lambda_init=None, fit_intercept=True):
        self.max_iter, self.tol = max_iter, tol
        self.alpha_1, self.alpha_2 = alpha_1, alpha_2
        self.lambda_1, self.lambda_2 = lambda_1, lambda_2
        self.alpha_init, self.lambda_init = alpha_init, lambda_init
        self.fit_intercept = fit_intercept

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        max_iter, tol = int(self.max_iter), float(self.tol)
        a1, a2 = float(self.alpha_1), float(self.alpha_2)
        l1, l2 = float(self.lambda_1), float(self.lambda_2)
        y_var = float(y.var())
        if self.fit_intercept:
            xm, ym = X.mean(axis=0), float(y.mean())
        else:
            xm, ym = np.zeros(p), 0.0
        tall = n > p
        if tall:
            # X'X and X'y of the centred data, without centring X
            G = X.T @ X
            c = X.T @ y
            if self.fit_intercept:
                G -= n * np.outer(xm, xm)
                c -= n * ym * xm
            e, V = np.linalg.eigh(G)
            z = V.T @ c
            yy = float(y @ y) - n * ym * ym
        else:
            Xc = X - xm if self.fit_intercept else X
            yc = y - ym
            e, U = np.linalg.eigh(Xc @ Xc.T)
            u = U.T @ yc
        e = np.maximum(e, 0.0)

        def mean_stats(alpha, lam):
            # the posterior mean at (alpha, lam), its squared norm, and
            # the squared error, without touching X when n > p
            r = lam / alpha
            if tall:
                w = z / (e + r)
                coef = V @ w
                sse = yy - 2.0 * float(w @ z) + float((e * w) @ w)
                return coef, float(w @ w), max(sse, 0.0)
            d = u / (e + r)
            coef = Xc.T @ (U @ d)
            resid = yc - Xc @ coef
            return coef, float((e * d) @ d), float(resid @ resid)

        eps = np.finfo(np.float64).eps
        alpha = 1.0 / (y_var + eps) if self.alpha_init is None else float(self.alpha_init)
        lam = 1.0 if self.lambda_init is None else float(self.lambda_init)
        old = None
        for it in range(max_iter):
            coef, cc, sse = mean_stats(alpha, lam)
            gamma = float(np.sum(alpha * e / (lam + alpha * e)))
            lam = (gamma + 2 * l1) / (cc + 2 * l2)
            alpha = (n - gamma + 2 * a1) / (sse + 2 * a2)
            if it != 0 and float(np.sum(np.abs(old - coef))) < tol:
                break
            old = coef
        self.n_iter_ = it + 1
        self.alpha_, self.lambda_ = alpha, lam
        self.coef_, _, _ = mean_stats(alpha, lam)
        self.intercept_ = ym - float(xm @ self.coef_) if self.fit_intercept else 0.0
        self.X_offset_ = xm
        # the posterior covariance (lambda I + alpha X'X)^-1
        if tall:
            self.sigma_ = (V / (alpha * e + lam)) @ V.T
        else:
            # Woodbury through the kernel side: (1/lam)(I - X'U D U'X),
            # D = alpha / (lam + alpha e)
            B = Xc.T @ U
            self.sigma_ = (np.eye(p) - (B * (alpha / (lam + alpha * e))) @ B.T) / lam
        return self

    def predict(self, X, return_std=False):
        X = pred_x(self, X)
        mean = X @ self.coef_ + self.intercept_
        if not return_std:
            return mean
        Xc = X - self.X_offset_
        var = np.einsum("ij,jk,ik->i", Xc, self.sigma_, Xc) + 1.0 / self.alpha_
        return mean, np.sqrt(var)

def _classifier_kernels():
    # imported on first use: the classifiers are their own library
    from ._generated import _loader_classifiers
    return _loader_classifiers


def _binary_labels(y):
    """Two classes as (classes_, y in {-1, +1}), classes_[1] the +1."""
    y = np.asarray(y)
    classes = np.unique(y)
    if classes.size == 1:
        raise ValueError("expected two classes, got 1 class")
    if classes.size != 2:
        raise ValueError("Only binary classification is supported. The type of the target "
                         f"is multiclass ({classes.size} classes).")
    return classes, np.where(y == classes[1], 1.0, -1.0)


def _seed(random_state):
    # the solvers' Park-Miller generator wants a seed in [1, 2^31 - 2]
    return int(random_state) % 2147483646 + 1


class LinearSVM(Tagged, ClassifierMixin, BaseEstimator):
    """The L1-loss (hinge) linear SVM by liblinear's own algorithm.

    ``examples/kernel-only/svm-liblinear.scm`` translated plainly:
    liblinear's solve_l2r_l1l2_svc, dual coordinate descent with a
    random order in every sweep, shrinking, and the projected-gradient
    stop -- what scikit-learn's ``LinearSVC(loss="hinge", dual=True,
    fit_intercept=False)`` runs, on the same problem

        min_w  1/2 ||w||^2 + C sum_i max(0, 1 - y_i w.x_i).

    No intercept (as ``fit_intercept=False``); two classes, the second
    of ``classes_`` being the positive one.  ``tol`` and ``max_iter``
    are LinearSVC's (the projected-gradient span and the sweep cap).

    Attributes after fit: classes_, coef_, dual_coef_ (the alphas),
    n_iter_.
    """

    _binary_only = True

    def __init__(self, C=1.0, tol=1e-4, max_iter=1000, random_state=0):
        self.C, self.tol, self.max_iter = C, tol, max_iter
        self.random_state = random_state

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        w = np.zeros(p)
        alpha = np.zeros(n)
        xnorm = np.zeros(n)
        self.n_iter_ = _classifier_kernels().svm_liblinear(
            X, ys, w, alpha, xnorm, float(self.C), int(self.max_iter), float(self.tol),
            _seed(self.random_state), n, p)
        self.coef_, self.dual_coef_ = w, alpha
        return self

    def decision_function(self, X):
        return pred_x(self, X) @ self.coef_

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


class _KernelMatrix:
    # the kernel matrix of KernelSVM and KernelSVR, as SVC and SVR take
    # it: rbf (gamma "scale", "auto" or a number), linear, or precomputed
    def _k(self, A, B):
        if self.kernel == "linear":
            return A @ B.T
        if self.kernel == "rbf":
            if A.shape[0] * B.shape[0] < 200_000:
                # numpy's vectorised exp, while the matrix sits in cache:
                # 0.14 ms to the loop's 0.31 at 200 x 200
                sa = (A * A).sum(1)[:, None]
                sb = (B * B).sum(1)[None, :]
                return np.exp(-self._gamma * np.maximum(sa + sb - 2.0 * (A @ B.T), 0.0))
            # the product by BLAS, the rest in place by svm-smo.scm's
            # rbf-from-products (on every thread of an OpenMP build;
            # 76 ms to numpy's 96 at 3,000 on one core, 50 to 105 on 20)
            G = np.ascontiguousarray(A @ B.T)
            _classifier_kernels().rbf_from_products(
                G, (A * A).sum(1), (B * B).sum(1), float(self._gamma), A.shape[0], B.shape[0])
            return G
        raise ValueError(f"kernel {self.kernel!r}: expected rbf, linear or precomputed")

    def _train_kernel(self, X):
        if self.kernel == "precomputed":
            return X
        p = X.shape[1]
        if self.gamma == "scale":
            v = float(X.var())
            self._gamma = 1.0 / (p * v) if v > 0 else 1.0
        elif self.gamma == "auto":
            self._gamma = 1.0 / p
        else:
            self._gamma = float(self.gamma)
        return self._k(X, X)

    def _support_kernel(self, X):
        X = pred_x(self, X)
        if self.kernel == "precomputed":
            return X[:, self.support_]
        return self._k(X, self.support_vectors_)


class KernelSVM(Tagged, ClassifierMixin, _KernelMatrix, BaseEstimator):
    """C-SVC by libsvm's own algorithm, over the whole kernel matrix.

    ``examples/kernel-only/svm-smo.scm`` translated plainly: libsvm's
    Solver::Solve -- SMO with the second-order working-set selection
    (WSS3), shrinking with gradient reconstruction, and the bias -- the
    solver scikit-learn's ``SVC`` runs, on the same problem (with the
    intercept).  The kernel matrix is built once in numpy and held
    whole, n x n doubles (800 MB at n = 10,000): libsvm with every row
    in its cache.  ``kernel`` is "rbf" (``gamma`` "scale", "auto" or a
    number, as in SVC), "linear", or "precomputed" (X is then the
    kernel matrix, and decision_function takes the kernel between new
    points and the training points).

    Attributes after fit: classes_, support_, dual_coef_ (alpha_i y_i
    over the support), intercept_, n_iter_; support_vectors_ unless
    precomputed.
    """

    _binary_only = True
    _pairwise = True

    def __init__(self, C=1.0, kernel="rbf", gamma="scale", tol=1e-3, max_iter=-1):
        self.C, self.kernel, self.gamma = C, kernel, gamma
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        self.classes_, ys = _binary_labels(y)
        n = ys.size
        K = self._train_kernel(X)
        alpha = np.zeros(n)
        rho = np.zeros(1)
        iters = int(self.max_iter) if self.max_iter > 0 else 10_000_000
        self.n_iter_ = _classifier_kernels().svm_smo(
            np.ascontiguousarray(K), ys, alpha, rho, float(self.C), iters, float(self.tol), n)
        self.support_ = np.flatnonzero(alpha > 0)
        self.dual_coef_ = (alpha * ys)[self.support_]
        self.intercept_ = -float(rho[0])
        if self.kernel != "precomputed":
            self.support_vectors_ = X[self.support_]
        return self

    def decision_function(self, X):
        return self._support_kernel(X) @ self.dual_coef_ + self.intercept_

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


class LinearSVR(Tagged, RegressorMixin, BaseEstimator):
    """The linear epsilon-SVR with the L1 loss, by liblinear's own algorithm.

    ``examples/kernel-only/svr-liblinear.scm`` translated plainly:
    liblinear's solve_l2r_l1l2_svr (dual coordinate descent, random
    order, shrinking) -- what scikit-learn's
    ``LinearSVR(loss="epsilon_insensitive", dual=True,
    fit_intercept=False)`` runs, on the same problem

        min_w  1/2 ||w||^2 + C sum_i max(0, |y_i - w.x_i| - epsilon).

    ``epsilon`` defaults to 0, ``tol`` to 1e-4 and ``max_iter`` to 1000
    sweeps, as in LinearSVR; no intercept.

    Attributes after fit: coef_, dual_coef_ (the betas), n_iter_.
    """

    def __init__(self, C=1.0, epsilon=0.0, tol=1e-4, max_iter=1000, random_state=0):
        self.C, self.epsilon = C, epsilon
        self.tol, self.max_iter = tol, max_iter
        self.random_state = random_state

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        w = np.zeros(p)
        beta = np.zeros(n)
        xnorm = np.zeros(n)
        self.n_iter_ = _classifier_kernels().svr_liblinear(
            X, y, w, beta, xnorm, float(self.C), float(self.epsilon), int(self.max_iter),
            float(self.tol), _seed(self.random_state), n, p)
        self.coef_, self.dual_coef_ = w, beta
        self.intercept_ = 0.0
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_


class KernelSVR(Tagged, RegressorMixin, _KernelMatrix, BaseEstimator):
    """epsilon-SVR by libsvm's own algorithm, over the whole kernel matrix.

    The same translated SMO solver as KernelSVM (``svm-smo.scm``), set
    up as libsvm's solve_epsilon_svr sets it up: the 2n variables
    alpha and alpha* with linear terms epsilon -/+ y_i.  scikit-learn's
    ``SVR``, with the intercept; ``epsilon=0.1``, ``tol=1e-3`` and the
    kernels as there.  The kernel matrix is held whole.

    Attributes after fit: support_, dual_coef_ (alpha - alpha* over the
    support), intercept_, n_iter_; support_vectors_ unless precomputed.
    """

    _pairwise = True

    def __init__(self, C=1.0, epsilon=0.1, kernel="rbf", gamma="scale", tol=1e-3, max_iter=-1):
        self.C, self.epsilon, self.kernel, self.gamma = C, epsilon, kernel, gamma
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n = y.size
        K = self._train_kernel(X)
        beta = np.zeros(n)
        rho = np.zeros(1)
        iters = int(self.max_iter) if self.max_iter > 0 else 10_000_000
        self.n_iter_ = _classifier_kernels().svr_smo(
            np.ascontiguousarray(K), y, beta, rho, float(self.C), float(self.epsilon), iters,
            float(self.tol), n)
        self.support_ = np.flatnonzero(beta != 0)
        self.dual_coef_ = beta[self.support_]
        self.intercept_ = -float(rho[0])
        if self.kernel != "precomputed":
            self.support_vectors_ = X[self.support_]
        return self

    def predict(self, X):
        return self._support_kernel(X) @ self.dual_coef_ + self.intercept_


def nmf_backend():
    """The variant CDNMF takes by default: cublas when a device
    answers, else blas, else loops."""
    built = nmf_backends()
    if not built:
        raise ImportError("scm2cpp_learn: no variant of the derived NMF was built")
    if "cublas" in built and cuda_available():
        return "cublas"
    cpu = [v for v in built if v != "cublas"]
    return cpu[0] if cpu else built[0]


class CDNMF(Tagged, TransformerMixin, BaseEstimator):
    """Non-negative matrix factorization by coordinate descent, the
    translator's derivation end to end.

    ``examples/kernel-only/nmf-cd.scm`` writes scikit-learn's
    NMF(solver="cd") iteration the plain way, with the residual
    R = X - W H: each half step sweeps the coordinates of one factor and
    moves R along the other.  ``--derive`` turns that half step into
    scikit-learn's own form -- the memo X H' - W H H' over the hoisted
    Gram H H', with R never formed -- and ``--blas`` / ``--cublas`` hand
    the products to (cu)BLAS.  Nothing of the Gram form is written by
    hand.  The iteration, the stopping rule (the projected-gradient
    violation down to ``tol`` times the first iteration's) and the
    result are scikit-learn's with Frobenius loss, no regularization and
    no shuffling.

    ``init`` is "random" (scikit-learn's: |N(0, 1)| scaled by
    sqrt(mean(X) / k), H drawn before W, from ``random_state``) or
    "custom" (W and H given to fit_transform).  scikit-learn's default
    "nndsvda" is not offered; pass "custom" with its W and H for an
    exact comparison.  ``backend`` is "cublas", "blas" or "loops", or
    None for the best built (``nmf_backend()``).

    ``transform`` solves for W with H fixed by the same coordinate
    descent (scikit-learn's NMF.transform), in numpy.

    Attributes after fit: components_ (H, k x p), n_components_, n_iter_,
    reconstruction_err_ (||X - W H||_F).
    """
    _positive_X = True

    def __init__(self, n_components=None, *, init="random", tol=1e-4, max_iter=200,
                 random_state=None, backend=None):
        self.n_components = n_components
        self.init, self.tol, self.max_iter = init, tol, max_iter
        self.random_state = random_state
        self.backend = backend

    def _lib(self):
        import importlib
        v = self.backend or nmf_backend()
        return importlib.import_module(f"{__name__}._generated._loader_nmf_{v}")

    def fit_transform(self, X, y=None, W=None, H=None):
        X = fit_x(self, X)
        if X.min() < 0:
            raise ValueError("Negative values in data passed to CDNMF (input X)")
        n, p = X.shape
        k = p if self.n_components is None else int(self.n_components)
        if k < 1:
            raise ValueError(f"n_components must be at least 1, got {self.n_components!r}")
        if self.init == "custom":
            if W is None or H is None:
                raise ValueError('init="custom" needs W and H')
            W = np.array(W, dtype=np.float64, copy=True)
            H = np.array(H, dtype=np.float64)
        elif self.init == "random":
            rng = np.random.RandomState(self.random_state)
            avg = np.sqrt(X.mean() / k)
            H = np.abs(avg * rng.standard_normal(size=(k, p)))
            W = np.abs(avg * rng.standard_normal(size=(n, k)))
        else:
            raise ValueError(f"init {self.init!r}: expected 'random' or 'custom'")
        W = np.ascontiguousarray(W)
        HT = np.ascontiguousarray(H.T)
        XT = np.ascontiguousarray(X.T)
        self.n_iter_ = self._lib().nmf(X, XT, W, HT, int(self.max_iter), float(self.tol),
                                       n, p, k)
        self.components_ = np.ascontiguousarray(HT.T)
        self.n_components_ = k
        self.reconstruction_err_ = float(np.linalg.norm(X - W @ self.components_))
        return W

    def fit(self, X, y=None, W=None, H=None):
        self.fit_transform(X, W=W, H=H)
        return self

    def transform(self, X):
        X = pred_x(self, X)
        if X.min() < 0:
            raise ValueError("Negative values in data passed to CDNMF (input X)")
        H = self.components_
        k = H.shape[0]
        HHt = H @ H.T
        XHt = X @ H.T
        avg = np.sqrt(X.mean() / k) if X.size else 0.0
        W = np.full((X.shape[0], k), avg)
        tol = float(self.tol)
        # the half step of the fit on W alone, H fixed; the stop on the
        # projected gradient, measured against the first sweep's, as there
        first = None
        for _ in range(int(self.max_iter)):
            viol = 0.0
            for j in range(k):
                if HHt[j, j] <= 0.0:
                    continue
                grad = W @ HHt[:, j] - XHt[:, j]
                pg = np.where(W[:, j] == 0.0, np.minimum(grad, 0.0), grad)
                viol += float(np.abs(pg).sum())
                W[:, j] = np.maximum(W[:, j] - grad / HHt[j, j], 0.0)
            if first is None:
                first = viol
            if first == 0.0 or viol / first <= tol:
                break
        return W


class CDGraphicalLasso(Tagged, BaseEstimator):
    """The graphical lasso, scikit-learn's own algorithm translated.

    ``examples/kernel-only/graphical-lasso.scm`` is scikit-learn's
    _graphical_lasso in mode "cd" and its inner solver
    enet_coordinate_descent_gram (the gap-safe rule included), written
    out whole; ``--blas`` makes its two matrix-vector products dgemv.
    The same model and stopping rule as ``GraphicalLasso(mode="cd")``:
    ``alpha``, ``tol``, ``enet_tol``, ``max_iter`` and
    ``assume_centered`` mean what they mean there.  scikit-learn's
    ``costs_`` (the objective each iteration, a log-determinant) is not
    computed.

    Attributes after fit: covariance_, precision_, location_, n_iter_.
    """

    def __init__(self, alpha=0.01, *, tol=1e-4, enet_tol=1e-4, max_iter=100,
                 assume_centered=False):
        self.alpha, self.tol, self.enet_tol = alpha, tol, enet_tol
        self.max_iter, self.assume_centered = max_iter, assume_centered

    def fit(self, X, y=None):
        import importlib
        from ._libfind import gramops_backend
        X = fit_x(self, X, ensure_min_samples=2, ensure_min_features=2)
        n, p = X.shape
        self.location_ = np.zeros(p) if self.assume_centered else X.mean(axis=0)
        Xc = X - self.location_
        emp = np.ascontiguousarray(Xc.T @ Xc / n)
        lib = importlib.import_module(f"{__name__}._generated._loader_gramops_{gramops_backend()}")
        self.covariance_ = np.zeros((p, p))
        self.precision_ = np.zeros((p, p))
        self.n_iter_ = lib.graphical_lasso(emp, self.covariance_, self.precision_,
                                           float(self.alpha), int(self.max_iter),
                                           float(self.tol), float(self.enet_tol), p)
        if not np.isfinite(self.precision_).all():
            raise FloatingPointError("the system is too ill-conditioned for this solver")
        return self


class LinearRANSAC(Tagged, RegressorMixin, BaseEstimator):
    """RANSAC for a linear model, scikit-learn's algorithm translated.

    ``examples/kernel-only/ransac.scm`` is RANSACRegressor.fit around
    LinearRegression, written out whole: per trial, least squares with
    an intercept on a subset of ``min_samples`` points, the inliers
    within ``residual_threshold``, the fit kept by inlier count and then
    R^2, the trial count lowered by scikit-learn's _dynamic_max_trials;
    finally least squares on the best inliers.  The defaults are
    RANSACRegressor's (min_samples p + 1, the threshold the MAD of y,
    max_trials 100, stop_probability 0.99).

    The subsets are drawn here, ``max_trials`` of them, before the
    trials run.  With scikit-learn installed they are drawn exactly as
    RANSACRegressor draws them (sample_without_replacement on a
    RandomState of ``random_state``), so the result is scikit-learn's;
    without it, numpy's choice draws different subsets.

    Attributes after fit: coef_, intercept_, inlier_mask_, n_trials_.
    """

    def __init__(self, *, min_samples=None, residual_threshold=None, max_trials=100,
                 stop_probability=0.99, random_state=None):
        self.min_samples, self.residual_threshold = min_samples, residual_threshold
        self.max_trials, self.stop_probability = max_trials, stop_probability
        self.random_state = random_state

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        max_trials = int(self.max_trials)
        ms = p + 1 if self.min_samples is None else int(self.min_samples)
        thr = (float(np.median(np.abs(y - np.median(y)))) if self.residual_threshold is None
               else float(self.residual_threshold))
        rs = np.random.RandomState(self.random_state)
        try:
            from sklearn.utils.random import sample_without_replacement
            draw = lambda: sample_without_replacement(n, ms, random_state=rs)
        except ImportError:
            draw = lambda: rs.choice(n, ms, replace=False)
        if ms > n:
            raise ValueError(f"min_samples may not be larger than the number of samples: "
                             f"n_samples = {n}")
        subsets = np.array([draw() for _ in range(max_trials)], dtype=np.float64)
        coef = np.zeros(p)
        mask = np.zeros(n)
        out = np.zeros(1)
        self.n_trials_ = _classifier_kernels().ransac(
            X, y, subsets, coef, mask, out, max_trials, ms, thr, float(self.stop_probability),
            n, p)
        self.coef_, self.intercept_ = coef, float(out[0])
        self.inlier_mask_ = mask.astype(bool)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


def _center(X, y, fit_intercept):
    X = np.ascontiguousarray(X, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    if fit_intercept:
        xm, ym = X.mean(axis=0), float(y.mean())
        return np.ascontiguousarray(X - xm), y - ym, xm, ym
    return X, y, np.zeros(X.shape[1]), 0.0


_SGD_LOSS = {"hinge": 0, "squared_error": 1, "perceptron": 2, "epsilon_insensitive": 3}
_SGD_LR = {"optimal": 0, "invscaling": 1, "constant": 2, "pa1": 3, "pa2": 4}


class _SGDLinear(BaseEstimator):
    # the shared run; the subclasses' __init__ name the parameters
    # (scikit-learn reads them off the signature), so this one has none
    def _set(self, *, loss, penalty, alpha, max_iter, tol, n_iter_no_change, fit_intercept,
             learning_rate, eta0, power_t, epsilon=0.1):
        self.loss, self.penalty, self.alpha = loss, penalty, alpha
        self.max_iter, self.tol = max_iter, tol
        self.n_iter_no_change, self.fit_intercept = n_iter_no_change, fit_intercept
        self.learning_rate, self.eta0, self.power_t = learning_rate, eta0, power_t
        self.epsilon = epsilon

    def _run(self, X, y):
        loss = getattr(self, "loss", "perceptron")
        lr = getattr(self, "learning_rate", "constant")
        penalty = getattr(self, "penalty", None)
        if loss not in _SGD_LOSS or lr not in _SGD_LR:
            raise ValueError("loss is one of %s, learning_rate one of %s"
                             % (sorted(_SGD_LOSS), sorted(_SGD_LR)))
        if penalty not in ("l2", None):
            raise ValueError("penalty is 'l2' or None")
        n, p = X.shape
        w = np.zeros(p)
        out = np.zeros(1)
        self.n_iter_ = _classifier_kernels().sgd(
            X, np.ascontiguousarray(y, dtype=np.float64), w, out,
            _SGD_LOSS[loss], _SGD_LR[lr],
            1 if penalty == "l2" else 0, float(getattr(self, "alpha", 1e-4)),
            float(self.eta0), float(getattr(self, "power_t", 0.5)),
            float(getattr(self, "epsilon", 0.1)), int(self.max_iter), float(self.tol),
            int(self.n_iter_no_change), 1 if self.fit_intercept else 0, n, p)
        self.coef_, self.intercept_ = w, float(out[0])
        return self

    def _linear(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class SGDLinearClassifier(Tagged, ClassifierMixin, _SGDLinear):
    """scikit-learn's SGDClassifier by its own _plain_sgd translated
    (``examples/kernel-only/sgd.scm``), with shuffle=False: the points
    are visited in order.  scikit-learn's shuffling draws from its own
    xorshift generator, which the kernel does not reproduce, so compare
    against ``SGDClassifier(shuffle=False)``, which this matches to
    rounding.  loss "hinge" or "perceptron", penalty "l2" or None,
    learning_rate "optimal", "constant", "invscaling", "pa1" or "pa2"
    (the passive-aggressive steps, eta0 their C: scikit-learn's
    replacement for PassiveAggressiveClassifier).  Two classes, the
    second of ``classes_`` positive.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    def __init__(self, *, loss="hinge", penalty="l2", alpha=1e-4, max_iter=1000, tol=1e-3,
                 n_iter_no_change=5, fit_intercept=True, learning_rate="optimal",
                 eta0=0.01, power_t=0.5):
        self._set(loss=loss, penalty=penalty, alpha=alpha, max_iter=max_iter,
                  tol=tol, n_iter_no_change=n_iter_no_change,
                  fit_intercept=fit_intercept, learning_rate=learning_rate,
                  eta0=eta0, power_t=power_t)
        del self.epsilon

    _binary_only = True

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        self.classes_, ys = _binary_labels(y)
        return self._run(X, ys)

    def decision_function(self, X):
        return self._linear(X)

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


class SGDLinearRegressor(Tagged, RegressorMixin, _SGDLinear):
    """scikit-learn's SGDRegressor by its own _plain_sgd translated, with
    shuffle=False (see SGDLinearClassifier).  loss "squared_error" or
    "epsilon_insensitive" (``epsilon``), penalty "l2" or None,
    learning_rate "invscaling" (the default), "constant", "optimal",
    "pa1" or "pa2" (scikit-learn's replacement for
    PassiveAggressiveRegressor).

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, loss="squared_error", penalty="l2", alpha=1e-4, max_iter=1000,
                 tol=1e-3, n_iter_no_change=5, fit_intercept=True,
                 learning_rate="invscaling", eta0=0.01, power_t=0.25, epsilon=0.1):
        self._set(loss=loss, penalty=penalty, alpha=alpha, max_iter=max_iter,
                  tol=tol, n_iter_no_change=n_iter_no_change,
                  fit_intercept=fit_intercept, learning_rate=learning_rate,
                  eta0=eta0, power_t=power_t, epsilon=epsilon)

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        return self._run(X, y)

    def predict(self, X):
        return self._linear(X)


class SGDPerceptron(SGDLinearClassifier):
    """scikit-learn's Perceptron: SGDClassifier with the perceptron's
    hinge (threshold 0), no penalty and the constant step eta0 = 1, by
    the same translated _plain_sgd, shuffle=False.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    # the loss, penalty and step rule are fixed, not parameters: _run
    # falls back to the perceptron's when the attributes are absent
    def __init__(self, *, max_iter=1000, tol=1e-3, n_iter_no_change=5, fit_intercept=True,
                 eta0=1.0):
        self.max_iter, self.tol, self.n_iter_no_change = max_iter, tol, n_iter_no_change
        self.fit_intercept, self.eta0 = fit_intercept, eta0


class GramOMP(Tagged, RegressorMixin, BaseEstimator):
    """Orthogonal matching pursuit over the Gram matrix, scikit-learn's
    own algorithm translated (``examples/kernel-only/omp.scm``:
    orthogonal_mp_gram and _gram_omp, X'X and X'y by dsyrk and dgemv).
    ``OrthogonalMatchingPursuit`` takes this route for n > p
    (precompute="auto"); here it is taken always.  ``n_nonzero_coefs``
    defaults, as there, to 10% of the features.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, n_nonzero_coefs=None, fit_intercept=True):
        self.n_nonzero_coefs, self.fit_intercept = n_nonzero_coefs, fit_intercept

    def fit(self, X, y):
        import importlib
        from ._libfind import gramops_backend
        X, y = fit_xy(self, X, y)
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        k = max(int(0.1 * p), 1) if self.n_nonzero_coefs is None else int(self.n_nonzero_coefs)
        lib = importlib.import_module(f"{__name__}._generated._loader_gramops_{gramops_backend()}")
        self.coef_ = np.zeros(p)
        self.n_iter_ = lib.omp(Xc, yc, self.coef_, np.zeros(1), 0, k, n, p)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


_GRAMOPS = []


def _gramops_kernels():
    # looked up once: several calls a fit, each a glob before
    if not _GRAMOPS:
        import importlib
        from ._libfind import gramops_backend
        _GRAMOPS.append(importlib.import_module(
            f"{__name__}._generated._loader_gramops_{gramops_backend()}"))
    return _GRAMOPS[0]


class LBFGSLogisticRegression(Tagged, ClassifierMixin, BaseEstimator):
    """L2-penalised logistic regression, scikit-learn's
    ``LogisticRegression(solver="lbfgs")`` translated whole
    (``examples/kernel-only/logistic-lbfgs.scm`` over ``lbfgs.scm``):
    the mean binomial loss for two classes, the multinomial for more,
    plus |W|^2 / (2 C n), minimised by scipy's L-BFGS-B as written in
    the subset (ten pairs, the More-Thuente search, gtol ``tol``, ftol
    64 eps).  The products X W' and R' X are dgemm where a CBLAS links.
    On the same data it takes the same iterations as scikit-learn and
    lands on the same coefficients to rounding.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    def __init__(self, *, C=1.0, tol=1e-4, max_iter=100, fit_intercept=True):
        self.C, self.tol, self.max_iter, self.fit_intercept = C, tol, max_iter, fit_intercept

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        self.classes_, yi = classes_of(y)
        n, p = X.shape
        nc = len(self.classes_)
        if nc < 2:
            raise ValueError("This solver needs samples of at least 2 classes in the data, "
                             f"but the data contains only one class: {self.classes_[0]!r}")
        multi = 1 if nc > 2 else 0
        k = nc if multi else 1
        coef = np.zeros(k * (p + 1))
        out = np.zeros(2)
        it = _gpu_or_cpu(n * p, getattr(self, "backend", None)).logistic_lbfgs(
            X, yi.astype(np.float64), coef, out, float(self.C), int(self.max_iter),
            float(self.tol), multi, 1 if self.fit_intercept else 0, n, p, k)
        self.coef_ = coef[:k * p].reshape(k, p).copy()
        self.intercept_ = coef[k * p:].copy()
        self.n_iter_ = np.array([min(it, self.max_iter)])
        return self

    def decision_function(self, X):
        z = pred_x(self, X) @ self.coef_.T + self.intercept_
        return z[:, 0] if z.shape[1] == 1 else z

    def predict_proba(self, X):
        z = self.decision_function(X)
        if z.ndim == 1:
            p1 = 1.0 / (1.0 + np.exp(-z))
            return np.column_stack([1.0 - p1, p1])
        e = np.exp(z - z.max(axis=1, keepdims=True))
        return e / e.sum(axis=1, keepdims=True)

    def predict(self, X):
        z = self.decision_function(X)
        if z.ndim == 1:
            return self.classes_[(z > 0).astype(int)]
        return self.classes_[np.argmax(z, axis=1)]


def _kfold(n, k):
    """scikit-learn's KFold(k) without shuffling: contiguous test blocks,
    the first n % k of them one longer."""
    sizes = np.full(k, n // k)
    sizes[: n % k] += 1
    out, start = [], 0
    for sz in sizes:
        test = np.arange(start, start + sz)
        out.append((np.r_[np.arange(0, start), np.arange(start + sz, n)], test))
        start += sz
    return out


def _stratified_kfold(y, k):
    """scikit-learn's StratifiedKFold(k) without shuffling: classes in
    order of first appearance, each spread over the folds as the sorted
    labels dealt k ways."""
    y = np.asarray(y)
    _, y_idx, y_inv = np.unique(y, return_index=True, return_inverse=True)
    _, class_perm = np.unique(y_idx, return_inverse=True)
    y_enc = class_perm[y_inv]
    nc = len(y_idx)
    y_order = np.sort(y_enc)
    alloc = np.asarray([np.bincount(y_order[i::k], minlength=nc) for i in range(k)])
    test_folds = np.empty(len(y), dtype=int)
    for c in range(nc):
        test_folds[y_enc == c] = np.arange(k).repeat(alloc[:, c])
    return [(np.flatnonzero(test_folds != f), np.flatnonzero(test_folds == f))
            for f in range(k)]


class _LBFGSGLM(Tagged, RegressorMixin, BaseEstimator):
    _family = None

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        fam, _ = self._family_power()
        if fam in (0, 2) and (y < 0).any() or fam == 1 and (y <= 0).any():
            raise ValueError(f"Some value(s) of y are out of the valid range of the loss "
                             f"{type(self).__name__}")
        coef = np.zeros(p + 1)
        out = np.zeros(2)
        fam, power = self._family_power()
        it = _gpu_or_cpu(n * p, getattr(self, "backend", None)).glm(X, y, coef, out, fam, float(power), float(self.alpha),
                                    int(self.max_iter), float(self.tol),
                                    1 if self.fit_intercept else 0, n, p)
        self.coef_, self.intercept_ = coef[:p].copy(), float(coef[p])
        self.n_iter_ = min(it, self.max_iter)
        return self

    def _linear(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_

    def predict(self, X):
        z = self._linear(X)
        return z if self._family_power() == (3, 0.0) else np.exp(z)


class LBFGSPoissonRegressor(_LBFGSGLM):
    _positive_y = True

    """scikit-learn's ``PoissonRegressor`` (solver "lbfgs") translated
    whole (``examples/kernel-only/glm.scm`` over ``lbfgs.scm``): the mean
    half Poisson deviance with the log link plus alpha |w|^2 / 2, from
    scikit-learn's start.  Same iterations and coefficients to rounding.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, alpha=1.0, fit_intercept=True, max_iter=100, tol=1e-4):
        self.alpha, self.fit_intercept, self.max_iter, self.tol = alpha, fit_intercept, max_iter, tol

    def _family_power(self):
        return 0, 1.0


class LBFGSGammaRegressor(LBFGSPoissonRegressor):
    """scikit-learn's ``GammaRegressor`` (solver "lbfgs"), as
    LBFGSPoissonRegressor with the half Gamma deviance.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def _family_power(self):
        return 1, 2.0


class LBFGSTweedieRegressor(_LBFGSGLM):
    """scikit-learn's ``TweedieRegressor`` (solver "lbfgs"): ``power`` 0
    with the identity link (the default), or a power of 1 or more with
    the log link, as link="auto" chooses.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, power=0.0, alpha=1.0, fit_intercept=True, max_iter=100, tol=1e-4):
        self.power, self.alpha, self.fit_intercept = power, alpha, fit_intercept
        self.max_iter, self.tol = max_iter, tol

    def _family_power(self):
        if self.power == 0:
            return 3, 0.0
        if self.power < 1:
            raise ValueError("power is 0 or at least 1 here")
        return 2, float(self.power)


class LBFGSLogisticRegressionCV(Tagged, ClassifierMixin, BaseEstimator):
    """scikit-learn's ``LogisticRegressionCV`` with its defaults (the L2
    penalty, solver "lbfgs", Cs 10 values from 1e-4 to 1e4,
    StratifiedKFold(5) without shuffling, accuracy, refit): each fold's
    path over the Cs warm-started from the previous C by the translated
    LogisticRegression (``logistic-lbfgs.scm``), the C of the best summed
    score, and the refit from the folds' mean coefficients at that C, as
    scikit-learn starts it.

    Attributes after fit: classes_, Cs_, C_, coef_, intercept_, scores_,
    n_iter_.
    """

    def __init__(self, *, Cs=10, cv=5, tol=1e-4, max_iter=100, fit_intercept=True):
        self.Cs, self.cv, self.tol, self.max_iter = Cs, cv, tol, max_iter
        self.fit_intercept = fit_intercept

    def _path(self, X, yi, Cs, coef, multi, k):
        n, p = X.shape
        lib = _gpu_or_cpu(n * p, getattr(self, "backend", None))
        coefs, iters = [], []
        out = np.zeros(2)
        for C in Cs:
            it = lib.logistic_lbfgs(X, yi, coef, out, float(C), int(self.max_iter),
                                    float(self.tol), multi, 1 if self.fit_intercept else 0,
                                    n, p, k)
            coefs.append(coef.copy())
            iters.append(min(it, self.max_iter))
        return coefs, iters

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        self.classes_, yi = classes_of(y)
        nc = len(self.classes_)
        if nc < 2:
            raise ValueError("This solver needs samples of at least 2 classes in the data, "
                             f"but the data contains only one class: {self.classes_[0]!r}")
        multi = 1 if nc > 2 else 0
        k = nc if multi else 1
        n, p = X.shape
        Cs = (np.logspace(-4, 4, int(self.Cs)) if np.isscalar(self.Cs)
              else np.asarray(self.Cs, float))
        self.Cs_ = Cs
        yf = yi.astype(np.float64)
        folds = _stratified_kfold(y, int(self.cv))
        paths, scores, iters = [], [], []
        for train, test in folds:
            coefs, it = self._path(np.ascontiguousarray(X[train]), yf[train], Cs,
                                   np.zeros(k * (p + 1)), multi, k)
            paths.append(coefs)
            iters.append(it)
            sc = []
            for c in coefs:
                z = X[test] @ c[:k * p].reshape(k, p).T + c[k * p:]
                pred = (z[:, 0] > 0).astype(int) if k == 1 else np.argmax(z, axis=1)
                sc.append(float(np.mean(pred == yi[test])))
            scores.append(sc)
        scores = np.asarray(scores)
        best = int(np.argmax(scores.sum(axis=0)))
        self.C_ = float(Cs[best])
        start = np.mean([paths[f][best] for f in range(len(folds))], axis=0)
        coefs, it = self._path(X, yf, [self.C_], start.copy(), multi, k)
        c = coefs[0]
        self.coef_ = c[:k * p].reshape(k, p).copy()
        self.intercept_ = c[k * p:].copy()
        self.scores_ = scores
        self.n_iter_ = np.asarray(iters)
        return self

    def decision_function(self, X):
        z = pred_x(self, X) @ self.coef_.T + self.intercept_
        return z[:, 0] if z.shape[1] == 1 else z

    def predict(self, X):
        z = self.decision_function(X)
        if z.ndim == 1:
            return self.classes_[(z > 0).astype(int)]
        return self.classes_[np.argmax(z, axis=1)]


class LBFGSHuberRegressor(Tagged, RegressorMixin, BaseEstimator):
    """The Huber regressor, scikit-learn's ``HuberRegressor`` translated
    whole (``examples/kernel-only/huber.scm`` over ``lbfgs.scm``): its
    _huber_loss_and_gradient over the weights, the intercept and the
    scale, minimised by L-BFGS-B with the scale bounded below by 10 eps
    (the generalized Cauchy point and the subspace step for that one
    bound, as L-BFGS-B takes them), scipy's defaults otherwise.  X w
    and X'c are dgemv where a CBLAS links.  Same iterations and
    coefficients as scikit-learn to rounding.

    Attributes after fit: coef_, intercept_, scale_, n_iter_, outliers_.
    """

    def __init__(self, *, epsilon=1.35, alpha=1e-4, max_iter=100, tol=1e-5,
                 fit_intercept=True):
        self.epsilon, self.alpha, self.max_iter, self.tol = epsilon, alpha, max_iter, tol
        self.fit_intercept = fit_intercept

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        coef = np.zeros(p + 2)
        coef[-1] = 1.0
        out = np.zeros(2)
        it = _gpu_or_cpu(n * p, getattr(self, "backend", None)).huber(
            X, y, coef, out, float(self.epsilon), float(self.alpha), int(self.max_iter),
            float(self.tol), 1 if self.fit_intercept else 0, n, p)
        self.coef_ = coef[:p].copy()
        self.intercept_ = float(coef[p])
        self.scale_ = float(coef[p + 1])
        self.n_iter_ = min(it, self.max_iter)
        self.outliers_ = np.abs(y - X @ self.coef_ - self.intercept_) > self.scale_ * self.epsilon
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class EMGaussianMixture(Tagged, DensityMixin, BaseEstimator):
    """The Gaussian mixture by EM with full covariances, scikit-learn's
    ``GaussianMixture(covariance_type="full")`` translated whole
    (``examples/kernel-only/gmm.scm``): its M step (means and
    covariances by products, the Cholesky factor, the precision factor
    L^-T), its E step (the log densities through X U - mu U, a product;
    log-sum-exp; the lower bound) and its stop on the bound.  The start
    is scikit-learn's: ``init_params="kmeans"`` takes the labels of
    ``KMeans(n_init=1)`` (scikit-learn's, so it must be installed) drawn
    from ``RandomState(random_state)``, ``"random"`` uniform draws
    normalised; with the same ``random_state`` the fit is
    scikit-learn's to rounding.  One initialisation (n_init=1).

    Attributes after fit: weights_, means_, precisions_cholesky_,
    precisions_, covariances_, converged_, n_iter_, lower_bound_.
    """

    def __init__(self, n_components=1, *, tol=1e-3, reg_covar=1e-6, max_iter=100,
                 init_params="kmeans", random_state=None):
        self.n_components, self.tol, self.reg_covar = n_components, tol, reg_covar
        self.max_iter, self.init_params, self.random_state = max_iter, init_params, random_state

    def fit(self, X, y=None):
        X = fit_x(self, X, ensure_min_samples=2)
        n, p = X.shape
        k = int(self.n_components)
        if k > n:
            raise ValueError(f"Expected n_samples >= n_components but got n_components = {k}, "
                             f"n_samples = {n}")
        rs = np.random.RandomState(self.random_state)
        if self.init_params == "kmeans":
            try:
                from sklearn.cluster import KMeans
            except ImportError as e:
                raise ImportError("init_params='kmeans' runs scikit-learn's KMeans; "
                                  "install scikit-learn or pass init_params='random'") from e
            labels = KMeans(n_clusters=k, n_init=1, random_state=rs).fit(X).labels_
            resp = np.zeros((n, k))
            resp[np.arange(n), labels] = 1.0
        elif self.init_params == "random":
            resp = rs.uniform(size=(n, k))
            resp /= resp.sum(axis=1)[:, None]
        else:
            raise ValueError("init_params is 'kmeans' or 'random'")
        resp = np.ascontiguousarray(resp)
        self.weights_ = np.zeros(k)
        self.means_ = np.zeros((k, p))
        self.precisions_cholesky_ = np.zeros((k, p, p))
        labels = np.zeros(n)
        out = np.zeros(2)
        it = _gpu_or_cpu(n * p, getattr(self, "backend", None)).gmm(X, resp, self.weights_, self.means_,
                                    self.precisions_cholesky_, labels, out,
                                    int(self.max_iter), float(self.tol),
                                    float(self.reg_covar), n, p, k)
        self.n_iter_ = it
        self.lower_bound_ = float(out[0])
        self.converged_ = bool(out[1] == 1.0)
        self.precisions_ = np.einsum("kij,klj->kil", self.precisions_cholesky_,
                                     self.precisions_cholesky_)
        self.covariances_ = np.linalg.inv(self.precisions_)
        return self

    def _weighted_log_prob(self, X):
        X = pred_x(self, X)
        n, p = X.shape
        out = np.empty((n, len(self.weights_)))
        for c, (mu, u) in enumerate(zip(self.means_, self.precisions_cholesky_)):
            y = X @ u - mu @ u
            out[:, c] = (-0.5 * (p * np.log(2 * np.pi) + (y * y).sum(axis=1))
                         + np.log(np.diag(u)).sum() + np.log(self.weights_[c]))
        return out

    def predict_proba(self, X):
        w = self._weighted_log_prob(X)
        w -= w.max(axis=1, keepdims=True)
        e = np.exp(w)
        return e / e.sum(axis=1, keepdims=True)

    def predict(self, X):
        return np.argmax(self._weighted_log_prob(X), axis=1)

    def fit_predict(self, X, y=None):
        return self.fit(X).predict(X)

    def score_samples(self, X):
        """The log density of each row under the mixture."""
        w = self._weighted_log_prob(X)
        m = w.max(axis=1)
        return m + np.log(np.exp(w - m[:, None]).sum(axis=1))

    def score(self, X, y=None):
        """The mean log-likelihood, as GaussianMixture.score."""
        return float(self.score_samples(X).mean())


class CovPCA(Tagged, TransformerMixin, BaseEstimator):
    """PCA through the covariance's eigenvectors, scikit-learn's
    ``PCA(svd_solver="covariance_eigh")`` -- what its "auto" picks for a
    tall design (p <= 1000, n >= 10 p) -- translated whole
    (``examples/kernel-only/pca.scm``: X'X by dsyrk where a CBLAS links,
    the eigenproblem by sym-eigen.scm -- which the BLAS build hands to
    LAPACK's dsyevd, as numpy's eigh does, and the loop build runs as
    Householder reduction and QL iteration in the subset -- and
    svd_flip's signs).  The BLAS build is level with scikit-learn on one
    core at 50,000 x 500 and with sklearnex on twenty; the loop build's
    eigensolver falls behind LAPACK's from about a hundred features.

    Attributes after fit: components_, explained_variance_,
    explained_variance_ratio_, singular_values_, mean_, noise_variance_,
    n_components_.
    """

    def __init__(self, n_components=None, *, backend=None):
        self.n_components, self.backend = n_components, backend

    def fit(self, X, y=None):
        X = fit_x(self, X)
        n, p = X.shape
        if self.n_components is not None and not 0 <= int(self.n_components) <= min(n, p):
            raise ValueError(f"n_components={self.n_components!r} must be between 0 and "
                             f"min(n_samples, n_features)={min(n, p)}")
        comps = np.zeros((p, p)); ev = np.zeros(p); sv = np.zeros(p); mean = np.zeros(p)
        # the device forms the covariance faster, but its build keeps
        # sym-eigen.scm's eigensolver; where the CPU build has LAPACK's
        # (gramops "blas") that is the faster whole, so the device is
        # taken by default only without it
        from ._libfind import gramops_backend
        dev = self.backend == "cublas" or (self.backend is None and gramops_backend() != "blas")
        lib = _accel(float(n) * p * p) if dev else None
        (lib or _gramops_kernels()).pca(X, comps, ev, sv, mean, n, p)
        k = min(n, p) if self.n_components is None else int(self.n_components)
        self.n_components_ = k
        self.mean_ = mean
        self.components_ = comps[:k].copy()
        self.explained_variance_ = ev[:k].copy()
        tot = ev.sum()
        self.explained_variance_ratio_ = ev[:k] / tot if tot > 0 else np.zeros(k)
        self.singular_values_ = sv[:k].copy()
        self.noise_variance_ = float(ev[k:].mean()) if k < min(n, p) else 0.0
        return self

    def transform(self, X):
        return (pred_x(self, X) - self.mean_) @ self.components_.T

    def fit_transform(self, X, y=None):
        return self.fit(X).transform(X)


_KPCA_KERNELS = {"linear": 0, "rbf": 1, "poly": 2, "sigmoid": 3, "cosine": 4}


def _psd_eigenvalues(vals):
    # scikit-learn's _check_psd_eigenvalues (double precision): refuse
    # a matrix far from PSD, zero the small negative and positive noise
    vals = np.array(vals, dtype=np.float64)
    top = vals.max() if vals.size else 0.0
    if top < 0:
        raise ValueError(f"All eigenvalues are negative (maximum is {top:g}). Either the "
                         "matrix is not PSD, or there was an issue while computing the "
                         "eigendecomposition of the matrix.")
    low = vals.min() if vals.size else 0.0
    if low < -1e-5 * top and low < -1e-10:
        raise ValueError(f"There are significant negative eigenvalues ({-low / top:g} of the "
                         "maximum positive). Either the matrix is not PSD, or there was an "
                         "issue while computing the eigendecomposition of the matrix.")
    vals[vals < 0] = 0.0
    vals[vals < 1e-12 * top] = 0.0
    return vals


class GramKernelPCA(Tagged, TransformerMixin, BaseEstimator):
    """scikit-learn's ``KernelPCA``: the kernel matrix (linear, rbf,
    poly, sigmoid, cosine or precomputed), centred in feature space, its
    largest eigenpairs with svd_flip's signs (``examples/kernel-only/
    kernel-pca.scm``).  Three routes to the eigenpairs:

    - the linear kernel with n_components <= p < n: through Xc'Xc
      (p x p, X'X by dsyrk), O(n p^2) instead of the n x n matrix;
    - a few pairs of a large matrix (``eigen_solver="auto"``, where
      scikit-learn takes ARPACK, and ``"subspace"``): subspace iteration
      whose product is a dgemm, stopped when every residual
      |K u - lam u| is under ``tol`` (1e-12 for 0) of the largest value,
      the dense route when it does not converge in ``max_iter`` steps;
    - otherwise dense: LAPACK's dsyevr over the wanted index range, as
      scipy's eigh(subset_by_index) that scikit-learn calls.

    No inverse transform.  Attributes after fit: eigenvalues_,
    eigenvectors_, X_fit_, gamma_, n_iter_ (the subspace steps, 1 for a
    direct solve), n_features_in_.
    """

    def __init__(self, n_components=None, *, kernel="linear", gamma=None, degree=3, coef0=1,
                 eigen_solver="auto", tol=0, max_iter=None, remove_zero_eig=False,
                 random_state=None):
        self.n_components, self.kernel, self.gamma = n_components, kernel, gamma
        self.degree, self.coef0, self.eigen_solver = degree, coef0, eigen_solver
        self.tol, self.max_iter, self.remove_zero_eig = tol, max_iter, remove_zero_eig
        self.random_state = random_state

    def _kernel(self, A, B):
        k = _gramops_kernels()
        if B is None:
            K = np.zeros((A.shape[0], A.shape[0]))
            k.kpca_kernel_self(A, K, self._kind, self.gamma_, float(self.degree),
                               float(self.coef0), A.shape[0], A.shape[1])
        else:
            K = np.zeros((A.shape[0], B.shape[0]))
            k.kpca_kernel(A, B, K, self._kind, self.gamma_, float(self.degree),
                          float(self.coef0), A.shape[0], B.shape[0], A.shape[1])
        return K

    def fit(self, X, y=None):
        X = fit_x(self, X)
        n, p = X.shape
        if self.kernel != "precomputed" and self.kernel not in _KPCA_KERNELS:
            raise ValueError(f"kernel={self.kernel!r}: expected one of "
                             f"{sorted(_KPCA_KERNELS) + ['precomputed']}")
        if self.eigen_solver not in ("auto", "dense", "subspace"):
            raise ValueError(f"eigen_solver={self.eigen_solver!r}: expected 'auto', 'dense' "
                             "or 'subspace'")
        if self.n_components is not None and int(self.n_components) < 1:
            raise ValueError(f"n_components={self.n_components!r} must be at least 1")
        if self.kernel == "precomputed" and n != p:
            raise ValueError(f"precomputed kernel is {n} x {p}; expected a square matrix")
        self._kind = _KPCA_KERNELS.get(self.kernel, -1)
        self.gamma_ = 1.0 / p if self.gamma is None else float(self.gamma)
        c = n if self.n_components is None else min(n, int(self.n_components))
        k = _gramops_kernels()
        vecs, vals = np.zeros((n, c)), np.zeros(c)
        m = np.zeros(n + 1)
        self.n_iter_ = 1
        if self.kernel == "linear" and c <= p < n:
            xm = X.mean(axis=0)
            G = _gram(X)
            nm2 = n * xm * xm
            if np.all(np.diagonal(G) - nm2 > 1e-4 * nm2):
                G -= np.outer(xm, n * xm)
                Xs, xs = X, xm
            else:
                Xs, xs = np.ascontiguousarray(X - xm), np.zeros(p)
                G = _gram(Xs)
            k.kpca_linear(Xs, xs, np.ascontiguousarray(G), vecs, vals, n, p, c)
            # KernelCenterer's statistics of K = X X', for transform
            m[:n] = X @ xm
            m[n] = float(xm @ xm)
        else:
            K = np.array(X, dtype=np.float64, order="C") if self.kernel == "precomputed" \
                else self._kernel(X, None)
            k.kpca_centre(K, m, n)
            # c + 25 columns: on an rbf kernel whose leading values fall
            # slowly (0.92 of the first by the fifth), 13 took 235 steps
            # to 1e-12 and 30 took 15
            b = min(n, max(2 * c, c + 25))
            # where scikit-learn's "auto" takes ARPACK; for 50 components
            # of 3,000 the 100 columns lost to dsyevr (6.2 s to 3.6 s)
            sub = self.eigen_solver == "subspace" or (
                self.eigen_solver == "auto" and n > 200 and c < 10)
            done = False
            if sub and b < n:
                rs = self.random_state
                rng = rs if isinstance(rs, np.random.RandomState) else \
                    np.random.RandomState(0 if rs is None else int(rs))
                Q = rng.standard_normal((n, b))
                tol = float(self.tol) if float(self.tol) > 0 else 1e-12
                it = 1000 if self.max_iter is None else int(self.max_iter)
                steps = k.kpca_top_subspace(K, Q, vecs, vals, n, b, c, tol, it)
                done = steps >= 0
                if done:
                    self.n_iter_ = steps
            if not done:
                k.kpca_top_dense(K, vecs, vals, n, c)
        vals = _psd_eigenvalues(vals)
        if self.remove_zero_eig or self.n_components is None:
            keep = vals > 0
            vecs, vals = vecs[:, keep], vals[keep]
        self.eigenvalues_ = vals
        self.eigenvectors_ = np.ascontiguousarray(vecs)
        self.X_fit_ = X
        self._m = m
        return self

    def fit_transform(self, X, y=None):
        self.fit(X)
        return self.eigenvectors_ * np.sqrt(self.eigenvalues_)

    def transform(self, X):
        X = pred_x(self, X)
        n = self.X_fit_.shape[0]
        if self.kernel == "precomputed":
            if X.shape[1] != n:
                raise ValueError(f"precomputed kernel has {X.shape[1]} columns; expected {n}")
            K = np.array(X, dtype=np.float64, order="C")
        else:
            K = self._kernel(X, self.X_fit_)
        _gramops_kernels().kpca_centre_new(K, self._m, K.shape[0], n)
        nz = self.eigenvalues_ > 0
        scaled = np.zeros_like(self.eigenvectors_)
        scaled[:, nz] = self.eigenvectors_[:, nz] / np.sqrt(self.eigenvalues_[nz])
        return K @ scaled


def _lda_svd_dof(n, K):
    # the divisor of LinearDiscriminantAnalysis's svd solver: n from
    # scikit-learn 1.9.1, n - K before; n without scikit-learn
    try:
        import sklearn
        v = tuple(int(x) for x in sklearn.__version__.split(".")[:3] if x.isdigit())
    except Exception:
        return n
    return n - K if v < (1, 9, 1) else n


class GramLDA(Tagged, ClassifierMixin, TransformerMixin, BaseEstimator):
    """scikit-learn's ``LinearDiscriminantAnalysis`` over the Gram matrix
    (``examples/kernel-only/lda.scm``): X'X by dsyrk and the class means
    in one pass, then the three solvers' own steps on p x p matrices --
    ``"svd"`` (the default) takes its first SVD, of the n x p
    standardised within-class design, as the eigenproblem of
    D^-1 Sw D^-1 (dsyevd); ``"lsqr"`` solves Sw W = M' by Cholesky;
    ``"eigen"`` is Sb v = lam Sw v (dsygvd).  ``shrinkage`` takes None or a
    float (not "auto"); no ``covariance_estimator``.

    Attributes after fit: classes_, coef_, intercept_, means_, priors_,
    covariance_ (lsqr, eigen, or store_covariance), scalings_ and
    explained_variance_ratio_ (svd, eigen), xbar_ (svd), n_features_in_.
    """

    def __init__(self, solver="svd", shrinkage=None, priors=None, n_components=None,
                 store_covariance=False, tol=1e-4):
        self.solver, self.shrinkage, self.priors = solver, shrinkage, priors
        self.n_components, self.store_covariance, self.tol = n_components, store_covariance, tol

    @staticmethod
    def _shrunk(C, s):
        # shrunk_covariance: (1 - s) C + s tr(C) / p I
        if s is None:
            return C
        p = C.shape[0]
        out = (1.0 - s) * C
        out.flat[::p + 1] += s * np.trace(C) / p
        return out

    def fit(self, X, y):
        if self.solver not in ("svd", "lsqr", "eigen"):
            raise ValueError(f"solver={self.solver!r}: expected 'svd', 'lsqr' or 'eigen'")
        s = self.shrinkage
        if s is not None and (isinstance(s, str) or not 0.0 <= float(s) <= 1.0):
            raise ValueError(f"shrinkage={s!r}: GramLDA takes None or a float in [0, 1]")
        if self.solver == "svd" and s is not None:
            raise NotImplementedError("shrinkage not supported with 'svd' solver.")
        s = None if s is None else float(s)
        X, y = fit_xy(self, X, y, classifier=True)
        n, p = X.shape
        if n < 2:
            raise ValueError(f"Found array with {n} sample(s) (shape={X.shape}) while a "
                             "minimum of 2 is required.")
        self.classes_, yi = classes_of(y)
        K = len(self.classes_)
        if n == K:
            raise ValueError("The number of samples must be more than the number of classes.")
        if K < 2:
            raise ValueError("The number of classes has to be greater than one; got 1 class")
        k = _gramops_kernels()
        lab = np.ascontiguousarray(yi, dtype=np.int32)
        G, means, counts = np.zeros((p, p)), np.zeros((K, p)), np.zeros(K)
        k.lda_moments(X, lab, G, means, counts, n, p, K)
        if self.priors is None:
            priors = counts / n
        else:
            priors = np.asarray(self.priors, dtype=np.float64)
            if np.any(priors < 0):
                raise ValueError("priors must be non-negative")
            if abs(priors.sum() - 1.0) > 1e-5:
                warnings.warn("The priors do not sum to 1. Renormalizing", UserWarning)
                priors = priors / priors.sum()
        self.priors_, self.means_ = priors, means
        top = min(K - 1, p)
        if self.n_components is not None and int(self.n_components) > top:
            raise ValueError("n_components cannot be larger than min(n_features, n_classes - 1).")
        self._max_components = top if self.n_components is None else int(self.n_components)
        xx = np.diagonal(G).copy()
        k.lda_within(G, means, counts, n, p, K)      # G is now Sw, empirical priors
        if not np.all(np.diagonal(G) > 1e-8 * xx / n):
            # a column whose class means dwarf its spread: the correction
            # cancelled its digits, so take the centred rows instead
            Xc = np.ascontiguousarray(X - means[yi])
            G = _gram(Xc) / n
        Sw_emp = G

        def class_cov():
            # scikit-learn's _class_cov: sum_k prior_k (shrunk) C_k; with
            # the empirical priors that is the shrunk Sw, else per class
            if self.priors is None or np.allclose(priors, counts / n):
                return self._shrunk(Sw_emp, s)
            C = np.zeros((p, p))
            for c in range(K):
                Xk = np.ascontiguousarray(X[yi == c] - means[c])
                C += priors[c] * self._shrunk(_gram(Xk) / max(Xk.shape[0], 1), s)
            return C

        if self.solver == "svd":
            if self.store_covariance:
                self.covariance_ = class_cov()
            self.xbar_ = priors @ means
            std, V, S = np.zeros(p), np.zeros((p, p)), np.zeros(p)
            k.lda_svd_first(np.ascontiguousarray(Sw_emp), std, V, S, p)
            # S is the SVD of Xc D^-1 / sqrt(n); scikit-learn before 1.9.1
            # divides by sqrt(n - K) instead (#33626), and its tol and
            # scalings_ see that scale
            S *= np.sqrt(n / _lda_svd_dof(n, K))
            rank = int(np.sum(S > self.tol))
            scal = (V[:, :rank] / std[:, None]) / S[:rank]
            fac = 1.0 if K == 1 else 1.0 / (K - 1)
            Z = (np.sqrt(n * priors * fac) * (means - self.xbar_).T).T @ scal
            _, S2, Vt2 = np.linalg.svd(Z, full_matrices=False)
            self.explained_variance_ratio_ = (S2 ** 2 / np.sum(S2 ** 2))[:self._max_components] \
                if self._max_components else np.empty((0,))
            rank2 = int(np.sum(S2 > self.tol * S2[0]))
            self.scalings_ = scal @ Vt2.T[:, :rank2]
            coef = (means - self.xbar_) @ self.scalings_
            self.intercept_ = -0.5 * np.sum(coef ** 2, axis=1) + np.log(priors)
            self.coef_ = coef @ self.scalings_.T
            self.intercept_ -= self.xbar_ @ self.coef_.T
        else:
            Sw = class_cov()
            self.covariance_ = Sw
            if self.solver == "lsqr":
                coef = _ridge_solve(Sw, np.ascontiguousarray(means.T), 0.0)
                if coef is None:
                    coef = np.linalg.lstsq(Sw, means.T, rcond=None)[0]
                self.coef_ = coef.T
                self.intercept_ = -0.5 * np.diag(means @ self.coef_.T) + np.log(priors)
            else:
                xbar = counts @ means / n
                St = self._shrunk(Sw_emp + (means - xbar).T @ ((counts / n)[:, None] * (means - xbar)), s)
                V, ev = np.zeros((p, p)), np.zeros(p)
                k.lda_eigen(np.ascontiguousarray(St - Sw), np.ascontiguousarray(Sw.copy()), V, ev, p)
                self.explained_variance_ratio_ = (ev / np.sum(ev))[:self._max_components]
                self.scalings_ = V
                self.coef_ = means @ V @ V.T
                self.intercept_ = -0.5 * np.diag(means @ self.coef_.T) + np.log(priors)
        if K == 2:
            self.coef_ = (self.coef_[1, :] - self.coef_[0, :]).reshape(1, -1)
            self.intercept_ = np.asarray(self.intercept_[1] - self.intercept_[0]).reshape(1)
        return self

    def decision_function(self, X):
        check_is_fitted(self)
        d = pred_x(self, X) @ self.coef_.T + self.intercept_
        return d.ravel() if d.shape[1] == 1 else d

    def predict(self, X):
        d = self.decision_function(X)
        idx = (d > 0).astype(int) if d.ndim == 1 else d.argmax(axis=1)
        return self.classes_[idx]

    def predict_proba(self, X):
        d = self.decision_function(X)
        if d.ndim == 1:
            p1 = 1.0 / (1.0 + np.exp(-d))
            return np.stack([1 - p1, p1], axis=1)
        e = np.exp(d - d.max(axis=1, keepdims=True))
        return e / e.sum(axis=1, keepdims=True)

    def predict_log_proba(self, X):
        P = self.predict_proba(X)
        with np.errstate(divide="ignore"):
            return np.log(P)

    def transform(self, X):
        if self.solver == "lsqr":
            raise NotImplementedError(
                "transform not implemented for 'lsqr' solver (use 'svd' or 'eigen').")
        check_is_fitted(self)
        X = pred_x(self, X)
        Xn = (X - self.xbar_) @ self.scalings_ if self.solver == "svd" else X @ self.scalings_
        return Xn[:, :self._max_components]


class GramTruncatedSVD(Tagged, TransformerMixin, BaseEstimator):
    """scikit-learn's ``TruncatedSVD`` on a dense X, through the Gram
    matrix (``examples/kernel-only/truncated-svd.scm``): the leading
    ``n_components`` pairs of X'X (n >= p; X'X by dsyrk) or of X X'
    (wide) by dsyevr over the wanted index range, the transformed data
    by one dgemm, svd_flip's signs (u_based_decision=False).

    The result is the exact truncated SVD, what ``algorithm="arpack"``
    computes; scikit-learn's default randomized solver approximates it
    (5 power iterations), so against that one the components agree to
    its approximation error.  ``algorithm``, ``n_iter``,
    ``n_oversamples``, ``power_iteration_normalizer``, ``random_state``
    and ``tol`` are taken for the interface and do not change the
    answer.  A scipy.sparse X (TruncatedSVD's usual input, latent
    semantic analysis) goes the same way: X'X (or X X') by csr-gram,
    its leading pairs by dsyevr, X V by csr-mm; no centring, as in
    scikit-learn.  The Gram is min(n, p) square, so a sparse X with
    both sides in the hundreds of thousands is beyond it.

    Attributes after fit: components_, explained_variance_,
    explained_variance_ratio_, singular_values_, n_features_in_.
    """
    _sparse = True

    def __init__(self, n_components=2, *, algorithm="randomized", n_iter=5, n_oversamples=10,
                 power_iteration_normalizer="auto", random_state=None, tol=0.0):
        self.n_components, self.algorithm, self.n_iter = n_components, algorithm, n_iter
        self.n_oversamples = n_oversamples
        self.power_iteration_normalizer = power_iteration_normalizer
        self.random_state, self.tol = random_state, tol

    def fit(self, X, y=None):
        self.fit_transform(X)
        return self

    def fit_transform(self, X, y=None):
        if self.algorithm not in ("randomized", "arpack"):
            raise ValueError(f"algorithm={self.algorithm!r}: expected 'randomized' or 'arpack'")
        X = fit_x(self, X, ensure_min_features=2)
        n, p = X.shape
        c = int(self.n_components)
        if not 1 <= c <= min(n, p):
            raise ValueError(f"n_components({c}) must be between 1 and min(n_samples, "
                             f"n_features)={min(n, p)}.")
        k = _gramops_kernels()
        V, s, Z = np.zeros((p, c)), np.zeros(c), np.zeros((n, c))
        if not _issparse(X):
            (k.tsvd_tall if n >= p else k.tsvd_wide)(X, V, s, Z, n, p, c)
            full = np.var(X, axis=0).sum()
        else:
            if n >= p:
                k.tsvd_gram(_sparse_gram(X), V, s, p, c)
                Z = _dot(X, V)
            else:
                U = np.zeros((n, c))
                k.tsvd_gram(_sparse_gram(as_csr(X.T)), U, s, n, c)
                with np.errstate(divide="ignore", invalid="ignore"):
                    V = np.where(s > 0, _dot(X, U, transpose=True) / s, 0.0)
                Z = U * s
            V, Z = np.ascontiguousarray(V), np.ascontiguousarray(Z)
            k.tsvd_flip(V, Z, n, p, c)
            m = _sparse_mean(X)
            full = float(np.sum(np.asarray(X.multiply(X).mean(axis=0)).ravel() - m * m))
        self.components_ = np.ascontiguousarray(V.T)
        self.singular_values_ = s
        self.explained_variance_ = np.var(Z, axis=0)
        self.explained_variance_ratio_ = self.explained_variance_ / full if full > 0 \
            else np.zeros(c)
        return Z

    def transform(self, X):
        check_is_fitted(self)
        X = pred_x(self, X)
        return _dot(X, self.components_.T) if _issparse(X) else X @ self.components_.T

    def inverse_transform(self, X):
        check_is_fitted(self)
        return np.asarray(X) @ self.components_


def _convergence_warning():
    try:
        from sklearn.exceptions import ConvergenceWarning
        return ConvergenceWarning
    except ImportError:
        return UserWarning


def _covariance(X):
    """(Xc'Xc / n, column means) from X'X less n m m', the centred copy
    only when a column's mean dwarfs its spread (_centered_gram's rule)."""
    n = X.shape[0]
    xm = X.mean(axis=0)
    G = _gram(X)
    nm2 = n * xm * xm
    if np.all(np.diagonal(G) - nm2 > 1e-4 * nm2):
        G -= np.outer(xm, n * xm)
    else:
        G = _gram(np.ascontiguousarray(X - xm))
    return G / n, xm


def _ortho_rotation(components, method="varimax", tol=1e-6, max_iter=100):
    # scikit-learn's decomposition._factor_analysis._ortho_rotation
    nrow, ncol = components.shape
    rotation_matrix = np.eye(ncol)
    var = 0
    for _ in range(max_iter):
        comp_rot = components @ rotation_matrix
        if method == "varimax":
            tmp = comp_rot * ((comp_rot ** 2).sum(axis=0) / nrow)
        else:
            tmp = 0
        u, s, v = np.linalg.svd(components.T @ (comp_rot ** 3 - tmp))
        rotation_matrix = u @ v
        var_new = np.sum(s)
        if var != 0 and var_new < var * (1 + tol):
            break
        var = var_new
    return (components @ rotation_matrix).T


class GramFactorAnalysis(Tagged, TransformerMixin, BaseEstimator):
    """scikit-learn's ``FactorAnalysis`` over the covariance
    (``examples/kernel-only/fa.scm``): scikit-learn takes, every
    iteration, the SVD of the n x p matrix Xc / (sqrt(psi) sqrt(n));
    its squared singular values and right singular vectors are the
    eigenpairs of D^-1 C D^-1 for C = Xc'Xc / n (formed once, by
    dsyrk) and D = diag(sqrt psi), so each iteration here is the top
    ``n_components`` eigenpairs of a p x p matrix (dsyevr) and the rows
    are read once.  The eigenproblem is exact: what
    ``svd_method="lapack"`` computes (to 1e-13 here, iterations alike);
    the default ``"randomized"`` approximates it, so against that one
    the fit agrees to its approximation.  ``iterated_power`` and
    ``random_state`` are taken for the interface.

    Attributes after fit: components_, noise_variance_, loglike_,
    n_iter_, mean_, n_features_in_.
    """

    def __init__(self, n_components=None, *, tol=1e-2, copy=True, max_iter=1000,
                 noise_variance_init=None, svd_method="randomized", iterated_power=3,
                 rotation=None, random_state=0):
        self.n_components, self.tol, self.copy, self.max_iter = n_components, tol, copy, max_iter
        self.noise_variance_init, self.svd_method = noise_variance_init, svd_method
        self.iterated_power, self.rotation, self.random_state = iterated_power, rotation, random_state

    def fit(self, X, y=None):
        if self.svd_method not in ("lapack", "randomized"):
            raise ValueError(f"svd_method={self.svd_method!r}: expected 'lapack' or 'randomized'")
        if self.rotation not in (None, "varimax", "quartimax"):
            raise ValueError(f"rotation={self.rotation!r}: expected None, 'varimax' or 'quartimax'")
        X = fit_x(self, X)
        n, p = X.shape
        c = p if self.n_components is None else int(self.n_components)
        C, self.mean_ = _covariance(X)
        var = np.diagonal(C).copy()
        if self.noise_variance_init is None:
            psi = np.ones(p)
        else:
            if len(self.noise_variance_init) != p:
                raise ValueError("noise_variance_init dimension does not with number of "
                                 "features : %d != %d" % (len(self.noise_variance_init), p))
            psi = np.array(self.noise_variance_init, dtype=np.float64)
        maxit = int(self.max_iter)
        W, ll = np.zeros((c, p)), np.zeros(max(maxit, 1))
        it = _gramops_kernels().fa_fit(np.ascontiguousarray(C), var, psi, W, ll, n, p, c,
                                       maxit, float(self.tol))
        if it > maxit:
            warnings.warn("FactorAnalysis did not converge. You might want to increase "
                          "the number of iterations.", _convergence_warning())
            it = maxit
        self.components_ = W
        if self.rotation is not None:
            self.components_ = _ortho_rotation(W.T, method=self.rotation)[:c]
        self.noise_variance_ = psi
        self.loglike_ = list(ll[:it])
        self.n_iter_ = it
        return self

    def transform(self, X):
        check_is_fitted(self)
        X = pred_x(self, X)
        Wpsi = self.components_ / self.noise_variance_
        cov_z = np.linalg.inv(np.eye(len(self.components_)) + Wpsi @ self.components_.T)
        return ((X - self.mean_) @ Wpsi.T) @ cov_z

    def get_covariance(self):
        check_is_fitted(self)
        cov = self.components_.T @ self.components_
        cov.flat[::len(cov) + 1] += self.noise_variance_
        return cov

    def get_precision(self):
        check_is_fitted(self)
        p = self.components_.shape[1]
        if self.n_components == 0:
            return np.diag(1.0 / self.noise_variance_)
        if self.n_components == p:
            return np.linalg.inv(self.get_covariance())
        W = self.components_
        P = (W / self.noise_variance_) @ W.T
        P.flat[::len(P) + 1] += 1.0
        P = W.T @ (np.linalg.inv(P) @ W)
        P /= self.noise_variance_[:, None]
        P /= -self.noise_variance_[None, :]
        P.flat[::len(P) + 1] += 1.0 / self.noise_variance_
        return P

    def score_samples(self, X):
        check_is_fitted(self)
        Xr = pred_x(self, X) - self.mean_
        P = self.get_precision()
        sign, logdet = np.linalg.slogdet(P)
        ll = -0.5 * (Xr * (Xr @ P)).sum(axis=1)
        ll -= 0.5 * (Xr.shape[1] * np.log(2.0 * np.pi) - (logdet if sign > 0 else -np.inf))
        return ll

    def score(self, X, y=None):
        return float(np.mean(self.score_samples(X)))


class GramLinearRegression(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``LinearRegression`` over the Gram matrix
    (``examples/kernel-only/linreg.scm``): the rows read once into
    Xc'Xc and Xc'y (dsyrk, dgemm; csr-gram and csr-mm for a scipy.sparse
    X), then the normal equations of the column-scaled Gram solved by
    Cholesky (dposv), where scikit-learn runs LAPACK's gelsd on the
    n x p design (lsqr on a sparse one).  The normal equations square
    the condition number, so the Gram's answer is taken only when the
    scaled Gram's condition number (dpocon's estimate) is at most 1e6
    (relative error about 1e-10) and the design has full rank at
    ``tol``; otherwise -- and for ``positive=True`` (scipy's nnls, dense
    X only, as in scikit-learn) -- the fit is scikit-learn's own: least
    squares on the centred X, or lsqr at ``tol`` on a sparse one.
    ``rank_`` and ``singular_`` come from the Gram's eigenvalues
    (dsyevd), computed when first read; the Gram is kept for them.
    ``sample_weight`` scales the centred rows by its square root, as
    scikit-learn does.

    Attributes after fit: coef_, intercept_, rank_ and singular_ (not
    after lsqr), n_features_in_.
    """
    _multi_output = True

    def __init__(self, *, fit_intercept=True, copy_X=True, tol=1e-6, n_jobs=None,
                 positive=False):
        self.fit_intercept, self.copy_X, self.tol = fit_intercept, copy_X, tol
        self.n_jobs, self.positive = n_jobs, positive

    @property
    def _sparse(self):
        return not self.positive

    def fit(self, X, y, sample_weight=None):
        X, y = fit_xy(self, X, y, multi_output=True)
        n, p = X.shape
        sparse = _issparse(X)
        tol = float(self.tol)
        t = 1 if y.ndim == 1 else y.shape[1]
        if sample_weight is not None:
            sw = np.asarray(sample_weight, dtype=np.float64)
            sw = np.full(n, float(sw)) if sw.ndim == 0 else sw
            if sw.shape != (n,):
                raise ValueError(f"sample_weight.shape == {sw.shape}, expected {(n,)}!")
            if np.all(sw == 0):
                raise ValueError("Sample weights must contain at least one non-zero number.")
        else:
            sw = None
        if sw is None and not sparse:
            G, B, xm, ym = _centered_gram(X, y, self.fit_intercept)
            r = None
        else:
            # rows scaled by sqrt(w): (Xw'Xw - S xm xm') and (Xw'yw - S xm ym')
            w = np.ones(n) if sw is None else sw
            S = w.sum()
            r = np.sqrt(w)
            ry = r[:, None] if y.ndim > 1 else r
            if self.fit_intercept:
                xm = (_dot(X, w, transpose=True) if sparse else w @ X) / S
                ym = w @ y / S
            else:
                xm, ym = np.zeros(p), (np.zeros(t) if y.ndim > 1 else 0.0)
            if sparse:
                import scipy.sparse as sp
                Xw = X if sw is None else as_csr(sp.diags(r) @ X)
                G = _sparse_gram(Xw) - S * np.outer(xm, xm)
                B = _dot(Xw, ry * y, transpose=True) - S * np.multiply.outer(xm, ym)
            else:
                Xw = np.ascontiguousarray(r[:, None] * (X - xm))
                G, B = _gram(Xw), _gram_xy(Xw, np.ascontiguousarray(ry * (y - ym)))
        coef = None
        for name in ("_rank", "_singular", "_kept"):
            vars(self).pop(name, None)
        if not self.positive:
            cols = np.zeros((p, t))
            if _gramops_kernels().linreg_solve(np.array(G, dtype=np.float64, order="C"),
                                               np.array(B.reshape(p, t), dtype=np.float64,
                                                        order="C"),
                                               cols, p, t, 1e-6, tol) == 1:
                coef = cols
                # rank_ and singular_ from G's eigenvalues, on first use
                self._kept = (np.array(G, dtype=np.float64, order="C"), tol)
        if coef is None:
            if r is None:
                r, ry = np.ones(n), np.ones(n) if y.ndim == 1 else np.ones((n, 1))
            ys = ry * (y - ym)
            if sparse:
                from scipy.sparse.linalg import LinearOperator, lsqr
                Xw = X if sw is None else as_csr(sp.diags(r) @ X)
                op = LinearOperator((n, p), matvec=lambda b: Xw @ b - r * (b @ xm),
                                    rmatvec=lambda u: Xw.T @ u - xm * (u @ r))
                Y2 = ys.reshape(n, -1)
                coef = np.column_stack([lsqr(op, Y2[:, j], atol=tol, btol=tol)[0]
                                        for j in range(t)])
            else:
                Xs = np.ascontiguousarray(r[:, None] * (X - xm))
                if self.positive:
                    from scipy import optimize
                    Y2 = ys.reshape(n, -1)
                    coef = np.column_stack([optimize.nnls(Xs, Y2[:, j])[0] for j in range(t)])
                else:
                    from scipy import linalg
                    coef, _, self._rank, self._singular = linalg.lstsq(Xs, ys.reshape(n, -1),
                                                                       cond=tol)
        if y.ndim == 1:
            self.coef_ = coef[:, 0]
            self.intercept_ = float(ym - xm @ self.coef_) if self.fit_intercept else 0.0
        else:
            self.coef_ = np.ascontiguousarray(coef.T)
            self.intercept_ = ym - xm @ coef if self.fit_intercept else np.zeros(t)
        return self

    @property
    def rank_(self):
        self._spectrum()
        return self._rank

    @property
    def singular_(self):
        self._spectrum()
        return self._singular

    def _spectrum(self):
        d = vars(self)
        if "_rank" in d:
            return
        if "_kept" not in d:
            raise AttributeError("rank_ and singular_ are not set (a sparse X solved by lsqr, "
                                 "or not fitted)")
        G, tol = d["_kept"]
        sv = np.zeros(G.shape[0])
        self._rank = _gramops_kernels().linreg_singular(G.copy(), sv, G.shape[0], tol)
        self._singular = sv

    def predict(self, X):
        X = pred_x(self, X)
        return (_dot(X, self.coef_.T) if _issparse(X) else X @ self.coef_.T) + self.intercept_


def _pls_moments(X, Y, scale):
    """Centred (and, with scale, standardised) Cxx, Cxy, Cyy, with the
    means and deviations: from X'X, X'Y and Y'Y less the n m m' terms,
    the centred copies only when a column's mean dwarfs its spread (the
    correction would cancel its digits)."""
    n = X.shape[0]
    xm, ym = X.mean(axis=0), Y.mean(axis=0)
    Gxx, Gxy, Gyy = _gram(X), _gram_xy(X, Y), _gram(np.ascontiguousarray(Y))
    Gxy = Gxy.reshape(X.shape[1], Y.shape[1])
    nx, ny = n * xm * xm, n * ym * ym
    if np.all(np.diagonal(Gxx) - nx > 1e-4 * nx) and np.all(np.diagonal(Gyy) - ny > 1e-4 * ny):
        Cxx = Gxx - np.outer(xm, n * xm)
        Cxy = Gxy - np.outer(xm, n * ym)
        Cyy = Gyy - np.outer(ym, n * ym)
    else:
        Xc, Yc = np.ascontiguousarray(X - xm), np.ascontiguousarray(Y - ym)
        Cxx, Cyy = _gram(Xc), _gram(Yc)
        Cxy = _gram_xy(Xc, Yc).reshape(X.shape[1], Y.shape[1])
    if scale:
        xs = np.sqrt(np.maximum(np.diagonal(Cxx), 0.0) / (n - 1))
        ys = np.sqrt(np.maximum(np.diagonal(Cyy), 0.0) / (n - 1))
        xs[xs == 0.0] = 1.0
        ys[ys == 0.0] = 1.0
        Cxx = Cxx / np.outer(xs, xs)
        Cxy = Cxy / np.outer(xs, ys)
        Cyy = Cyy / np.outer(ys, ys)
    else:
        xs, ys = np.ones(X.shape[1]), np.ones(Y.shape[1])
    return (np.ascontiguousarray(Cxx), np.ascontiguousarray(Cxy), np.ascontiguousarray(Cyy),
            xm, ym, xs, ys)


class _GramPLS(Tagged, TransformerMixin, BaseEstimator):
    # scikit-learn's _PLS over the cross products (examples/kernel-only/pls.scm)
    _multi_output = True
    _mode, _canon = 0, 0

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, multi_output=True)
        n, p = X.shape
        if n < 2:
            raise ValueError(f"Found array with {n} sample(s) (shape={X.shape}) while a "
                             "minimum of 2 is required.")
        self._predict_1d = y.ndim == 1
        Y = y.reshape(n, -1)
        q = Y.shape[1]
        k = int(self.n_components)
        upper = min(n, p) if not self._canon else min(n, p, q)
        if not 1 <= k <= upper:
            raise ValueError(f"`n_components` upper bound is {upper}. Got {k} instead. "
                             "Reduce `n_components`.")
        algo = 1 if getattr(self, "algorithm", "nipals") == "svd" else 0
        Cxx, Cxy, Cyy, self._x_mean, self._y_mean, self._x_std, self._y_std = \
            _pls_moments(X, Y, self.scale)
        xw, yw = np.zeros((p, k)), np.zeros((q, k))
        xl, yl = np.zeros((p, k)), np.zeros((q, k))
        niter = np.zeros(k, dtype=np.int32)
        found = _gramops_kernels().pls_fit(Cxx, Cxy, Cyy, xw, yw, xl, yl, niter, p, q, k,
                                           self._mode, self._canon, algo,
                                           int(self.max_iter), float(self.tol))
        if found < k:
            warnings.warn(f"y residual is constant at iteration {found}")
        # scikit-learn keeps the list empty for the svd algorithm
        self.n_iter_ = [int(t) for t in niter[:found]] if algo == 0 else []
        if algo == 0:
            if any(t == int(self.max_iter) for t in self.n_iter_):
                warnings.warn("Maximum number of iterations reached", UserWarning)
        self.x_weights_, self.y_weights_ = xw, yw
        self.x_loadings_, self.y_loadings_ = xl, yl
        self.x_rotations_ = xw @ np.linalg.pinv(xl.T @ xw)
        self.y_rotations_ = yw @ np.linalg.pinv(yl.T @ yw)
        coef = self.x_rotations_ @ yl.T
        self.coef_ = (coef * self._y_std).T / self._x_std
        self.intercept_ = self._y_mean
        self._n_features_out = k
        self._X, self._Y = X, Y
        return self

    def transform(self, X, y=None, copy=True):
        check_is_fitted(self)
        Xs = (pred_x(self, X) - self._x_mean) / self._x_std
        xs = Xs @ self.x_rotations_
        if y is None:
            return xs
        Y = np.asarray(y, dtype=np.float64)
        Y = Y.reshape(-1, 1) if Y.ndim == 1 else Y
        return xs, ((Y - self._y_mean) / self._y_std) @ self.y_rotations_

    def fit_transform(self, X, y=None):
        return self.fit(X, y).transform(X, y)

    def inverse_transform(self, X, y=None):
        check_is_fitted(self)
        Xr = np.asarray(X, dtype=np.float64) @ self.x_loadings_.T * self._x_std + self._x_mean
        if y is None:
            return Xr
        Yr = np.asarray(y, dtype=np.float64) @ self.y_loadings_.T * self._y_std + self._y_mean
        return Xr, Yr

    def predict(self, X, copy=True):
        check_is_fitted(self)
        yp = (pred_x(self, X) - self._x_mean) @ self.coef_.T + self.intercept_
        return yp.ravel() if self._predict_1d else yp


class GramPLSRegression(RegressorMixin, _GramPLS):
    """scikit-learn's ``PLSRegression`` over the cross products
    (``examples/kernel-only/pls.scm``): X'X (dsyrk), X'Y and Y'Y once,
    then NIPALS and the regression deflation as products and rank-one
    updates of those p x p, p x q and q x q matrices, never the n rows
    again.  The scores x_scores_ = X R and y_scores_ (Y less the earlier
    components' X scores, times the Y weights) are formed at the end.

    Attributes after fit: x_weights_, y_weights_, x_loadings_,
    y_loadings_, x_rotations_, y_rotations_, x_scores_, y_scores_,
    coef_, intercept_, n_iter_, n_features_in_.
    """
    _mode, _canon = 0, 0

    def __init__(self, n_components=2, *, scale=True, max_iter=500, tol=1e-06, copy=True):
        self.n_components, self.scale, self.max_iter = n_components, scale, max_iter
        self.tol, self.copy = tol, copy

    def fit(self, X, y):
        super().fit(X, y)
        Xs = (self._X - self._x_mean) / self._x_std
        Ys = (self._Y - self._y_mean) / self._y_std
        T = Xs @ self.x_rotations_
        U = Ys @ self.y_weights_
        for k in range(U.shape[1]):
            # Y deflated by the earlier components' X scores (regression mode)
            U[:, k] -= T[:, :k] @ (self.y_loadings_[:, :k].T @ self.y_weights_[:, k])
            U[:, k] /= self.y_weights_[:, k] @ self.y_weights_[:, k]
        self.x_scores_, self.y_scores_ = T, U
        del self._X, self._Y
        return self

    def fit_transform(self, X, y=None):
        return self.fit(X, y).transform(X, y)


class GramPLSCanonical(_GramPLS):
    """scikit-learn's ``PLSCanonical`` (canonical deflation, mode A,
    ``algorithm`` "nipals" or "svd") over the cross products, as
    ``GramPLSRegression``."""
    _mode, _canon = 0, 1

    def __init__(self, n_components=2, *, scale=True, algorithm="nipals", max_iter=500,
                 tol=1e-06, copy=True):
        self.n_components, self.scale, self.algorithm = n_components, scale, algorithm
        self.max_iter, self.tol, self.copy = max_iter, tol, copy

    def fit(self, X, y):
        if self.algorithm not in ("nipals", "svd"):
            raise ValueError(f"algorithm={self.algorithm!r}: expected 'nipals' or 'svd'")
        super().fit(X, y)
        del self._X, self._Y
        return self


class GramCCA(_GramPLS):
    """scikit-learn's ``CCA`` (canonical deflation, mode B: pinv of each
    block from the eigenproblem of its Gram, cut where _pinv2_old cuts)
    over the cross products, as ``GramPLSRegression``."""
    _mode, _canon = 1, 1

    def __init__(self, n_components=2, *, scale=True, max_iter=500, tol=1e-06, copy=True):
        self.n_components, self.scale, self.max_iter = n_components, scale, max_iter
        self.tol, self.copy = tol, copy

    def fit(self, X, y):
        super().fit(X, y)
        del self._X, self._Y
        return self


class GramPLSSVD(Tagged, TransformerMixin, BaseEstimator):
    """scikit-learn's ``PLSSVD``: the SVD of the centred (scaled) X'Y,
    formed from X'Y less n mx my' instead of from centred copies."""
    _multi_output = True

    def __init__(self, n_components=2, *, scale=True, copy=True):
        self.n_components, self.scale, self.copy = n_components, scale, copy

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, multi_output=True)
        n, p = X.shape
        if n < 2:
            raise ValueError(f"Found array with {n} sample(s) (shape={X.shape}) while a "
                             "minimum of 2 is required.")
        Y = y.reshape(n, -1)
        k = int(self.n_components)
        upper = min(n, p, Y.shape[1])
        if not 1 <= k <= upper:
            raise ValueError(f"`n_components` upper bound is {upper}. Got {k} instead. "
                             "Reduce `n_components`.")
        _, C, _, self._x_mean, self._y_mean, self._x_std, self._y_std = \
            _pls_moments(X, Y, self.scale)
        U, _, Vt = np.linalg.svd(C, full_matrices=False)
        U, Vt = U[:, :k], Vt[:k]
        # svd_flip, u-based: each column of U's largest entry positive
        sg = np.sign(U[np.argmax(np.abs(U), axis=0), np.arange(k)])
        sg[sg == 0] = 1.0
        self.x_weights_, self.y_weights_ = U * sg, (Vt * sg[:, None]).T
        self._n_features_out = k
        return self

    def transform(self, X, y=None):
        check_is_fitted(self)
        xs = ((pred_x(self, X) - self._x_mean) / self._x_std) @ self.x_weights_
        if y is None:
            return xs
        Y = np.asarray(y, dtype=np.float64)
        Y = Y.reshape(-1, 1) if Y.ndim == 1 else Y
        return xs, ((Y - self._y_mean) / self._y_std) @ self.y_weights_

    def fit_transform(self, X, y=None):
        return self.fit(X, y).transform(X, y)


class ParallelFastICA(Tagged, TransformerMixin, BaseEstimator):
    """FastICA, scikit-learn's ``FastICA`` at its defaults translated
    whole (``examples/kernel-only/fastica.scm``: algorithm="parallel",
    fun="logcosh", whiten="unit-variance", whiten_solver="svd" -- the
    singular vectors of X' taken from the eigenvectors of X'X, signed as
    scikit-learn signs them).  The start is ``RandomState(random_state)
    .normal(size=(k, k))``, scikit-learn's draw, unless ``w_init`` is
    given; with the same start the fit is scikit-learn's to rounding.

    Attributes after fit: components_, mixing_, mean_, whitening_, n_iter_.
    """

    def __init__(self, n_components=None, *, max_iter=200, tol=1e-4, w_init=None,
                 random_state=None):
        self.n_components, self.max_iter, self.tol = n_components, max_iter, tol
        self.w_init, self.random_state = w_init, random_state

    def fit(self, X, y=None):
        X = fit_x(self, X, ensure_min_samples=2)
        n, p = X.shape
        k = min(n, p) if self.n_components is None else min(int(self.n_components), n, p)
        if self.w_init is None:
            w0 = np.random.RandomState(self.random_state).normal(size=(k, k))
        else:
            w0 = np.asarray(self.w_init, dtype=np.float64)
        w0 = np.ascontiguousarray(w0)
        self.components_ = np.zeros((k, p)); self.whitening_ = np.zeros((k, p))
        self._unmixing = np.zeros((k, k)); self.mean_ = np.zeros(p)
        self.n_iter_ = _gpu_or_cpu(n * p, getattr(self, "backend", None)).fastica(
            X, w0, self.components_, self.whitening_, self._unmixing, self.mean_,
            int(self.max_iter), float(self.tol), n, p, k)
        self.mixing_ = np.linalg.pinv(self.components_)
        return self

    def transform(self, X):
        return (pred_x(self, X) - self.mean_) @ self.components_.T

    def fit_transform(self, X, y=None):
        return self.fit(X).transform(X)


class CovARDRegression(Tagged, RegressorMixin, BaseEstimator):
    """Automatic relevance determination, scikit-learn's ``ARDRegression``
    for n >= p translated whole (``examples/kernel-only/ard.scm``): each
    iteration sigma = pinvh(diag(lambda) + alpha G) over the kept
    features (the eigenproblem in the subset, scipy's cutoff), then
    coef, gamma, lambda, alpha and the pruning at ``threshold_lambda``,
    stopping on the coefficients' summed change.  ``hoist=True`` (the
    default) takes the kept features' Gram from X'X formed once;
    ``hoist=False`` forms it from X every iteration, as scikit-learn
    does.  Same iterations and coefficients to rounding either way.

    Attributes after fit: coef_, intercept_, alpha_, lambda_, sigma_,
    n_iter_.
    """

    def __init__(self, *, max_iter=300, tol=1e-3, alpha_1=1e-6, alpha_2=1e-6,
                 lambda_1=1e-6, lambda_2=1e-6, threshold_lambda=1e4, fit_intercept=True,
                 hoist=True):
        self.max_iter, self.tol = max_iter, tol
        self.alpha_1, self.alpha_2, self.lambda_1, self.lambda_2 = alpha_1, alpha_2, lambda_1, lambda_2
        self.threshold_lambda, self.fit_intercept, self.hoist = threshold_lambda, fit_intercept, hoist

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        if n < p:
            raise ValueError(f"CovARDRegression is the n >= p route (_update_sigma); got "
                             f"n_samples = {n} for {p} features")
        self.coef_ = np.zeros(p)
        self.lambda_ = np.zeros(p)
        sigma = np.zeros(p * p)
        out = np.zeros(2)
        self.n_iter_ = _gramops_kernels().ard(
            Xc, np.ascontiguousarray(yc), self.coef_, sigma, self.lambda_, out,
            int(self.max_iter), float(self.tol), float(self.alpha_1), float(self.alpha_2),
            float(self.lambda_1), float(self.lambda_2), float(self.threshold_lambda),
            1 if self.hoist else 0, n, p)
        k = int(out[1])
        self.alpha_ = float(out[0])
        self.sigma_ = sigma[:k * k].reshape(k, k).copy()
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


def _gpu_or_cpu(size, backend=None):
    """The --cuda translation (kernels and device-resident cuBLAS) when it
    was built, a device answers, the backend allows it and the problem has
    at least a million entries; the CPU library otherwise."""
    import os
    from ._libfind import gpu_built
    if (backend in (None, "cuda") and size >= 1e6 and not os.environ.get("SCM2CPP_NO_DEVICE")
            and gpu_built() and cuda_available()):
        import importlib
        return importlib.import_module(f"{__name__}._generated._loader_gpu_cuda")
    return _gramops_kernels()


def _accel(work):
    """The --cublas build of the selection and Gram products, when it was
    built, a device answers, and WORK (flops) is large enough to pay for
    the transfer; else None."""
    import os
    from ._libfind import accel_built
    if (work < 2e9 or os.environ.get("SCM2CPP_NO_DEVICE") or not accel_built()
            or not cuda_available()):
        return None
    import importlib
    return importlib.import_module(f"{__name__}._generated._loader_accel_cublas")


# Products under this many multiply-adds go to numpy: no BLAS threads
# them, and a ctypes call to the package's library costs 10 us more than
# numpy's (a 200 x 10 GramRidge took twice as long through it)
_SMALL = 1e6


def _gram(Xc, backend=None):
    """X'X: gram.scm's gram-xx where the BLAS build is here (one dsyrk on
    every core, half the flops of numpy's X.T @ X, which is a dgemm), on
    the device for a large product when one answers, else numpy.  With
    the BLAS build the device is taken by default only from p = 4000:
    the product reads X once, so its copy to the device is most of the
    device's time, and twenty cores' dsyrk was faster up to p = 2000
    (200,000 x 200: 0.044 s against 0.096 s)."""
    from ._libfind import gramops_backend
    n, p = Xc.shape
    if backend is None and float(n) * p * p < _SMALL:
        return np.ascontiguousarray(Xc.T @ Xc)
    blas = gramops_backend() == "blas"
    dev = backend == "cublas" or (backend is None and (not blas or p >= 4000))
    lib = _accel(float(n) * p * p) if dev else None
    if lib is None:
        if not blas:
            return np.ascontiguousarray(Xc.T @ Xc)
        lib = _gramops_kernels()
    G = np.zeros((p, p))
    lib.gram_xx(np.ascontiguousarray(Xc), G, n, p)
    return G


def _gram_xy(Xc, y):
    """X'y (y one target or several) by gram.scm's gram-xy where the BLAS
    build is here, so that the Gram-route fits run on one BLAS: numpy's
    OpenBLAS keeps its threads spinning after a call, and the next dsyrk
    of the other library then shared the cores with them (CovRidge at
    200,000 x 200 took 0.14 s for a 0.044 s product)."""
    from ._libfind import gramops_backend
    n, p = Xc.shape
    q = 1 if y.ndim == 1 else y.shape[1]
    if gramops_backend() != "blas" or float(n) * p * q < _SMALL:
        return Xc.T @ y
    c = np.zeros((p, q))
    _gramops_kernels().gram_xy(np.ascontiguousarray(Xc), np.ascontiguousarray(y), c, n, p, q)
    return c.ravel() if y.ndim == 1 else c


def _ridge_solve(G, c, alpha):
    """(G + alpha I) b = c by gram.scm's gram-ridge-solve (LAPACK's dposv in the
    BLAS build), c one column or several; None when the factor breaks
    down (alpha 0 on a singular G), for the caller's least squares.  In
    the package's library rather than numpy's for the reason _gram_xy
    gives: numpy's solve between two dsyrk calls cost the next one half
    its speed.  (Until 0.17 this was rfe.scm's Cholesky in loops, 3.7x
    numpy's solve at p = 200.)"""
    p = G.shape[0]
    cols = np.array(c.reshape(p, -1), dtype=np.float64, order="C")
    if _gramops_kernels().gram_ridge_solve(np.ascontiguousarray(G, dtype=np.float64), cols,
                                           float(alpha), p, cols.shape[1]) != 0:
        return None
    return cols.ravel() if c.ndim == 1 else cols


def _threads():
    # the threads the sparse Gram splits into: OMP_NUM_THREADS, else every core
    try:
        t = int(os.environ.get("OMP_NUM_THREADS", ""))
        if t > 0:
            return t
    except ValueError:
        pass
    return os.cpu_count() or 1


def _sparse_gram(X):
    """X'X (p x p) for a CSR X by sparse.scm's csr-gram: the rows in
    order, each row's outer product into the upper triangle.  Blocks of
    rows of equal work (sum nnz_i^2) run on threads (ctypes lets go of
    the GIL), each into its own G -- as many as fit in about 1 GB -- and
    the G's are summed, then the triangle mirrored.  (Walking the
    columns instead, each into its own row of one G, visited every row
    once per entry from anywhere in memory: 12x slower on one core at
    200,000 x 200, 5% dense, where this takes 0.025 s and scipy's
    X.T @ X 0.26 s.)"""
    from concurrent.futures import ThreadPoolExecutor
    n, p = X.shape
    G = np.zeros((p, p))
    if p == 0 or X.nnz == 0:
        return G
    rp, ci, v = X.indptr, X.indices, X.data
    k = _gramops_kernels()
    w = np.diff(rp).astype(np.float64) ** 2
    t = max(1, min(_threads(), n, int(1e9 // (8.0 * p * p)), int(w.sum() // 1e6) + 1))
    cuts = [0] + list(np.searchsorted(np.cumsum(w), w.sum() * np.arange(1, t) / t) + 1) + [n]
    blocks = sorted({(int(a), int(b)) for a, b in zip(cuts[:-1], cuts[1:]) if b > a})
    Gs = [G] + [np.zeros((p, p)) for _ in blocks[1:]]
    run = lambda j: k.csr_gram(rp, ci, v, Gs[j], p, blocks[j][0], blocks[j][1])
    if len(blocks) == 1:
        run(0)
    else:
        with ThreadPoolExecutor(len(blocks)) as ex:
            list(ex.map(run, range(len(blocks))))
        for H in Gs[1:]:
            G += H
    low = np.tril_indices(p, -1)
    G[low] = G.T[low]
    return G


def _dot(X, B, transpose=False):
    """X B (or X'B) for a CSR X and a dense B (1-D or 2-D) by sparse.scm's
    csr-mm, rows in parallel; scipy's product below a small size."""
    m = X.shape[1] if transpose else X.shape[0]
    B2 = np.ascontiguousarray(np.asarray(B, dtype=np.float64).reshape(X.shape[0 if transpose else 1], -1))
    if float(X.nnz) * B2.shape[1] < _SMALL:
        out = np.asarray((X.T if transpose else X) @ B2)
    else:
        A = X.tocsc() if transpose else X
        out = np.zeros((m, B2.shape[1]))
        _gramops_kernels().csr_mm(np.ascontiguousarray(A.indptr, dtype=np.int32),
                                  np.ascontiguousarray(A.indices, dtype=np.int32),
                                  np.ascontiguousarray(A.data, dtype=np.float64),
                                  B2, out, m, B2.shape[1])
    return out.ravel() if np.ndim(B) == 1 else out


def _sparse_mean(X):
    return np.asarray(X.mean(axis=0)).ravel()


def _cpu_select_lib():
    return _gramops_kernels()


def f_regression(X, y, *, center=True, backend=None):
    """scikit-learn's ``f_regression`` translated (``fscore.scm``): F and
    p-values of each feature against y.  ``y`` may also be n x q, the q
    targets in one call (one product X'Y, on the device when one answers
    and the product is large) -- what a loop of scikit-learn's calls
    gives, column by column.  Infinite F (perfect correlation) becomes
    the largest double and NaN F zero with p-value 1, as
    force_finite=True has it.  p-values need scipy (else None)."""
    X = np.ascontiguousarray(X, dtype=np.float64)
    Y = np.asarray(y, dtype=np.float64)
    one = Y.ndim == 1
    Y = np.ascontiguousarray(Y.reshape(len(Y), -1))
    n, p = X.shape
    q = Y.shape[1]
    lib = _accel(float(n) * p * q) if backend in (None, "cublas") else None
    if lib is None:
        lib = _cpu_select_lib()
    r = np.zeros((p, q))
    F = np.zeros((p, q))
    with np.errstate(divide="ignore", invalid="ignore"):
        lib.f_regression(X, Y, r, F, 1 if center else 0, n, p, q)
    dof = n - (2 if center else 1)
    try:
        from scipy import stats
        pv = stats.f.sf(F, 1, dof)
    except ImportError:
        pv = None
    inf = np.isinf(F)
    F[inf] = np.finfo(np.float64).max
    nan = np.isnan(F)
    F[nan] = 0.0
    if pv is not None:
        pv[nan] = 1.0
    if one:
        return F[:, 0], (None if pv is None else pv[:, 0])
    return F, pv


def f_classif(X, y):
    """scikit-learn's ``f_classif`` translated (``fscore.scm``: f_oneway's
    sums of squares, the class sums one product).  p-values need scipy."""
    X = np.ascontiguousarray(X, dtype=np.float64)
    classes, lab = np.unique(np.asarray(y), return_inverse=True)
    n, p = X.shape
    k = len(classes)
    F = np.zeros(p)
    with np.errstate(divide="ignore", invalid="ignore"):
        _cpu_select_lib().f_classif(X, lab.astype(np.int32), F, n, p, k)
    try:
        from scipy import special
        pv = special.fdtrc(k - 1, n - k, F)
    except ImportError:
        pv = None
    return F, pv


def _clean_nans(scores):
    scores = np.array(scores, dtype=np.float64, copy=True)
    scores[np.isnan(scores)] = np.finfo(np.float64).min
    return scores


class _SelectBase(Tagged, TransformerMixin, BaseEstimator):
    def fit(self, X, y):
        X, y = fit_xy(self, X, y, y_numeric=False)
        sf = self.score_func
        fn = {"f_classif": f_classif, "f_regression": f_regression}.get(sf, sf)
        self.scores_, self.pvalues_ = fn(X, y)
        return self

    def transform(self, X):
        X = pred_x(self, X)
        return X[:, self.get_support()]

    def fit_transform(self, X, y):
        return self.fit(X, y).transform(X)


class SelectKBest(_SelectBase):
    """scikit-learn's ``SelectKBest`` over the translated F statistics
    (``score_func`` "f_classif", "f_regression", or one of this module's
    functions): the k best scores by a stable sort, NaN scores last.

    Attributes after fit: scores_, pvalues_.
    """

    def __init__(self, score_func="f_classif", *, k=10):
        self.score_func, self.k = score_func, k

    def get_support(self):
        check_is_fitted(self)
        if self.k == "all":
            return np.ones(len(self.scores_), dtype=bool)
        mask = np.zeros(len(self.scores_), dtype=bool)
        if self.k == 0:
            return mask
        mask[np.argsort(_clean_nans(self.scores_), kind="mergesort")[-self.k:]] = True
        return mask


class SelectPercentile(_SelectBase):
    """scikit-learn's ``SelectPercentile`` over the translated F
    statistics: scores above the (100 - percentile)th percentile, ties
    at it kept in order up to the percentile's count.

    Attributes after fit: scores_, pvalues_.
    """

    def __init__(self, score_func="f_classif", *, percentile=10):
        self.score_func, self.percentile = score_func, percentile

    def get_support(self):
        check_is_fitted(self)
        if self.percentile == 100:
            return np.ones(len(self.scores_), dtype=bool)
        if self.percentile == 0:
            return np.zeros(len(self.scores_), dtype=bool)
        scores = _clean_nans(self.scores_)
        threshold = np.percentile(scores, 100 - self.percentile)
        mask = scores > threshold
        ties = np.where(scores == threshold)[0]
        if len(ties):
            max_feats = int(len(scores) * self.percentile / 100)
            mask[ties[: max_feats - mask.sum()]] = True
        return mask


class GramRFE(Tagged, RegressorMixin, TransformerMixin, BaseEstimator):
    """scikit-learn's ``RFE`` around ``Ridge(alpha)`` (``alpha=0``:
    ``LinearRegression()``) translated whole (``rfe.scm``): the centred
    Gram formed once (on the device for a large one when one answers),
    each round's fit from its Cholesky factor with the dropped features
    taken out by plane rotations, the features ranked by coef^2 in a
    stable order.  scikit-learn refits from X every round; the ranking
    and the final coefficients are the same to rounding.

    Attributes after fit: support_, ranking_, n_features_, coef_,
    intercept_.
    """

    def __init__(self, alpha=1.0, *, n_features_to_select=None, step=1, backend=None):
        self.alpha, self.n_features_to_select, self.step = alpha, n_features_to_select, step
        self.backend = backend

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        k = self.n_features_to_select
        nsel = p // 2 if k is None else (int(k) if isinstance(k, (int, np.integer)) else int(p * k))
        step = int(max(1, self.step * p)) if 0.0 < self.step < 1.0 else int(self.step)
        lib = _accel(float(n) * p * p) if self.backend in (None, "cublas") else None
        if lib is None:
            lib = _cpu_select_lib()
        coef = np.zeros(p)
        support = np.zeros(p, dtype=np.int32)
        ranking = np.zeros(p, dtype=np.int32)
        lib.rfe(X, y, coef, support, ranking, float(self.alpha), nsel, step, n, p)
        self.support_ = support.astype(bool)
        self.ranking_ = ranking.astype(int)
        self.n_features_ = int(self.support_.sum())
        self.coef_ = coef[self.support_].copy()
        self.intercept_ = float(y.mean() - X.mean(axis=0)[self.support_] @ self.coef_)
        return self

    def transform(self, X):
        return pred_x(self, X)[:, self.support_]

    def predict(self, X):
        return self.transform(X) @ self.coef_ + self.intercept_

    def fit_transform(self, X, y):
        return self.fit(X, y).transform(X)


class _GramLarsBase(Tagged, RegressorMixin, BaseEstimator):
    def _fit_lars(self, X, y, method, alpha, max_iter):
        X, y = fit_xy(self, X, y)
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        G = _gram(Xc)
        cov = Xc.T @ yc
        self.coef_ = np.zeros(p)
        self.n_iter_ = _classifier_kernels().lars(
            G, cov, self.coef_, np.zeros(1), np.zeros(1), 0, float(n), float(alpha), method,
            int(max_iter), float(np.finfo(np.float64).eps), p)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class GramLars(_GramLarsBase):
    """Least angle regression, scikit-learn's _lars_path_solver with a
    Gram translated (``examples/kernel-only/lars.scm``, method "lar").
    ``Lars`` takes the Gram route for n > p (precompute="auto"); here it
    is taken always, the Gram X'X formed in numpy.  ``n_nonzero_coefs``
    defaults to 500, as there.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, n_nonzero_coefs=500, fit_intercept=True):
        self.n_nonzero_coefs, self.fit_intercept = n_nonzero_coefs, fit_intercept

    def fit(self, X, y):
        return self._fit_lars(X, y, 0, 0.0, int(self.n_nonzero_coefs))


class GramLassoLars(_GramLarsBase):
    """The lasso by least angle regression, scikit-learn's
    _lars_path_solver with a Gram translated (method "lasso": variables
    leave the active set when their coefficient crosses zero, the
    Cholesky factor downdated by Givens rotations).  ``LassoLars`` takes
    the Gram route for n > p; here it is taken always.  ``alpha``
    defaults to 1.0 and ``max_iter`` to 500, as there.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, alpha=1.0, *, max_iter=500, fit_intercept=True):
        self.alpha, self.max_iter, self.fit_intercept = alpha, max_iter, fit_intercept

    def fit(self, X, y):
        return self._fit_lars(X, y, 1, float(self.alpha), int(self.max_iter))


class _GramLarsCVBase(Tagged, RegressorMixin, BaseEstimator):
    """LarsCV / LassoLarsCV: KFold(cv) without shuffling; on each fold
    the whole path by the translated LARS over the training fold's Gram
    (centred on the training means), the test residuals interpolated
    onto the union of the folds' alphas as scikit-learn interpolates
    them (the path's coefficients interpolated, the residuals being
    affine in them, the mean square from the test fold's Gram); the
    alpha of the least mean square error, refitted on all the data."""

    def __init__(self, *, fit_intercept=True, max_iter=500, cv=5, max_n_alphas=1000):
        self.fit_intercept, self.max_iter, self.cv = fit_intercept, max_iter, cv
        self.max_n_alphas = max_n_alphas

    def _lars(self, Xc, yc, alpha_min, rec):
        n, p = Xc.shape
        G = _gram(Xc)
        cov = Xc.T @ yc
        coef = np.zeros(p)
        mi = int(self.max_iter)
        path = np.zeros((mi + 1, p)) if rec else np.zeros(1)
        alphas = np.zeros(mi + 1) if rec else np.zeros(1)
        it = _classifier_kernels().lars(G, cov, coef, path, alphas, 1 if rec else 0, float(n),
                                        float(alpha_min), self._method, mi,
                                        float(np.finfo(np.float64).eps), p)
        return it, coef, (path[:it + 1] if rec else None), (alphas[:it + 1] if rec else None)

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        if n < int(self.cv):
            raise ValueError(f"Cannot have number of splits n_splits={self.cv} greater than "
                             f"the number of samples: n_samples={n}.")
        folds = []
        for train, test in _kfold(n, int(self.cv)):
            Xtr, ytr, Xte, yte = X[train], y[train], X[test], y[test]
            if self.fit_intercept:
                xm, ym = Xtr.mean(axis=0), ytr.mean()
                Xtr, Xte, ytr, yte = Xtr - xm, Xte - xm, ytr - ym, yte - ym
            _, _, path, alphas = self._lars(np.ascontiguousarray(Xtr), ytr, 0.0, True)
            folds.append((alphas, path, _gram(Xte), Xte.T @ yte, float(yte @ yte), len(test)))
        all_alphas = np.unique(np.concatenate([f[0] for f in folds]))
        stride = int(max(1, int(len(all_alphas) / float(self.max_n_alphas))))
        all_alphas = all_alphas[::stride]
        mse = np.empty((len(all_alphas), len(folds)))
        for j, (alphas, path, Gt, cyt, yy, nt) in enumerate(folds):
            a, c = alphas[::-1], path[::-1]
            if a[0] != 0:
                a, c = np.r_[0, a], np.r_[c[:1], c]
            if a[-1] != all_alphas[-1]:
                a, c = np.r_[a, all_alphas[-1]], np.r_[c, c[-1:]]
            ci = np.column_stack([np.interp(all_alphas, a, c[:, q]) for q in range(p)])
            mse[:, j] = (((ci @ Gt) * ci).sum(axis=1) - 2.0 * ci @ cyt + yy) / nt
        mask = np.all(np.isfinite(mse), axis=-1)
        all_alphas, mse = all_alphas[mask], mse[mask]
        self.alpha_ = float(all_alphas[int(np.argmin(mse.mean(axis=-1)))])
        self.cv_alphas_, self.mse_path_ = all_alphas, mse
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        self.n_iter_, self.coef_, _, _ = self._lars(Xc, yc, self.alpha_, False)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class GramLarsCV(_GramLarsCVBase):
    """scikit-learn's ``LarsCV`` (method "lar") over the translated LARS;
    see _GramLarsCVBase.  Attributes after fit: alpha_, coef_, intercept_,
    cv_alphas_, mse_path_, n_iter_."""
    _method = 0


class GramLassoLarsCV(_GramLarsCVBase):
    """scikit-learn's ``LassoLarsCV`` (method "lasso") over the translated
    LARS; see _GramLarsCVBase.  Attributes after fit: alpha_, coef_,
    intercept_, cv_alphas_, mse_path_, n_iter_."""
    _method = 1


class GramOMPCV(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``OrthogonalMatchingPursuitCV``: KFold(cv) without
    shuffling; on each fold the path of the translated OMP (``omp.scm``,
    the path recorded) up to ``max_iter`` columns on the centred training
    fold, the test fold's mean square error after each column, the number
    of columns that minimises the folds' mean (over the shortest path),
    refitted as GramOMP.  ``max_iter`` defaults, as there, to
    min(max(10% of p, 5), p).

    Attributes after fit: n_nonzero_coefs_, coef_, intercept_, n_iter_.
    """

    def __init__(self, *, fit_intercept=True, max_iter=None, cv=5):
        self.fit_intercept, self.max_iter, self.cv = fit_intercept, max_iter, cv

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        if n < int(self.cv):
            raise ValueError(f"Cannot have number of splits n_splits={self.cv} greater than "
                             f"the number of samples: n_samples={n}.")
        kmax = min(max(int(0.1 * p), 5), p) if self.max_iter is None else int(self.max_iter)
        lib = _gramops_kernels()
        mses = []
        for train, test in _kfold(n, int(self.cv)):
            Xtr, ytr, Xte, yte = X[train], y[train], X[test], y[test]
            if self.fit_intercept:
                xm, ym = Xtr.mean(axis=0), ytr.mean()
                Xtr, Xte, ytr, yte = Xtr - xm, Xte - xm, ytr - ym, yte - ym
            path = np.zeros((kmax, p))
            k = lib.omp(np.ascontiguousarray(Xtr), np.ascontiguousarray(ytr), np.zeros(p),
                        path, 1, kmax, len(train), p)
            res = Xte @ path[:k].T - yte[:, None]
            mses.append((res ** 2).mean(axis=0))
        m = min(len(f) for f in mses)
        best = int(np.argmin(np.mean([f[:m] for f in mses], axis=0))) + 1
        self.n_nonzero_coefs_ = best
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        self.coef_ = np.zeros(p)
        self.n_iter_ = lib.omp(Xc, yc, self.coef_, np.zeros(1), 0, best, n, p)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class GramLassoLarsIC(Tagged, RegressorMixin, BaseEstimator):
    """LassoLars with the penalty chosen by AIC or BIC, scikit-learn's
    ``LassoLarsIC``: the whole "lasso" path by the translated
    _lars_path_solver (``examples/kernel-only/lars.scm``, the path
    recorded as lars_path(return_path=True) returns it), then
    scikit-learn's criterion n log(2 pi s^2) + RSS / s^2 + K df at
    each knot, s^2 the OLS noise variance RSS_ols / (n - p - 1).  The
    residual sums are taken from the Gram (|y - X c|^2 = y'y - 2 c'X'y
    + c'X'Xc, the OLS fit by its Cholesky factor) rather than from X
    at every knot as scikit-learn takes them -- the same numbers to
    rounding, without the n x knots product.  n > p + 1, as there.

    Attributes after fit: alpha_, coef_, intercept_, alphas_, criterion_,
    noise_variance_, n_iter_.
    """

    def __init__(self, criterion="aic", *, fit_intercept=True, max_iter=500,
                 noise_variance=None):
        self.criterion, self.fit_intercept, self.max_iter = criterion, fit_intercept, max_iter
        self.noise_variance = noise_variance

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        mi = int(self.max_iter)
        G0 = _gram(Xc)
        cov0 = Xc.T @ yc
        yy = float(yc @ yc)
        path = np.zeros((mi + 1, p))
        alphas = np.zeros(mi + 1)
        coef = np.zeros(p)
        it = _classifier_kernels().lars(
            G0.copy(), cov0.copy(), coef, path, alphas, 1, float(n), 0.0, 1, mi,
            float(np.finfo(np.float64).eps), p)
        cp, al = path[:it + 1], alphas[:it + 1]
        rss = yy - 2.0 * (cp @ cov0) + ((cp @ G0) * cp).sum(axis=1)
        df = (np.abs(cp) > np.finfo(np.float64).eps).sum(axis=1)
        if self.noise_variance is None:
            if n <= p + int(self.fit_intercept):
                raise ValueError(f"n must exceed p (+1 with an intercept) to estimate the "
                                 f"noise variance; got n_samples = {n} for {p} features; "
                                 "pass noise_variance")
            L = np.linalg.cholesky(G0)
            beta = np.linalg.solve(L.T, np.linalg.solve(L, cov0))
            self.noise_variance_ = (yy - 2.0 * beta @ cov0 + beta @ G0 @ beta) / (
                n - p - int(self.fit_intercept))
        else:
            self.noise_variance_ = float(self.noise_variance)
        factor = {"aic": 2.0, "bic": np.log(n)}[self.criterion]
        self.criterion_ = (n * np.log(2 * np.pi * self.noise_variance_)
                           + rss / self.noise_variance_ + factor * df)
        best = int(np.argmin(self.criterion_))
        self.alphas_, self.n_iter_ = al, it
        self.alpha_ = float(al[best])
        self.coef_ = cp[best].copy()
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class WeiszfeldTheilSen(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``TheilSenRegressor`` translated whole
    (``examples/kernel-only/theilsen.scm``): the least squares fit of
    every subset of n_subsamples rows (p + 1 by default: each an exact
    solve, the minimum-norm fit for a singular one, as gelss gives it)
    and the spatial median of the fits by the modified Weiszfeld
    iteration.  The subsets are scikit-learn's: all the combinations
    when there are at most ``max_subpopulation``, else
    ``RandomState(random_state).choice`` draws, made here the same way
    (and on large problems that drawing is most of the time, on both
    sides).

    Attributes after fit: coef_, intercept_, n_iter_, n_subpopulation_,
    breakdown_.
    """

    def __init__(self, *, fit_intercept=True, max_subpopulation=1e4, n_subsamples=None,
                 max_iter=300, tol=1e-3, random_state=None):
        self.fit_intercept, self.max_subpopulation = fit_intercept, max_subpopulation
        self.n_subsamples, self.max_iter, self.tol = n_subsamples, max_iter, tol
        self.random_state = random_state

    def fit(self, X, y):
        from itertools import combinations
        from math import comb
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        fi = 1 if self.fit_intercept else 0
        ns = min(p + fi, n) if self.n_subsamples is None else int(self.n_subsamples)
        total = max(1, comb(n, ns))
        self.n_subpopulation_ = int(min(self.max_subpopulation, total))
        self.breakdown_ = 1 - (0.5 ** (1 / ns) * (n - ns + 1) + ns - 1) / n
        if total <= self.max_subpopulation:
            idx = np.array(list(combinations(range(n), ns)), dtype=np.int32)
        else:
            rs = np.random.RandomState(self.random_state)
            idx = np.array([rs.choice(n, size=ns, replace=False)
                            for _ in range(self.n_subpopulation_)], dtype=np.int32)
        nsub = len(idx)
        w = np.zeros((nsub, p + fi))
        c = np.zeros(p + fi)
        self.n_iter_ = _classifier_kernels().theilsen(X, y, idx, w, c, nsub, ns, fi,
                                                      int(self.max_iter), float(self.tol), p)
        self.intercept_ = float(c[0]) if fi else 0.0
        self.coef_ = c[fi:].copy()
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


class L1LinearSVM(Tagged, ClassifierMixin, BaseEstimator):
    """The L1-regularized L2-loss linear SVM by liblinear's own
    algorithm: ``examples/kernel-only/svm-l1.scm`` translated plainly,
    liblinear's solve_l1r_l2_svc (coordinate descent with a Newton step,
    a line search and shrinking) -- what scikit-learn's
    ``LinearSVC(penalty="l1", dual=False)`` runs, on

        min_w  sum_j |w_j| + C sum_i max(0, 1 - y_i w.x_i)^2,

    the intercept a ones column (``intercept_scaling``) penalised with
    the rest, as liblinear has it.  The coordinate order is random from
    a different generator than liblinear's, so the fit agrees with
    scikit-learn's to its tolerance.  Two classes.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    def __init__(self, C=1.0, tol=1e-4, max_iter=1000, fit_intercept=True,
                 intercept_scaling=1.0, random_state=0):
        self.C, self.tol, self.max_iter = C, tol, max_iter
        self.fit_intercept, self.intercept_scaling = fit_intercept, intercept_scaling
        self.random_state = random_state

    _binary_only = True

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        scaling = float(self.intercept_scaling)
        if self.fit_intercept:
            X = np.hstack([X, np.full((n, 1), scaling)])
        q = X.shape[1]
        w = np.zeros(q)
        # liblinear walks the design by columns
        self.n_iter_ = _classifier_kernels().svm_l1(
            np.ascontiguousarray(X.T), ys, w, float(self.C), float(self.tol), int(self.max_iter),
            _seed(self.random_state), n, q)
        self.coef_ = w[:p].copy()
        self.intercept_ = float(w[p] * scaling) if self.fit_intercept else 0.0
        return self

    def decision_function(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


class L1LogisticRegression(Tagged, ClassifierMixin, BaseEstimator):
    """L1-regularized logistic regression by liblinear's own algorithm.

    ``examples/kernel-only/logistic-l1.scm`` translated plainly:
    liblinear's solve_l1r_lr (newGLMNET: Newton iterations over a
    coordinate-descent subproblem with random order and shrinking, and
    a line search) -- what scikit-learn's
    ``LogisticRegression(l1_ratio=1, solver="liblinear",
    fit_intercept=False)`` runs, on the same problem

        min_w  sum_j |w_j| + C sum_i log(1 + exp(-y_i w.x_i)).

    ``tol`` and ``max_iter`` are LogisticRegression's (the tolerance is
    scaled as liblinear scales it; the cap counts Newton iterations).
    No intercept; two classes.  ``CovLogistic`` solves the same problem
    by majorization over the Gram matrix instead.

    Attributes after fit: classes_, coef_, n_iter_.
    """

    _binary_only = True

    def __init__(self, C=1.0, tol=1e-4, max_iter=100, random_state=0):
        self.C, self.tol, self.max_iter = C, tol, max_iter
        self.random_state = random_state

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        w = np.zeros(p)
        # liblinear walks the design by columns
        self.n_iter_ = _classifier_kernels().logistic_l1(
            np.ascontiguousarray(X.T), ys, w, float(self.C), float(self.tol), int(self.max_iter),
            _seed(self.random_state), n, p)
        self.coef_ = w
        self.intercept_ = 0.0
        return self

    def decision_function(self, X):
        return pred_x(self, X) @ self.coef_

    def predict_proba(self, X):
        p1 = 1.0 / (1.0 + np.exp(-self.decision_function(X)))
        return np.column_stack([1.0 - p1, p1])

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


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
        self._rounds = 0
        for _ in range(max_rounds):
            self._rounds += 1
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


class GramLogisticRegression(Tagged, ClassifierMixin, BaseEstimator):
    """scikit-learn's ``LogisticRegression(l1_ratio=1, solver="liblinear")``
    interface over CovLogistic: the same problem,

        min_w  ||w||_1 + C sum_i log(1 + exp(-y_i (w.x_i + b))),

    solved by majorization over the Gram matrix instead of liblinear's
    Newton steps.  As in liblinear the intercept is the weight of a
    constant column of value ``intercept_scaling`` and is penalized
    with the rest.  ``tol`` is CovLogistic's (the largest coefficient
    move in a round, relative to their size) and ``max_iter`` caps the
    rounds.  Two classes.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    _binary_only = True

    def __init__(self, C=1.0, *, fit_intercept=True, intercept_scaling=1.0, tol=1e-7,
                 max_iter=500):
        self.C, self.fit_intercept, self.intercept_scaling = C, fit_intercept, intercept_scaling
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, classifier=True)
        n = X.shape[0]
        self.classes_, ys = _binary_labels(y)
        s = float(self.intercept_scaling)
        if self.fit_intercept:
            X = np.column_stack([X, np.full(n, s)])
        m = CovLogistic(X, (ys > 0).astype(np.float64))
        lam = 1.0 / (n * float(self.C))
        beta = m._fit_one(np.zeros(m.p), lam, float(self.tol), 200, int(self.max_iter))
        self.n_iter_ = m._rounds
        if self.fit_intercept:
            self.coef_, self.intercept_ = beta[:-1].copy(), float(beta[-1]) * s
        else:
            self.coef_, self.intercept_ = beta, 0.0
        return self

    def decision_function(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_

    def predict_proba(self, X):
        p1 = 1.0 / (1.0 + np.exp(-self.decision_function(X)))
        return np.column_stack([1.0 - p1, p1])

    def predict(self, X):
        z = self.decision_function(X)
        return self.classes_[(z > 0).astype(int)]


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
        self._sweeps = 0
        for _ in range(max_sweeps):
            self._sweeps += 1
            moved = 0.0
            for g, w, L in zip(self.groups, self.wg, self.Lg):
                if L <= 0.0:    # all-zero columns: the group stays at zero
                    continue
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


class GramGroupLasso(Tagged, RegressorMixin, BaseEstimator):
    """A ``Lasso``-style interface over CovGroupLasso: fit(X, y) centres
    the data when ``fit_intercept`` and runs the block descent at
    ``alpha``,

        (1 / 2 n) ||y - X b - b0||^2 + alpha sum_g sqrt(|g|) ||b_g||_2.

    ``groups`` is a list of index arrays partitioning the columns, or
    None for one group per column (the lasso).  ``tol`` is
    CovGroupLasso's and ``max_iter`` its sweep cap.

    Attributes after fit: coef_, intercept_, n_iter_, n_features_in_.
    """

    def __init__(self, alpha=1.0, *, groups=None, fit_intercept=True, tol=1e-8,
                 max_iter=10000):
        self.alpha, self.groups, self.fit_intercept = alpha, groups, fit_intercept
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y)
        n, p = X.shape
        G, c, xm, ym = _centered_gram(X, y, self.fit_intercept)
        groups = [[j] for j in range(p)] if self.groups is None else self.groups
        m = CovGroupLasso(gram=G, corr=c, nobs=n, groups=groups)
        beta, _ = m._fit_one(np.zeros(p), m.c0.copy(), float(self.alpha), float(self.tol),
                             int(self.max_iter))
        self.coef_, self.n_iter_ = beta, m._sweeps
        self.intercept_ = float(ym - xm @ self.coef_)
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_ + self.intercept_


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


class GramMultiTaskElasticNet(Tagged, RegressorMixin, BaseEstimator):
    """scikit-learn's ``MultiTaskElasticNet`` interface over
    CovMultiTaskLasso: fit(X, Y) centres the data when
    ``fit_intercept``, forms the Gram matrix once and runs the row-block
    sweep at ``alpha``.  Y is (n, n_tasks); coef_ is (n_tasks, p) as
    scikit-learn has it.  ``tol`` is CovMultiTaskLasso's and
    ``max_iter`` its sweep cap.

    Attributes after fit: coef_, intercept_, n_iter_, n_features_in_.
    """

    _multi_output = "only"

    def __init__(self, alpha=1.0, *, l1_ratio=0.5, fit_intercept=True, tol=1e-8,
                 max_iter=100000):
        self.alpha, self.l1_ratio, self.fit_intercept = alpha, l1_ratio, fit_intercept
        self.tol, self.max_iter = tol, max_iter

    def fit(self, X, y):
        X, y = fit_xy(self, X, y, multi_output=True)
        if y.ndim != 2:
            raise ValueError("For mono-task outputs, use GramElasticNet or GramLasso; "
                             "y must be (n_samples, n_tasks)")
        n, p = X.shape
        t = y.shape[1]
        G, c, xm, ym = _centered_gram(X, y, self.fit_intercept)
        g = np.ascontiguousarray(G.ravel())
        c = np.ascontiguousarray(c.ravel())
        lam, r = float(self.alpha), float(self.l1_ratio)
        tol, cap = float(self.tol), int(self.max_iter)
        W, prev = np.zeros(p * t), np.empty(p * t)
        swept = 0
        while swept < cap:
            chunk = min(20, cap - swept)
            prev[:] = W
            kernel.mt_descend(g, c, W, lam * r, lam * (1.0 - r), chunk, float(n), p, t)
            swept += chunk
            if np.max(np.abs(W - prev)) < tol * _scale(W):
                break
        W = W.reshape(p, t)
        self.coef_, self.n_iter_ = np.ascontiguousarray(W.T), swept
        self.intercept_ = ym - xm @ W
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_.T + self.intercept_


class GramMultiTaskLasso(GramMultiTaskElasticNet):
    """scikit-learn's ``MultiTaskLasso`` interface over CovMultiTaskLasso:
    GramMultiTaskElasticNet with l1_ratio 1.

    Attributes after fit: coef_, intercept_, n_iter_, n_features_in_.
    """

    def __init__(self, alpha=1.0, *, fit_intercept=True, tol=1e-8, max_iter=100000):
        self.alpha, self.fit_intercept, self.tol, self.max_iter = alpha, fit_intercept, tol, max_iter

    @property
    def l1_ratio(self):
        return 1.0


class CovMultiTaskLassoCV(Tagged, RegressorMixin, BaseEstimator):
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

    _multi_output = "only"

    def __init__(self, cv=5, num=100, eps=1e-3, tol=1e-8, l1_ratio=1.0,
                 force_cpu=False, force_gpu=False, n_jobs=1):
        # Same fold-thread parallelism as CovLassoCV; default sequential.
        self.cv, self.num, self.eps, self.tol = cv, num, eps, tol
        self.l1_ratio, self.force_cpu, self.force_gpu = l1_ratio, force_cpu, force_gpu
        self.n_jobs = n_jobs

    def fit(self, X, Y):
        X, Y = fit_xy(self, X, Y, multi_output=True)
        if Y.ndim != 2:
            raise ValueError("For mono-task outputs, use CovLassoCV; Y must be (n, n_tasks)")
        n = X.shape[0]
        cv, num = int(self.cv), int(self.num)
        tol, l1_ratio = float(self.tol), float(self.l1_ratio)
        full = CovMultiTaskLasso(X, Y)
        self.alphas_ = full.lambda_grid(num=num, eps=float(self.eps),
                                        l1_ratio=l1_ratio)
        bounds = np.linspace(0, n, cv + 1).astype(int)
        self.mse_path_ = np.empty((num, cv))
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
            path = m.fit_path(self.alphas_, tol=tol, l1_ratio=l1_ratio)
            # all validation residuals in one product: (nf, num, T)
            resid = np.tensordot(Xf, path, axes=([1], [1])) - Yf[:, None, :]
            self.mse_path_[:, k] = np.mean(resid * resid, axis=(0, 2))

        if int(self.n_jobs) > 1:
            from concurrent.futures import ThreadPoolExecutor
            with ThreadPoolExecutor(max_workers=int(self.n_jobs)) as ex:
                list(ex.map(one_fold, range(cv)))
        else:
            for k in range(cv):
                one_fold(k)
        return self._finish(full)

    def _fit_gpu(self, X, Y, full, G, C, bounds, n):
        # The grid as one launch, the fold's Gram shared by its
        # problems and nobs absorbed into each problem's lambda as in
        # CovLassoCV; None when the device declined.
        p_, T = full.p, full.n_tasks
        num, cv = int(self.num), int(self.cv)
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
        W = _grid_descend(grams, corrs, lams, p_, T, tol=float(self.tol),
                          l1_ratio=float(self.l1_ratio))
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
        self.coef_ = full.fit(self.alpha_, tol=float(self.tol),
                              l1_ratio=float(self.l1_ratio))
        self.intercept_ = 0.0 if self.coef_.ndim == 1 else np.zeros(self.coef_.shape[1])
        return self

    def predict(self, X):
        return pred_x(self, X) @ self.coef_
