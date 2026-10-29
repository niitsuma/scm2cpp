# Approaches that were tried and dropped

What was tried, what it gave, why it lost, and what took its place,
gathered from the work log (`CHANGES.ja.md`, cited as "sec." and line,
since a few section numbers occur twice), `docs/benchmarks.md` and the
comments in the kernels and the package. The last section lists the
cases that still lose today. Read it before trying one of these again:
most of them lost for a reason that has not changed.

## Translator

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| The original relational (cKanren) type inference, `run*` over all solutions | comp-test.scm ran 4 h, later 10 h, without stopping | Three tautological `conde` disjunctions and a missing `fresh` in `number-typeo` doubled the solutions at each of k arithmetic sites (2^k) | Hindley-Milner (algorithm W) by default; the fixed relational version (67 s) stays behind `SCM2CPP_RELATIONAL=1` | sec. 17 (l.97), sec. 27 (l.225) |
| Re-deriving the whole body relationally for each named let in `clambda` | Did not return on deep nesting (cut at 9.5 min) | Repeated work | The type HM already has; open return types closed to Void | sec. 48 (l.740) |
| Relational gate falling back to the old `derive-type` | All tests relational: PASS=102 FAIL=55; pca.scm over 20 min (HM 5 s) | The old engine's cost | Fallback to HM, gate budget 3600 s to 60 s (then PASS=157) | sec. 133 (l.3398), sec. 134 (l.3425) |
| Lambda return type through `cpptype`, as on the argument side | Infinite recursion | The union type needs handling on its own side | Reverted to `ctype` (open) | sec. 15 (l.88) |
| `(list ...)` as `std::vector` | cons fails | `ptr_vector` has no `push_front` | `std::list` (`ptr_list`) | sec. 19 (l.116) |
| Unifying an unsized `make-vector` with a known container naively | Calls to a nonexistent `std::vector<double>(boost::array<...>)` | Unsized won over sized | Unsized meeting sized rebinds to the size | sec. 40 (l.499) |
| Header functions without `inline` | Through the helper 3x slower than the expanded expression; ODR broken across two units | Not inlined | `inline` on generated and 10 runtime functions | sec. 41 (l.528) |
| Faithful `set!` re-pointing of a container variable | Unworkable | C++ references cannot be re-seated; it needs pointers at every use | A warning and a documented limit (open) | sec. 50 (l.1097) |
| Value-returning accumulate loops left as self-referencing functors | QAP 40 functors / 0 loops, then 19 / 21 | Only literal-else loops became `do` | Immediately invoked lambda plus `while` (13 functors, 9 whiles) | sec. 51 (l.1124), sec. 52 (l.1147) |
| `std::tanh` in the translator | `std::tanh` does not vectorise: FastICA 0.6x of scikit-learn | Library call in the hot loop | Reverted; `1 - 2/(e^2x + 1)` in the source | sec. 118 (l.3092), fastica.scm |
| `(* 1.0 n)` to make a double | n itself became double: the minimal runtime and the `-P omp` loop bounds broke | Inference unifies n with the product | `(exact->inexact n)` where n is also an index | sec. 117 (l.3060), sec. 156 |
| Memo tables through a `--binding` to `std::map` | Rejected | Needs the user to write a C++ header | `make-hash` / `hash-ref` in the subset | sec. 75 (l.1682) |
| Five ways to write memoisation after the tabulate rule went | The promise vector first did not compile | alpha-conversion, element type, `force` as a write | Promise vector and hash table kept | sec. 74 (l.1648) |

