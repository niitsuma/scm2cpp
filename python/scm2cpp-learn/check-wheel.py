"""A wheel's smoke test (cibuildwheel's test command): every library
the package loads is there and answers, and a few estimators agree
with scikit-learn on a small problem.  Exits non-zero on a failure.
"""
import os
import sys
import warnings

import numpy as np
from sklearn.decomposition import PCA
from sklearn.linear_model import LassoCV, LogisticRegression, QuantileRegressor, lasso_path
from sklearn.model_selection import TimeSeriesSplit
from sklearn.svm import SVC

import scm2cpp_learn as m

warnings.simplefilter("ignore")
print("scm2cpp_learn", m.__version__, "derived:", m.derived_backend(), "nmf:", m.nmf_backend())
rng = np.random.default_rng(0)
X = rng.standard_normal((400, 30))
beta = np.zeros(30)
beta[[3, 11, 20]] = [2.0, -1.5, 0.8]
y = X @ beta + 0.1 * rng.standard_normal(400)
bad = []
if os.environ.get("SCM2CPP_EXPECT_BLAS"):
    # the wheels are built against OpenBLAS on every platform
    from scm2cpp_learn._libfind import gramops_backend
    got = {"derived": m.derived_backend(), "nmf": m.nmf_backend(), "gramops": gramops_backend()}
    print("backends:", got)
    bad += [k + " is " + v for k, v in got.items() if v == "loops"]


def check(name, a, b, tol):
    d = float(np.max(np.abs(np.asarray(a) - np.asarray(b))))
    print(f"{name:28} {d:.1e}")
    if not d <= tol:
        bad.append(name)


lams = np.geomspace(1.0, 0.01, 10)
_, sk, _ = lasso_path(X, y, alphas=lams, precompute=True, tol=1e-12)
check("CovLasso path", m.CovLasso(X, y).fit_path(lams, tol=1e-10), sk.T, 1e-6)
check("DerivedLasso path", m.DerivedLasso(X, y).fit_path(lams, tol=1e-10), sk.T, 1e-6)
# a splitter for cv and an intercept: LassoCV on the same grid
cvx = m.CovLassoCV(cv=TimeSeriesSplit(5), num=30, tol=1e-12, fit_intercept=True).fit(X + 1.0, y + 3.0)
cvs = LassoCV(cv=TimeSeriesSplit(5), alphas=cvx.alphas_, tol=1e-12, max_iter=100000).fit(X + 1.0, y + 3.0)
check("CovLassoCV TimeSeriesSplit", cvx.mse_path_, cvs.mse_path_, 1e-8)
check("CovLassoCV intercept", [cvx.alpha_, cvx.intercept_, *cvx.coef_],
      [cvs.alpha_, cvs.intercept_, *cvs.coef_], 1e-8)
# constant columns (one of zeros, one of threes) take coefficient 0, as
# scikit-learn skips a column whose norm is zero, and leave the rest alone
Xk = X.copy()
Xk[:, 5], Xk[:, 7] = 0.0, 3.0
for fi in (False, True):
    cvk = m.CovLassoCV(cv=TimeSeriesSplit(5), num=30, tol=1e-12, fit_intercept=fi,
                       force_cpu=True).fit(Xk, y)
    cks = LassoCV(cv=TimeSeriesSplit(5), alphas=cvk.alphas_, tol=1e-12, max_iter=100000,
                  fit_intercept=fi).fit(Xk, y)
    check(f"constant columns intercept={fi}", [cvk.alpha_, cvk.intercept_, *cvk.coef_],
          [cks.alpha_, cks.intercept_, *cks.coef_], 1e-8)
# solver="lars": the translated LARS path read at the same grid, against
# LassoCV on the same alphas and folds, on columns that are moving
# averages over overlapping windows (strongly correlated, slow for
# coordinate descent), with a constant column and a doubled column among them
rl = np.random.default_rng(3)
zl = rl.standard_normal(470)
Xl = np.column_stack([np.convolve(zl, np.ones(w) / w, "valid")[:400] for w in (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64)])
Xl = np.column_stack([Xl, Xl[:, :6] * Xl[:, 6:], np.full(400, 2.0)])
# a column twice another (the lasso puts the weight on the longer one;
# two equal columns would tie in the path and break it)
Xl = np.column_stack([Xl, 2.0 * Xl[:, 1]])
yl = Xl[:, [1, 7, 14]] @ np.array([1.0, -0.5, 0.3]) + 0.5 * rl.standard_normal(400)
for fi in (False, True):
    cvl = m.CovLassoCV(cv=TimeSeriesSplit(5), num=30, fit_intercept=fi, solver="lars").fit(Xl, yl)
    cls = LassoCV(cv=TimeSeriesSplit(5), alphas=cvl.alphas_, tol=1e-14, max_iter=10**6,
                  fit_intercept=fi).fit(Xl, yl)
    check(f"CovLassoCV lars intercept={fi}", [cvl.alpha_, cvl.intercept_, *cvl.coef_],
          [cls.alpha_, cls.intercept_, *cls.coef_], 1e-6)
    # working_set: the same fit from a set of columns grown until no
    # column outside it breaks the optimality conditions (4 columns at a
    # time here, so the set has to grow)
    cvw = m.CovLassoCV(cv=TimeSeriesSplit(5), num=30, fit_intercept=fi, solver="lars",
                       working_set=4).fit(Xl, yl)
    assert max(r for r, _ in cvw.working_set_) > 1, cvw.working_set_
    check(f"CovLassoCV lars working_set intercept={fi}",
          [cvw.alpha_, cvw.intercept_, *cvw.coef_, *cvw.alphas_, *cvw.mse_path_.ravel()],
          [cvl.alpha_, cvl.intercept_, *cvl.coef_, *cvl.alphas_, *cvl.mse_path_.ravel()], 1e-9)
