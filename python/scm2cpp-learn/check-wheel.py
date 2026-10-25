"""A wheel's smoke test (cibuildwheel's test command): every library
the package loads is there and answers, and a few estimators agree
with scikit-learn on a small problem.  Exits non-zero on a failure.
"""
import os
import sys
import warnings

import numpy as np
from sklearn.decomposition import PCA
from sklearn.linear_model import LogisticRegression, lasso_path
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
