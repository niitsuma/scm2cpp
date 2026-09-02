"""The memory-lean lasso against scikit-learn, and against the Gram form.

    python3 bench/lasso-memory-compare.py --kernel-dir DIR [--cuda-lib SO]

The package's CovLasso trades memory for time: it forms the p x p Gram
matrix once, and every coordinate step after that is O(p) instead of
O(n).  examples/kernel-only/lasso-kernel.scm is the other choice --
the residual-form coordinate descent that keeps only an n-vector
beyond X itself, and reads X twice per coordinate.  That is the
algorithm inside scikit-learn's Lasso(precompute=False), so the two
should run neck and neck; this script checks that, and asks what a GPU
adds to the residual form (bench/resid-cd.cu: the dot product and the
residual update of each coordinate step spread over the whole device,
with a grid barrier between them).

Protocol.  One dense problem per shape, columns AR(1)-correlated
(--corr, default 0.9) so that the descent takes a realistic number of
sweeps rather than three; scikit-learn's own Lasso at
its defaults decides how many sweeps S the problem takes to converge,
and every row then does exactly S sweeps of the same coordinate
descent at the same lambda (sklearn: tol=0, max_iter=S), so a row is
the cost of the bookkeeping, not of a different stopping rule.  BLAS
is pinned to one thread; CPU rows are one core against one core, and
sklearn gets X already in its Fortran layout so no row pays a copy.
Gram rows include forming the Gram matrix.  The last column is the largest
coefficient difference from the sklearn reference.

Each --kernel-dir holds a lasso_kernel.py and liblasso_kernel.so, built by

    racket scm2cpp-file.scm -t scm2c.typ -M lasso_kernel.scm
    g++ -O3 -march=native -std=c++17 -shared -fPIC -I. \\
        -o liblasso_kernel.so lasso_kernel_capi.cpp
"""
import argparse
import ctypes
import os
import sys
import time
import warnings

for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_v, "1")

import numpy as np

from scm2cpp_lasso import kernel as cov_kernel


