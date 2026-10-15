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
from ._libfind import load_batch_lib, derived_backends, nmf_backends

# the derived kernel's variants that were built, each bound to its own
# library: {'cublas': module, 'blas': module, 'loops': module}
_DERIVED = {}
for _v in derived_backends():
    try:
        _DERIVED[_v] = __import__("scm2cpp_lasso._generated._loader_derived_" + _v,
                                  fromlist=["lasso"])
    except ImportError:
        pass

__all__ = ["CovLasso", "CovRidge", "CovBayesianRidge", "CovLogistic", "CovGroupLasso",
           "LinearSVM", "KernelSVM", "LinearSVR", "KernelSVR", "L1LogisticRegression",
           "CDNMF", "nmf_backend", "CDGraphicalLasso", "LinearRANSAC",
           "SGDLinearClassifier", "SGDLinearRegressor", "SGDPerceptron", "GramOMP", "GramLars", "GramLassoLars", "GramLassoLarsIC",
           "LBFGSLogisticRegression", "LBFGSHuberRegressor",
           "EMGaussianMixture", "CovPCA", "ParallelFastICA", "CovARDRegression",
           "L1LinearSVM",
           "CovMultiTaskLasso", "CovMultiTaskLassoCV", "DerivedLasso",
           "cuda_available", "derived_backend", "kernel"]
