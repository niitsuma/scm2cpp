# scm2cpp-tfs

*[Japanese (README.ja.md)](README.ja.md)*

Temporal feature selection: lasso over the moving averages of a
series, with no design matrix at any step.  The solver is Scheme,
translated to C++ by
[scm2cpp](https://github.com/niitsuma/scm2cpp).

```console
$ pip install scm2cpp-tfs
```

Installing needs a C++17 compiler and nothing else.  If `nvcc` is on
the path, the batched GPU solver is built as well; without it the
package installs and works the same, minus that one method.

```python
import numpy as np
from scm2cpp_tfs import TemporalLasso, cuda_available

model = TemporalLasso(series, wmax=200, nobs=1800)
lambdas = model.lambda_grid(y, num=150)     # from lambda_max down

path = model.fit_path(y, lambdas)           # warm-started, sequential
grid = model.fit_path_batch(y, lambdas)     # every lambda from zero
beta = path[-1]

model.windows(beta)          # the window lengths it kept
model.predict(beta)          # fitted values, no design matrix
model.score(y, beta)         # R^2
```

## What is never formed

Feature *j* is the mean of the last *j+1* observations, for *j* in
0..wmax-1.  The matrix that would hold those features is never built:

* **the Gram matrix** comes from the series' prefix sums in O(n p)
  time -- forming X and multiplying it out would cost O(n p^2) time
  and O(n p) space;
* **the descent** costs O(p) per coordinate instead of O(n), and is
  exactly resumable, so a path is walked warm and a grid of lambdas
  goes to a GPU at once;
* **prediction** reads window means straight off the prefix sums and
  skips every window the penalty dropped, so a sparse fit predicts in
  time proportional to its own support.  Against numpy that has to
  form the design first, `predict` is about 20x faster at p=200,
  n=1800.

## Elastic net and ridge

`fit_path` and `fit_path_batch` take `l1_ratio` for the elastic net,
on the same kernels and the same GPU path; `l1_ratio=1` is bit-for-bit
the lasso.  `TemporalRidge` is the closed-form companion: the same
design-free Gram matrix, one eigendecomposition, then O(p^2) per
alpha -- a two-thousand-alpha ridge path over two hundred windows
takes tens of milliseconds.

## Choosing lambda

The penalty is compared against correlations on the features' own
scale, so the useful range depends on the data.  `lambda_max(y)` is
the smallest penalty that leaves every coefficient at zero, and
`lambda_grid(y)` walks down from it -- the construction scikit-learn
uses.  Windows of one series are naturally on one scale; if you feed
it something where they are not, standardize first.

## Logistic regression with L1

`TemporalLogistic` classifies from the same windows, still with no
design matrix anywhere: the fixed quadratic G/4 comes from the
prefix-sum Gram construction, the linear predictor is the prediction
kernel, and the gradient X'(y - mu) is the cross-product builder
applied to the current residual.  Objectives agree with
scikit-learn's L1 `LogisticRegression` to 2e-16; a 15-lambda path
over 100 windows and 3000 rows takes 0.16 s.

```python
clf = TemporalLogistic(series, wmax=100, nobs=3000)
path = clf.fit_path(y01, clf.lambda_grid(y01))
clf.predict_proba(path[-1])
```

## Autoregression

`TemporalAR` fits AR(p) by Yule-Walker on the same principle that
runs everything here: the lagged design's Gram matrix collapses onto
p+1 autocovariances (one O(n p) translated kernel), and
Levinson-Durbin solves the Toeplitz system in O(p^2), yielding on the
way the partial autocorrelations and every order's prediction-error
power -- so one fit at `max_order` prices all smaller models, and
AIC/BIC order selection is free.

```python
from scm2cpp_tfs import TemporalAR

ar = TemporalAR(series, max_order=50)
ar.pacf                    # partial autocorrelations, the order plot
phi = ar.fit()             # order chosen by AIC (or fit(order=3))
ar.forecast(10)            # recursive prediction
```

Coefficients agree with `statsmodels.regression.yule_walker`
(`method="mle"`) to 2e-14; a full fit at n=20000, max_order=200 takes
about 4 ms.

## Rolling statistics

Statistics of every trailing window, for one window length or a
whole batch at once, pandas-shaped (NaN over the first w-1 rows):

```python
from scm2cpp_tfs import rolling_min, rolling_mean, rolling_std

rolling_min(x, 20)                  # one window
rolling_mean(x, range(1, 201))      # one row per window
```

Min and max run on a translated monotone-deque kernel, O(n) per
window, and match pandas exactly; sum, mean and std ride prefix sums
(std's precision note is in its docstring).  Over all windows 1..200
on a 100k-point series: min 2.9x pandas, mean 6.6x -- constant-factor
wins, stated as such, since the output itself is O(n w).

## With pandas

`examples/pandas_demo.py` takes a daily frame and answers which
lookback windows explain tomorrow's move:

```console
$ pip install scm2cpp-tfs pandas
$ python3 pandas_demo.py
rows 1821, candidate windows 120, GPU yes
chosen lambda 4.35e-05 (9 of 120 windows kept)

selected windows (largest coefficient first); the target was built from 5 and 60:
 window  coefficient
      4       0.5273
     51      -0.1684
     24       0.1060
...
hold-out R^2: 0.2653
```

## Where this comes from

`examples/kernel-only/lasso-cov.scm` and `tfs-predict.scm` in
[scm2cpp](https://github.com/niitsuma/scm2cpp), translated to C++ and
committed to `python/scm2cpp-tfs/`.  That repository also derives the
covariance-update solver automatically from a naive one by finite
differencing.  To refresh the committed C++ after changing the Scheme,
run `regenerate.sh` -- that step, and only that step, needs Racket.

## License

MIT, the same as scm2cpp.
