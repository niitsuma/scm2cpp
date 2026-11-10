"""A wheel's smoke test (cibuildwheel's test command): every library
the package loads is there and answers, and a few estimators agree
with scikit-learn on a small problem.  Exits non-zero on a failure.
"""
import os
import sys
import warnings

import numpy as np
from sklearn.decomposition import PCA
from sklearn.linear_model import LassoCV, LogisticRegression, lasso_path
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
yb = (X @ beta > 0).astype(int)
check("LBFGSLogisticRegression", m.LBFGSLogisticRegression().fit(X, yb).coef_,
      LogisticRegression().fit(X, yb).coef_, 1e-6)
check("CovPCA", np.abs(m.CovPCA(5).fit(X).components_),
      np.abs(PCA(5, svd_solver="covariance_eigh").fit(X).components_), 1e-8)
check("KernelSVM", m.KernelSVM().fit(X, yb).decision_function(X[:50]),
      SVC().fit(X, yb).decision_function(X[:50]), 1e-2)
if bad:
    print("FAILED:", ", ".join(bad))
    sys.exit(1)
print("ok")
