"""The derived SVM against scikit-learn, linear and kernel.

    python3 bench/svm-compare.py --liblinear-dir DIR --kernel-dir DIR [--kernel-dir DIR ..]
                                 --dual-dir DIR [--linear N,P ..] [--rbf N,P ..] [--best B]

--liblinear-dir holds svm_liblinear.py and libsvm_liblinear.so built
from examples/kernel-only/svm-liblinear.scm with -M: liblinear's
solver whole (random order, shrinking), the same algorithm LinearSVC
runs, translated plainly.  Each --kernel-dir holds svm_kernel.py and libsvm_kernel.so built from
examples/kernel-only/svm-kernel.scm with -M (plainly, or with --derive
--blas / --cublas, which differ only where n < p: the derived kernel
takes the primal sweep as written otherwise); --dual-dir holds
svm_dual.py and libsvm_dual.so from svm-dual.scm, the kernel-form
sweep for any K.  A directory label may be given as LABEL=DIR.

Linear: y = sign(X w* + noise) on a standard-normal design, C = 1,
no intercept.  Every solver stops when a sweep's projected gradients
span no more than --tol (liblinear's test; LinearSVC's tol) or after
--iters sweeps (LinearSVC's max_iter, default 1000; it may report
non-convergence and stop there); the objective says what each
reached.  Ours is the primal problem exactly as LinearSVC with
fit_intercept=False solves it (both are liblinear's dual coordinate
descent; liblinear adds shrinking and a random order), so the primal
objective 1/2 ||w||^2 + C sum max(0, 1 - y w.x) is comparable and is
printed beside the time.  SVC(kernel='linear') is libsvm's SMO and
always fits an intercept: its time is given for scale.

Kernel (RBF, gamma = 1/p): ours builds K in numpy (O(n^2 p), timed
in) and runs the kernel-form sweep; SVC(kernel='rbf') and
SVC(kernel='precomputed') on the same K are the references.  libsvm
solves the problem with an intercept and the constraint sum alpha_i
y_i = 0, ours without, so the objectives are not the same number;
the held-out accuracy on 2,000 fresh rows is printed for both.
"""
import argparse
import importlib.util
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time
import warnings
from pathlib import Path

import numpy as np


