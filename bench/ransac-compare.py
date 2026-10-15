"""RANSAC for a linear model against scikit-learn's RANSACRegressor.

    python3 bench/ransac-compare.py --kernel-dir DIR

--kernel-dir holds ransac.py and libransac.so built from
examples/kernel-only/ransac.scm with -M.  Both sides run
RANSACRegressor's algorithm around LinearRegression with its defaults
(min_samples p + 1, residual_threshold the MAD of y, stop_probability
0.99) and max_trials 1000, from random_state 0: ours is handed the
subsets scikit-learn draws, drawn the same way (sample_without_replacement
on a RandomState(0), one per trial, in order) and timed with the
drawing.  The trial counts, the inlier masks and the coefficients are
compared.  Data: y = X w + 1 + noise, a fraction of y moved far off.
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel-dir", required=True)
    args = ap.parse_args()
    spec = importlib.util.spec_from_file_location("ransac_k", Path(args.kernel_dir) / "ransac.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    from sklearn.linear_model import RANSACRegressor
    from sklearn.utils.random import sample_without_replacement
    warnings.simplefilter("ignore")
    for n, p, frac in [(1000, 3, 0.2), (10000, 5, 0.4), (100000, 10, 0.3), (20000, 20, 0.5)]:
        rng = np.random.default_rng(0)
        X = rng.standard_normal((n, p))
        y = X @ rng.standard_normal(p) + 1.0 + 0.1 * rng.standard_normal(n)
        o = rng.random(n) < frac
        y[o] += 10 * rng.standard_normal(o.sum())
        t = time.perf_counter()
        s = RANSACRegressor(random_state=0, max_trials=1000).fit(X, y)
        ts = time.perf_counter() - t
        t = time.perf_counter()
        ms = p + 1
        thr = np.median(np.abs(y - np.median(y)))
        rs = np.random.RandomState(0)
        subs = np.array([sample_without_replacement(n, ms, random_state=rs) for _ in range(1000)], dtype=np.float64)
        coef = np.zeros(p)
        mask = np.zeros(n)
        out = np.zeros(1)
        trials = m.ransac(np.ascontiguousarray(X), y, subs, coef, mask, out, 1000, ms, thr, 0.99, n, p)
        tt = time.perf_counter() - t
        print(f"n={n} p={p}, {frac:.0%} outliers: sklearn {ts:.4f} s ({s.n_trials_} trials), "
              f"ransac.scm {tt:.4f} s ({trials} trials), {ts / tt:.1f}x; same inliers "
              f"{np.array_equal(mask.astype(bool), s.inlier_mask_)}, max |dcoef| "
              f"{np.abs(coef - s.estimator_.coef_).max():.1e}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