## Derivation and rewriting

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| Route A: term-pattern rule search (`-R`, `--rules`, `--apply-rule`; five rules) | Each new kernel shape needed a hand entry; mt-kernel matched none (its residual form 50x slower than hand mt-descend); c = X'r rebuilt per penalty | Rules are shape-specific | Route B `--derive` (raise and differencing). Do not reintroduce | sec. 72, sec. 77 (l.1787), sec. 78 (l.1809) |
| PLT Redex as the rewrite engine | Not adopted | An engine on the type inference's own unification can take side conditions as constraints | Own engine (later deleted with route A) | sec. 33 (l.353) |
| Local LLM proposing closed-form rules | A wrong sum of squares, n(n-1)(n+1)/6; with 3 retries it kept the same wrong formula | The model's mathematics | Dropped with route A; the LLM only supplies `-I` hints | sec. 34 (l.385), sec. 35 (l.402), sec. 29 |
| Local LLM proposing what to store for naive TFS lasso (3 prompt styles) | "Nothing to share", a wrong O(n) claim, or w+1 expanded instead of beta[j] | The model did not produce the proposal at all | Nothing (a stronger model untried) | sec. 43 (l.614) |
| Repeated-subexpression scan plus LLM choice of tables | No candidate for the naive O(n^2) prefix sum | Textual matching cannot see overlapping sums or recurrences | Nothing (CSE level only) | sec. 45 (l.664) |
| Static cost hill-climb firing `cd-covariance-update` | Cost rose 19008 to 23359 | A one-off Gram build weighed like work inside the sweep | `--apply-rule`, later route B | sec. 47 (l.709) |
| Timing gate v1 (threshold 0.7, one shot, sizes substituted by `eq?`) | `eq?` never matched literals, so all sizes ran one program; noise once accepted a do-nothing rewrite | `eq?` on numbers; single timing | `equal?`, best of 3, threshold 0.33 | sec. 43 (l.587) |
| Zero-update skip as a rule, then as automatic guard insertion with LLM per site | Fired at one site in lasso-kernel.scm | Whether D is often zero is knowledge about the algorithm | Guards written in the kernel source | sec. 69 (l.1367), sec. 71 (l.1476), sec. 73 (l.1593) |
| Gram by derived scalar triple loops | 100000 x 500: derived 52.8 s, residual 3.5 s, numpy X'X 0.45 s | Scalar loops | `matmul` forms with `--blas` / `--cublas` (0.577 s) | sec. 68 (l.1340), sec. 79 (l.1853) |
| `(array-gram! g x)` plus an emitter matching the C++ loop to dsyrk | 1.16 s where the later form gives 0.577 s | Only the Gram; the emitter knew loop shapes; cuBLAS needed its own path | `matmul` plus bindings/ (rewrite-blas.scm) | sec. 79 (l.1882) |
| A catalogue of nine BLAS ops, one per product shape | Mixed row/column operands could not be folded | One op per shape | `contract` (einsum) plus gemm/gemv/syrk and one fold rule | sec. 100 (l.2651) |
| Always taking the derived Gram form | Pays O(np^2) when p >= n | No guard | `(if (< p n) derived original)`, as `precompute='auto'` | sec. 92 (l.2372) |
| Differencing `x *= a` with an elementwise a | Rejected | X diag(a) r is not determined by c = X r | Not done (open) | sec. 92 (l.2399) |

