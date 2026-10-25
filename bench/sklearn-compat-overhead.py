"""What the scikit-learn interface costs: fit and predict, before and after.

    python bench/sklearn-compat-overhead.py --old DIR --new DIR [--rounds 3]
    PYTHONPATH=DIR python bench/sklearn-compat-overhead.py --checks

DIR is a directory holding an importable scm2cpp_learn (a copy of an
installed one, or src/ of a checkout over the same compiled libraries).
Each (estimator, shape) is timed in a fresh process for the old and the
new package in turn, --rounds times, alternating, and the best time of
all rounds is kept for each side, so load from other jobs lands on both
sides alike.  BLAS and OpenMP are pinned to one thread and the device is
off (SCM2CPP_NO_DEVICE=1); run under taskset -c N for one core.

With --one it is the worker: one estimator, one shape, one package,
JSON on stdout.
"""
import argparse
import json
import os
import subprocess
import sys
import time

for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(v, "1")
os.environ.setdefault("SCM2CPP_NO_DEVICE", "1")

SHAPES = {"small": (200, 10), "medium": (2000, 50), "large": (20000, 200)}

# name -> (target kind, constructor kwargs, largest shape it runs at)
CASES = {
    "CovLassoCV": ("reg", {}, "large"),
    "GramLasso": ("reg", {"alpha": 0.1}, "large"),
    "GramRidge": ("reg", {}, "large"),
    "CovBayesianRidge": ("reg", {}, "large"),
    "CovARDRegression": ("reg", {}, "medium"),
    "LinearSVM": ("bin", {}, "large"),
    "KernelSVM": ("bin", {}, "medium"),
    "LinearSVR": ("reg", {}, "large"),
    "KernelSVR": ("reg", {}, "medium"),
    "L1LinearSVM": ("bin", {}, "large"),
    "L1LogisticRegression": ("bin", {}, "large"),
    "LBFGSLogisticRegression": ("multi", {}, "large"),
    "LBFGSLogisticRegressionCV": ("bin", {}, "medium"),
    "LBFGSPoissonRegressor": ("count", {}, "large"),
    "LBFGSHuberRegressor": ("reg", {}, "large"),
    "SGDLinearClassifier": ("bin", {}, "large"),
    "SGDLinearRegressor": ("reg", {}, "large"),
    "GramOMP": ("reg", {}, "large"),
    "GramOMPCV": ("reg", {}, "large"),
    "GramLars": ("reg", {}, "large"),
    "GramLassoLars": ("reg", {"alpha": 0.01}, "large"),
    "GramLassoLarsCV": ("reg", {}, "medium"),
    "GramLassoLarsIC": ("reg", {}, "large"),
    "WeiszfeldTheilSen": ("reg", {}, "small"),
    "LinearRANSAC": ("reg", {"random_state": 0}, "large"),
    "GramRFE": ("reg", {}, "medium"),
    "SelectKBest": ("bin", {}, "large"),
    "CDNMF": ("pos", {"n_components": 5, "random_state": 0}, "medium"),
    "CovPCA": ("none", {}, "large"),
    "ParallelFastICA": ("none", {"random_state": 0}, "medium"),
    "EMGaussianMixture": ("none", {"n_components": 3, "init_params": "random",
                                   "random_state": 0}, "medium"),
    "CDGraphicalLasso": ("none", {"alpha": 0.2}, "medium"),
}


def data(kind, n, p):
    import numpy as np
    rng = np.random.default_rng(0)
    X = rng.standard_normal((n, p))
    z = X @ rng.standard_normal(p) / np.sqrt(p)
    if kind == "pos":
        X = np.abs(X)
    y = {"reg": z + 0.3 * rng.standard_normal(n), "bin": (z > 0).astype(float),
         "multi": np.digitize(z, [-0.5, 0.5]).astype(float),
         "count": rng.poisson(np.exp(0.5 * z)).astype(float)}.get(kind)
    return X, y


def best(f, budget=1.0, at_least=3, at_most=200):
    ts, spent = [], 0.0
    while len(ts) < at_least or (spent < budget and len(ts) < at_most):
        t = time.perf_counter()
        f()
        dt = time.perf_counter() - t
        ts.append(dt)
        spent += dt
    return min(ts)


