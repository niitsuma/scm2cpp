# scm2cpp-lasso

A fast lasso over moving-average features of a time series, with no
design matrix and an optional GPU path.

```console
$ pip install scm2cpp-lasso
```

Installing needs a C++17 compiler and nothing else.  If `nvcc` is on
the path, the batched GPU solver is built as well; if it is not, the
package installs and works exactly the same, minus that one method.

```python
import numpy as np
from scm2cpp_lasso import TemporalLasso, cuda_available

model = TemporalLasso(series, wmax=200, nobs=1800)  # Gram built once
lambdas = 0.5 * 0.99 ** np.arange(400)

path = model.fit_path(y, lambdas)        # warm-started, sequential
grid = model.fit_path_batch(y, lambdas)  # every lambda from zero
print("GPU:", cuda_available())
```

Feature *j* is the mean of the last *j+1* observations.  The matrix
that would hold those features is never formed: the solver goes from
the series to the Gram matrix through lag sums, so each coordinate
step costs O(p) instead of O(n), and the descent is exactly resumable
-- which is what lets a path be walked warm, and a whole grid of
lambdas be handed to a GPU at once.

`fit_path` is for a single path, where each lambda starts from the
previous solution.  `fit_path_batch` is for the case warm starting
cannot help -- a cross-validation grid, where the folds differ -- and
solves every lambda from zero, in parallel on the GPU when there is
one.

Over a 400-lambda path at 200 candidate windows and 1800 rows, on an
RTX 4090 and an i9-10900X:

| call                                  | time    |
|---------------------------------------|---------|
| `fit_path` (warm, sequential)         | 0.091 s |
| `fit_path_batch` (GPU)                | 0.047 s |
| `fit_path_batch(force_cpu=True)`      | 0.178 s |

GPU and CPU agree to 2e-14, and the objectives are within 3e-17 of
scikit-learn's `lasso_path` on the same grid.

## Where this comes from

The solver is not written in C++ by hand.  It is
`examples/kernel-only/lasso-cov.scm` from
[scm2cpp](https://github.com/niitsuma/scm2cpp), a Scheme-to-C++
translator, and the C++ it ships is that file translated.  The same
repository derives this covariance-update solver automatically from a
naive one by finite differencing; this package is the derived kernel,
packaged.

To refresh the committed C++ after changing the Scheme, run
`python/regenerate.sh` in the scm2cpp checkout -- that step, and only
that step, needs Racket.

## License

MIT, the same as scm2cpp.
