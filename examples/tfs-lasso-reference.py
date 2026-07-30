"""Reference for a proper TFS-style check: the signal y is built from moving
averages of x at two window lengths the program is not told about. Every
window length from 1 to WMAX is offered as a candidate feature, and lasso
coordinate descent must pick out the two that matter from among all of them.
Mirrors the scm2cpp program bit-for-bit (same LCG, same window range, same
coordinate descent), so the two should agree closely.
"""
import numpy as np

N = 400
WMAX = 40
TRUE_W = [5, 20]
TRUE_BETA = [2.0, -1.5]
LAM = 0.02
SWEEPS = 20000


class LCG:
    """Park-Miller minimal-standard generator via Schrage's method, so every
    intermediate product stays within 32-bit signed range -- the plain C++
    int that scm2cpp maps Scheme integers to, unlike Racket's own bignums."""
    A, M, Q, R = 16807, 2147483647, 127773, 2836

    def __init__(self, seed=98765):
        self.s = seed

    def next(self):
        hi, lo = self.s // self.Q, self.s % self.Q
        test = self.A * lo - self.R * hi
        self.s = test if test > 0 else test + self.M
        return self.s / self.M


def build():
    r = LCG()
    x = np.array([10.0 * r.next() for _ in range(N)])
    ps = np.cumsum(x)  # ps[i] = sum_{a=0}^{i} x[a]

    n_obs = N - WMAX
    windows = list(range(1, WMAX + 1))  # every candidate window, 1..WMAX
    p = len(windows)

    def ma(w, t):
        return (ps[t] - (ps[t - w] if t - w >= 0 else 0.0)) / w

    X = np.zeros((n_obs, p))
    for j, w in enumerate(windows):
        for row in range(n_obs):
            t = WMAX + row
            X[row, j] = ma(w, t)

    y = np.zeros(n_obs)
    for w, b in zip(TRUE_W, TRUE_BETA):
        for row in range(n_obs):
            t = WMAX + row
            y[row] += b * ma(w, t)

    xnorm = (X ** 2).sum(axis=0)
    return X, y, xnorm, n_obs, p, windows


def lasso(X, y, xnorm, lam, sweeps):
    """scikit-learn's coordinate descent. Its objective is
    (1/(2n))||y-Xw||^2 + alpha*||w||_1; multiplying by n gives
    (1/2)||y-Xw||^2 + alpha*n*||w||_1, which is the same objective the
    scm2cpp kernel's g = lam*n soft-threshold implements with alpha=lam.
    """
    from sklearn.linear_model import Lasso
    m = Lasso(alpha=lam, fit_intercept=False, max_iter=sweeps, tol=1e-12)
    m.fit(X, y)
    return m.coef_


if __name__ == "__main__":
    X, y, xnorm, n_obs, p, windows = build()
    beta = lasso(X, y, xnorm, LAM, SWEEPS)
    yhat = X @ beta
    nonzero = [(w, b) for w, b in zip(windows, beta) if abs(b) > 1e-6]
    print(f"windows tried: 1..{WMAX} ({p} candidates)")
    print("true generator: " + ", ".join(f"w={w} beta={b}" for w, b in zip(TRUE_W, TRUE_BETA)))
    print("lasso selected (|beta|>1e-6):")
    for w, b in nonzero:
        print(f"  w={w:2d}  beta_hat={b:+.6f}")
    print("max|beta_true_windows - recovered| =",
          f"{max(abs(beta[w-1]-b) for w,b in zip(TRUE_W,TRUE_BETA)):.6f}")
    print("max|beta| among the other", p - len(TRUE_W), "windows =",
          f"{max(abs(beta[j]) for j in range(p) if (j+1) not in TRUE_W):.6f}")
    print("max|y-yhat| =", f"{np.max(np.abs(y - yhat)):.6f}")
    print("y[0:5]    =", " ".join(f"{v:.6f}" for v in y[:5]))
    print("yhat[0:5] =", " ".join(f"{v:.6f}" for v in yhat[:5]))
