"""The package's classifiers against scikit-learn: agreement and time.

    python3 check-classifiers.py [--best B] [--quick]

Run in the venv the package is installed in, after a reinstall.  Each
row fits the same problem with the same algorithm on both sides --
LinearSVM against LinearSVC(loss="hinge", dual=True), KernelSVM
against SVC (rbf, and precomputed on the same K), LinearSVR against
LinearSVR(loss="epsilon_insensitive"), KernelSVR against SVR (rbf),
L1LogisticRegression against LogisticRegression(l1_ratio=1,
solver="liblinear"), CDNMF against NMF(solver="cd") from the same
random start -- with
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

from scm2cpp_lasso import CDNMF, KernelSVM, KernelSVR, L1LogisticRegression, LinearSVM, LinearSVR, nmf_backend


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
    ap.add_argument("--only", choices=["svm", "svr", "logistic", "nmf"])
    args = ap.parse_args()
    from sklearn.svm import SVC, SVR, LinearSVC
    from sklearn.svm import LinearSVR as SkLinearSVR
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
    want = lambda part: args.only in (None, part)
    if want("svm"):
        print("LinearSVM vs LinearSVC(hinge, dual), C=1, tol 1e-4, at most 1000 sweeps  (ours, sklearn)")
    for n, p in ([] if not want("svm") else
                 [(5000, 200)] if args.quick else [(5000, 200), (100000, 200), (2000, 20000)]):
        X = rng.standard_normal((n, p))
        y = np.sign(X @ (rng.standard_normal(p) / np.sqrt(p)) + 0.5 * rng.standard_normal(n))
        primal = lambda w: 0.5 * float(w @ w) + float(np.maximum(0, 1 - y * (X @ w)).sum())
        a, ta = best_of(lambda: LinearSVM(C=1.0, tol=1e-4, max_iter=1000).fit(X, y), B)
        s, ts = best_of(lambda: LinearSVC(loss="hinge", dual=True, C=1.0, tol=1e-4, max_iter=1000,
                                          fit_intercept=False).fit(X, y), B)
        report("%d x %d" % (n, p), ta, ts, primal(a.coef_), primal(s.coef_.ravel()),
               float(np.mean(a.predict(X) == s.predict(X))))

    if want("svm"):
        print("KernelSVM vs SVC, rbf, gamma 1/p, C=1, tol 1e-3  (dual objective; ours includes building K)")
    for n in ([] if not want("svm") else [2000] if args.quick else [2000, 5000, 10000]):
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

    if want("svr"):
        print("LinearSVR vs LinearSVR(epsilon_insensitive, dual), C=1, epsilon 0.1, tol 1e-4, at most 1000 sweeps  (ours, sklearn)")
    for n, p in ([] if not want("svr") else [(5000, 200)] if args.quick else [(5000, 200), (20000, 500)]):
        X = rng.standard_normal((n, p))
        y = X @ (rng.standard_normal(p) / np.sqrt(p)) + 0.3 * rng.standard_normal(n)
        obj = lambda w: 0.5 * float(w @ w) + float(np.maximum(0, np.abs(y - X @ w) - 0.1).sum())
        # both stop at the 1,000-sweep cap here, where the random order
        # alone moves the objective by about 1%; at 20,000 sweeps both
        # land on the same value
        a, ta = best_of(lambda: LinearSVR(C=1.0, epsilon=0.1, tol=1e-4, max_iter=1000).fit(X, y), B)
        s, ts = best_of(lambda: SkLinearSVR(loss="epsilon_insensitive", dual=True, C=1.0, epsilon=0.1,
                                            tol=1e-4, max_iter=1000, fit_intercept=False).fit(X, y), B)
        oa, os_ = obj(a.coef_), obj(s.coef_)
        rel = abs(oa - os_) / os_
        flag = "   <-- disagrees" if rel > 0.03 else ""
        bad += 1 if flag else 0
        print("  %-26s %8.3fs %8.3fs %5.1fx   objective %.8g / %.8g   (at the sweep cap)%s"
              % ("%d x %d" % (n, p), ta, ts, ts / ta, oa, os_, flag), flush=True)

    if want("svr"):
        print("KernelSVR vs SVR, rbf, gamma 1/p, C=1, epsilon 0.1, tol 1e-3  (ours includes building K; max prediction difference)")
    for n in ([] if not want("svr") else [1000] if args.quick else [1000, 3000, 6000]):
        p = 10
        X = rng.standard_normal((n, p))
        y = np.sin(X[:, 0] * 2.0) + X[:, 1] * X[:, 2] + 0.1 * rng.standard_normal(n)
        Xt = rng.standard_normal((1000, p))
        g = 1.0 / p
        a, ta = best_of(lambda: KernelSVR(C=1.0, epsilon=0.1, gamma=g, tol=1e-3).fit(X, y), B)
        s, ts = best_of(lambda: SVR(C=1.0, epsilon=0.1, gamma=g, tol=1e-3).fit(X, y), B)
        d = float(np.abs(a.predict(Xt) - s.predict(Xt)).max())
        flag = "   <-- disagrees" if d > 1e-2 else ""
        bad += 1 if flag else 0
        print("  %-26s %8.3fs %8.3fs %5.1fx   iterations %d / %d   max |prediction difference| %.1e%s"
              % ("%d x %d" % (n, p), ta, ts, ts / ta, a.n_iter_, int(np.ravel(s.n_iter_)[0]), d, flag), flush=True)

    if want("logistic"):
        print("L1LogisticRegression vs LogisticRegression(liblinear, L1), tol 1e-4, at most 100 Newton  (ours, sklearn)")
    for n, p, C in ([] if not want("logistic") else [(5000, 200, 0.1)] if args.quick else
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
    from sklearn.decomposition import NMF
    if want("nmf"):
        print("CDNMF (%s) vs NMF(solver='cd'), init random from the same seed, tol 1e-4, at most 200 iterations"
              % nmf_backend())
    for n, p, k in ([] if not want("nmf") else [(1000, 500, 10)] if args.quick else
                    [(1000, 500, 10), (5000, 2000, 20), (20000, 1000, 30)]):
        rng2 = np.random.default_rng(0)
        X = np.abs(rng2.standard_normal((n, k)) @ rng2.standard_normal((k, p))) + 0.1 * rng2.random((n, p))
        a, ta = best_of(lambda: CDNMF(k, random_state=0).fit(X), 1 if n * p > 1e6 else B)
        s, ts = best_of(lambda: NMF(k, solver="cd", init="random", random_state=0, tol=1e-4,
                                    max_iter=200).fit(X), 1 if n * p > 1e6 else B)
        d = float(np.abs(a.components_ - s.components_).max())
        flag = "   <-- disagrees" if d > 1e-8 else ""
        bad += 1 if flag else 0
        print("  %-26s %8.3fs %8.3fs %5.1fx   iterations %d / %d   max |H - H_sklearn| %.1e%s"
              % ("%d x %d, k=%d" % (n, p, k), ta, ts, ts / ta, a.n_iter_, s.n_iter_, d, flag), flush=True)
    print("all agree" if bad == 0 else f"{bad} row(s) disagree")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
