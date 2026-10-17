# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Scm2Cpp translates a subset of Scheme into human-readable C++. Scheme
values get no runtime representation: an integer becomes `int`, a vector
becomes `boost::array<double,N>` or `std::vector<double>`, a promise
becomes a memoising callable. Types come from whole-program inference;
what inference cannot pin down becomes a C++ template parameter.

## Commands

```console
$ raco link --user vendor/rkanren     # once per machine (or: export PLTCOLLECTS=$PWD/vendor:)
$ ./run-tests.sh                      # full regression suite; expect PASS=156 FAIL=0 (134 without a CUDA device, 108 without cblas.h either)
```

Translate and run one program (this is also how to run a single test case
from the suite -- the suite is just this loop over the files listed in
`CASES=` inside `run-tests.sh`):

```console
$ racket scm2cpp-file.scm -t scm2c.typ prog.scm      # writes prog.hpp + prog.cpp
$ g++ -std=c++17 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o prog prog.cpp
$ ./prog
```

Use `-O3 -march=native` when timing anything: the generated loop nests
("two or more consecutive inner loops") do not vectorise at `-O2`.

`-M` additionally emits `prog_capi.cpp` (extern "C" wrappers) and
`prog.py` (ctypes loader) so translated functions can be called from
Python on numpy arrays; this only covers functions whose types resolved
concretely (template functions are skipped with a named comment).

The bundled `vendor/rkanren` is mandatory: it is cKanren's constraint
framework over the recursive miniKanren core, and the catalog package
`cKanren` lacks the miniKanren layer this code calls (`nullo`,
`never-pairo`). Do not replace it with the catalog version. The
original cKanren is not in the tree (git history, commit 3c945f9);
nothing may require a `cKanren` collection.

## The Python packages and the benchmarks (any machine)

Everything the README's tables report is reproducible from this tree
with a C++17 compiler, Python 3.10+ and, for the CUDA rows, nvcc plus a
device. Racket is not needed for the packages: the translated C++ under
`python/scm2cpp-lasso/src/scm2cpp_lasso/_generated/` is committed
(`python/scm2cpp-lasso/regenerate.sh` refreshes it and is the only step
that runs the translator). Two kernels are there: `lasso_cov.*`, the
hand-written Gram-route sweep of `lasso-cov.scm` behind `CovLasso` and
everything else, and `derived_cublas/` + `derived_blas/` +
`derived_loops/`, the plain `lasso-design.scm` (X in C order, norms and residual taken inside) translated with
`--derive --cublas` / `--derive --blas` / `--derive` behind
`DerivedLasso`; `setup.py` builds the cuBLAS variant when the toolkit
is there, and the BLAS variant when a CBLAS compiles and links, else
the loop variant; `DerivedLasso(backend=None)` takes cublas when a
device answers, else blas, else loops (`derived_backend()` says
which).  A third library, `classifiers.*`, is `svm-liblinear.scm`,
`svm-smo.scm`, `logistic-l1.scm` and `svr-liblinear.scm` translated
plainly into one, behind `LinearSVM`, `KernelSVM`, `L1LogisticRegression`,
`LinearSVR` and `KernelSVR` (`svm-smo.scm`'s `smo-solve` serves both C-SVC
and epsilon-SVR), and `nmf_cublas/` + `nmf_blas/` + `nmf_loops/` are
`nmf-cd.scm` derived like `lasso-design.scm`, behind `CDNMF`
(`nmf_backend()`); `gramops_blas/` (or `gramops_loops/`) is
`graphical-lasso.scm`, `omp.scm` and `lbfgs-objectives.scm` (scipy's
L-BFGS-B under the logistic and Huber objectives), `gmm.scm`,
`fastica.scm`, `pca.scm` and `ard.scm` with `--blas`, behind
`CDGraphicalLasso`, `GramOMP`, `LBFGSLogisticRegression`,
`LBFGSHuberRegressor`, `EMGaussianMixture`, `ParallelFastICA`,
`CovPCA` and `CovARDRegression`, and `ransac.scm`, `sgd.scm` and
`lars.scm` sit in the classifiers library behind `LinearRANSAC`,
`SGDLinear*` / `SGDPerceptron`, `GramLars` / `GramLassoLars` /
`GramLassoLarsIC` (and the composed `GramLarsCV` / `GramLassoLarsCV`),
`svm-l1.scm` behind `L1LinearSVM` and `theilsen.scm` behind
`WeiszfeldTheilSen`; `lbfgs-objectives.scm` also carries `glm.scm`
(`LBFGSPoissonRegressor`, `LBFGSGammaRegressor`, `LBFGSTweedieRegressor`;
`LBFGSLogisticRegressionCV` and `GramOMPCV` are compositions); gramops
also carries `fscore.scm`, `rfe.scm` and `gram.scm` (`f_regression`,
`f_classif`, `SelectKBest`, `SelectPercentile`, `GramRFE`), and
`accel_cublas/` is those three and `pca.scm` with `--cublas`, built with
the CUDA toolkit and taken by the wrappers only for large products
(`SCM2CPP_NO_DEVICE=1` keeps them on the CPU); `gpu_cuda/` is
`fastica.scm`, `gmm.scm` and `lbfgs-objectives.scm` translated with
`--cuda`, compiled by nvcc into `libscm2cpp_gpu.so` and taken by
`ParallelFastICA`, `EMGaussianMixture` and the `LBFGS*` classes for a
million entries or more when a device answers; the classifiers are
compiled
with `-fstrict-overflow` (Python's `-fno-strict-overflow` costs the
linear SVM 25%).