## BLAS and LAPACK

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| Jacobi rotations for sym-eigen.scm | 14x slower than scikit-learn at 500 features | Convergence cost | Householder plus QL (1.6x slower), then LAPACK dsyevd | sec. 118 (l.3104), benchmarks |
| The subset's QL as the package eigensolver | CovPCA 50000 x 500 0.46 s against 0.26 s | Unblocked QL against blocked divide and conquer | dsyevd through `lower-library-calls` (0.251 s); Scheme kept as oracle | sec. 141, sec. 142 (l.3587) |
| GraphicalLasso's per-column products as loops | 0.6x at p=400, 0.4x at p=800 | Reductions are not reordered, so not vectorised | `matmul` to dgemv (1.3x at p=800) | sec. 113 (l.2982) |
| Bootstrap Gram as `X.T @ (X*m)` | Slower | numpy sends distinct operands to gemm | `diag(sqrt m) X` then dsyrk (1.4-1.7x on the Gram) | sec. 85 (l.2225) |
| dgemm with one dimension 1 | 1.3x slower than dgemv; binary logistic 0.8x | OpenBLAS 0.3.33 | dgemv when m or n is 1 | sec. 117 (l.3083) |
| numpy `X.T @ X` for the Gram | Twice the flops | dgemm, not dsyrk | `gram-xx` (dsyrk) | sec. 144 (l.3631) |
| numpy's OpenBLAS and gramops' OpenBLAS alternating | A 0.044 s dsyrk took 0.113 s | The finished pool's threads keep spinning | X'y and the solve inside the same library | sec. 144 (l.3636) |
| `_ridge_solve` through rfe.scm's loop Cholesky | 3.7x slower than numpy at p=200 | Scalar loops | `spd-solve` to dposv (2.1x faster than numpy) | sec. 152 (l.3797) |
| Refitting every RFE round (scikit-learn's way) | Slower | Repeated factorisation | One Cholesky, then cholesky-delete (2-10x) | sec. 122 (l.3184) |
| GramLinearRegression by two eigendecompositions | 20,000 x 2,000 in 3 s on one core | Two O(p^3) decompositions | Cholesky with dpocon (1.4 s) | sec. 156 |
| PLS mode B pinv as a triple loop | CCA 50,000 x 500 4.2 s | Scalar loops | `matmul` to dgemm (1.2 s) | sec. 154 (l.3838) |
| Dual GCV through y - yhat and 1 - H_ii | LOO relative error 3e-3 at alpha=1e-10; alpha_ changed on 50 x 200 | Cancellation | Eigenpairs of XcXc' + 11', e = c / diag G^-1 (2e-15) | sec. 155 (l.3865) |
| KernelPCA subspace iteration for 50 components | 6.2 s against dsyevr 3.6 s | Too many columns and steps | dsyevr there; subspace only where scikit-learn uses ARPACK | sec. 149 (l.3737) |

## CUDA

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| CUDA covariance lasso (residual on the device, one scalar back per sweep) | Loses below n=100k; loses to the CPU covariance form at every size | Coordinate descent takes one j after another: 2 launches and 1 readback per coordinate | The CPU covariance form ("the speed came from the algorithm") | sec. 42 (l.581) |
| Cooperative residual-form GPU kernel | Slower at n=1,800; idle machine 1.2-1.3x only at n=100,000 (an earlier 1.6-1.9x was load); a beta[j] read race drifted 3e-5 | 2 grid barriers per coordinate | The Gram form and cuBLAS | sec. 67 (l.1316), sec. 91 (l.2366) |
| CV grid on the GPU: fold Gram per alpha, cold starts, one thread per problem; then indexed Grams; then warm walks over `span` alphas | 5,000 x 1000: 5.5 s, 1.65 s, 7.0 s against 0.064 s for the final design (CPU 0.87 s) | Transfers (4 GB) and idle device | One thread block per problem, span 1; the 512 MB rule and `force_gpu` dropped | sec. 62 (l.1222), sec. 85 (l.2131) |
| `--cublas` for estimators with host loops between products (GMM, FastICA, ARD, L-BFGS) | At most 1.15x | Matrices cross the bus per product | `--cuda` kernels with device-resident arrays | sec. 122 (l.3192), sec. 123 |
| The first `-M` wrapper writing back the whole registry | Wrote into freed locals; heap corruption | Wrote non-caller arrays | Write back only the caller's arrays | sec. 123 (l.3220) |
| HMM (device reading host memory) | 0.4-2 GB/s against 7-12 GB/s for copies | Page migration | An explicit mirror registry | sec. 123 (l.3224) |
| Grams over 2e9 flops on the device | 200,000 x 200: 0.096 s against 0.044 s on 20 cores | Transfer | Device only for p >= 4000 | sec. 144 (l.3633) |
| CovPCA on cuBLAS with the Scheme eigensolver | 0.30 s against CPU LAPACK 0.251 s | No device eigensolver | Device only without CPU LAPACK | sec. 142 (l.3608) |
| A local-LLM binding to `boost::container::vector` | Passed g++, failed nvcc | nvcc | std:: types preferred | sec. 63 (l.1237) |

## OpenMP (`-P omp`)

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| A pragma on the outermost loop, unconditionally | cov-descend's sweep raced: coefficients like 1e56, different on each run, no diagnostic | No dependence check | Per-loop dependence analysis | sec. 24 (l.163), sec. 55 (l.947), sec. 57 (l.989) |
| A low size threshold (`SCM2CPP_OMP_MIN` 1, then 1024) | tfs-lasso 1.25 s on one thread, over 200 s at 1 / 20 threads; SVC 0.4 s to 43 s under load 25 at 1024 | Short loops opened parallel regions | A work guard (trip counts multiplied), 65536 | sec. 58 (l.1042), sec. 140 (l.3557) |
| A pragma where the trip count cannot be read | Thread start on every call of short Householder loops | No guard possible | No directive there | sec. 140 (l.3552) |
| `!(i == n)` and `i = (i+1)` loop forms | MSVC rejects the first; g++ 14 rejects the second in templates (broke a 0.16.0 wheel) | Not canonical OpenMP | `i < n` and `i += s` | sec. 140 (l.3560), sec. 149 (l.3740) |
| The runtime guard as an OpenMP `if` clause | 1-thread CovPCA 0.454 s to 0.557 s | The loop still runs in the outlined function, reductions through memory | Two copies of the loop, `if (work > T) {pragma loop} else {loop}` | sec. 141 (l.3579) |
| Column-wise csr-gram, so that `-P omp` could take the outer loop | The pragma landed on the zero fill; 0.31 s against scipy's 0.26 s | Injectivity not provable (the written column is data; two index forms of one array) | Row-wise outer products, blocks of rows on Python threads (0.025 s) | sec. 156 |

## Python package

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| Tolerance on coefficient movement in cov-descend | 10% slower when it does not fire; never fires on moving-average designs | abs/max inside the coordinate loop | Stop when nothing moves | sec. 56 (l.976), lasso-cov.scm |
| The first residual-form lasso kernel | 1.5-2.5x slower than scikit-learn | Updated the residual for coordinates that did not move | `(if (not (= bnew old)))` and `-ffast-math` | sec. 67 (l.1325) |
| DerivedLasso stopping only at a bitwise fixed point | 40x CovLasso at 5000 x 200; wide data used up max_sweeps (7 s) | Too strict | `tol` with a comparison-only max move | sec. 93 (l.2464) |
| DerivedLasso transposing X and taking norms in numpy | 0.36 s at 100,000 x 500, the bulk of the call | Copies | lasso-design.scm (constructor 0.000 s) | sec. 95, sec. 97 (l.2565) |
| Maximum-movement stop in svm-kernel.scm | Objective 185.8 against the optimum 0.054 at 2,000 x 20,000 | Stopped far too early | liblinear's projected-gradient span | sec. 105 (l.2764) |
| Fixed order, with or without shrinking, for the linear SVM | Worse objective (1548.32 against 1541.06); shrinking with fixed order stalls | The same points shrunk every sweep | svm-liblinear.scm, random order plus shrinking | sec. 105 (l.2805) |
| svm-dual.scm for nonlinear SVM (no shrinking, every move updates all of c) | 40x slower than SVC (194.7 s against 4.42 s), later 50-90x | No working set | svm-smo.scm (libsvm WSS3, shrinking), 1.1-1.2x faster | sec. 105, sec. 106 (l.2814) |
| Python's default `-fno-strict-overflow` | Linear SVM sweep 25% slower | i*p+j not an induction variable | `-fstrict-overflow` (`-march=native` gave nothing) | sec. 109 (l.2895) |
| DBSCAN by brute force without stored neighbourhoods | About half of scikit-learn's brute speed; its tree 8x faster in 2-D; 512 x n tiles 3x slower | Two distance passes | Not shipped | sec. 111 (l.2930) |
| KMeans Lloyd in the subset | 0.88-2.1x with BLAS, slower with cuBLAS | scikit-learn's Lloyd is already Cython over BLAS | Not shipped | sec. 114 (l.2999) |
| NMF as written, then derived before the distribute rule | 20x slower (4.57 s against 0.246 s), then 2.4x slower | R allocated and multiplied again and again | The distribute rule (1.22-1.40x) | sec. 112 (l.2971) |
| `validate_data` on every input | 100-200 us a call: a 0.1 ms fit 3x slower, a small predict 30x | Validation overhead | A direct path for C-order float64 arrays | sec. 134 (l.3440) |
| A centred copy of X for the intercept | At 20000 x 200 the copy cost as much as the Gram | Memory traffic | X'X - n xm xm' (`_centered_gram`), the copy only for ill-scaled columns | sec. 135 (l.3489) |
| Library lookup by glob on each call; ctypes for tiny products | GramRidge 200 x 10 4.8x slower; ctypes 10 us over numpy | Per-call overhead | lru_cache; numpy under 1e6 multiply-adds | sec. 152 (l.3793) |
| Scalar exp for small rbf kernel matrices | 0.31 ms against numpy 0.14 ms at 200 x 200 | numpy's exp is vectorised | numpy under 200k elements | sec. 152 (l.3803) |
| Reproducing scikit-learn's xorshift SGD shuffle | Not possible | The subset has no bit operations | Compared with `shuffle=False` only | sec. 116 (l.3031) |

## Testing

| Tried | Result | Why it lost | Instead | Source |
|---|---|---|---|---|
| Passing a test on translate, compile and run alone | Wrong outputs passed: a 32-bit LCG overflow (pi 3.06 against 3.83), 5 cases with no output, an fft returning its input | Nothing compared the output | The fourth stage, a diff against Racket's own output | sec. 49 (l.787), sec. 50 (l.839) |
| Nothing running the Colab notebook | A CPU runtime failed on `nvidia-smi` while every test passed | The suite and CI never ran the .ipynb | The `notebook` job in wheels.yml (tools/run-notebook.py) | sec. 156 |

## Still losing (open)

| Case | Numbers | Why | Ideas | Source |
|---|---|---|---|---|
| Sparse X, thousands of columns, few nonzeros per row | Ridge 50,000 x 2,000 0.1x, LinearRegression 0.2x, TruncatedSVD randomized 0.1x, Lasso 0.7x (one core) | The Gram route pays p^2 memory and a p^3 solve; LinearRegression at 0.5%: scikit-learn's lsqr takes 11 iterations of 1.3 ms (0.026 s); ours 0.27 s, half of it csr-gram's cache misses on a 32 MB G, the rest the Cholesky | Switch to lsqr / CG when p^3/3 exceeds about 30 x nnz; cache-blocked csr-gram; randomized TruncatedSVD through csr-mm | sec. 156, benchmarks |
| Derived SVM kernel form on CPU BLAS, 2,000 x 20,000 | 1.049 s against 0.721 s as written | 12 sweeps do not repay the kernel matrix; the guard sees only the shape | A guard that counts sweeps | sec. 105 (l.2802) |
| ParallelFastICA 200 x 10 | 1.29x slower than 0.15.1 | dsyevd is heavier than the subset solver for p <= 20 | A size branch was rejected: the `--blas` tests are all small and would skip LAPACK | sec. 152 (l.3807) |
| Exact TruncatedSVD, 5,000 x 2,000, 20 components | 0.5x of randomized on one core (3.5x on 20) | Full eigenproblem | -- | sec. 151 (l.3783) |
| GramLogisticRegression | 2.5x (20000 x 200) to 9x (200 x 10) slower than liblinear | The majorizer algorithm | -- | sec. 135 (l.3502) |
| SVC / SVR against sklearnex on 20 cores | 0.5x / 0.4x | SMO updates one pair at a time | -- | sec. 146 (l.3664) |
| DBSCAN, KMeans, NMF under cuBLAS | Slower than the CPU (NMF 1,000 x 500 0.6x) | Only the product is on the device | A fused distance kernel the translator cannot emit yet | sec. 111, sec. 114, sec. 112 |
| `GridSearchCV(GramLasso())` | 1.3x only | Each clone refits; no shared Gram as in CovLassoCV | -- | sec. 138 (l.3529) |
| Invariant-product hoist | A loop whose k starts far below p pays a p x p product once | No guard derived | -- | sec. 124 (l.3250) |
| cuBLAS nested scopes | X uploaded 2 extra times for the memo build and the restore | Each scope uploads again | -- | sec. 98 (l.2638) |