__version__ = "0.9.0"

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
                    "scm2cpp_lasso: the derived kernel was not built; "
                    "reinstall the package (pip install --force-reinstall "
                    "scm2cpp-lasso)")
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
        one coefficient in a sweep below which that lambda is done.
        """
        lams = np.ascontiguousarray(lambdas, dtype=np.float64).ravel()
        beta = np.zeros(self.p)
        resid = np.empty(self.nobs)      # filled by the kernel from y
        xnorm = np.empty(self.p)         # the column norms, taken inside
        betas = np.zeros(lams.size * self.p)
        self._kernel.lasso_design(self.X, self.y, resid, xnorm, beta, lams,
                                  betas, int(max_sweeps), float(tol),
                                  self.nobs, self.p, lams.size)
        return betas.reshape(lams.size, self.p)


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


class CovBayesianRidge:
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
        self.max_iter = int(max_iter)
        self.tol = float(tol)
        self.alpha_1, self.alpha_2 = float(alpha_1), float(alpha_2)
        self.lambda_1, self.lambda_2 = float(lambda_1), float(lambda_2)
        self.alpha_init, self.lambda_init = alpha_init, lambda_init
        self.fit_intercept = fit_intercept

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        if X.ndim != 2 or y.ndim != 1 or X.shape[0] != y.size:
            raise ValueError(f"X is {X.shape} and y is {y.shape}; expected "
                             "(n, p) and (n,)")
        n, p = X.shape
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
        for it in range(self.max_iter):
            coef, cc, sse = mean_stats(alpha, lam)
            gamma = float(np.sum(alpha * e / (lam + alpha * e)))
            lam = (gamma + 2 * self.lambda_1) / (cc + 2 * self.lambda_2)
            alpha = (n - gamma + 2 * self.alpha_1) / (sse + 2 * self.alpha_2)
            if it != 0 and float(np.sum(np.abs(old - coef))) < self.tol:
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
        X = np.ascontiguousarray(X, dtype=np.float64)
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
    if classes.size != 2:
        raise ValueError(f"expected two classes, got {classes.size}")
    return classes, np.where(y == classes[1], 1.0, -1.0)


def _seed(random_state):
    # the solvers' Park-Miller generator wants a seed in [1, 2^31 - 2]
    return int(random_state) % 2147483646 + 1


class LinearSVM:
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

    def __init__(self, C=1.0, tol=1e-4, max_iter=1000, random_state=0):
        self.C, self.tol, self.max_iter = float(C), float(tol), int(max_iter)
        self.random_state = random_state

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        w = np.zeros(p)
        alpha = np.zeros(n)
        xnorm = np.zeros(n)
        self.n_iter_ = _classifier_kernels().svm_liblinear(
            X, ys, w, alpha, xnorm, self.C, self.max_iter, self.tol,
            _seed(self.random_state), n, p)
        self.coef_, self.dual_coef_ = w, alpha
        return self

    def decision_function(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_

    def predict(self, X):
        return self.classes_[(self.decision_function(X) > 0).astype(int)]


class _KernelMatrix:
    # the kernel matrix of KernelSVM and KernelSVR, as SVC and SVR take
    # it: rbf (gamma "scale", "auto" or a number), linear, or precomputed
    def _k(self, A, B):
        if self.kernel == "linear":
            return A @ B.T
        if self.kernel == "rbf":
            sa = (A * A).sum(1)[:, None]
            sb = (B * B).sum(1)[None, :]
            return np.exp(-self._gamma * np.maximum(sa + sb - 2.0 * (A @ B.T), 0.0))
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
        X = np.ascontiguousarray(X, dtype=np.float64)
        if self.kernel == "precomputed":
            return X[:, self.support_]
        return self._k(X, self.support_vectors_)


class KernelSVM(_KernelMatrix):
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

    def __init__(self, C=1.0, kernel="rbf", gamma="scale", tol=1e-3, max_iter=-1):
        self.C, self.kernel, self.gamma = float(C), kernel, gamma
        self.tol, self.max_iter = float(tol), int(max_iter)

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        self.classes_, ys = _binary_labels(y)
        n = ys.size
        K = self._train_kernel(X)
        alpha = np.zeros(n)
        rho = np.zeros(1)
        iters = self.max_iter if self.max_iter > 0 else 10_000_000
        self.n_iter_ = _classifier_kernels().svm_smo(
            np.ascontiguousarray(K), ys, alpha, rho, self.C, iters, self.tol, n)
        self.support_ = np.flatnonzero(alpha > 0)
        self.dual_coef_ = (alpha * ys)[self.support_]
        self.intercept_ = -float(rho[0])
        if self.kernel != "precomputed":
            self.support_vectors_ = X[self.support_]
        return self

    def decision_function(self, X):
        return self._support_kernel(X) @ self.dual_coef_ + self.intercept_

    def predict(self, X):
        return self.classes_[(self.decision_function(X) > 0).astype(int)]


class LinearSVR:
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
        self.C, self.epsilon = float(C), float(epsilon)
        self.tol, self.max_iter = float(tol), int(max_iter)
        self.random_state = random_state

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        n, p = X.shape
        w = np.zeros(p)
        beta = np.zeros(n)
        xnorm = np.zeros(n)
        self.n_iter_ = _classifier_kernels().svr_liblinear(
            X, y, w, beta, xnorm, self.C, self.epsilon, self.max_iter, self.tol,
            _seed(self.random_state), n, p)
        self.coef_, self.dual_coef_ = w, beta
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_


class KernelSVR(_KernelMatrix):
    """epsilon-SVR by libsvm's own algorithm, over the whole kernel matrix.

    The same translated SMO solver as KernelSVM (``svm-smo.scm``), set
    up as libsvm's solve_epsilon_svr sets it up: the 2n variables
    alpha and alpha* with linear terms epsilon -/+ y_i.  scikit-learn's
    ``SVR``, with the intercept; ``epsilon=0.1``, ``tol=1e-3`` and the
    kernels as there.  The kernel matrix is held whole.

    Attributes after fit: support_, dual_coef_ (alpha - alpha* over the
    support), intercept_, n_iter_; support_vectors_ unless precomputed.
    """

    def __init__(self, C=1.0, epsilon=0.1, kernel="rbf", gamma="scale", tol=1e-3, max_iter=-1):
        self.C, self.epsilon, self.kernel, self.gamma = float(C), float(epsilon), kernel, gamma
        self.tol, self.max_iter = float(tol), int(max_iter)

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        n = y.size
        K = self._train_kernel(X)
        beta = np.zeros(n)
        rho = np.zeros(1)
        iters = self.max_iter if self.max_iter > 0 else 10_000_000
        self.n_iter_ = _classifier_kernels().svr_smo(
            np.ascontiguousarray(K), y, beta, rho, self.C, self.epsilon, iters, self.tol, n)
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
        raise ImportError("scm2cpp_lasso: no variant of the derived NMF was built")
    if "cublas" in built and cuda_available():
        return "cublas"
    cpu = [v for v in built if v != "cublas"]
    return cpu[0] if cpu else built[0]


class CDNMF:
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

    Attributes after fit: components_ (H, k x p), n_iter_,
    reconstruction_err_ (||X - W H||_F).
    """

    def __init__(self, n_components, *, init="random", tol=1e-4, max_iter=200,
                 random_state=None, backend=None):
        self.n_components = int(n_components)
        self.init, self.tol, self.max_iter = init, float(tol), int(max_iter)
        self.random_state = random_state
        self.backend = backend

    def _lib(self):
        import importlib
        v = self.backend or nmf_backend()
        return importlib.import_module(f"{__name__}._generated._loader_nmf_{v}")

    def fit_transform(self, X, W=None, H=None):
        X = np.ascontiguousarray(X, dtype=np.float64)
        if X.min() < 0:
            raise ValueError("NMF needs a non-negative X")
        n, p = X.shape
        k = self.n_components
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
        self.n_iter_ = self._lib().nmf(X, XT, W, HT, self.max_iter, self.tol, n, p, k)
        self.components_ = np.ascontiguousarray(HT.T)
        self.reconstruction_err_ = float(np.linalg.norm(X - W @ self.components_))
        return W

    def fit(self, X, W=None, H=None):
        self.fit_transform(X, W, H)
        return self