```console
$ python3 -m venv ~/venv-scm2cpp && . ~/venv-scm2cpp/bin/activate
$ pip install numpy scikit-learn celer skglm       # sklearn is the reference; celer/skglm optional rows
$ pip install python/scm2cpp-lasso                 # setup.py runs nvcc on batch_capi.cu when nvcc is on PATH
$ python -c 'import scm2cpp_lasso as m; print(m.__version__, m.cuda_available())'
```

Reinstall (`pip install python/scm2cpp-lasso`, no `-e`) after any
change under `src/scm2cpp_lasso/` -- `batch_capi.cu` is compiled at
install time, and `_libfind.py` binds the C entry points by name, so a
stale `libscm2cpp_batch.so` shows up as a missing symbol or a fallback
to the CPU, not as an error.  After changing compile flags in
`setup.py`, also remove `python/scm2cpp-lasso/build/` (git-ignored):
setuptools reuses the objects there when the sources have not
changed, so the new flags never reach the compiler. cuML (`pip install cuml-cu12`, CUDA 12)
installs into the same venv (checked with Python 3.14, cuML 26.08);
`bench/lasso-compare.py` then fills in its row.

The scripts, and which table each feeds:

- `bench/lasso-table.py` -- the first table (n=1800, p=200, 4096
  lambdas): residual kernel, covariance kernel warm/cold, GPU, sklearn
  with and without `precompute`.
- `bench/lasso-compare.py [--nobs N] [-p P] [--cv-only]` -- the cold
  grid against sklearn/celer/skglm/cuML, the warm 400-lambda path, and
  the `CovLassoCV` rows (CPU, CUDA, sklearn `LassoCV`); the CV table's
  four shapes are `--cv-only` at (1800,200), (5000,1000),
  (100000,200), (100000,500).
- `bench/multitask-compare.py [--cv] [--nobs N] [-p P] [-t 8]` -- the
  multi-task table (single fits without `--cv`, the CV pair with).
- `bench/cv-grid-designs.py [--nobs N] [-p P] [--spans 1 5 10]` -- the
  GPU designs for a CV grid side by side (replicated cold threads,
  fold-indexed threads, warm runs, one block per problem), kernel time
  alone plus the whole-estimator CPU row; the comparison behind the
  block-per-problem kernel `CovLassoCV` and `CovMultiTaskLassoCV`
  launch.
- `bench/lasso-memory-compare.py` -- peak memory of the Gram route
  against the residual route.