# working_set on a design wider than it is long (p = 3000, n = 150), where
# the set stays far smaller than p: against the full Gram's fit
rw = np.random.default_rng(5)
Zw = rw.standard_normal((150, 60))
Xw = np.column_stack([Zw[:, i] * Zw[:, j] for i in range(60) for j in range(50)])
yw = Xw[:, [7, 400, 2100]] @ np.array([1.0, -0.7, 0.5]) + 0.3 * rw.standard_normal(150)
cwf = m.CovLassoCV(cv=5, num=40, fit_intercept=True, solver="lars").fit(Xw, yw)
cww = m.CovLassoCV(cv=5, num=40, fit_intercept=True, solver="lars", working_set=200).fit(Xw, yw)
assert max(q for _, q in cww.working_set_) < Xw.shape[1], cww.working_set_
check("CovLassoCV lars working_set wide", [cww.alpha_, cww.intercept_, *cww.coef_, *cww.mse_path_.ravel()],
      [cwf.alpha_, cwf.intercept_, *cwf.coef_, *cwf.mse_path_.ravel()], 1e-9)
# a coefficient that leaves the LARS path is exactly zero from that knot
# on: no grid point may carry a rounding residue of it (0.22.0 left about
# 1e-19 on every grid point up to the next knot, a spurious nonzero).
# Moving averages and their products, where the path drops variables
# (more steps than columns); the largest entry that is neither zero nor
# above 1e-9 of its row's largest must be 0
rz = np.random.default_rng(7)
zz = rz.standard_normal(260)
Az = np.column_stack([np.convolve(zz, np.ones(w) / w, "valid")[:180] for w in (1, 2, 3, 4, 6, 8, 12, 16)])
Xz = np.column_stack([Az] + [Az[:, i] * Az[:, j] for i in range(8) for j in range(i, 8)])
yz = np.sign(np.roll(zz[:180], -1))
cvz = m.CovLassoCV(cv=5, num=200, fit_intercept=True, solver="lars").fit(Xz, yz)
Xzc, yzc = Xz - Xz.mean(0), yz - yz.mean()
Bz, itz = cvz._lars_grid(Xzc.T @ Xzc, Xzc.T @ yzc, len(yz))
assert itz > Xz.shape[1], itz
small = (Bz != 0) & (np.abs(Bz) <= 1e-9 * np.abs(Bz).max(axis=1, keepdims=True))
check("CovLassoCV lars exact zeros", [np.abs(Bz[small]).max() if small.any() else 0.0], [0.0], 0.0)
yb = (X @ beta > 0).astype(int)
check("LBFGSLogisticRegression", m.LBFGSLogisticRegression().fit(X, yb).coef_,
      LogisticRegression().fit(X, yb).coef_, 1e-6)
check("CovPCA", np.abs(m.CovPCA(5).fit(X).components_),
      np.abs(PCA(5, svd_solver="covariance_eigh").fit(X).components_), 1e-8)
check("KernelSVM", m.KernelSVM().fit(X, yb).decision_function(X[:50]),
      SVC().fit(X, yb).decision_function(X[:50]), 1e-2)
# the interior point kernel's answer, moved to its vertex, is the simplex's
qo = m.FrischNewtonQuantileRegressor(quantile=0.3, alpha=0.01).fit(X + 1.0, y + 3.0)
qs = QuantileRegressor(quantile=0.3, alpha=0.01).fit(X + 1.0, y + 3.0)
check("FrischNewtonQuantileRegressor", [qo.intercept_, *qo.coef_], [qs.intercept_, *qs.coef_], 1e-8)
if bad:
    print("FAILED:", ", ".join(bad))
    sys.exit(1)
print("ok")
