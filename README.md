# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml) [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/niitsuma/scm2cpp/blob/master/notebooks/compare-sklearn.ipynb)

*[Japanese (README.ja.md)](README.ja.md) · [中文 (README.zh.md)](README.zh.md)*

Scm2Cpp translates a subset of Scheme into C++ that a person can read
and edit, and scikit-learn's machine-learning algorithms, written in it
plainly, come out fast. The translator derives the fast form of an
algorithm from the naive one (the Gram matrix hoisted out of a
coordinate descent, a loop-invariant product formed once), hands the
products to BLAS or cuBLAS, and turns parallel loops into CUDA kernels.
The estimators ship on PyPI as `scm2cpp-lasso`, with compiled wheels
for Linux, macOS and Windows (no compiler, no Racket).

## Machine-learning algorithms it speeds up

Each is scikit-learn's own algorithm written in the subset, checked
against scikit-learn's iterations and results. Times against
scikit-learn on one core (i9-10900X, an RTX 4090 for the device rows,
scikit-learn 1.9); the conditions are in the section named on the right.

| algorithm, n x p | `scm2cpp_lasso` class | against scikit-learn | how | section |
|---|---|---|---|---|
| Lasso, 4,096 penalties each from zero, 1,800 x 200 | `CovLasso` (`fit_path_batch`) | 16x on one core, 340x on the GPU (tolerance 1e-8 against its 1e-4) | the descent over the Gram matrix | [Example: a fast lasso](docs/lasso.md#example-a-fast-lasso-from-scheme-to-pip-and-the-gpu) |
| Lasso path, 20 penalties, 100,000 x 500 | `DerivedLasso` (`fit_path`) | 6.7x | derived from the naive descent (`--derive --cublas`) | [First example: the lasso](#first-example-the-lasso) |
| RFE(LinearRegression), 20,000 x 500 | `GramRFE(0.0, ..)` | 1,047x | the Gram, its Cholesky factor downdated per drop | [Feature selection by F statistics and RFE](docs/benchmarks.md#feature-selection-by-f-statistics-and-rfe-and-the-devices-gram) |
| f_regression, 100 targets, 20,000 x 1,000 | `f_regression` | 49x | one product on the device | [Feature selection by F statistics and RFE](docs/benchmarks.md#feature-selection-by-f-statistics-and-rfe-and-the-devices-gram) |
| GraphicalLasso, p = 50 | `CDGraphicalLasso` | 45x | `--blas` | [GraphicalLasso, KMeans and RANSAC](docs/benchmarks.md#graphicallasso-kmeans-and-ransac-measured-against-sklearn) |
| HuberRegressor / LogisticRegression / PoissonRegressor, 200,000 x 100 | `LBFGSHuberRegressor` / `LBFGSLogisticRegression` / `LBFGSPoissonRegressor` | 22x / 15x / 10x | L-BFGS-B, `--cuda` | [GPU kernels from the translator](docs/benchmarks.md#gpu-kernels-from-the-translator---cuda) |
| LassoLarsIC, 200,000 x 100 | `GramLassoLarsIC` | 20x | the criterion from the Gram | [Perceptron, passive-aggressive, ARD, LassoLarsIC](docs/benchmarks.md#perceptron-passive-aggressive-ard-lassolarsic-and-the-l1-linear-svm) |
| FastICA / GaussianMixture, 200,000 x 20 | `ParallelFastICA` / `EMGaussianMixture` | 6.7x / 3.1x | `--cuda` | [GPU kernels from the translator](docs/benchmarks.md#gpu-kernels-from-the-translator---cuda) |
| LogisticRegressionCV, 2,000 x 20 / LarsCV, 2,000 x 50 | `LBFGSLogisticRegressionCV` / `GramLarsCV` | 6.6x / 6.6x | the folds over one Gram, warm starts | [GLMs, the cross-validated estimators](docs/benchmarks.md#glms-the-cross-validated-estimators-and-theil-sen) |
| ARDRegression, 20,000 x 100 | `CovARDRegression` | 3.1x | X'X formed once (`--derive` derives it) | [Loop-invariant products, derived](docs/benchmarks.md#loop-invariant-products-derived) |
| LinearSVC, 100,000 x 200 | `LinearSVM` | 1.9x | liblinear's solver in the subset | [The SVM](docs/benchmarks.md#the-svm-measured-against-sklearn) |
| NMF (cd), 20,000 x 1,000, 30 | `CDNMF` | 1.8x | derived (`--derive --cublas`) | [NMF, derived](docs/benchmarks.md#nmf-derived-measured-against-sklearn) |

### Using one in place of scikit-learn's

Most classes take the scikit-learn estimator's parameters under the
same names (a subset of them) and have its `fit` / `predict` /
`transform`, `coef_`, `n_iter_` and so on, so an import is the change:

```python
from scm2cpp_lasso import LBFGSLogisticRegression as LogisticRegression

clf = LogisticRegression(C=1.0).fit(X, y)   # scikit-learn's iterations and coefficients
```

The ones that differ: `CovLasso`, `CovRidge` and `DerivedLasso` take
the data in the constructor and solve a whole grid of penalties at
once (`fit_path` / `fit_path_batch`, where scikit-learn loops
`Lasso(alpha=a).fit` with `fit_intercept=False`); `GramRFE` takes the
ridge penalty instead of an estimator (`GramRFE(1.0,
n_features_to_select=20)` for `RFE(Ridge(alpha=1.0),
n_features_to_select=20)`, `alpha=0` for `LinearRegression`).  The
package README's [table of every
estimator](python/scm2cpp-lasso/README.md#estimators-at-a-glance) gives
each class with its scikit-learn counterpart.

**scikit-learn compatibility.** From 0.14.0 the estimators derive from
scikit-learn's `BaseEstimator` and mixins (scikit-learn itself stays
optional), so `clone`, `GridSearchCV`, `Pipeline` and
`cross_val_score` take them, and all 39 with a `fit(X, y)` pass
`check_estimator`; `GramLasso`, `GramElasticNet` and `GramRidge` are
the `fit(X, y)` forms of the Gram-matrix solvers.  The cost is the
input checks, from about 10 us per call to one pass over X; the
package README's [compatibility
section](python/scm2cpp-lasso/README.md#scikit-learn-compatibility)
has the measurements.

### Installing

```console
$ pip install scm2cpp-lasso
```

| platform | what pip installs |
|---|---|
| Linux x86_64 (glibc 2.28 or later) | a wheel, OpenBLAS inside |
| macOS 14 or later, Apple silicon | a wheel, OpenBLAS inside |
| Windows x86_64 | a wheel, without BLAS (the loop variants: same answers, slower products) |
| anything else (Linux aarch64, Intel Macs, musl) | the sdist, built on install: needs a C++17 compiler |

One wheel serves every Python 3.8 or later (the libraries are loaded
through ctypes); each wheel is tested on install with Python 3.12, and
the Linux one with 3.13 and 3.14 too.  The wheels carry no GPU code:
for the CUDA builds install from the sdist where `nvcc` is on the path
(`pip install --no-binary scm2cpp-lasso scm2cpp-lasso`).  Building the
translator itself is [docs/translator.md](docs/translator.md#installation).

### Against Intel's sklearnex

sklearnex (scikit-learn-intelex) accelerates some of the same
estimators.  On one core the package is ahead of it on every one
compared (LogisticRegression, Ridge, PCA, SVC, SVR, RFE(Ridge): 1.2x
to 128x); given all 20 cores, sklearnex is ahead on Ridge, the larger
PCA and the SVMs (the package's kernels are single-threaded), while
the device build of logistic regression (4.4x) and RFE (78x) stay
ahead.  sklearnex is not scikit-learn's arithmetic (12 L-BFGS
iterations to scikit-learn's 6, coefficients 6e-3 apart); this
package's are.  It has no lasso.  The table and the conditions are in
the [package README](python/scm2cpp-lasso/README.md#against-intels-sklearnex).

To reproduce the comparison on Colab's machines in one click, open
`notebooks/compare-sklearn.ipynb` with the badge at the top (a CPU
runtime installs the wheel; a GPU runtime builds the CUDA paths too).

Not every case is faster: PCA at 50,000 x 500 and KMeans at large n
run at or below scikit-learn's speed, and their sections say so.

## First example: the lasso

`pip install scm2cpp-lasso` and
`DerivedLasso(X, y).fit_path(lambdas)` runs a lasso whose C++ the
translator *derived*: the source is the naive residual-form
coordinate descent (`examples/kernel-only/lasso-design.scm`, flat
loops over X as numpy holds it, no Gram matrix anywhere), `--derive`
turns it into the covariance form with the Gram matrix hoisted in
front of the penalty path, and `--blas` / `--cublas` hand its three
products to BLAS or cuBLAS.  Nothing of it is written at the Gram
level by hand, and nothing is prepared in numpy.  On an RTX 4090 the
cuBLAS build solves a 20-penalty path in 0.024 / 0.052 / 0.11 s at
5,000 x 1,000 / 100,000 x 200 / 100,000 x 500, against 0.100 / 0.236
/ 0.759 s for scikit-learn's `lasso_path(precompute=True)` at its
default tolerance on one core -- 4.2x, 4.5x, 6.7x; 2.2x, 4.5x,
4.0x when scikit-learn gets all 20 BLAS threads, since only its Gram
product scales -- and the CPU build times the same as the
hand-written `CovLasso` beside it.  The
table, the conditions and the differences against a tight reference
are in `python/scm2cpp-lasso/README.md`.  Every rule of the derivation, in the order
it fires, with links into the code, is in `DERIVATION.md`.

## What the translation looks like

Unlike conventional Scheme compilers, which emit C intended only for a machine,
Scm2Cpp gives Scheme values no runtime representation: an integer becomes an
`int`, a vector becomes a `std::array<double,1025>`, and `(car x)` becomes
`car(x)`. Types come from whole-program inference; what inference cannot pin
down becomes a C++ template parameter.

```scheme
(define (square x) (* x x))
(define (average x y) (/ (+ x y) 2.0))
(define (improve guess x) (average guess (/ x guess)))
```

becomes

```cpp
double square( double x )                 { return (x*x) ; }
double average( double x, double y )      { return ((x+y)/2.0) ; }
double improve( double guess, double x )  { return average(guess,double((x/guess))) ; }
```

## Documentation

- [docs/lasso.md](docs/lasso.md) - the lasso in detail: the kernels,
  every lasso pip can install, cross-validation, the GPU batch, memory,
  calling it from Python
- [docs/benchmarks.md](docs/benchmarks.md) - each estimator family
  against scikit-learn: the algorithm, the protocol, the full tables
- [docs/translator.md](docs/translator.md) - the translator itself:
  installing it, the command line and its options, the Scheme subset,
  the test suite, the Typed Racket cross-check, the runtime header
- [python/scm2cpp-lasso/README.md](python/scm2cpp-lasso/README.md) -
  the Python package: every estimator, the sklearnex comparison
- `FILES.md` - every source file's role in a line or two and the
  `require` graph between the Racket modules, grouped by pipeline
  stage; where a change goes (`FILES.ja.md` in Japanese)
- `DERIVATION.md` - how `DerivedLasso` is derived: each rule on the
  `--derive --blas` log line for `lasso-design.scm`, in firing order,
  with links into the code (`DERIVATION.ja.md` in Japanese)
- `CHANGES.ja.md` - a record of the modifications made to the historical code
  base, with the reason for each
- `scribblings/scm2cpp.scrbl` - the manual of the Racket interface
  (`read-source-forms`, `scm2cpp-match-list`, ...). Its examples are
  evaluated when it is built, so it is also a test: `raco scribble
  --dest /tmp/scm2cpp-doc scribblings/scm2cpp.scrbl` (with
  `PLTCOLLECTS=$PWD/vendor:` or rkanren linked) writes
  `scm2cpp.html`, and `run-tests.sh` builds it as `doc-unit`
- `ideal/stream-ideal-new.cpp` - the intended shape of the generated code for
  delayed streams, written by hand

## Contributing

See `CONTRIBUTING.md`.

## License

MIT License; see `LICENSE`, which carries the MIT terms and nothing else.

Several files derive from Aubrey Jaffer's Schlep and SLIB, and from utilities
published in Paul Graham's *On Lisp*; `vendor/rkanren` is a bundled
third-party library. These remain under their own permissive terms, which are
reproduced in full at the head of each file. Those conditions are additional
to the MIT terms and are recorded in `NOTICE`, together with the provenance
and the measured extent of each derivation -- not in `LICENSE`, so that the
licence file stays identifiable as plain MIT. Redistributors must honour them
in addition to the MIT terms.

## Citing

A paper describing the design is in preparation and is not in this repository
yet. Until it appears, cite the repository and the commit you used;
machine-readable metadata is in `CITATION.cff`.

The temporal feature selection behind the `tfs-` kernels (the
moving-average designs, [`scm2cpp-tfs`](https://pypi.org/project/scm2cpp-tfs/))
is described in H. Niitsuma, *An Extension of Temporal Feature Selection*, Zenodo, 2026, [doi:10.5281/zenodo.18909363](https://zenodo.org/records/18909363).
