"""Temporal feature selection on a pandas time series.

Which lookback windows explain tomorrow's move?  The frame goes in,
the answer comes out as a frame -- a selected-window table and a
fitted column -- with no design matrix built at any point, not for the
fit and not for the prediction.

    pip install scm2cpp-tfs pandas
    python3 pandas_demo.py
"""
import numpy as np
import pandas as pd

from scm2cpp_tfs import TemporalLasso, cuda_available

WMAX = 120          # candidate lookbacks: 1..120 business days
HORIZON = 1         # predict this many steps ahead


def demo_frame(days=2000, seed=11):
    """A daily frame whose next return leans on two momentum windows.

    The features are moving averages of the returns, not of the price:
    the model penalizes coefficients on the raw feature scale, so
    features that all live at the same size -- returns do, price
    levels do not -- are what a lasso can compare fairly.
    """
    rng = np.random.default_rng(seed)
    idx = pd.bdate_range("2015-01-02", periods=days)
    ret = 0.01 * rng.standard_normal(days)
    frame = pd.DataFrame({"price": 100.0 * np.exp(np.cumsum(ret)),
                          "ret": ret}, index=idx)
    mom5 = frame["ret"].rolling(5).mean()
    mom60 = frame["ret"].rolling(60).mean()
    # tomorrow's return leans on two momentum windows, plus noise
    frame["target"] = (0.60 * mom5 - 0.40 * mom60
                       + 0.004 * rng.standard_normal(days)).shift(-HORIZON)
    return frame.dropna()


def main():
    frame = demo_frame()
    series = frame["ret"].to_numpy()   # features are its window means
    target = frame["target"].to_numpy()

    # rows the model can see: every row that has WMAX days of history
    nobs = len(frame) - WMAX
    rows = frame.index[WMAX:]
    y = target[WMAX:]

    model = TemporalLasso(series, wmax=WMAX, nobs=nobs)

    # a path, and a hold-out to choose on: the last fifth is the test
    cut = int(nobs * 0.8)
    train = TemporalLasso(series[:WMAX + cut], wmax=WMAX, nobs=cut)
    # the grid comes from the data: above lambda_max every coefficient
    # is zero, and the penalty is compared against correlations on the
    # features' own scale, so guessing a range is guessing the scale
    lambdas = train.lambda_grid(y[:cut], num=150)
    path = train.fit_path(y[:cut], lambdas)

    scores = []
    for beta in path:
        pred = model.predict(beta)[cut:]
        resid = y[cut:] - pred
        scores.append(resid @ resid)
    best = int(np.argmin(scores))
    beta = path[best]

    print(f"rows {nobs}, candidate windows {WMAX}, "
          f"GPU {'yes' if cuda_available() else 'no'}")
    print(f"chosen lambda {lambdas[best]:.3g} "
          f"({(np.abs(beta) > 1e-9).sum()} of {WMAX} windows kept)")

    kept = pd.DataFrame(
        {"window": model.windows(beta),
         "coefficient": [beta[w - 1] for w in model.windows(beta)]}
    ).head(8)
    print("\nselected windows (largest coefficient first); the target was"
          " built from 5 and 60:")
    print(kept.round(4).to_string(index=False))

    out = pd.DataFrame({"target": y, "fitted": model.predict(beta)},
                       index=rows)
    out["residual"] = out["target"] - out["fitted"]
    print("\nfitted frame, last rows:")
    print(out.tail().round(4).to_string())

    test = out.iloc[cut:]
    ss = ((test["target"] - test["target"].mean()) ** 2).sum()
    r2 = 1.0 - (test["residual"] ** 2).sum() / ss
    print(f"\nhold-out R^2: {r2:.4f}")

    # a whole cross-validation grid at once, which is where the GPU is
    grid = model.fit_path_batch(y, lambdas)
    print(f"batch path over {len(lambdas)} lambdas: {grid.shape}")


if __name__ == "__main__":
    main()
