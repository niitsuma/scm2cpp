"""darts' quantile linear model with FrischNewtonQuantileRegressor inside.

    python3 bench/darts-quantile-compare.py [--quick]

LinearRegressionModel(likelihood="quantile") of darts fits a
scikit-learn QuantileRegressor for every quantile and, through
MultiOutputRegressor, for every step of the output chunk: a linear
program each, by HiGHS.  It takes the class from its own module when
fit() runs, so

    import darts.models.forecasting.linear_regression_model as lrm
    lrm.QuantileRegressor = scm2cpp_learn.FrischNewtonQuantileRegressor

puts the interior point method of examples/kernel-only/quantile.scm
there (the same constructor arguments; needs scm2cpp-learn installed),
and nothing else of darts changes: the lagged features, the model
container, predict().

Both fits run on the same series; printed are the fit times, the
largest difference of the coefficients and intercepts over all the
regressors, and the largest difference of the predicted quantiles
(predict(n, predict_likelihood_parameters=True)), relative to the
largest value predicted.  One core on both sides.
"""
import argparse
import os
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_v, "1")
import importlib
import logging
import time
import warnings

import numpy as np


def series(n, seed):
    from darts import TimeSeries
    rng = np.random.default_rng(seed)
    t = np.arange(n)
    e = rng.standard_normal(n) * (1.0 + 0.5 * np.sin(2 * np.pi * t / 24.0))   # the spread has a period too
    v = 100.0 + 0.002 * t + 10.0 * np.sin(2 * np.pi * t / 24.0) + 4.0 * np.sin(2 * np.pi * t / 168.0)
    for i in range(1, n):
        e[i] += 0.7 * e[i - 1]
    return TimeSeries.from_values(v + 2.0 * e)


def regressors(model):
    """Every fitted regressor of the model, in a fixed order."""
    out = []
    for q in sorted(model.model.keys()):
        m = model.model[q]
        out.extend(getattr(m, "estimators_", [m]))
    return out


def fit(lrm, cls, ts, lags, chunk, quantiles, kwargs):
    saved = lrm.QuantileRegressor
    lrm.QuantileRegressor = cls
    try:
        model = lrm.LinearRegressionModel(lags=lags, output_chunk_length=chunk, likelihood="quantile",
                                          quantiles=quantiles, **kwargs)
        t = time.perf_counter()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            model.fit(ts)
        t = time.perf_counter() - t
        pred = model.predict(n=chunk, predict_likelihood_parameters=True).values()
    finally:
        lrm.QuantileRegressor = saved
    return model, t, pred


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true", help="small sizes only (a check, not a timing)")
    args = ap.parse_args()
    import darts
    import scm2cpp_learn
    from sklearn.linear_model import QuantileRegressor
    logging.getLogger("darts").setLevel(logging.ERROR)
    lrm = importlib.import_module("darts.models.forecasting.linear_regression_model")
    quantiles = [0.1, 0.5, 0.9]
    q = args.quick
    cases = [
        (800 if q else 5000, 24, 1, dict()),
        (800 if q else 5000, 24, 1, dict(alpha=0.0)),
        (800 if q else 5000, 24, 12, dict(alpha=0.0)),
        (600 if q else 2000, 168, 1, dict(alpha=0.0)),
        (1500 if q else 20000, 24, 1, dict(alpha=0.0)),
    ]
    print("darts %s, scm2cpp-learn %s: LinearRegressionModel(likelihood=\"quantile\", quantiles=%s)"
          % (darts.__version__, scm2cpp_learn.__version__, quantiles))
    print("%7s %5s %6s %-10s %5s %10s %10s %7s  %12s %12s" % (
        "length", "lags", "chunk", "", "fits", "sklearn", "this", "ratio", "coef differ", "pred differ"))
    bad = 0
    for cls in (QuantileRegressor, scm2cpp_learn.FrischNewtonQuantileRegressor):   # load the libraries
        fit(lrm, cls, series(200, 0), 4, 1, [0.5], dict(alpha=0.0))
    for n, lags, chunk, kwargs in cases:
        ts = series(n, 1)
        m0, t0, p0 = fit(lrm, QuantileRegressor, ts, lags, chunk, quantiles, kwargs)
        m1, t1, p1 = fit(lrm, scm2cpp_learn.FrischNewtonQuantileRegressor, ts, lags, chunk, quantiles, kwargs)
        r0, r1 = regressors(m0), regressors(m1)
        if not (len(r0) == len(r1) == len(quantiles) * chunk
                and all(type(r).__name__ == "FrischNewtonQuantileRegressor" for r in r1)):
            bad += 1
        dc = max(max(float(np.abs(a.coef_ - b.coef_).max()), abs(float(a.intercept_) - float(b.intercept_))
                     / max(abs(float(a.intercept_)), 1.0)) for a, b in zip(r0, r1))
        dp = float(np.abs(p0 - p1).max()) / float(np.abs(p0).max())
        if not (dc < 1e-6 and dp < 1e-8):
            bad += 1
        print("%7d %5d %6d %-10s %5d %9.2fs %9.3fs %6.0fx  %12.1e %12.1e" % (
            n, lags, chunk, "alpha=%g" % kwargs.get("alpha", 1.0), len(r1), t0, t1, t0 / t1, dc, dp))
    print("ALL SAME" if bad == 0 else "%d DIFFERENT" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
