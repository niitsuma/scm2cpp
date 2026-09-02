import sys, time, warnings, numpy as np
sys.path.insert(0,'/tmp'); warnings.filterwarnings("ignore")
import tfs_lasso_cov as lc         # the ctypes loader scm2cpp generated
from sklearn.linear_model import Lasso

def tfs_lasso(x, wmax, nobs, sweeps, lam):
    """Raw series to coefficients; the design matrix is never formed."""
    ps = np.ascontiguousarray(np.cumsum(x)); n = ps.size
    p = wmax
    s  = np.zeros((wmax+1)*(wmax+1)); q = np.zeros(n); cs = np.zeros(n+1)
    pv = np.zeros(wmax+1); g = np.zeros(p*p); c = np.zeros(p); beta = np.zeros(p)
    t = wmax+np.arange(nobs); ws = np.arange(1,wmax+1)
    X = np.stack([(ps[t]-ps[t-w])/w for w in ws],axis=1)   # only to build y
    y = np.ascontiguousarray(2.0*X[:,4]-1.5*X[:,19]); del X
    lc.build_S(ps, s, q, cs, n, nobs, wmax)
    lc.build_P(ps, y, pv, nobs, wmax)
    lc.build_G(s, pv, g, c, wmax, p)
    lc.cov_descend(g, c, beta, lam, sweeps, nobs, p)
    return beta, y

nobs, wmax, SW, LAM = 4000, 80, 120, 0.02
x = np.random.default_rng(7).standard_normal(nobs+wmax+1)
beta, y = tfs_lasso(x, wmax, nobs, SW, LAM)

ps=np.cumsum(x); t=wmax+np.arange(nobs); ws=np.arange(1,wmax+1)
X=np.stack([(ps[t]-ps[t-w])/w for w in ws],axis=1)
b_sk = Lasso(alpha=LAM, fit_intercept=False, max_iter=SW, tol=1e-12).fit(X,y).coef_
print("max |scm2cpp - sklearn| :", f"{np.max(np.abs(beta-b_sk)):.2e}")
print("beta[4], beta[19]  :", f"{beta[4]:+.6f}", f"{beta[19]:+.6f}")
print("sklearn            :", f"{b_sk[4]:+.6f}", f"{b_sk[19]:+.6f}")
