# The estimators against scikit-learn

*[Japanese](benchmarks.ja.md)* · [README](../README.md)

Each estimator family measured against scikit-learn: the algorithm, how it was written in the subset, the protocol, and the table the README's summary is drawn from.

## The SVM, measured against sklearn

Four SVM kernels live in `examples/kernel-only/`.
`svm-liblinear.scm` is liblinear's solver for the L1-loss linear SVM,
written out whole: dual coordinate descent with a random order in
every sweep, shrinking, and the projected-gradient stop test. It is
the code scikit-learn's `LinearSVC(loss="hinge", dual=True)` runs.
`svm-kernel.scm` is the same sweep with a fixed order and no
shrinking. `--derive` turns it into the kernel form (a memo
`c = X w` over the kernel matrix `X X'`) under `(if (< n p) ..)`.
`svm-dual.scm` is that kernel form written by hand for any kernel
matrix, so it also runs a nonlinear (RBF) SVM, and `svm-smo.scm` is
libsvm's SMO solver, the one `SVC` runs, written out whole.

Measured with `bench/svm-compare.py` on one core (i9-10900X, RTX 4090
for the cuBLAS row, sklearn 1.9.1, load average about 4.5 from other
jobs). The setting is C = 1 with no intercept, and every linear solver
stops at the same test (projected-gradient span <= 1e-4) or after
1,000 sweeps. The objective is the primal
`1/2 |w|^2 + C sum max(0, 1 - y w.x)`:

| n x p | `svm-liblinear.scm`, plain | `LinearSVC` | ratio | objective (ours / sklearn) | `svm-kernel.scm --derive --cublas` |
|---|---|---|---|---|---|
| 5,000 x 200 | 0.369 s | 0.774 s | 2.1x | 1541.06 / 1541.37 | 0.982 s (n > p: the sweep as written) |
| 100,000 x 200 | 25.9 s | 48.7 s | 1.9x | 34503.5 / 34506.9 | 29.6 s (likewise) |
| 300 x 2,000 | 0.011 s | 0.026 s | 2.4x | 0.08439 / 0.08430 | 0.003 s (kernel form) |
| 2,000 x 20,000 | 0.965 s | 1.998 s | 2.1x | 0.05411 / 0.05400 | 0.256 s (kernel form) |

- **The same algorithm runs about 2x faster than sklearn and reaches
  the same objective.** The gain is in the implementation, not the
  algorithm: liblinear walks every row through its sparse
  `feature_node` list even for dense data, while the translated loop
  is dense and vectorises at `-O3 -march=native`. The kernel is
  translated plainly; `--derive` leaves it alone, because the point a
  step works on is `index[s]`, a let-bound index rather than a loop
  coordinate.
- **Shrinking and random order are part of the algorithm.**
  `svm-kernel.scm` has neither. On tall data it needs as many sweeps,
  each over every point, and ends at a worse objective (1548.32 at
  5,000 x 200). Shrinking alone with a fixed order is worse still: the
  same points are shrunk sweep after sweep and the fit stalls.
- **On wide data the derived kernel form pays on the GPU.** At
  2,000 x 20,000 the cuBLAS build is 7.8x `LinearSVC`. The CPU BLAS
  build is not: 1.049 s against 0.721 s for the sweep as written. A fit
  of 12 sweeps cannot repay an n x n x p kernel matrix, and the guard
  looks only at the shape, not at the number of sweeps.

Nonlinear (RBF, gamma = 1/p, C = 1; accuracy on 2,000 fresh rows; a
K built in numpy is timed in on our side; load average 1.6-3.7). `svm-smo.scm` is libsvm's
solver for C-SVC, written out whole: WSS3 working-set selection,
shrinking with gradient reconstruction, and the bias. It solves SVC's
problem at SVC's tol of 1e-3, over the whole kernel matrix (libsvm
with a cache large enough for every row), so it is compared with
`SVC(kernel='precomputed')` on the same K. `svm-dual.scm` is the
kernel form of `svm-kernel.scm`: no intercept, no shrinking, tol 1e-4.

| n x p | `svm-smo.scm` | `SVC(kernel='precomputed')`, K included | `SVC(kernel='rbf')` | dual objective (ours / SVC) | iterations (ours / SVC) | `svm-dual.scm` |
|---|---|---|---|---|---|---|
| 2,000 x 50 | 0.070 s | 0.078 s | 0.145 s | -1071.2597 / -1071.2597 | 2,291 / 2,274 | 4.71 s |
| 5,000 x 50 | 0.490 s | 0.561 s | 0.957 s | -2622.9261 / -2622.9261 | 5,741 / 5,755 | 38.2 s |
| 10,000 x 50 | 2.08 s | 2.55 s | 4.05 s | -5044.1532 / -5044.1531 | 10,930 / 10,951 | 193.9 s |

**With libsvm's algorithm, the nonlinear SVM is faster than sklearn
too**: 1.1-1.2x `SVC(kernel='precomputed')` on the same K, and about
2x `SVC(kernel='rbf')`, which computes kernel rows on demand through
its cache. The iteration counts and the dual objectives agree, and
so do the test accuracies (0.669 / 0.725 / 0.748 for both). The cost is
memory: the whole n x n kernel matrix (800 MB at n = 10,000), which
`SVC(kernel='rbf')` never holds. `svm-dual.scm` shows what the
algorithm, not the translation, costs: without shrinking and with
every moved alpha updating all n entries of its memo, it is about
50-90x slower.

## L1 logistic regression, measured against sklearn

`examples/kernel-only/logistic-l1.scm` is liblinear's solver for
L1-regularized logistic regression, `solve_l1r_lr` (newGLMNET, Yuan,
Ho and Lin 2011), written out whole. Each Newton iteration builds a
quadratic model of the loss, minimises it plus the L1 term by
coordinate descent (random order, shrinking), and takes a step by
line search; coordinates the gradient holds at zero leave the outer
active set. It is the code `LogisticRegression(l1_ratio=1,
solver="liblinear", fit_intercept=False)` runs, translated plainly.