- `bench/ridge-enet-compare.py [--nobs N] [-p P]` -- the elastic-net
  path (`CovLasso` with `l1_ratio=0.5` against `enet_path`) and the
  ridge path (`CovRidge` against `Ridge` per alpha and `RidgeCV`),
  whole calls on one core; the package README's elastic-net/ridge
  table.  `bench/lasso-compare.py --cv-only --l1-ratio 0.5` is the
  `ElasticNetCV` table beside the `LassoCV` one.
- `bench/nmf-compare.py --kernel-dir LABEL=DIR..` -- `nmf-cd.scm`
  plain / `--derive --blas` / `--derive --cublas` against
  `NMF(solver="cd")`; the README's NMF table.
- `bench/glasso-compare.py`, `bench/kmeans-compare.py`,
  `bench/ransac-compare.py --kernel-dir ..` -- `graphical-lasso.scm`,
  `kmeans.scm`, `ransac.scm` against `GraphicalLasso`, `KMeans(lloyd)`
  and `RANSACRegressor` on the same starts / subsets; the README's
  table for each.
- `bench/sgd-omp-lars-compare.py --sgd-dir DIR --omp-dir DIR --lars-dir DIR`
  -- `sgd.scm`, `omp.scm` (`--blas`) and `lars.scm` against
  `SGDClassifier`/`SGDRegressor` (shuffle off), `OrthogonalMatchingPursuit`,
  `Lars`/`LassoLars`; the README's table.
- `bench/lbfgs-compare.py` -- the package's `LBFGSLogisticRegression`
  and `LBFGSHuberRegressor` (`lbfgs.scm` under `logistic-lbfgs.scm` /
  `huber.scm`, `--blas`) against `LogisticRegression` and
  `HuberRegressor`, iterations and coefficients side by side; the
  README's L-BFGS table.
- `bench/gmm-ica-pca-compare.py` -- the package's `EMGaussianMixture`,
  `ParallelFastICA` and `CovPCA` against `GaussianMixture`, `FastICA`
  and `PCA` from the same starts; the README's table.
- `bench/linear-variants-compare.py` -- `SGDPerceptron` and the
  passive-aggressive SGD options, `CovARDRegression` (Gram hoisted and
  not), `GramLassoLarsIC` and `L1LinearSVM` against `Perceptron`,
  `SGDClassifier`/`SGDRegressor` (pa1), `ARDRegression`, `LassoLarsIC`
  and `LinearSVC(penalty="l1")`; the README's table.
- `bench/glm-cv-compare.py` -- the GLMs, `LBFGSLogisticRegressionCV`,
  `GramLarsCV` / `GramLassoLarsCV`, `GramOMPCV` and `WeiszfeldTheilSen`
  against their scikit-learn counterparts; the README's table.
- `bench/select-compare.py` -- `f_regression` (one and many targets),
  `SelectKBest`, `GramRFE` against scikit-learn, and the device Gram
  under `GramLassoLarsIC` / `GramLassoLarsCV` / `CovPCA` against the CPU;
  the README's two tables.
- `bench/cuda-compare.py` -- the `--cuda` build (`libscm2cpp_gpu.so`)
  against the CPU build and scikit-learn: FastICA, the mixture, the
  L-BFGS fits; the README's `--cuda` table.
- `bench/dbscan-compare.py --kernel-dir LABEL=DIR..` -- `dbscan.scm`
  against `DBSCAN(algorithm="brute")` and the default; the README's
  DBSCAN table.
- `bench/logistic-l1-compare.py --kernel-dir DIR` -- liblinear's L1
  logistic regression written in the subset (`logistic-l1.scm`,
  built with `-M`) against `LogisticRegression(solver="liblinear")`;
  the README's L1 logistic table.
- `bench/bayesian-ridge-compare.py [--shape N,P ..]` --
  `CovBayesianRidge` against `BayesianRidge`, whole fits with
  `sigma_`; the package README's Bayesian ridge table.