def worker(name, shape):
    import numpy as np
    import scm2cpp_learn as m
    kind, kw, _ = CASES[name]
    n, p = SHAPES[shape]
    X, y = data(kind, n, p)
    cls = getattr(m, name)
    fit = (lambda: cls(**kw).fit(X)) if y is None else (lambda: cls(**kw).fit(X, y))
    est = fit()
    use = getattr(est, "predict", None) or getattr(est, "transform", None)
    Xs = X[:50]          # predict on a few rows: where a fixed cost shows
    out = {"fit": best(fit)}
    if use is not None:  # the old CDNMF had no transform
        out.update(predict=best(lambda: use(X)), predict50=best(lambda: use(Xs)))
    print(json.dumps(out))


def checks():
    """The input checks alone, per shape: the direct path, the direct
    path under assume_finite, and scikit-learn's validate_data (what a
    list, a DataFrame or another dtype goes through)."""
    import numpy as np
    import sklearn
    from sklearn.base import BaseEstimator
    from sklearn.utils.validation import validate_data
    from scm2cpp_learn._compat import fit_xy, pred_x

    class E(BaseEstimator):
        pass

    for shape, (n, p) in SHAPES.items():
        X, y = data("reg", n, p)
        e = E()
        fit_xy(e, X, y)
        rows = {"fit_xy": lambda: fit_xy(e, X, y), "pred_x": lambda: pred_x(e, X),
                "pred_x 50 rows": lambda: pred_x(e, X[:50])}
        out = []
        for k, f in rows.items():
            t = best(f)
            with sklearn.config_context(assume_finite=True):
                ta = best(f)
            out.append(f"{k} {t*1e6:.1f} us (assume_finite {ta*1e6:.1f})")
        tv = best(lambda: validate_data(e, X, y, dtype=np.float64, order="C", y_numeric=True))
        out.append(f"validate_data(X, y) {tv*1e6:.1f} us")
        print(f"{shape:6s} {n}x{p}: " + "; ".join(out), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old")
    ap.add_argument("--new")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--one", nargs=2)
    ap.add_argument("--checks", action="store_true",
                    help="time the input checks alone (the new package on the path)")
    a = ap.parse_args()
    if a.checks:
        checks()
        return
    if a.one:
        worker(*a.one)
        return
    order = list(SHAPES)
    rows = []
    for name in (a.only or CASES):
        top = order.index(CASES[name][2])
        for shape in order[:top + 1]:
            res = {"old": {}, "new": {}}
            for _ in range(a.rounds):
                for side, path in (("old", a.old), ("new", a.new)):
                    env = dict(os.environ, PYTHONPATH=path)
                    r = subprocess.run([sys.executable, __file__, "--one", name, shape],
                                       env=env, capture_output=True, text=True)
                    if r.returncode:
                        sys.exit(f"{name} {shape} {side}: {r.stderr[-400:]}")
                    d = json.loads(r.stdout.strip().splitlines()[-1])
                    for k, v in d.items():
                        res[side][k] = min(v, res[side].get(k, float("inf")))
            row = {"name": name, "shape": shape, **{f"{s}_{k}": v for s in res
                                                    for k, v in res[s].items()}}
            rows.append(row)
            nan = float("nan")
            for k in ("old_predict", "new_predict", "old_predict50", "new_predict50"):
                row.setdefault(k, nan)
            print(f"{name:26s} {shape:6s} fit {row['old_fit']*1e3:10.3f} -> "
                  f"{row['new_fit']*1e3:10.3f} ms ({row['new_fit']/row['old_fit']-1:+6.1%})  "
                  f"predict {row['old_predict']*1e6:9.1f} -> {row['new_predict']*1e6:9.1f} us  "
                  f"predict50 {row['old_predict50']*1e6:7.1f} -> "
                  f"{row['new_predict50']*1e6:7.1f} us", flush=True)
    print(json.dumps(rows))


if __name__ == "__main__":
    main()