Measured with `bench/logistic-l1-compare.py`: one core, tol 1e-4, at
most 100 Newton iterations, best of three, sklearn 1.9.1, load
average about 2. Our time includes transposing X into columns, which
liblinear also does inside:

| n x p, C | `logistic-l1.scm` | `LogisticRegression` (liblinear) | ratio | objective (ours / sklearn) | nonzeros | Newton iterations |
|---|---|---|---|---|---|---|
| 1,000 x 50, 1 | 0.003 s | 0.005 s | 1.8x | 229.43158 / 229.43158 | 43 / 43 | 13 / 13 |
| 5,000 x 200, 0.1 | 0.080 s | 0.117 s | 1.5x | 64.465989 / 64.465993 | 74 / 74 | 18 / 16 |
| 20,000 x 500, 0.05 | 1.243 s | 2.361 s | 1.9x | 108.71711 / 108.71713 | 144 / 144 | 19 / 17 |
| 100,000 x 200, 0.05 | 9.508 s | 18.153 s | 1.9x | 324.5394 / 324.53954 | 124 / 124 | 19 / 19 |

It is the SVM's result again: the same algorithm runs about 2x faster
and lands on the same objective and the same support. The gain is the
dense loop, which vectorises, against liblinear's `feature_node`
lists. The iteration counts differ by one or two because the two
random orders are different streams. The loss is not quadratic, so
`--derive` has no Gram form to find here.
`scm2cpp_lasso.CovLogistic` solves the same problem by a different
algorithm (a fixed X'X/4 majorizer over the lasso's descent); this
table is the like-for-like one.

The package carries these solvers: `scm2cpp_lasso.LinearSVM`,
`KernelSVM` and `L1LogisticRegression` are `svm-liblinear.scm`,
`svm-smo.scm` and `logistic-l1.scm` translated into one library, and
`LinearSVR` and `KernelSVR` the epsilon-SVRs beside them
(`svr-liblinear.scm`, liblinear's; and libsvm's, through the same SMO
in `svm-smo.scm`, whose solver takes any linear term and maps 2n
variables onto the n kernel rows), with
scikit-learn's interface (`fit`, `predict`, `decision_function`); the
package README has their table, measured through the package.

## NMF, derived, measured against sklearn

`examples/kernel-only/nmf-cd.scm` writes scikit-learn's
`NMF(solver="cd")` iteration the plain way. Each half step forms the
residual R = X - W H and sweeps the coordinates of one factor,
moving R along a column of the other: no Gram matrix anywhere.
`--derive` finds R as the scratch, memoises R H' over the hoisted
H H', and then distributes the fill through the memo
(`R H' = X H' - W (H H')`, a rule added for this kernel), so R is never
formed. The result is the form scikit-learn's
`_update_coordinate_descent` builds by hand, `XHt - W HHt`, and
`--blas` / `--cublas` hand its products to (cu)BLAS
(`derive: nmf-half: raise differencing matmul distribute guard`).

Measured with `bench/nmf-compare.py`: scikit-learn
`NMF(solver="cd", init="custom")` from the same W and H, tol 1e-4, at
most 200 iterations, one core, load average under 2:

| n x p, k | sklearn | `nmf-cd.scm` plain | `--derive --blas` | `--derive --cublas` | iterations (all) | max \|W - W_sklearn\| |
|---|---|---|---|---|---|---|
| 1,000 x 500, 10 | 0.246 s | 4.57 s | 0.202 s (1.22x) | 0.645 s | 200 | 1.2e-12 |
| 5,000 x 2,000, 20 | 10.68 s | - | 8.09 s (1.32x) | 6.75 s (1.58x) | 200 | 2.5e-13 |
| 20,000 x 1,000, 30 | 29.04 s | - | 20.72 s (1.40x) | 16.38 s (1.77x) | 200 | 8.9e-13 |

The derivation takes the plain kernel from 20x slower than
scikit-learn to 1.2-1.8x faster, with the same iterates to 1e-12. The
package carries it as `scm2cpp_lasso.CDNMF` (the three variants, as for
`DerivedLasso`).

## DBSCAN, measured against sklearn

`examples/kernel-only/dbscan.scm` is DBSCAN by brute-force
neighbourhoods, the dot products by tiled matrix products (256 x 1024
tiles, kept in cache). It makes three passes over the tiles: neighbour
counts, a union-find over the core points, and border points to the
cluster with the smallest root. It stores no neighbourhood, and its
labels are scikit-learn's exactly: clusters are numbered by their
smallest core point, as `dbscan_inner` starts them.
`bench/dbscan-compare.py`, one core:

| n x p | sklearn `brute` | sklearn default | `dbscan.scm --blas` | `--cublas` | labels identical |
|---|---|---|---|---|---|
| 5,000 x 2 | 0.054 s | 0.017 s | 0.079 s | 0.343 s | yes |
| 20,000 x 2 | 0.622 s | 0.079 s | 1.067 s | 2.665 s | yes |
| 5,000 x 32 | 0.062 s | 0.061 s | 0.111 s | 0.217 s | yes |
| 20,000 x 32 | 0.964 s | 0.969 s | 1.757 s | 3.184 s | yes |

**This one is not faster.** scikit-learn's brute search stores the
neighbourhoods and walks the n^2 distances once; this kernel stores
nothing and walks them twice (once to count, once to join). Per pass it
is level with scikit-learn, so overall it runs at about half the speed.
In two dimensions scikit-learn's default tree is 8x faster still. The
cuBLAS build is slower again, because only the product runs on the
device: the threshold test stays on the host, and every tile comes back
across the bus. A fused distance-and-threshold kernel on the device is
what would pay, and the translator emits BLAS calls, not device code.
DBSCAN is therefore not in the package.