- `bench/svm-compare.py --liblinear-dir DIR --kernel-dir DIR.. --dual-dir DIR`
  -- liblinear's solver written in the subset (`svm-liblinear.scm`,
  plain) and the derived linear SVM (`svm-kernel.scm` built with
  `-M`, plain / `--derive --blas` / `--derive --cublas`) against
  `LinearSVC`, and the kernel-form SVM (`svm-dual.scm`) on an RBF
  kernel against `SVC`; the README's SVM tables.

Protocol shared by all of them: BLAS/OpenMP pinned to one thread inside
the scripts, and the process pinned to cores (`taskset -c 0-3 python
bench/...`) so a loaded machine still gives a usable number -- report
the load average with any number taken while other jobs run (the README
figures: i9-10900X, RTX 4090, sklearn 1.9.0). `--best N` where offered
is best-of-N. `run-tests.sh` does not build the package (its
`pymodule-lasso` case is the `-M` wrapper route with the system
`python3`); the package's own checks are
`python/scm2cpp-lasso/check-gpu.py`, run in the venv after a reinstall:
every GPU path (`CovLassoCV`, `CovMultiTaskLassoCV`, the cold batches,
the shared-memory fallback) against its CPU path, expected to agree to
1e-14; and `check-derived.py`: `DerivedLasso` against `CovLasso` and
sklearn on a tall and a wide design, expected to agree to 1e-8, with
the whole-call times of the three; and `check-classifiers.py`: the
three classifiers against `LinearSVC`, `SVC` and `LogisticRegression`
on the same problem and stopping rule, expected to agree to 0.5% in
the objective and 98% in the predictions (both sides stop at a
tolerance), with the times the package README's classifier table
reports.

## Before committing