class CDGraphicalLasso:
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
        self.alpha, self.tol, self.enet_tol = float(alpha), float(tol), float(enet_tol)
        self.max_iter, self.assume_centered = int(max_iter), assume_centered

    def fit(self, X):
        import importlib
        from ._libfind import gramops_backend
        X = np.asarray(X, dtype=np.float64)
        n, p = X.shape
        self.location_ = np.zeros(p) if self.assume_centered else X.mean(axis=0)
        Xc = X - self.location_
        emp = np.ascontiguousarray(Xc.T @ Xc / n)
        lib = importlib.import_module(f"{__name__}._generated._loader_gramops_{gramops_backend()}")
        self.covariance_ = np.zeros((p, p))
        self.precision_ = np.zeros((p, p))
        self.n_iter_ = lib.graphical_lasso(emp, self.covariance_, self.precision_, self.alpha,
                                           self.max_iter, self.tol, self.enet_tol, p)
        if not np.isfinite(self.precision_).all():
            raise FloatingPointError("the system is too ill-conditioned for this solver")
        return self


class LinearRANSAC:
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
        self.max_trials, self.stop_probability = int(max_trials), float(stop_probability)
        self.random_state = random_state

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        n, p = X.shape
        ms = p + 1 if self.min_samples is None else int(self.min_samples)
        thr = (float(np.median(np.abs(y - np.median(y)))) if self.residual_threshold is None
               else float(self.residual_threshold))
        rs = np.random.RandomState(self.random_state)
        try:
            from sklearn.utils.random import sample_without_replacement
            draw = lambda: sample_without_replacement(n, ms, random_state=rs)
        except ImportError:
            draw = lambda: rs.choice(n, ms, replace=False)
        subsets = np.array([draw() for _ in range(self.max_trials)], dtype=np.float64)
        coef = np.zeros(p)
        mask = np.zeros(n)
        out = np.zeros(1)
        self.n_trials_ = _classifier_kernels().ransac(
            X, y, subsets, coef, mask, out, self.max_trials, ms, thr, self.stop_probability, n, p)
        self.coef_, self.intercept_ = coef, float(out[0])
        self.inlier_mask_ = mask.astype(bool)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


