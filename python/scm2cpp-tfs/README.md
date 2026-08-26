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