## GraphicalLasso, KMeans and RANSAC, measured against sklearn

Three more of scikit-learn's algorithms, each written out whole in the
subset and translated plainly, with no derivation. Where a product
matters it is written as `matmul`, so `--blas` hands it to BLAS as
numpy would. All three give scikit-learn's results: the same iteration
or trial counts, and the same labels, inliers, precision or
coefficients to 1e-14. One core throughout.

**GraphicalLasso** (`examples/kernel-only/graphical-lasso.scm`):
`_graphical_lasso` in mode "cd" with `enet_coordinate_descent_gram`
inside it, the gap-safe rule included. `bench/glasso-compare.py`
uses an AR(1) design with n = 20p, alpha 0.1 and 100 iterations on
both sides:

| p | sklearn | plain | `--blas` |
|---|---|---|---|
| 50 | 0.302 s | 0.0167 s (18.1x) | 0.0066 s (45.5x) |
| 100 | 0.639 s | 0.148 s (4.3x) | 0.0436 s (14.7x) |
| 200 | 1.69 s | 1.36 s (1.2x) | 0.292 s (5.8x) |
| 400 | 7.74 s | 11.4 s (0.7x) | 3.32 s (2.3x) |
| 800 | 43.3 s | 92.9 s (0.5x) | 33.9 s (1.3x) |

For small p the gain is Python's: scikit-learn calls its Cython inner
solver once per column and does the bookkeeping in numpy, while here the
whole loop is C++. For large p the work is two matrix-vector products
per column. As loops they are reductions, which the compiler may not
reorder and so cannot vectorise, and the plain build falls behind; as
`matmul` under `--blas` they are dgemv, as in scikit-learn.

**KMeans** (`examples/kernel-only/kmeans.scm`): Lloyd's algorithm as
`_kmeans_single_lloyd` runs it, the distances `|c|^2 - 2 x.c` by tiled
products. `bench/kmeans-compare.py` starts both sides from the same k
points:

| n x p, k | sklearn | `--blas` | `--cublas` |
|---|---|---|---|
| 10,000 x 20, 8 | 0.021 s | 0.010 s (2.1x) | 0.256 s |
| 100,000 x 20, 16 | 0.346 s | 0.394 s (0.88x) | 1.49 s |
| 100,000 x 100, 32 | 1.26 s | 1.21 s (1.04x) | 2.42 s |
| 200,000 x 50, 64 | 3.41 s | 3.33 s (1.02x) | 7.55 s |

**Level with scikit-learn**: its Lloyd step is already Cython over BLAS,
so the same algorithm has nothing left to gain. The cuBLAS build loses,
because each small tile crosses the bus. KMeans is not in the package.

**RANSAC** (`examples/kernel-only/ransac.scm`): `RANSACRegressor.fit`
around `LinearRegression`, given the subsets scikit-learn draws (the
package draws them the same way). `bench/ransac-compare.py`, with
max_trials 1000:

| n x p, outliers | sklearn | `ransac.scm` | trials (both) |
|---|---|---|---|
| 1,000 x 3, 20% | 0.0155 s | 0.0128 s (1.2x) | 9 |
| 10,000 x 5, 40% | 0.0944 s | 0.0321 s (2.9x) | 98 |
| 100,000 x 10, 30% | 0.270 s | 0.160 s (1.7x) | 97 |
| 20,000 x 20, 50% | 1.23 s | 0.508 s (2.4x) | 1,000 |

The gain is again the per-trial Python and validation scikit-learn pays.
The package carries `CDGraphicalLasso` and `LinearRANSAC`.

## SGD, OMP and LARS, measured against sklearn

The last three, written out whole and translated plainly:
`examples/kernel-only/sgd.scm` (`_plain_sgd`: SGDClassifier's hinge
with the "optimal" rate, and SGDRegressor's squared error with
"invscaling", the weight vector kept as a scale times a vector),
`omp.scm` (`orthogonal_mp_gram` / `_gram_omp`), and `lars.scm`
(`_lars_path_solver` with a Gram, for "lar" and "lasso", the Cholesky
downdate by Givens rotations included). `bench/sgd-omp-lars-compare.py`
runs each against scikit-learn on the same data, one core:

| estimator, n x p | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| SGDClassifier, 10,000 x 20 | 0.018 s | 0.005 s | 3.3x | 30 / 30 epochs, weights identical |
| SGDClassifier, 100,000 x 50 | 0.159 s | 0.101 s | 1.6x | identical |
| SGDClassifier, 50,000 x 500 | 2.24 s | 2.08 s | 1.1x | identical |
| SGDRegressor, 100,000 x 50 | 0.114 s | 0.090 s | 1.3x | identical |
| OrthogonalMatchingPursuit, 2,000 x 100 | 0.004 s | 0.001 s | 2.8x | same columns, coef to 3e-15 |
| OrthogonalMatchingPursuit, 20,000 x 1,000 | 0.381 s | 0.350 s | 1.1x | coef to 3e-15 |
| Lars, 2,000 x 100 | 0.004 s | 0.001 s | 3.8x | 20 / 20 steps, coef to 1e-15 |
| Lars, 20,000 x 1,000 | 0.465 s | 0.352 s | 1.3x | 200 / 200 steps, coef to 5e-15 |
| LassoLars, 2,000 x 100 | 0.006 s | 0.001 s | 5.0x | 38 / 38 steps, coef to 2e-15 |
| LassoLars, 20,000 x 1,000 | 0.404 s | 0.333 s | 1.2x | 104 / 104 steps, coef to 4e-15 |