def build(nobs, p, corr, nnz=8, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.standard_normal((nobs, p))
    # AR(1) correlation across columns: neighbouring features share
    # signal, which is what makes coordinate descent take many sweeps
    for j in range(1, p):
        X[:, j] = corr * X[:, j - 1] + np.sqrt(1.0 - corr * corr) * X[:, j]
    beta = np.zeros(p)
    beta[rng.choice(p, nnz, replace=False)] = rng.standard_normal(nnz) * 2.0
    y = X @ beta + 0.5 * rng.standard_normal(nobs)
    return X, y


def timed(fn, repeat):
    best = float("inf")
    out = None
    for _ in range(repeat):
        t = time.perf_counter()
        out = fn()
        best = min(best, time.perf_counter() - t)
    return best, out


class Cuda:
    def __init__(self, path):
        lib = ctypes.CDLL(path)
        P = ctypes.POINTER(ctypes.c_double)
        lib.resid_cd_new.restype = ctypes.c_void_p
        lib.resid_cd_new.argtypes = [P, P, ctypes.c_int, ctypes.c_int]
        lib.resid_cd_run.restype = ctypes.c_int
        lib.resid_cd_run.argtypes = [ctypes.c_void_p, P, P, ctypes.c_double,
                                     ctypes.c_int]
        lib.resid_cd_blocks.restype = ctypes.c_int
        lib.resid_cd_blocks.argtypes = [ctypes.c_void_p]
        lib.resid_cd_free.argtypes = [ctypes.c_void_p]
        self.lib, self.P = lib, P

    def ptr(self, a):
        return a.ctypes.data_as(self.P)

    def run(self, xflat, xnorm, n, p, lam, iters):
        ctx = self.lib.resid_cd_new(self.ptr(xflat), self.ptr(xnorm), n, p)
        if not ctx:
            raise RuntimeError("no cooperative-launch device")
        beta, resid = np.zeros(p), None
        try:
            resid = self.y.copy()
            rc = self.lib.resid_cd_run(ctx, self.ptr(beta), self.ptr(resid),
                                       lam, iters)
            if rc:
                raise RuntimeError("cuda error %d" % rc)
            blocks = self.lib.resid_cd_blocks(ctx)
        finally:
            self.lib.resid_cd_free(ctx)
        return beta, blocks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", action="append", required=True,
                    help="LABEL=DIR (or DIR); repeatable, one row each")
    ap.add_argument("--cuda-lib")
    ap.add_argument("--shapes", default="1800x200,5000x1000,100000x200,100000x500")
    ap.add_argument("--frac", type=float, default=0.01,
                    help="lambda as a fraction of lambda_max")
    ap.add_argument("--corr", type=float, default=0.9,
                    help="AR(1) correlation between neighbouring columns")
    ap.add_argument("--repeat", type=int, default=3)
    args = ap.parse_args()

    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or "memory-lean", load_kernel(d)))
    from sklearn.exceptions import ConvergenceWarning
    from sklearn.linear_model import Lasso
    # tol=0 rows are meant to run exactly S sweeps; sklearn warns about it
    warnings.simplefilter("ignore", ConvergenceWarning)

    cuda = Cuda(args.cuda_lib) if args.cuda_lib else None

    for shape in args.shapes.split(","):
        nobs, p = (int(s) for s in shape.split("x"))
        X, y = build(nobs, p, args.corr)
        XF = np.asfortranarray(X)          # sklearn's layout, copied once here
        xnorm = np.ascontiguousarray((X * X).sum(axis=0))
        lam = args.frac * float(np.max(np.abs(X.T @ y))) / nobs
        xflat = np.ascontiguousarray(X.T.ravel())      # column major, j*n+i

        ref = Lasso(alpha=lam, fit_intercept=False, precompute=False)
        ref.fit(XF, y)
        S = int(ref.n_iter_)
        bref = ref.coef_
        nnz = int((np.abs(bref) > 0).sum())
        mem_resid = nobs * 8
        mem_gram = p * p * 8
        print("n=%d p=%d corr=%.2g  lambda=%.3g (%.2g*lambda_max)  sklearn "
              "converged in S=%d sweeps, %d nonzero"
              % (nobs, p, args.corr, lam, args.frac, S, nnz))
        print("  extra memory beyond X: residual form %s, Gram form %s"
              % (human(mem_resid), human(mem_gram)))

        rows = []

        def row(name, seconds, beta):
            rows.append((name, seconds, float(np.max(np.abs(beta - bref)))))

        def sk(precompute):
            m = Lasso(alpha=lam, fit_intercept=False, precompute=precompute,
                      tol=0.0, max_iter=S, copy_X=False)
            m.fit(XF, y)
            return m.coef_

        t, b = timed(lambda: sk(False), args.repeat)
        row("sklearn Lasso, residual form (precompute=False)", t, b)

        for label, lasso_kernel in kernels:
            def ours_resid(lasso_kernel=lasso_kernel):
                beta, resid = np.zeros(p), y.copy()
                # the kernel takes a path of penalties; a single fit is the
                # path of length one
                lams, betas = np.array([lam]), np.zeros(p)
                lasso_kernel.lasso(xflat, beta, resid, xnorm, lams, betas,
                                   S, nobs, p, 1)
                return beta

            t, b = timed(ours_resid, args.repeat)
            row("scm2cpp lasso-kernel, residual form (%s)" % label, t, b)

        if cuda is not None:
            cuda.y = y
            try:
                t, (b, blocks) = timed(
                    lambda: cuda.run(xflat, xnorm, nobs, p, lam, S),
                    args.repeat)
                row("scm2cpp residual form + CUDA (%d blocks, X upload "
                    "included)" % blocks, t, b)
            except RuntimeError as e:
                print("  CUDA row skipped: %s" % e)

        t, b = timed(lambda: sk(True), args.repeat)
        row("sklearn Lasso, Gram form (precompute=True)", t, b)

        def ours_gram():
            g = np.ascontiguousarray((X.T @ X).ravel())
            c = np.ascontiguousarray(X.T @ y)
            beta = np.zeros(p)
            cov_kernel.cov_descend(g, c, beta, lam, S, float(nobs), p)
            return beta

        t, b = timed(ours_gram, args.repeat)
        row("scm2cpp CovLasso, Gram form (Gram build included)", t, b)

        for name, sec, gap in rows:
            print("  %-64s %8.3f s   max|dbeta| %.1e" % (name, sec, gap))
        print()


def load_kernel(d):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "lasso_kernel_" + str(abs(hash(d))),
        os.path.join(os.path.abspath(d), "lasso_kernel.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def human(nbytes):
    for unit in ("B", "KB", "MB", "GB"):
        if nbytes < 1024:
            return "%.0f %s" % (nbytes, unit)
        nbytes /= 1024.0
    return "%.1f TB" % nbytes


if __name__ == "__main__":
    main()