def _center(X, y, fit_intercept):
    X = np.ascontiguousarray(X, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    if fit_intercept:
        xm, ym = X.mean(axis=0), float(y.mean())
        return np.ascontiguousarray(X - xm), y - ym, xm, ym
    return X, y, np.zeros(X.shape[1]), 0.0


_SGD_LOSS = {"hinge": 0, "squared_error": 1, "perceptron": 2, "epsilon_insensitive": 3}
_SGD_LR = {"optimal": 0, "invscaling": 1, "constant": 2, "pa1": 3, "pa2": 4}


class _SGDLinear:
    def __init__(self, *, loss, penalty="l2", alpha=1e-4, max_iter=1000, tol=1e-3,
                 n_iter_no_change=5, fit_intercept=True, learning_rate, eta0, power_t,
                 epsilon=0.1):
        self.loss, self.penalty, self.alpha = loss, penalty, float(alpha)
        self.max_iter, self.tol = int(max_iter), float(tol)
        self.n_iter_no_change, self.fit_intercept = int(n_iter_no_change), fit_intercept
        self.learning_rate, self.eta0, self.power_t = learning_rate, float(eta0), float(power_t)
        self.epsilon = float(epsilon)

    def _run(self, X, y):
        if self.loss not in _SGD_LOSS or self.learning_rate not in _SGD_LR:
            raise ValueError("loss is one of %s, learning_rate one of %s"
                             % (sorted(_SGD_LOSS), sorted(_SGD_LR)))
        if self.penalty not in ("l2", None):
            raise ValueError("penalty is 'l2' or None")
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        w = np.zeros(p)
        out = np.zeros(1)
        self.n_iter_ = _classifier_kernels().sgd(
            X, np.ascontiguousarray(y, dtype=np.float64), w, out,
            _SGD_LOSS[self.loss], _SGD_LR[self.learning_rate],
            1 if self.penalty == "l2" else 0, self.alpha, self.eta0, self.power_t,
            self.epsilon, self.max_iter, self.tol, self.n_iter_no_change,
            1 if self.fit_intercept else 0, n, p)
        self.coef_, self.intercept_ = w, float(out[0])
        return self

    def decision_function(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


class SGDLinearClassifier(_SGDLinear):
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
        super().__init__(loss=loss, penalty=penalty, alpha=alpha, max_iter=max_iter,
                         tol=tol, n_iter_no_change=n_iter_no_change,
                         fit_intercept=fit_intercept, learning_rate=learning_rate,
                         eta0=eta0, power_t=power_t)

    def fit(self, X, y):
        self.classes_, ys = _binary_labels(y)
        return self._run(X, ys)

    def predict(self, X):
        return self.classes_[(self.decision_function(X) > 0).astype(int)]


class SGDLinearRegressor(_SGDLinear):
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
        super().__init__(loss=loss, penalty=penalty, alpha=alpha, max_iter=max_iter,
                         tol=tol, n_iter_no_change=n_iter_no_change,
                         fit_intercept=fit_intercept, learning_rate=learning_rate,
                         eta0=eta0, power_t=power_t, epsilon=epsilon)

    def fit(self, X, y):
        return self._run(X, y)

    def predict(self, X):
        return self.decision_function(X)


class SGDPerceptron(SGDLinearClassifier):
    """scikit-learn's Perceptron: SGDClassifier with the perceptron's
    hinge (threshold 0), no penalty and the constant step eta0 = 1, by
    the same translated _plain_sgd, shuffle=False.

    Attributes after fit: classes_, coef_, intercept_, n_iter_.
    """

    def __init__(self, *, max_iter=1000, tol=1e-3, n_iter_no_change=5, fit_intercept=True,
                 eta0=1.0):
        super().__init__(loss="perceptron", penalty=None, max_iter=max_iter, tol=tol,
                         n_iter_no_change=n_iter_no_change, fit_intercept=fit_intercept,
                         learning_rate="constant", eta0=eta0)


class GramOMP:
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
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        k = max(int(0.1 * p), 1) if self.n_nonzero_coefs is None else int(self.n_nonzero_coefs)
        lib = importlib.import_module(f"{__name__}._generated._loader_gramops_{gramops_backend()}")
        self.coef_ = np.zeros(p)
        self.n_iter_ = lib.omp(Xc, yc, self.coef_, k, n, p)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


def _gramops_kernels():
    import importlib
    from ._libfind import gramops_backend
    return importlib.import_module(f"{__name__}._generated._loader_gramops_{gramops_backend()}")


class LBFGSLogisticRegression:
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
        X = np.ascontiguousarray(X, dtype=np.float64)
        self.classes_, yi = np.unique(np.asarray(y), return_inverse=True)
        n, p = X.shape
        nc = len(self.classes_)
        if nc < 2:
            raise ValueError("LBFGSLogisticRegression needs at least two classes")
        multi = 1 if nc > 2 else 0
        k = nc if multi else 1
        coef = np.zeros(k * (p + 1))
        out = np.zeros(2)
        it = _gramops_kernels().logistic_lbfgs(
            X, yi.astype(np.float64), coef, out, float(self.C), int(self.max_iter),
            float(self.tol), multi, 1 if self.fit_intercept else 0, n, p, k)
        self.coef_ = coef[:k * p].reshape(k, p).copy()
        self.intercept_ = coef[k * p:].copy()
        self.n_iter_ = np.array([min(it, self.max_iter)])
        return self

    def decision_function(self, X):
        z = np.ascontiguousarray(X, dtype=np.float64) @ self.coef_.T + self.intercept_
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


class LBFGSHuberRegressor:
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
        X = np.ascontiguousarray(X, dtype=np.float64)
        y = np.ascontiguousarray(y, dtype=np.float64)
        n, p = X.shape
        coef = np.zeros(p + 2)
        coef[-1] = 1.0
        out = np.zeros(2)
        it = _gramops_kernels().huber(
            X, y, coef, out, float(self.epsilon), float(self.alpha), int(self.max_iter),
            float(self.tol), 1 if self.fit_intercept else 0, n, p)
        self.coef_ = coef[:p].copy()
        self.intercept_ = float(coef[p])
        self.scale_ = float(coef[p + 1])
        self.n_iter_ = min(it, self.max_iter)
        self.outliers_ = np.abs(y - X @ self.coef_ - self.intercept_) > self.scale_ * self.epsilon
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


class EMGaussianMixture:
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
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        k = int(self.n_components)
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
        it = _gramops_kernels().gmm(X, resp, self.weights_, self.means_,
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
        X = np.ascontiguousarray(X, dtype=np.float64)
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


class CovPCA:
    """PCA through the covariance's eigenvectors, scikit-learn's
    ``PCA(svd_solver="covariance_eigh")`` -- what its "auto" picks for a
    tall design (p <= 1000, n >= 10 p) -- translated whole
    (``examples/kernel-only/pca.scm``: X'X by dsyrk where a CBLAS links,
    the eigenproblem by Householder reduction and QL iteration in the
    subset, svd_flip's signs).  Faster than scikit-learn up to p of
    about 100; at several hundred features LAPACK's blocked eigensolver
    wins.

    Attributes after fit: components_, explained_variance_,
    explained_variance_ratio_, singular_values_, mean_, noise_variance_,
    n_components_.
    """

    def __init__(self, n_components=None):
        self.n_components = n_components

    def fit(self, X, y=None):
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        comps = np.zeros((p, p)); ev = np.zeros(p); sv = np.zeros(p); mean = np.zeros(p)
        _gramops_kernels().pca(X, comps, ev, sv, mean, n, p)
        k = min(n, p) if self.n_components is None else int(self.n_components)
        self.n_components_ = k
        self.mean_ = mean
        self.components_ = comps[:k].copy()
        self.explained_variance_ = ev[:k].copy()
        self.explained_variance_ratio_ = ev[:k] / ev.sum()
        self.singular_values_ = sv[:k].copy()
        self.noise_variance_ = float(ev[k:].mean()) if k < min(n, p) else 0.0
        return self

    def transform(self, X):
        return (np.asarray(X, dtype=np.float64) - self.mean_) @ self.components_.T

    def fit_transform(self, X, y=None):
        return self.fit(X).transform(X)


class ParallelFastICA:
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
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        k = min(n, p) if self.n_components is None else min(int(self.n_components), n, p)
        if self.w_init is None:
            w0 = np.random.RandomState(self.random_state).normal(size=(k, k))
        else:
            w0 = np.asarray(self.w_init, dtype=np.float64)
        w0 = np.ascontiguousarray(w0)
        self.components_ = np.zeros((k, p)); self.whitening_ = np.zeros((k, p))
        self._unmixing = np.zeros((k, k)); self.mean_ = np.zeros(p)
        self.n_iter_ = _gramops_kernels().fastica(
            X, w0, self.components_, self.whitening_, self._unmixing, self.mean_,
            int(self.max_iter), float(self.tol), n, p, k)
        self.mixing_ = np.linalg.pinv(self.components_)
        return self

    def transform(self, X):
        return (np.asarray(X, dtype=np.float64) - self.mean_) @ self.components_.T

    def fit_transform(self, X, y=None):
        return self.fit(X).transform(X)


class CovARDRegression:
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
        self.max_iter, self.tol = int(max_iter), float(tol)
        self.alpha_1, self.alpha_2, self.lambda_1, self.lambda_2 = alpha_1, alpha_2, lambda_1, lambda_2
        self.threshold_lambda, self.fit_intercept, self.hoist = threshold_lambda, fit_intercept, hoist

    def fit(self, X, y):
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        if n < p:
            raise ValueError("CovARDRegression is the n >= p route (_update_sigma)")
        self.coef_ = np.zeros(p)
        self.lambda_ = np.zeros(p)
        sigma = np.zeros(p * p)
        out = np.zeros(2)
        self.n_iter_ = _gramops_kernels().ard(
            Xc, np.ascontiguousarray(yc), self.coef_, sigma, self.lambda_, out,
            self.max_iter, self.tol, float(self.alpha_1), float(self.alpha_2),
            float(self.lambda_1), float(self.lambda_2), float(self.threshold_lambda),
            1 if self.hoist else 0, n, p)
        k = int(out[1])
        self.alpha_ = float(out[0])
        self.sigma_ = sigma[:k * k].reshape(k, k).copy()
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


class _GramLarsBase:
    def _fit_lars(self, X, y, method, alpha, max_iter):
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        G = np.ascontiguousarray(Xc.T @ Xc)
        cov = Xc.T @ yc
        self.coef_ = np.zeros(p)
        self.n_iter_ = _classifier_kernels().lars(
            G, cov, self.coef_, np.zeros(1), np.zeros(1), 0, float(n), float(alpha), method,
            int(max_iter), float(np.finfo(np.float64).eps), p)
        self.intercept_ = ym - float(xm @ self.coef_)
        return self

    def predict(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


class GramLars(_GramLarsBase):
    """Least angle regression, scikit-learn's _lars_path_solver with a
    Gram translated (``examples/kernel-only/lars.scm``, method "lar").
    ``Lars`` takes the Gram route for n > p (precompute="auto"); here it
    is taken always, the Gram X'X formed in numpy.  ``n_nonzero_coefs``
    defaults to 500, as there.

    Attributes after fit: coef_, intercept_, n_iter_.
    """

    def __init__(self, *, n_nonzero_coefs=500, fit_intercept=True):
        self.n_nonzero_coefs, self.fit_intercept = int(n_nonzero_coefs), fit_intercept

    def fit(self, X, y):
        return self._fit_lars(X, y, 0, 0.0, self.n_nonzero_coefs)


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
        self.alpha, self.max_iter, self.fit_intercept = float(alpha), int(max_iter), fit_intercept

    def fit(self, X, y):
        return self._fit_lars(X, y, 1, self.alpha, self.max_iter)


class GramLassoLarsIC:
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
        self.criterion, self.fit_intercept, self.max_iter = criterion, fit_intercept, int(max_iter)
        self.noise_variance = noise_variance

    def fit(self, X, y):
        Xc, yc, xm, ym = _center(X, y, self.fit_intercept)
        n, p = Xc.shape
        G0 = np.ascontiguousarray(Xc.T @ Xc)
        cov0 = Xc.T @ yc
        yy = float(yc @ yc)
        path = np.zeros((self.max_iter + 1, p))
        alphas = np.zeros(self.max_iter + 1)
        coef = np.zeros(p)
        it = _classifier_kernels().lars(
            G0.copy(), cov0.copy(), coef, path, alphas, 1, float(n), 0.0, 1, self.max_iter,
            float(np.finfo(np.float64).eps), p)
        cp, al = path[:it + 1], alphas[:it + 1]
        rss = yy - 2.0 * (cp @ cov0) + np.einsum("sj,jk,sk->s", cp, G0, cp)
        df = (np.abs(cp) > np.finfo(np.float64).eps).sum(axis=1)
        if self.noise_variance is None:
            if n <= p + int(self.fit_intercept):
                raise ValueError("n must exceed p (+1 with an intercept) to estimate the "
                                 "noise variance; pass noise_variance")
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
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_


class L1LinearSVM:
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
        self.C, self.tol, self.max_iter = float(C), float(tol), int(max_iter)
        self.fit_intercept, self.intercept_scaling = fit_intercept, float(intercept_scaling)
        self.random_state = random_state

    def fit(self, X, y):
        X = np.asarray(X, dtype=np.float64)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        if self.fit_intercept:
            X = np.hstack([X, np.full((n, 1), self.intercept_scaling)])
        q = X.shape[1]
        w = np.zeros(q)
        # liblinear walks the design by columns
        self.n_iter_ = _classifier_kernels().svm_l1(
            np.ascontiguousarray(X.T), ys, w, self.C, self.tol, self.max_iter,
            _seed(self.random_state), n, q)
        self.coef_ = w[:p].copy()
        self.intercept_ = float(w[p] * self.intercept_scaling) if self.fit_intercept else 0.0
        return self

    def decision_function(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_ + self.intercept_

    def predict(self, X):
        return self.classes_[(self.decision_function(X) > 0).astype(int)]


class L1LogisticRegression:
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

    def __init__(self, C=1.0, tol=1e-4, max_iter=100, random_state=0):
        self.C, self.tol, self.max_iter = float(C), float(tol), int(max_iter)
        self.random_state = random_state

    def fit(self, X, y):
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, p = X.shape
        self.classes_, ys = _binary_labels(y)
        w = np.zeros(p)
        # liblinear walks the design by columns
        self.n_iter_ = _classifier_kernels().logistic_l1(
            np.ascontiguousarray(X.T), ys, w, self.C, self.tol, self.max_iter,
            _seed(self.random_state), n, p)
        self.coef_ = w
        return self

    def decision_function(self, X):
        return np.ascontiguousarray(X, dtype=np.float64) @ self.coef_

    def predict_proba(self, X):
        p1 = 1.0 / (1.0 + np.exp(-self.decision_function(X)))
        return np.column_stack([1.0 - p1, p1])

    def predict(self, X):
        return self.classes_[(self.decision_function(X) > 0).astype(int)]


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
