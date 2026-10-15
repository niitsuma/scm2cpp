"""The package's classifiers against scikit-learn: agreement and time.

    python3 check-classifiers.py [--best B] [--quick]

Run in the venv the package is installed in, after a reinstall.  Each
row fits the same problem with the same algorithm on both sides --
LinearSVM against LinearSVC(loss="hinge", dual=True), KernelSVM
against SVC (rbf, and precomputed on the same K), L1LogisticRegression
against LogisticRegression(l1_ratio=1, solver="liblinear") -- with
fit_intercept=False where scikit-learn offers it, at the same tol
and iteration cap.  Printed: the time of each fit (best of B, one
core), the objective or the dual objective on both sides, and the
agreement of the predictions.  Both sides stop at a tolerance (or,
for the linear SVM on tall data, at the sweep cap), so the objectives
agree to that, not to rounding; the check exits non-zero when one
differs by more than 0.5% relative or the predictions disagree on more
than 2% of the rows.
"""
import argparse
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import sys
import time
import warnings

import numpy as np

from scm2cpp_lasso import KernelSVM, L1LogisticRegression, LinearSVM


def best_of(fn, k):
    best, out = None, None
    for _ in range(k):
        t = time.perf_counter()
        out = fn()
        dt = time.perf_counter() - t
        best = dt if best is None else min(best, dt)
    return out, best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--best", type=int, default=3)
    ap.add_argument("--quick", action="store_true")
    args = ap.parse_args()
    from sklearn.svm import SVC, LinearSVC
    from sklearn.linear_model import LogisticRegression
    warnings.simplefilter("ignore")
    B = args.best
    bad = 0

    def report(label, ta, ts, oa, os_, agree):
        nonlocal bad
        rel = abs(oa - os_) / max(abs(os_), 1e-300)
        flag = ""
        if rel > 5e-3 or agree < 0.98:
            bad += 1
            flag = "   <-- disagrees"
        print("  %-26s %8.3fs %8.3fs %5.1fx   objective %.8g / %.8g   same predictions %.1f%%%s"
              % (label, ta, ts, ts / ta, oa, os_, 100 * agree, flag), flush=True)

    rng = np.random.default_rng(0)
    print("LinearSVM vs LinearSVC(hinge, dual), C=1, tol 1e-4, at most 1000 sweeps  (ours, sklearn)")
    for n, p in ([(5000, 200)] if args.quick else [(5000, 200), (100000, 200), (2000, 20000)]):
        X = rng.standard_normal((n, p))
        y = np.sign(X @ (rng.standard_normal(p) / np.sqrt(p)) + 0.5 * rng.standard_normal(n))
        primal = lambda w: 0.5 * float(w @ w) + float(np.maximum(0, 1 - y * (X @ w)).sum())
        a, ta = best_of(lambda: LinearSVM(C=1.0, tol=1e-4, max_iter=1000).fit(X, y), B)
        s, ts = best_of(lambda: LinearSVC(loss="hinge", dual=True, C=1.0, tol=1e-4, max_iter=1000,
                                          fit_intercept=False).fit(X, y), B)
        report("%d x %d" % (n, p), ta, ts, primal(a.coef_), primal(s.coef_.ravel()),
               float(np.mean(a.predict(X) == s.predict(X))))

    print("KernelSVM vs SVC, rbf, gamma 1/p, C=1, tol 1e-3  (dual objective; ours includes building K)")
    for n in ([2000] if args.quick else [2000, 5000, 10000]):
        p = 50
        X = rng.standard_normal((n, p))
        f = lambda Z: np.sin(Z[:, 0] * 2.0) + Z[:, 1] * Z[:, 2] - 0.5 * Z[:, 3] ** 2
        y = np.sign(f(X) + 0.3 * rng.standard_normal(n))
        g = 1.0 / p
        a, ta = best_of(lambda: KernelSVM(C=1.0, gamma=g, tol=1e-3).fit(X, y), B)
        s, ts = best_of(lambda: SVC(C=1.0, gamma=g, tol=1e-3).fit(X, y), B)
        K = a._k(X, X)
        def dual(sup, coef):
            ay = np.zeros(n)
            ay[sup] = coef
            return 0.5 * float(ay @ K @ ay) - float(np.abs(ay).sum())
        report("%d x %d" % (n, p), ta, ts, dual(a.support_, a.dual_coef_),
               dual(s.support_, s.dual_coef_.ravel()), float(np.mean(a.predict(X) == s.predict(X))))
        _, tp = best_of(lambda: SVC(kernel="precomputed", C=1.0, tol=1e-3).fit(a._k(X, X), y), B)
        print("  %-26s %8s %8.3fs %5.1fx   (SVC(kernel='precomputed'), K included)" % ("", "", tp, tp / ta))

    print("L1LogisticRegression vs LogisticRegression(liblinear, L1), tol 1e-4, at most 100 Newton  (ours, sklearn)")
    for n, p, C in ([(5000, 200, 0.1)] if args.quick else
                    [(5000, 200, 0.1), (20000, 500, 0.05), (100000, 200, 0.05)]):
        X = rng.standard_normal((n, p))
        b = np.zeros(p)
        q = max(1, p // 20)
        b[rng.choice(p, q, replace=False)] = 2.0 * rng.standard_normal(q)
        y = np.where(X @ b + 0.5 * rng.standard_normal(n) > 0, 1.0, -1.0)
        obj = lambda w: float(np.abs(w).sum() + C * np.logaddexp(0.0, -y * (X @ w)).sum())
        a, ta = best_of(lambda: L1LogisticRegression(C=C, tol=1e-4, max_iter=100).fit(X, y), B)
        s, ts = best_of(lambda: LogisticRegression(l1_ratio=1.0, solver="liblinear", C=C, tol=1e-4,
                                                   max_iter=100, fit_intercept=False).fit(X, y), B)
        report("%d x %d, C=%g" % (n, p, C), ta, ts, obj(a.coef_), obj(s.coef_.ravel()),
               float(np.mean(a.predict(X) == s.predict(X))))
    print("all agree" if bad == 0 else f"{bad} row(s) disagree")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
