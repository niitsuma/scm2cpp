# Three ways to run the same lasso path, timed against each other:
#
#   sklearn cold    one Lasso().fit per lambda, no warm start -- the
#                   same shape of work the GPU batch does;
#   sklearn path    lasso_path over the whole grid, warm-started --
#                   the strongest sequential CPU baseline;
#   translated CPU  the scm2cpp covariance kernel, one core, cold
#                   per lambda (printed by batch-lasso);
#   translated GPU  the same kernel, one CUDA thread per lambda.
#
# The problem and grid are regenerated here bit-for-bit (same
# Park-Miller stream), and the GPU betas are checked against sklearn's
# by objective value, so the table compares solvers on solutions of
# like quality, not just wall clocks.
#
#   python3 compare-sklearn.py <path-to-batch-lasso-binary>
import subprocess, sys, time
import numpy as np
from sklearn.linear_model import Lasso, lasso_path

P, NOBS, ITERS, BATCH = 200, 1800, 200, 4096
N = P + NOBS

def data():
    seed, acc = 98765, 0.0
    ps = np.empty(N)
    for k in range(N):
        seed = (16807 * seed) % 2147483647
        acc += 10.0 * seed / 2147483647.0
        ps[k] = acc
    t = np.arange(NOBS) + P
    y = 2.0 * (ps[t] - ps[t - 5]) / 5.0 - 1.5 * (ps[t] - ps[t - 20]) / 20.0
    w = np.arange(1, P + 1)[:, None]
    X = (ps[t[None, :]] - ps[t[None, :] - w]) / w
    return X.T.copy(), y          # nobs x p, column j = window j+1

def objective(X, y, beta, alpha):
    r = y - X @ beta
    return 0.5 * r @ r / len(y) + alpha * np.abs(beta).sum()

def main():
    X, y = data()
    alphas = 0.5 * 0.999 ** np.arange(BATCH)

    out = subprocess.run([sys.argv[1], "betas.bin"], capture_output=True,
                         text=True, check=True).stdout
    print(out.strip())
    fields = dict(kv.split("=") for kv in out.split() if "=" in kv)
    cpu_s, gpu_s = float(fields["cpu(1core)"][:-1]), float(fields["gpu"][:-1])
    ours = np.fromfile("betas.bin").reshape(BATCH, P)

    t0 = time.perf_counter()
    sk_alphas, coefs, _ = lasso_path(X, y, alphas=alphas, max_iter=2000)
    path_s = time.perf_counter() - t0
    assert np.allclose(sk_alphas, alphas)   # given descending, kept as given
    sk_path = coefs.T

    ncold = 256                     # cold fits are slow; sample and scale
    t0 = time.perf_counter()
    for a in alphas[:ncold]:
        Lasso(alpha=a, max_iter=2000, fit_intercept=False).fit(X, y)
    cold_s = (time.perf_counter() - t0) * BATCH / ncold

    gaps = []
    for i in range(0, BATCH, 64):
        o_ours = objective(X, y, ours[i], alphas[i])
        o_sk = objective(X, y, sk_path[i], alphas[i])
        gaps.append((o_ours - o_sk) / abs(o_sk))
    gaps = np.array(gaps)

    print(f"objective gap vs sklearn: median {np.median(gaps):.2e} "
          f"max {gaps.max():.2e}")
    print(f"sklearn cold (est. x{BATCH}): {cold_s:.2f}s")
    print(f"sklearn lasso_path (warm):    {path_s:.2f}s")
    print(f"translated cov CPU (1 core):  {cpu_s:.2f}s")
    print(f"translated cov GPU:           {gpu_s:.2f}s")

if __name__ == "__main__":
    main()