SGD runs with `shuffle=False` on both sides, and the weights are then
bit-identical. scikit-learn's shuffling draws from its own xorshift
generator, which the subset, having no bit operations, does not
reproduce. The gains are again scikit-learn's per-step Python, and they
shrink as the compiled work grows. On paths where variables leave the
lasso, `LassoLars` still agrees step for step. Two translator fixes came
out of these kernels: `(expt x y)` is now emitted as `std::pow`, and
alpha-conversion's fresh names avoid every symbol of the program, where
they used to avoid only the names bound so far. The package carries all
five as `SGDLinearClassifier`, `SGDLinearRegressor`, `GramOMP`,
`GramLars` and `GramLassoLars`.

## L2 logistic regression and the Huber regressor (L-BFGS), measured against sklearn

scikit-learn's default `LogisticRegression` and its `HuberRegressor`
both hand their objective to scipy's L-BFGS-B. Both are written out
whole: `examples/kernel-only/lbfgs.scm` is L-BFGS-B as it runs for
them (the direction from ten pairs, MINPACK-2's More-Thuente line
search with L-BFGS-B's constants, its stopping tests and restarts; for
one variable bounded below, as the Huber scale is, the generalized
Cauchy point and the subspace step that L-BFGS-B takes), and
`logistic-lbfgs.scm` / `huber.scm` are the objectives and gradients
(`LinearModelLoss` with the binomial or multinomial loss,
`_huber_loss_and_gradient`), their products written as `matmul` and
translated with `--blas`. `bench/lbfgs-compare.py`, one core
(load ~1.5):

| estimator, n x p (classes) | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| LogisticRegression, 500 x 20 (2) | 0.0021 s | 0.0003 s | 8.3x | 8 / 8 iterations, coef to 2e-16 |
| LogisticRegression, 5,000 x 100 (2) | 0.0081 s | 0.0048 s | 1.7x | 10 / 10, 2e-16 |
| LogisticRegression, 5,000 x 100 (5) | 0.0262 s | 0.0152 s | 1.7x | 15 / 15, 4e-14 |
| LogisticRegression, 50,000 x 200 (2) | 0.223 s | 0.207 s | 1.1x | 11 / 11, 1e-15 |
| LogisticRegression, 50,000 x 200 (5) | 0.662 s | 0.569 s | 1.2x | 17 / 17, 1e-13 |
| HuberRegressor, 500 x 20 | 0.0043 s | 0.0002 s | 18x | 15 / 15, 2e-16 |
| HuberRegressor, 5,000 x 100 | 0.0305 s | 0.0098 s | 3.1x | 16 / 16, 2e-16 |
| HuberRegressor, 50,000 x 200 | 1.170 s | 0.464 s | 2.5x | 16 / 16, 1e-15 |
| HuberRegressor, 200,000 x 100 | 1.708 s | 0.653 s | 2.6x | 12 / 12, 1e-15 |

The iterations agree one for one, and so do the coefficients to
rounding: the line search tries the same steps. A large binary logistic
problem is two matrix-vector products per evaluation on both sides, so
the ratio there is near 1. The Huber regressor gains more because
scikit-learn slices the inliers and the outliers into new arrays at
every evaluation. Two runtime and translator changes came with these
kernels. `blas_gemm` in `scm2cpp-blas.hpp` now calls dgemv when m or n
is 1 at run time (one class of a logistic regression): OpenBLAS's
dgemm with a unit dimension cost a third more. And `(exact->inexact
n)` is now emitted as `double(n)`; unlike `(* 1.0 n)`, it leaves the
type of `n` alone. The package carries both as `LBFGSLogisticRegression`
and `LBFGSHuberRegressor`.

## The Gaussian mixture, FastICA and PCA, measured against sklearn

