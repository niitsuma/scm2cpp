import sys, warnings, numpy as np
sys.path.insert(0,'/tmp'); warnings.filterwarnings("ignore")
import tfs_lasso_cov_multi as lcm
from sklearn.linear_model import Lasso

def tfs_multi(xs, wmax, nobs, sweeps, lam, y):
    """Several series, one target. The design matrix is never formed."""
    m = len(xs); n = len(xs[0])
    ps = np.ascontiguousarray(np.concatenate([np.cumsum(x) for x in xs]))
    p = m*wmax; w1 = wmax+1
    s  = np.zeros(m*m*w1*w1); q = np.zeros(n); cs = np.zeros(n+1)
    pv = np.zeros(m*w1); g = np.zeros(p*p); c = np.zeros(p); beta = np.zeros(p)
    lcm.build_S_multi(ps, s, q, cs, n, nobs, wmax, m)
    lcm.build_P_multi(ps, np.ascontiguousarray(y), pv, n, nobs, wmax, m)
    lcm.build_G_multi(s, pv, g, c, wmax, m, p)
    lcm.cov_descend_multi(g, c, beta, lam, sweeps, nobs, p)
    return beta

m, wmax, nobs, SW, LAM = 3, 12, 400, 200, 0.02
N = nobs+wmax+1
rng = np.random.default_rng(0)
xs = [rng.standard_normal(N) for _ in range(m)]
pss = [np.cumsum(x) for x in xs]
t = wmax+np.arange(nobs); ws = np.arange(1,wmax+1)
cols = [(c,w) for c in range(m) for w in ws]
X = np.stack([(pss[c][t]-pss[c][t-w])/w for (c,w) in cols], axis=1)
# the target: only series 0 window 5 and series 2 window 9 matter
y = 2.0*X[:,0*wmax+4] - 1.5*X[:,2*wmax+8]

beta = tfs_multi(xs, wmax, nobs, SW, LAM, y)
b_sk = Lasso(alpha=LAM, fit_intercept=False, max_iter=SW, tol=1e-12).fit(X,y).coef_
print(f"series={m} wmax={wmax} -> {m*wmax} columns")
print("max |scm2cpp - sklearn| :", f"{np.max(np.abs(beta-b_sk)):.2e}")
nz=[(c,w,beta[c*wmax+w-1]) for (c,w) in cols if abs(beta[c*wmax+w-1])>1e-6]
print("selected (series, window, coef):")
for c,w,b in nz: print(f"  series {c}, window {w:2d}: {b:+.6f}")
print("true generator: series 0 window 5 = +2.0, series 2 window 9 = -1.5")