Every commit, without exception, is preceded by a full `./run-tests.sh`
run on the tree exactly as it will be committed: after the last edit,
before `git commit`, and again if anything changes in between. This
holds for documentation-only and comment-only commits too (a stale
`CASES=` line, a doc-unit example, or a Scribble snippet is text, and
the suite reads text); "the files I touched are not read by the tests"
is not a reason to skip it. Expect PASS=156 FAIL=0 (PASS=134 on a machine
without a CUDA device and cuBLAS, 108 without `cblas.h` either: the
`*-cublas` / `*-blas` rounds and their binding checks are skipped).
A run that has not finished is not a passed run: wait for the
`---- PASS=.. FAIL=..` line. Do not push without being told to.
Comments and identifiers
in committed code are ASCII; `CHANGES.ja.md` is the one exception (it is
the Japanese changelog, and substantive changes get a numbered section
there). New subset features get a case under `probe/` and a line in
`run-tests.sh`'s `CASES=`. `scm2cpp-match.scm` carries `module+ test`
submodules (`raco test scm2cpp-match.scm`, the suite's `match-unit`)
for the examples whose output is fixed; an example whose C++ carries
a numbered template type (`Unknown_typeNNNType`, a counter) stays a
comment rather than a check.
`scribblings/scm2cpp.scrbl` is the manual of the provided interface
(`read-source-forms`, `scm2cpp-match-list`, ...); its `eval:check`
examples run when it is built (`raco scribble --dest DIR
scribblings/scm2cpp.scrbl`, the suite's `doc-unit`), so a change to
a provided function's behaviour is checked there, and a new provided
function gets a `@defproc` with a checked example. No root
`info.rkt`: it would make the whole tree a collection for `raco
setup`.

## Architecture

`FILES.md` is the inventory: every file's role and the `require`
graph, by stage, with a section on where a change goes.  What follows
is the pipeline, in order (all inside `scm2cpp-file.scm` ->
`scm2cpp-match.scm`):

0. **Include splice** (`scm-include.rkt`) -- a top-level
   `(include "file.scm")` is replaced by that file's text, relative to
   the including file, before anything reads the program. Every reader
   of a source program (the translator, the relational gate's
   `source-forms`, `test-oracle.rkt`, the proposers, the tests) goes
   through `read-source-forms`/`read-source-string`; a new reader must
   too, and a script that copies a kernel elsewhere must copy what it
   includes. A file is spliced once per program: a second include of
   it, direct or through another included file, contributes nothing
   (`lasso-auto.scm` includes `lasso-kernel.scm` and `lasso-cov.scm`,
   which both include `soft-threshold.scm`).
1. **User macro expansion** (`scheme-macro-parser.rkt`) -- a source file's
   own `define-macro`s are expanded first.
2. **Pre-pass** (`rewrite-named-let` in `scm2cpp-match.scm`) -- rewrites
   forms so later stages never see them: self-tail named lets become
   `do` loops, `letrec` of one lambda becomes a named let, `(delay E)`
   becomes `(make-promise (lambda () E))`, `let*` becomes nested `let`s.
   When a shape misbehaves in inference or emission, first check whether
   it should be normalised away here instead.
3. **Derivation** (`--derive`, `rewrite-derive.scm` over
   `rewrite-raise.scm` / `rewrite-incremental.scm` / `rewrite-driver.scm`)
   runs on the source as read, before step 1, because that is where a
   function's `with-arrays` shape declaration still stands: loops are
   raised to the array algebra, the scratch vector (the target of an
   `array-dec!`/`row-dec!`, or the increments, by a scaled row) is found, its update is
   differenced into a memo over a hoisted Gram matrix, and the result
   goes back under the same `with-arrays` for the ordinary expansion.
   Restoration of the scratch follows the parameter-liveness pass. The
   derived body is guarded, not unconditional: it runs under
   `(if (< p n) ..)`, p and n being the declared dims of the matrix
   whose rows update the scratch, with the original sweep in the else
   branch -- scikit-learn's `precompute='auto'` rule, derived
   (`guard` in the log; `probe/derive-lasso-wide.scm` is the p > n
   case).  The function's `with-arrays` may sit inside a `let` that
   allocates the scratch locally; a scratch formed by whole-array
   assignments -- `(array-set! r x)` `(array-dec! r (matmul w (transpose
   ht)))` -- whose memo is the derivation's contraction over it has the
   fill distributed through the memo (`distribute` in the log:
   c = x ht - w g, g the Gram already built), and the local allocation
   then moves to the original branch (`probe/derive-nmf-half.scm`). The scratch may be decremented or incremented (`array-inc!`
   / `row-inc!`, `probe/derive-lasso-inc.scm`), one direction per
   sweep; it may be a vector, a matrix updated by rows or columns, or
   a tensor updated by fibers (`probe/derive-mt3.scm`: the fold writes
   its products under a nested `with-arrays` that redeclares the
   rank-3 names as the matrices their other axes flatten to). The
   kernels in `examples/kernel-only/` (lasso, enet, mt) derive this way;
   `probe/derive-*.scm` are the suite's cases, translated plainly,
   with `--derive`, with `--derive --blas` and (where a device is)
   `--derive --cublas` against the same oracle.
   Before the differencing, `rewrite-invariant.scm` hoists products of
   loop-invariant arrays: in a loop, `(matmul (transpose A) B)` whose
   operands are arrays the loop never assigns, binds or passes to a
   program function -- or gathers `a[i*k+c] = x[i*p + E(c)]` of such an
   x, declared `(n p)` by some `with-arrays` of the function -- becomes
   a lookup in X'Z, allocated before the loop and formed (as a matmul,
   under a flag) on first use; a gather fill nothing else reads goes
   (`invariant` in the log, `probe/derive-invariant.scm`; ard.scm's
   HOIST 0 derives to its hand-written HOIST 1). It works within one
   function: a product formed in a callee of the loop is not seen.
   The loop nests the differencing hoists are folded to contractions
   (`fold-matmul` in `rewrite-derive.scm`, one rule: a nest of
   `range-for`s around a dot product of two views, or around a fiber
   update by a scaled view, becomes `(contract (k ..) (i ..) (a la ..)
   (b lb ..))` -- numpy's einsum, every index named on the axis it
   runs over; `(row a j ..)` puts the summed index last, `(col a j ..)`
   first). The Gram, the memo build and the restore of every kernel,
   at any rank and with the operands cut either way, are the same
   rule. `array-macros.scm` expands a contraction to its nest (the
   Gram to the upper triangle plus mirror); `matmul` is its two-index
   sugar for hand-written kernels. `--blas` / `--cublas`
   (`rewrite-blas.scm`, run on the source before macro expansion when
   `SCM2CPP_BLAS` is set) lower a contraction whose summed labels sit
   at the front or the back of each operand to one of four ops that
   `bindings/cblas-binding.scm` / `bindings/cublas-binding.scm`
   declare through the ordinary custom-binding mechanism --
   `blas-gemm!` (two transposition flags, alpha, beta), `blas-gemv!`,
   `blas-syrk!`, and `blas-gemm-batched!` for labels that both
   operands and the target carry in front unsummed (a loop of dgemm,
   `cublasDgemmStridedBatched` on the device; the C++ is
   `scm2cpp-blas.hpp` / `scm2cpp-cublas.hpp`) -- so nothing in the
   emitter matches a loop for BLAS, and no product shape needs code
   of its own: the flags come from where the summed labels sit. Under
   cuBLAS a matrix the scope only reads is uploaded once at scope
   entry, one it writes (and every materialised operand) is copied at
   the call. Summed labels in the middle of an operand are left as
   the loop nest. The null-update guard
   (`(if (not (= bnew old)) ..)` around an update by a multiple of
   `bnew - old`) is not inserted by any pass: it is written in the
   source (`lasso-kernel.scm`) and carried through the derivation.
   Test data for derivation checks must be dyadic (integer entries,
   power-of-two norms) so both sides print identical digits; a
   binding-test's data must not be integral (its C++/Racket compare is
   textual, and `14.0` is not `14`).
   A term-pattern rule search (`rewrite-search.scm`, `-R`/`--rules`/
   `--apply-rule`) preceded the derivation and was removed in favour of
   it (CHANGES.ja.md section 78); do not reintroduce pattern rules for
   shapes the derivation should derive.
   `examples/kernel-only/lasso-auto.scm` is the other way to reach
   BLAS: a hand-written kernel that writes its products as `matmul`
   forms from the start (the Gram route for n > p over `cov-descend`,
   `lasso` otherwise, as scikit-learn's `precompute='auto'` chooses)
   and is translated with `--blas`/`--cublas` but not `--derive`
   (the derivation now emits the same branch, so it would only nest a
   redundant guard); `probe/auto-lasso.scm`
   is its case, in the same rounds as `probe/matmul.scm`.
4. **Type inference** (`infer-type-from-org-expr` in
   `type-infer-match.scm`) -- alpha-converts (`alpha-conv.scm`), then
   Hindley-Milner (`type-infer-hm.scm`) by default, or the original
   relational inference (rkanren) with `SCM2CPP_RELATIONAL=1`. HM quirks
   that matter: a statement-position `if` does not unify its branches,
   so the return type of a loop whose value is unused stays open (the
   emitter closes those to `void`); element types still open after
   inference default to `double`; unresolved variables render as
   `Unknown_typeNNNType` and become template parameters.
5. **Emission** (`scm2cpp-match-port` in `scm2cpp-match.scm`, one large
   scope) -- per top-level form.  Under `--cuda` (SCM2CPP_PARALLEL=cuda)
   a loop that `loop-independent?` accepts and whose body is scalars
   and array elements (`cuda-kernel-ok?`) becomes a `__global__`
   kernel defined before its function (`cuda-kernel-code`, launched
   above `cu::min_trip()`, the host loop below), and in every function
   that reaches a device statement (`cuda-active-fns`) each other
   statement is bracketed by `cu::need_host` / `cu::wrote_host`
   (`cuda-wrap`); the runtime is `scm2cpp-cuda.hpp`, a registry of
   device mirrors keyed by data pointer (spans carry their length for
   it).  `SCM2CPP_CUDA_DEBUG=1` synchronises and reports every launch
   and transfer. Functions go through `cdeffun`;
   expression-position lambdas and named lets become functor structs via
   `clambda`. `clambda` looks the loop's type up in the front-end's
   table rather than re-deriving it relationally (the relational
   deriver does not return on deeply nested bodies). Output is indented
   by `astyle` if present.

Cross-cutting analyses inside `scm2cpp-match.scm`:

- **Mutation summaries** (`compute-mutation-summaries!`,
  `mutation-summary`, `stmt-writes?`): per function, which parameter
  indices it writes, as a fixpoint over calls. This drives everything
  const: container parameters a function never writes are emitted
  `const T&`; functor captures the body never writes are `const T&`
  members; a captured function is held by value as a `boost::function`
  whose per-parameter constness is reconstructed from the summary --
  get this wrong and real functions stop converting to the
  `boost::function` type.
- **Containers cross by reference** (`container-type?`): vectors, lists
  and binding-declared types pass by `&` so callee writes reach the
  caller. Streams and integral images are deliberately not in this set
  (temporaries must still bind).
- **Integral images** (`integ-*`): `-I` recognises box-sum-from-origin
  nests of any rank (the rank is discovered by peeling loops, not
  declared) and rewrites them to summed-area-table build+query.
  Recognition is strict shape-matching; anything else is silently left
  as a plain loop, so wrong hints cannot break a program.
- **Custom bindings** (`custom-binding.scm`, `--binding`): user-declared
  C++ template types and operations, verified two ways (declared model
  against the rule in Racket; model against the real C++ by
  `binding-check.rkt`).

The runtime is a single header, `scm2cpp.hpp`: streams
(`stream_cell<T>`), memoising promises (`promise<F,T>`/`make_promise` --
promises of vectors work, and `force` takes its promise by reference so
that the memoisation lands in the caller's promise rather than a copy),
`integral_image<T,N>`, `make_array` for `(vector ...)` literals. Non-template functions emitted into the header
get `inline` (ODR plus real performance: a non-inlined per-element
helper cost 3x).

Authoring tools that are NOT part of translation (translation stays
deterministic; these propose, verify, and hand back source):
`memo-propose.rkt` (memoisation proposals gated on output equality AND a
growth-rate timing test), `repeat-scan.rkt` (enumerates repeated pure
subexpressions), `block-equiv.scm` (decides whether two blocks compute
the same value: pure block = function of its free variables, loop
indices included). `--llm-hints CMD` is the only model hook in the
translator itself, is off unless given, and only ever supplies `-I`
array names.

## The subset, when writing Scheme meant for translation

- No union types: "a vector or `#f`" does not translate. Use a
  preallocated buffer plus a 0/1 flag.
- No heterogeneous pair returns: `(cons vec num)` as a result does not
  translate. Use an out-parameter plus a scalar return.
- Loops are `do` or named `let`; a loop's non-recursive tail is `#f` by
  convention.
- Arrays are flat with explicit index arithmetic (`(+ (* i n) j)`).
- Multiplying by `(* 1.0 n)` rather than `n` is the idiom for forcing a
  parameter to a floating type when nothing else constrains it.
- A name that spells a C++ keyword (`new`, `case`, `int` ..) is
  emitted with the suffix `_scm` (`schlep-symbol` in `schlep-name.scm`,
  `probe/cxx-keywords.scm`); the existing kernels still say `bnew`.
- Column-major flat matrices indexed `j*n+i` suit kernels whose sweeps
  touch one column at a time (see `examples/kernel-only/`).
- A definition several programs share is written once and taken by
  `(include "file.scm")`, never copied (`soft-threshold.scm`).
- Memoisation over an integer index is a vector of promises
  (`probe/promise-table.scm`); over anything else it is a hash table
  (`make-hash`/`hash-ref`/`hash-set!`/`hash-has-key?`/`hash-count`,
  `probe/hash-memo.scm`, through the `define-memo` macro of
  `probe/define-memo.scm`, taken by include). `probe/fib.scm` is fib
  both ways side by side; no rewrite finds either (the tabulation
  rule went with the rule search). `even?` has no emission rule -- write
  `(= (remainder n 2) 0)`; and `(let ((x (begin ..))) ..)` emits a
  call to a nonexistent `begin`, so keep statements in statement
  position.