Three more of scikit-learn's estimators written out whole and translated
with `--blas`: `examples/kernel-only/gmm.scm` (`GaussianMixture` with
full covariances: the M step's means and covariances as products, the
Cholesky and precision factors, the E step through X U - mu U, the stop
on the lower bound), `fastica.scm` (`FastICA` at its defaults: the
whitening from the eigenvectors of X'X, signed as scikit-learn signs
X's singular vectors, the parallel iteration, the symmetric
decorrelation) and `pca.scm` (`PCA` by the covariance's eigenvectors,
the solver scikit-learn's "auto" picks for a tall design). The last two
share `sym-eigen.scm`: Householder reduction to tridiagonal form and the
implicit QL iteration, written in the subset. `bench/gmm-ica-pca-compare.py`,
one core, the same starts on both sides (random_state 0):

| estimator, n x p | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| GaussianMixture, 2,000 x 5 (4 components) | 0.0078 s | 0.0032 s | 2.4x | 3 / 3 iterations, 4e-16 |
| GaussianMixture, 20,000 x 10 (8) | 0.125 s | 0.058 s | 2.1x | 3 / 3, 9e-16 |
| GaussianMixture, 20,000 x 10 (8, overlapping) | 0.288 s | 0.137 s | 2.1x | 9 / 9, 5e-15 |
| GaussianMixture, 100,000 x 20 (5) | 1.011 s | 0.618 s | 1.6x | 4 / 4, 1e-14 |
| FastICA, 5,000 x 8 | 0.0116 s | 0.0085 s | 1.4x | 27 / 27, 6e-13 |
| FastICA, 50,000 x 10 | 0.083 s | 0.075 s | 1.1x | 17 / 17, 3e-13 |
| FastICA, 100,000 x 30 | 1.059 s | 0.741 s | 1.4x | 21 / 21, 3e-11 |
| PCA, 1,000 x 10 | 0.0005 s | 0.0001 s | 4.2x | 6e-15 |
| PCA, 10,000 x 50 | 0.0021 s | 0.0015 s | 1.3x | 4e-13 |
| PCA, 100,000 x 50 | 0.0214 s | 0.0150 s | 1.4x | 4e-14 |
| PCA, 20,000 x 200 | 0.0270 s | 0.0331 s | 0.8x | 2e-13 |
| PCA, 50,000 x 500 | 0.248 s | 0.406 s | 0.6x | 3e-12 |

The mixture's time includes the KMeans start on both sides (the package
runs scikit-learn's own KMeans for it). PCA is where the subset loses:
past a hundred or so features the eigenproblem dominates, and LAPACK's
blocked divide-and-conquer `dsyevd` beats the unblocked QL iteration.
A first version with Jacobi rotations was 14x slower at 500 features.
FastICA computes tanh as 1 - 2 / (e^2x + 1). The C library's `tanh`
does not vectorise and made the whole fit 0.6x of scikit-learn's. The
package carries the three as `EMGaussianMixture`, `ParallelFastICA`
and `CovPCA`.

## Perceptron, passive-aggressive, ARD, LassoLarsIC and the L1 linear SVM

Five more, each scikit-learn's own algorithm in the subset:

- `sgd.scm` now takes scikit-learn's other `_plain_sgd` options: the
  perceptron's hinge (threshold 0), the epsilon-insensitive loss, the
  "constant" step, the passive-aggressive steps "pa1" / "pa2", and no
  penalty. That covers `Perceptron` and what scikit-learn 1.8 replaced
  `PassiveAggressiveClassifier` / `PassiveAggressiveRegressor` with.
- `ard.scm` is `ARDRegression` for n >= p. Each iteration takes scipy's
  `pinvh` of diag(lambda) + alpha G over the kept features, with the
  eigenproblem from `sym-eigen.scm`. scikit-learn forms the kept
  features' Gram from X every iteration. A flag takes it from X'X,
  formed once, instead. That is the loop-invariant product moved out of
  the loop, by hand, and the table shows both.
- `lars.scm` records the path as `lars_path(return_path=True)` returns
  it. `LassoLarsIC` picks a knot on that path by scikit-learn's
  criterion. The package computes the residual sums from the Gram
  (|y - Xc|^2 = y'y - 2c'X'y + c'Gc) rather than from X at every knot.
- `svm-l1.scm` is liblinear's `solve_l1r_l2_svc`, what
  `LinearSVC(penalty="l1", dual=False)` runs. Its random coordinate order
  comes from a different generator than liblinear's, so it agrees to
  the tolerance rather than to rounding.

`bench/linear-variants-compare.py`, one core, SGD with `shuffle=False`:

| estimator, n x p | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| Perceptron, 10,000 x 20 | 0.0043 s | 0.0014 s | 3.0x | 8 / 8 epochs, identical |
| Perceptron, 100,000 x 50 | 0.0785 s | 0.0516 s | 1.5x | identical |
| SGDClassifier pa1, 10,000 x 20 | 0.0056 s | 0.0026 s | 2.2x | 9 / 9, identical |
| SGDRegressor epsilon-insensitive pa1, 100,000 x 50 | 0.112 s | 0.091 s | 1.2x | 7 / 7, identical |
| ARDRegression, 20,000 x 100 | 0.054 s | 0.034 s | 1.6x | 3 / 3, 1e-14 |
| ARDRegression, Gram hoisted, 20,000 x 100 | 0.054 s | 0.018 s | 3.1x | 3 / 3, 1e-14 |
| ARDRegression, Gram hoisted, 100,000 x 200 | 0.697 s | 0.235 s | 3.0x | 3 / 3, 8e-14 |
| LassoLarsIC (aic), 5,000 x 100 | 0.041 s | 0.0049 s | 8.3x | 100 / 100 steps, 9e-16 |
| LassoLarsIC (aic), 200,000 x 100 | 2.867 s | 0.141 s | 20x | 100 / 100, 6e-16 |
| LinearSVC l1, 5,000 x 100 | 0.779 s | 0.699 s | 1.1x | objective to 4e-7 |
| LinearSVC l1, 100,000 x 50 | 4.837 s | 3.189 s | 1.5x | objective to 8e-8 |

LassoLarsIC gains the most. scikit-learn evaluates its criterion with an
n x knots product and an SVD least squares, and the Gram already holds
the same numbers. With these, every candidate listed earlier is in. The
package carries them as `SGDPerceptron`, the new options of
`SGDLinearClassifier` / `SGDLinearRegressor`, `CovARDRegression`,
`GramLassoLarsIC` and `L1LinearSVM`.

## GLMs, the cross-validated estimators and Theil-Sen

- `examples/kernel-only/glm.scm` is a third objective for `lbfgs.scm`.
  It covers `PoissonRegressor`, `GammaRegressor` and `TweedieRegressor`
  (the half deviances with the log link, power 0 with the identity
  link), each started where scikit-learn starts it.
- The cross-validated estimators are compositions in the package:
  - `LogisticRegressionCV` uses the Cs path, warm-started per fold.
  - `LarsCV` / `LassoLarsCV` use LARS paths interpolated onto the union
    of the folds' alphas.
  - `OrthogonalMatchingPursuitCV` uses `omp.scm`, which now records its
    path too.

  The folds are dealt as `KFold` / `StratifiedKFold` deal them without
  shuffling. In LarsCV the test error comes from the test fold's Gram.
- `theilsen.scm` is `TheilSenRegressor`: every subset's fit (an exact
  solve, or gelss's minimum-norm fit for a singular subset), then the
  spatial median by the modified Weiszfeld iteration.

`bench/glm-cv-compare.py`, one core:

| estimator, n x p | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| PoissonRegressor (alpha 1e-3), 2,000 x 20 | 0.0022 s | 0.0004 s | 6.0x | 8 / 8 iterations, 2e-16 |
| GammaRegressor (alpha 1e-3), 50,000 x 100 | 0.0719 s | 0.0647 s | 1.1x | 7 / 7, 1e-15 |
| TweedieRegressor (power 1.5), 50,000 x 100 | 0.0740 s | 0.0654 s | 1.1x | 7 / 7, 9e-16 |
| LogisticRegressionCV, 2,000 x 20 | 0.0816 s | 0.0124 s | 6.6x | same C, 2e-16 |
| LogisticRegressionCV, 20,000 x 50 (3 classes) | 0.617 s | 0.389 s | 1.6x | same C, 1e-11 |
| LarsCV, 2,000 x 50 | 0.0348 s | 0.0053 s | 6.6x | same alpha, 4e-16 |
| LassoLarsCV, 50,000 x 200 | 1.297 s | 0.593 s | 2.2x | same alpha, 7e-16 |
| OrthogonalMatchingPursuitCV, 50,000 x 200 | 1.416 s | 0.517 s | 2.7x | same k, 3e-16 |
| TheilSenRegressor, 1,000 x 5 | 0.309 s | 0.192 s | 1.6x | 5 / 5, 4e-15 |
| TheilSenRegressor, 5,000 x 10 | 0.885 s | 0.669 s | 1.3x | 5 / 5, 3e-15 |

The large GLM fits are two matrix-vector products per evaluation on
both sides, so they come out at 1.1x. Most of TheilSen's time, on both
sides, goes to drawing the 10,000 subsets with
`RandomState.choice`. That drawing is kept so that the subsets are
scikit-learn's. The fits and the median take 8 ms against scikit-learn's
roughly 200 ms. The package carries these as `LBFGSPoissonRegressor`,
`LBFGSGammaRegressor`, `LBFGSTweedieRegressor`,
`LBFGSLogisticRegressionCV`, `GramLarsCV`, `GramLassoLarsCV`,
`GramOMPCV` and `WeiszfeldTheilSen`.

## Feature selection by F statistics and RFE, and the device's Gram

- `examples/kernel-only/fscore.scm` is scikit-learn's `f_regression`
  (through `r_regression`) and `f_classif` (`f_oneway`). Many targets go
  in one call, so X'Y is a single product; with `--cublas` it runs on the
  device. scikit-learn takes one target per call.
- `rfe.scm` is `RFE` around `Ridge` / `LinearRegression`. The centred
  Gram is formed once, and its Cholesky factor once. Each dropped
  feature is taken out of the factor by plane rotations (`lars.scm`'s
  `cholesky_delete`), and each round ranks by coef^2 in a stable order.
  scikit-learn refits from X every round.
- `gram.scm` is the bare X'X and X'Y. The package builds it, with
  `fscore.scm`, `rfe.scm` and `pca.scm`, as one `--cublas` library. The
  Gram-route wrappers use it when a device answers and the product is
  large.

`bench/select-compare.py`, one core plus an RTX 4090:

| call, n x p | sklearn | ours | ratio | agreement |
|---|---|---|---|---|
| f_regression, 100,000 x 500, 1 target | 0.152 s | 0.078 s | 1.9x | F to 3e-15 |
| f_regression, 20,000 x 1,000, 100 targets (device) | 6.07 s | 0.125 s | 49x | F to 2e-14 |
| f_regression, 100,000 x 200, 200 targets (device) | 12.7 s | 0.399 s | 32x | F to 8e-14 |
| SelectKBest(f_classif), 100,000 x 500 | 0.448 s | 0.100 s | 4.5x | same features |
| RFE(Ridge), 5,000 x 100 | 0.245 s | 0.0031 s | 80x | same ranking, coef to 2e-15 |
| RFE(Ridge), 50,000 x 300 | 38.7 s | 0.157 s | 246x | same ranking, 1e-14 |
| RFE(LinearRegression), 20,000 x 500 | 167 s | 0.160 s | 1,047x | same ranking, 1e-14 |

| Gram on the device, n x p | sklearn | ours, CPU | ours, device |
|---|---|---|---|
| LassoLarsIC, 100,000 x 300 | 3.44 s | 0.289 s | 0.201 s |
| LassoLarsCV, 100,000 x 300 | 3.98 s | 1.97 s | 1.53 s |
| PCA, 200,000 x 300 | 0.427 s | 0.421 s | 0.245 s |

RFE's thousandfold gain is the refit avoided: one Gram and one factor
replace p fits from X. The device helps only where one product
dominates. That holds for many targets in f_regression, a large Gram
(LassoLarsIC, PCA's covariance) and nothing else. At 100 features, or
when the folds' copies of X dominate, the CPU time is unchanged. The
estimators whose loops run between products (the mixture, FastICA,
the L-BFGS fits) gain at most 15% on the device. Their elementwise
work stays on the host, and the matrices it writes cross the bus at
every product. The package carries `f_regression`, `f_classif`,
`SelectKBest`, `SelectPercentile` and `GramRFE`, and the device Gram
under `GramLassoLarsIC`, `GramLarsCV`, `GramLassoLarsCV`, `GramLars`,
`GramLassoLars` and `CovPCA`.

## GPU kernels from the translator (`--cuda`)

`--cuda` turns the loops of an ordinary kernel into CUDA kernels. It
uses the dependence test the translator already had for its OpenMP
annotation: every element a loop writes belongs to one iteration, and
a scalar carried across iterations is a sum. So the source needs no
annotation. Each such loop whose body computes only on scalars and
array elements becomes a `__global__` function, one thread per
iteration, with the sum reduced by an atomic add. Below
`SCM2CPP_CUDA_MIN` iterations the host loop runs instead.

What makes this pay is that the arrays stay on the device. The
runtime (`scm2cpp-cuda.hpp`) keeps, for every array a device statement
has touched, a device copy and two flags:

- a kernel or a cuBLAS product uploads only what the device lacks;
- a host statement downloads only what the host lacks, and then marks
  what it wrote.

The translator places those calls statement by statement. An
iteration whose host part touches only small arrays (FastICA's
k x k decorrelation, L-BFGS's direction) therefore never moves the
large ones.

The package carries FastICA, the Gaussian mixture and the L-BFGS fits
translated this way. It takes that build when a device answers and the
problem has a million entries or more. `bench/cuda-compare.py`: one
core against an RTX 4090, the same Scheme as the CPU build.

| estimator, n x p | sklearn | ours, CPU | ours, `--cuda` | ratio to sklearn | agreement |
|---|---|---|---|---|---|
| LogisticRegression, 200,000 x 100 | 0.494 s | 0.289 s | 0.034 s | 14.5x | 6 / 6 / 6 iterations, 2e-15 |
| PoissonRegressor, 200,000 x 100 | 0.371 s | 0.335 s | 0.036 s | 10.4x | 8 / 8 / 8, 1e-15 |
| HuberRegressor, 200,000 x 100 | 2.020 s | 0.725 s | 0.093 s | 21.8x | 14 / 14 / 14, 2e-16 |
| LogisticRegressionCV, 200,000 x 100 | 5.50 s | 5.15 s | 1.86 s | 3.0x | same C, 1e-10 |
| FastICA, 200,000 x 20 | 3.223 s | 2.544 s | 0.479 s | 6.7x | 59 / 59 / 59, 1e-6 |
| GaussianMixture (8), 200,000 x 20 | 1.723 s | 1.053 s | 0.562 s | 3.1x | 2 / 2 / 2, 4e-16 |

The device sums in another order, so the results differ from the CPU
build's in the last digits, more for FastICA, whose iteration
amplifies them. The iteration counts do not change. LogisticRegressionCV
gains least: each of its fifty fits uploads its fold again.

## Loop-invariant products, derived

A loop that forms a product of columns it gathers from an array it
never writes recomputes entries of one fixed table. ARD's iteration
forms the kept features' Gram from X, `gk = Xk'Xk` with
`xk[i,c] = x[i, idx[c]]`, and each entry is `(X'X)[idx[r], idx[c]]`.
The gathered columns are invariant data under an operation that costs
nothing next to the product, an index lookup. So the inner products can
be taken over X itself, once, and the lookup applied to the result.

`--derive` now does this before the differencing
(`rewrite-invariant.scm`, `invariant` in the log). An array is
invariant in a loop when the loop neither assigns it, binds it, nor
passes it bare to a function of the program. An operand of
`(matmul (transpose A) B)` in the loop is either such an array or a
gather of one, found earlier in the same statement list with nothing
in between writing what it reads. The gathered array must be declared
`(n p)` by a `with-arrays` of the function, which makes the gathered
index a column. The table `X'Z` is allocated before the loop and formed
on its first use, as a `matmul` again, so `--blas` makes it one
`dsyrk`, `dgemm` or `dgemv`. The product becomes the gather
`gk[r,c] = T[idx[r], idx[c]]`, and the fill of `xk` goes when nothing
else in the loop reads it. Two different bases (`Xk'Zk`), a vector on
the right (`Xk'y`) and a product of the whole arrays are the same rule
(`probe/derive-invariant.scm`).

The fill may be of any rank: a nest of counting loops
`a[v1,..,vr] = x[u1,..,ur]`, each axis of x indexed by a loop variable
itself (a full axis) or by an expression of exactly one of them (a
gathered axis), as in `x[i1, e1(c1), e2(c2), i2]`. The product may be
any `contract` as well as the `matmul` forms. A summed label must sit
on a full axis: a sum over gathered rows depends on the whole index
set, not on each index, so no table lookup gives it. The table carries
every free axis at its full extent (`probe/derive-invariant.scm`
gathers two axes of a rank-3 array, and rows, `x[ridx[c], j]`, whose
table is X X').

What no contraction spells is memoised instead. A call `f(op(X, p1),
p2)` of a pure function with a loop in it, inside a loop that leaves X
alone, becomes `(memo-call M (f ..) KEY ..)`: a table from the key to
the value, allocated before the loop, so `f` runs once per distinct
key (`memo` in the log). The key is what varies: the scalar arguments,
and for an array argument filled in the loop from invariant data, the
values the fill depends on. An index array read as `idx[c]` over a
loop of k enters as `(memo-range idx k)`. When the filled array is a
local nothing else reads, the fill moves into the miss path. The C++ is
`scm2cpp::memo_get` over an `std::unordered_map` from the key's bytes
(`scm2cpp.hpp`). `memo-call` can also be written by hand
(`probe/memo-call.scm`).

`ard.scm`'s HOIST 0 is scikit-learn's form, the Gram from X each
iteration. With `--derive --blas` it comes out as the HOIST 1 written
by hand: `ard` with `-M`, one core, tol 1e-8, load average 1.4:

| n x p (iterations) | HOIST 0, `--blas` | HOIST 0, `--derive --blas` | HOIST 1 by hand, `--blas` |
|---|---|---|---|
| 5,000 x 100 (28) | 0.046 s | 0.023 s | 0.021 s |
| 20,000 x 200 (14) | 0.267 s | 0.122 s | 0.109 s |
| 20,000 x 400 (18) | 1.124 s | 0.650 s | 0.607 s |

The coefficients agree with HOIST 0's to 1e-15. The remaining gap is the
first iteration, which forms X'X where HOIST 1 had it before the loop.
The trade is a p x p product once for an n k^2 one per iteration. It
pays from the second iteration when k is near p, and no guard is
derived for a loop whose k starts much smaller than p.

## RidgeCV from one eigenproblem

`GramRidgeCV` against scikit-learn's `RidgeCV` (`cv=None`, its
leave-one-out by generalised cross-validation), from
`bench/eigen-compare.py` (`--threads 1` under `taskset -c 0`, and
`--threads all`; the MKL build, load average 1.5, best of three). X is
Gaussian plus one, y ten columns of it plus noise; both choose the same
alpha and the coefficients agree to 2e-13.

| case | scikit-learn `RidgeCV` | `GramRidgeCV` | ratio, one core | ratio, 20 cores |
|---|---|---|---|---|
| 200,000 x 200, 3 alphas | 2.04 s | 0.80 s | 2.6x | 3.6x |
| 200,000 x 200, 50 alphas | 26.6 s | 0.96 s | 27.7x | 29.0x |
| 20,000 x 500, 50 alphas | 9.64 s | 0.33 s | 28.9x | 29.2x |
| 2,000 x 5,000, 50 alphas | 3.16 s | 1.47 s | 2.1x | 4.5x |

One eigenproblem serves every alpha on both sides; the difference is
what an alpha costs after it. scikit-learn takes, per alpha, a pass of
numpy over the n x p factor; `ridge-gcv.scm` forms every alpha's
diag H and fitted values as two products, (Z o Z) W and Z (R o W), so
50 alphas cost about what 3 do. With 3 alphas the gap is the
factorisation: X'X by dsyrk and dsyevd on p x p against the SVD of the
n x p design. The wide case is the n x n eigenproblem of Xc Xc' on
both sides, which is most of either time.

## KernelPCA by subspace iteration

`GramKernelPCA` against scikit-learn's `KernelPCA` from
`bench/eigen-compare.py` (the MKL build, load average 1.3, best of
three; X Gaussian, gamma 1/p). Both sides form the kernel and centre
it in well under a tenth of the time; the eigenproblem is the rest.

| case | scikit-learn `KernelPCA` | `GramKernelPCA` | ratio, one core | ratio, 20 cores |
|---|---|---|---|---|
| rbf, 3,000 x 20, 5 components | 1.11 s (ARPACK) | 0.35 s (subspace) | 3.2x | 3.0x |
| rbf, 6,000 x 20, 5 components | 4.63 s (ARPACK) | 1.33 s (subspace) | 3.5x | 4.2x |
| rbf, 3,000 x 20, 50 components | 3.48 s (dense) | 3.63 s (dense) | 1.0x | 1.2x |
| linear, 5,000 x 50, 10 components | 19.8 s (ARPACK on 5,000 x 5,000) | 0.002 s (X'X) | 10,000x | 2,100x |

With five components scikit-learn's ARPACK multiplies the n x n matrix
by one vector at a time, which reads the whole matrix for every product;
subspace iteration multiplies it by 30 columns at once (one dgemm), and
on this kernel, whose leading values fall slowly (the fifth is 0.92 of
the first), 15 steps reach residuals of 1e-12. The block size is the
lever: 13 columns took 235 steps. With 50 components both sides call
dsyevr on the same index range, and 100 columns of subspace iteration
lost to it (6.2 s to 3.6 s on one core), so the package keeps it to the
range where scikit-learn takes ARPACK. The linear row compares an
n x n eigenproblem with a p x p one.

## LDA from the Gram matrix

`GramLDA` against scikit-learn's `LinearDiscriminantAnalysis` from
`bench/eigen-compare.py` (the MKL build, load average 2.1-2.8, best of
three; X Gaussian with the class shifting every feature by 0.1). The
coefficients agree to 4e-13 and the predictions exactly.

| case | scikit-learn | `GramLDA` | ratio, one core | ratio, 20 cores |
|---|---|---|---|---|
| svd (default), 200,000 x 100, 5 classes | 4.80 s | 0.092 s | 52x | 35x |
| svd, 50,000 x 500, 10 classes | 4.07 s | 0.25 s | 16x | 14x |
| lsqr, 200,000 x 100, 5 classes | 0.42 s | 0.089 s | 4.7x | 8.9x |
| eigen, 200,000 x 100, 5 classes | 0.56 s | 0.094 s | 6.0x | 12x |

scikit-learn's default solver centres a copy of the n x p design per
class, scales it and takes its SVD (LAPACK's dgesdd on 200,000 x 100);
`GramLDA` reads the design once for the class means and X'X and solves
a p x p eigenproblem, which gives the same right singular vectors and
values. lsqr and eigen form per-class covariances and the total one
from the design (three passes of products over it) where the package
forms one Gram.

## TruncatedSVD from the Gram matrix

`GramTruncatedSVD` against scikit-learn's `TruncatedSVD`, its default
randomized solver and its exact arpack one, from `bench/eigen-compare.py`
(the MKL build, load average 1.8-3.0, best of three; X Gaussian with
column scales falling linearly from 3 to 0.2). The package's components
agree with arpack's to 5e-13; randomized's differ from both by up to 1.3
on this spectrum, whose values fall slowly.

| case | scikit-learn | `GramTruncatedSVD` | ratio, one core | ratio, 20 cores |
|---|---|---|---|---|
| 200,000 x 100, 10 components, randomized | 1.16 s | 0.22 s | 5.4x | 7.0x |
| 200,000 x 100, 10 components, arpack | 4.46 s | 0.22 s | 20x | 25x |
| 50,000 x 500, 20 components, randomized | 1.27 s | 0.39 s | 3.3x | 5.1x |
| 50,000 x 500, 20 components, arpack | 10.1 s | 0.41 s | 24x | 21x |
| 5,000 x 2,000, 20 components, randomized | 0.46 s | 0.96 s | 0.5x | 3.5x |
| 5,000 x 2,000, 20 components, arpack | 5.17 s | 1.01 s | 5.1x | 9.1x |

The package forms X'X once (dsyrk) and asks dsyevr for the leading
pairs; arpack multiplies by X and X' a vector at a time, and randomized
takes a few products with a block plus QR and a small SVD. With 2,000
features and 20 components, randomized's products are cheaper than the
exact route's O(n p^2 + p^3), and on one core it is faster.