def load(d, base):
    spec = importlib.util.spec_from_file_location(base + "_" + str(abs(hash(d))), Path(d) / (base + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def best_of(fn, k):
    best, out = None, None
    for _ in range(k):
        t = time.perf_counter()
        out = fn()
        dt = time.perf_counter() - t
        best = dt if best is None else min(best, dt)
    return out, best


def primal(w, X, y, C):
    return 0.5 * float(w @ w) + C * float(np.maximum(0.0, 1.0 - y * (X @ w)).sum())


def rbf(A, B, gamma):
    sa = (A * A).sum(1)[:, None]
    sb = (B * B).sum(1)[None, :]
    return np.exp(-gamma * np.maximum(sa + sb - 2.0 * (A @ B.T), 0.0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--liblinear-dir")
    ap.add_argument("--kernel-dir", action="append", default=[])
    ap.add_argument("--dual-dir")
    ap.add_argument("--linear", action="append", default=[])
    ap.add_argument("--rbf", action="append", default=[])
    ap.add_argument("--best", type=int, default=3)
    ap.add_argument("--C", type=float, default=1.0)
    ap.add_argument("--tol", type=float, default=1e-4)
    ap.add_argument("--iters", type=int, default=1000)
    args = ap.parse_args()
    from sklearn.svm import LinearSVC, SVC
    from sklearn.exceptions import ConvergenceWarning
    warnings.simplefilter("ignore", ConvergenceWarning)

    kernels = []
    for spec in args.kernel_dir:
        label, _, d = spec.rpartition("=")
        kernels.append((label or Path(d).name, load(d, "svm_kernel")))
    dual = load(args.dual_dir, "svm_dual") if args.dual_dir else None
    lib = load(args.liblinear_dir, "svm_liblinear") if args.liblinear_dir else None
    C, B = args.C, args.best
    rng = np.random.default_rng(0)

    for spec in args.linear or ["100000,200"]:
        n, p = map(int, spec.split(","))
        X = rng.standard_normal((n, p))
        wstar = rng.standard_normal(p) / np.sqrt(p)
        y = np.sign(X @ wstar + 0.5 * rng.standard_normal(n))
        print(f"linear SVM, n={n} p={p}, C={C}, best of {B}, one core", flush=True)
        if lib is not None:
            def ours_lib():
                w = np.zeros(p); alpha = np.zeros(n); xnorm = np.zeros(n)
                s = lib.svm_liblinear(X, y, w, alpha, xnorm, C, args.iters, args.tol, 1, n, p)
                return w, s
            (w, s), t = best_of(ours_lib, B)
            print("  %-44s %8.3f s   primal objective %.6g   sweeps %d" % ("svm-liblinear.scm (plain)", t, primal(w, X, y, C), s), flush=True)
        for label, k in kernels:
            def ours():
                w = np.zeros(p); alpha = np.zeros(n); xnorm = np.zeros(n)
                k.svm(X, y, w, alpha, xnorm, C, args.iters, args.tol, n, p)
                return w
            w, t = best_of(ours, B)
            print("  %-44s %8.3f s   primal objective %.6g" % ("svm-kernel.scm (%s)" % label, t, primal(w, X, y, C)), flush=True)
        def skl():
            return LinearSVC(loss="hinge", dual=True, C=C, tol=args.tol, max_iter=args.iters, fit_intercept=False).fit(X, y)
        m, t = best_of(skl, B)
        print("  %-44s %8.3f s   primal objective %.6g   sweeps %d" % ("sklearn LinearSVC(hinge, dual)", t, primal(m.coef_.ravel(), X, y, C), m.n_iter_), flush=True)
        if n <= 10_000 and n * p <= 20_000_000:
            _, t = best_of(lambda: SVC(kernel="linear", C=C).fit(X, y), 1)
            print("  %-44s %8.3f s   (libsvm, with intercept)" % ("sklearn SVC(kernel='linear')", t), flush=True)
        print()

    for spec in args.rbf or ["5000,50"]:
        n, p = map(int, spec.split(","))
        X = rng.standard_normal((n, p))
        Xt = rng.standard_normal((2000, p))
        f = lambda Z: np.sin(Z[:, 0] * 2.0) + Z[:, 1] * Z[:, 2] - 0.5 * Z[:, 3] ** 2
        y = np.sign(f(X) + 0.3 * rng.standard_normal(n)); yt = np.sign(f(Xt))
        gamma = 1.0 / p
        print(f"RBF SVM, n={n} p={p}, gamma=1/p, C={C}, best of {B}, one core")
        if dual is not None:
            def ours():
                K = rbf(X, X, gamma)
                alpha = np.zeros(n); c = np.zeros(n)
                dual.svm_dual(K, y, alpha, c, C, args.iters, args.tol, n)
                return alpha
            alpha, t = best_of(ours, B)
            acc = float(np.mean(np.sign(rbf(Xt, X, gamma) @ (alpha * y)) == yt))
            print("  %-44s %8.3f s   test accuracy %.3f" % ("svm-dual.scm on numpy's K, tol %g" % args.tol, t, acc))
        m, t = best_of(lambda: SVC(kernel="rbf", gamma=gamma, C=C).fit(X, y), B)
        print("  %-44s %8.3f s   test accuracy %.3f" % ("sklearn SVC(kernel='rbf')", t, float(np.mean(m.predict(Xt) == yt))))
        def pre():
            K = rbf(X, X, gamma)
            return SVC(kernel="precomputed", C=C).fit(K, y)
        m, t = best_of(pre, B)
        print("  %-44s %8.3f s   test accuracy %.3f" % ("sklearn SVC(kernel='precomputed'), K included", t, float(np.mean(m.predict(rbf(Xt, X, gamma)) == yt))))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
