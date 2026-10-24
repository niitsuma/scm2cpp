# The files, what each is for, and what depends on what

A map of the tree for someone about to change it.  The pipeline
itself is described in `CLAUDE.md` (Architecture) and in `README.md`;
this file is the inventory: every checked-in source file, its role in
one or two lines, and the `require` graph between the Racket modules,
so that a change can be placed and its blast radius seen before it is
made.  Files are grouped by the stage they belong to, in pipeline
order.  The dependency lists are the module `require`s as of the
commit that last touched this file (`grep -n require *.scm *.rkt`
regenerates them).

## 1. The translator: entry point and pipeline

```
scm2cpp-file.scm                          the command line
  |-- scm-include.rkt                     (include "f.scm") splicing; read-source-forms
  `-- scm2cpp-match.scm                   scm2cpp-match-list: the pipeline and the emitter
        |-- scheme-macro-parser.rkt       define-macro expansion (array-macros.scm seeded)
        |-- rewrite-derive.scm            --derive: loops -> array algebra -> Gram form -> contract
        |     |-- rewrite-invariant.scm     products of loop-invariant arrays, tabulated once
        |     |-- rewrite-raise.scm         R1-R7, plain loops raised into the algebra
        |     |-- rewrite-driver.scm        the fixpoint over the improvement rules
        |     |     |-- rewrite-incremental.scm   finite differencing (the derivation proper)
        |     |     |-- rewrite-normalize.scm     cost-neutral rewrites exposing folds
        |     |     |-- rewrite-precompute.scm    hoist a loop-invariant fold; fold-of-fold
        |     |     |-- rewrite-lagsum.scm        lag-indexed prefix tables for slice sums
        |     |     |-- rewrite-contract.scm      array contraction of user temporaries
        |     |     |-- rewrite-cost.scm          the polynomial cost model the gates share
        |     |     `-- rewrite-raise.scm
        |     `-- rewrite-incremental.scm
        |-- rewrite-blas.scm              --blas/--cublas: contractions -> gemm / gemv / syrk
        |-- custom-binding.scm            --binding and the bindings/ files
        |-- type-infer-match.scm          the inference front end (HM by default)
        |     |-- type-infer-hm.scm         algorithm W
        |     |-- type-infer-rel-bridge.scm SCM2CPP_RELATIONAL=1: the relational route
        |     |     `-- type-infer-rel.scm    the relational inferencer (rkanren)
        |     |-- depend-analysis.scm       which globals/functions each definition uses
        |     `-- (utilities below)
        |-- scm2cpp-function.scm          function signatures: template args, return types
        |-- schlep-name.scm / schlep-base.scm   name mangling and declarations (from Schlep)
        `-- alpha-conv.scm, type-symbols.scm, type-infer-util.scm, depend-analysis.scm,
            onlisp.scm, slib-plt.scm, list-util.scm, cl-util.scm, alist-util.scm
```

| file | role | requires |
|---|---|---|
| `scm2cpp-file.scm` | The command line.  Parses the flags (`-t`, `-M`, `-I`, `-P`, `--derive`, `--blas`, `--cublas`, `--binding`, `--llm-hints`, `-S`, `-N`, `--inference`), turns each into an environment variable (`SCM2CPP_*`), calls `scm2cpp-match-list` once, writes `<base>.hpp` / `<base>.cpp`, and with `-M` also `<base>_capi.cpp` and `<base>.py`.  No rewriting happens here: every optimisation runs inside `scm2cpp-match-list` and is selected by the variables. | `scm2cpp-match.scm`, `scm-include.rkt` |
| `scm2cpp-match.scm` | The pipeline and the emitter, one large scope.  `scm2cpp-match-list` = derive-source-maybe -> lower-blas-maybe -> macro expansion -> `rewrite-named-let` (the pre-pass) -> save-scm-maybe -> `scm2cpp-match-values` (inference, then C++ per top-level form: `cdeffun`, `clambda`, `cstat`, `cexp`).  Also holds the mutation summaries (constness), the integral-image rewrite (`-I`), the parallel back ends (`-P`), the minimal-runtime decision, and a `module+ test` (the suite's `match-unit`). | `alist-util`, `cl-util`, `list-util`, `onlisp`, `schlep-name`, `alpha-conv`, `type-infer-util`, `depend-analysis`, `rewrite-derive`, `rewrite-blas`, `custom-binding`, `type-symbols`, `type-infer-match`, `scm2cpp-function`, `scheme-macro-parser.rkt` |
| `scm-include.rkt` | `read-source-forms` / `read-source-string`: the one reader of a source program.  Splices a top-level `(include "file.scm")` in place, relative to the including file, once per program.  Every consumer of a program (translator, oracle, relational gate, proposers, tests) goes through it. | -- |
| `scheme-macro-parser.rkt` | Expands a program's own `define-macro`s (and the built-in `array-macros.scm` layer) by writing a small Racket program and running it; the expansion is textual so the oracle and the translator see the same forms. | -- |
| `array-macros.scm` | The array-and-fold layer: four `define-macro`s (`range-for`, `range-fold`, `range-sum`, `with-arrays`), the last of which expands every form of the algebra inside its body: `array-ref`/`array-set!`/`array-inc!`/`array-dec!`/`array-mul!`/`array-div!` (cell and elementwise; `*=` and `/=` also by a scalar), `array-sum`/`array-reduce`/`array-dot`, `box` and `sub` (prefix and hyperrectangle sums), `row`, `slice`, `scale`, `row-inc!`/`row-dec!`, `array-gather!`/`array-permute!`, and the whole-array products `matmul`/`transpose` (the Gram expands to the upper triangle plus mirror).  Seeded into every expansion and into the oracle; the head comment is the reference. | -- (data; the macro parser expands it) |
| `scm2cpp-function.scm` | Helpers over a function's inferred signature: argument names and types, return type, whether it is a template (open types), the template-argument string. | `schlep-name.scm` |
| `schlep-name.scm` | Name mangling, declarations (`declare-names` reads the `-t` type file), pragma handling.  Derived from Aubrey Jaffer's Schlep `scm2c`. | `schlep-base`, `alpha-conv`, `alist-util`, `slib-plt`, `type-symbols`, `list-util`, `cl-util` |
| `schlep-base.scm` | The Schlep globals (input/output names, current procedure, output line counter, `report`). | -- |
| `scm2c.typ` | The type-declaration file passed with `-t`: name patterns to C types, Schlep's format. | -- |

### Type inference

| file | role | requires |
|---|---|---|
| `type-infer-match.scm` | The front end: alpha-conversion, dependency analysis, then either HM or the relational bridge; converts the result into the environment the emitter reads (`var-env->type`, `type->ctype`). | `rel-util`, `type-infer-rel-bridge`, `alist-util`, `cl-util`, `list-util`, `onlisp`, `schlep-name`, `alpha-conv`, `type-symbols`, `type-infer-util`, `type-infer-hm`, `type-rel-util`, `depend-analysis` |
| `type-infer-hm.scm` | Hindley-Milner (algorithm W), `derive-type-hm`: same contract as the relational `derive-type`, the default since `--inference hm`. | `type-symbols`, `type-infer-util`, `custom-binding` |
| `type-infer-rel-bridge.scm` | `SCM2CPP_RELATIONAL=1`: runs `type-infer-rel.scm` on the program as read (re-reads the source file, hence `SCM2CPP_SOURCE_FILE`) and converts its answer into the emitter's vocabulary. | `type-infer-rel`, `type-symbols`, `scm-include.rkt` |
| `type-infer-rel.scm` | The relational type inferencer: a pile of `conde` clauses over rkanren, runs forwards (types from terms) and backwards (terms from types).  Its numeric tower is one `number` type (see its head comment). | rkanren (vendor) |
| `type-infer-util.scm` | The environment machinery both inferencers share: unknown-type variables, environment update, type unification helpers.  Also the one PLaneT dependency (`amb.plt`). | `alist-util`, `list-util`, `alpha-conv`, `type-symbols`, `type-rel-util`, `schlep-name`, `rel-util`, `onlisp`, `cl-util`, and PLaneT's amb.plt |
| `type-rel-util.scm` | Relational helpers over the numeric type order (`number-typeo`). | `type-symbols`, `rel-util` |
| `type-symbols.scm` | The type vocabulary: type symbols, the numeric order, C type names (`ctype-alist`), operator tables, compiler tags. | `alist-util`, `alpha-conv` |
| `depend-analysis.scm` | Which globals and functions each top-level definition uses; orders inference and finds the functions whose types stay open. | `alist-util`, `list-util`, `alpha-conv`, `type-symbols`, `rel-util`, `cl-util`, `type-infer-util` |
| `alpha-conv.scm` | Alpha-conversion of a program and the primitive operator signatures (`op-num-num->num`, ...). | `list-util`, `cl-util` |
| `custom-binding.scm` | User bindings for C++ templates (`--binding`, and the `bindings/` files under `--blas`/`--cublas`): a type constructor for the inference, an operation table for the emitter, a Scheme model per operation, test programs.  Declarations are data. | `type-symbols` |

### The derivation (`--derive`) and the products (`--blas` / `--cublas`)

| file | role | requires |
|---|---|---|
| `rewrite-derive.scm` | `derive-forms`: per function with a `with-arrays` declaration, raise the loops, find the scratch, run the driver, then `fold-matmul` the loop nests of the Gram, the memo build and the restore into `(contract ...)` forms (one rule, any rank, either view) and guard the derived body by `(if (< p n) ..)` over the original (`guard-by-shape`); logs which rules fired. | `rewrite-driver`, `rewrite-raise`, `rewrite-incremental`, `rewrite-invariant` |
| `rewrite-invariant.scm` | `hoist-invariant-products`: in a loop, a product (`matmul` or `contract`) whose operands are arrays the loop never writes, or gathers of them at any rank (`a[v..] = x[u..]`, each axis of x a loop variable or an expression of one), becomes a lookup in a table over the full axes, formed once before the loop's first use (lazily, under a flag); a fill nothing else reads is dropped (`invariant` in the log). `memo-invariant-calls`: a pure call with a loop in it, on invariant or filled arrays, becomes `(memo-call M (f ..) KEY ..)` keyed by what varies (`memo`). Run by `derive-forms` before the differencing. | `rewrite-incremental` |
| `rewrite-raise.scm` | Loop raising R1-R7: the inverse of the macro expansions, applied only where the expansion is exactly what stands there (`do` -> `range-for`, flat index -> `array-ref` when the declared width matches, accumulation -> `array-sum`, self-update -> `array-dec!`/`row-dec!`). | `rewrite-incremental`, `rewrite-normalize` |
| `rewrite-driver.scm` | `derive-fixpoint`: alternate the improvement rules over a statement list until none fires; restoration of the scratch after the liveness pass; `lower-replacement`. | `rewrite-incremental`, `rewrite-precompute`, `rewrite-normalize`, `rewrite-lagsum`, `rewrite-contract`, `rewrite-cost`, `rewrite-raise` |
| `rewrite-incremental.scm` | Finite differencing over the array algebra: grow the expression around each read of the scratch vector, difference the update into a memo over a hoisted Gram matrix (`incrementalize`, `degree`, `walk-collect`, `pure?`, `subst`). | -- |
| `rewrite-normalize.scm` | Cost-neutral rewrites (inlining a pure fill, `elem->vexpr`) that expose folds for the other rules. | `rewrite-incremental` |
| `rewrite-precompute.scm` | Two generic rules: hoist a loop-invariant pure fold into a table; fold of a fold. | `rewrite-incremental` |
| `rewrite-lagsum.scm` | Slice-product sums answered from one prefix table indexed by lag. | `rewrite-incremental` |
| `rewrite-contract.scm` | Array contraction of a user temporary produced and consumed under one syntactic discipline. | `rewrite-incremental` |
| `rewrite-cost.scm` | The polynomial cost model (`--cost speed` / `memory`) the rule gates compare against. | `rewrite-incremental` |
| `rewrite-blas.scm` | `lower-blas-forms`: each `contract` form (and each `matmul`, desugared to one) becomes one call of `blas-gemm!`, `blas-gemv!`, `blas-syrk!` or `blas-gemm-batched!` (leading labels shared by both operands) with the transposition flags read off where the summed labels sit; under cublas the matrix operands are uploaded once per scope or per call.  `lower-library-calls`: a call of a Scheme function the loaded binding has an op for becomes that op (`sym-eigen` as `lapack-syevd!`, LAPACK's dsyevd), the definition staying for the oracle and the builds without it. | |
| `bindings/cblas-binding.scm` | The ops above declared for `<cblas.h>` with their Scheme models; the C++ is `scm2cpp-blas.hpp`. | -- |
| `bindings/cublas-binding.scm` | The same ops with the matrix operand on the device (`dmat-upload`); the C++ is `scm2cpp-cublas.hpp`. | -- |
| `bindings/cuda-binding.scm` | The same ops for `--cuda`, on device-resident arrays; the C++ is `scm2cpp-cuda.hpp`. | -- |
| `scratch-internalize.scm` | The liveness pass's consumer: a scratch parameter (written, never read afterwards) leaves the signature and is allocated inside the function.  Checked by `test-internalize.rkt`; not on the default path. | `scm2cpp-match.scm` |
| `block-equiv.scm` | Do two write-free blocks compute the same value?  Used by `repeat-scan.rkt`. | `custom-binding.scm` |

### Utilities (no translator logic)

| file | role | requires |
|---|---|---|
| `list-util.scm` | Tree and list helpers (`map-tree`, `flatten-tree`, `filter-tree`, ...). | -- |
| `alist-util.scm` | Association-list and small-set updates (`alist-cons-update`, `vset-union`, ...). | -- |
| `cl-util.scm` | Common Lisp names (`cl:nth`, `cl:subst`, `cl:some`, ...). | -- |
| `rel-util.scm` | Relational list helpers over rkanren (`listo`, `memo`, `reverseo`, ...). | `alist-util`, `cl-util`, `list-util` |
| `onlisp.scm` | Paul Graham's On Lisp utilities in Racket. | `list-util`, `cl-util` |
| `slib-plt.scm` | SLIB's `defmacro` / `macroexpand` for Racket (Aubrey Jaffer). | -- |

## 2. Runtime headers (what the generated code includes)

| file | role |
|---|---|
| `scm2cpp.hpp` | The single runtime header: streams (`stream_cell<T>`), memoising promises (`promise<F,T>`, `make_promise`, `force` by reference), `integral_image<T,N>`, `make_array`, `span`.  Under `SCM2CPP_MINIMAL` (numeric kernels) it is std-only and nvcc takes it. |
| `scm2cpp-blas.hpp` | The four binding ops as cblas calls: `blas_gemm` (dgemm with flags, alpha, beta), `blas_gemv`, `blas_syrk` (dsyrk + mirror), `blas_gemm_batched` (a loop of dgemm over contiguous slabs). |
| `scm2cpp-cublas.hpp` | The same ops as cuBLAS calls over a `device_matrix` uploaded once. |
| `scm2cpp-cuda.hpp` | The `--cuda` runtime: the registry of device mirrors (`dev`, `need_host`, `wrote_dev`, `wrote_host`, `fresh`, `end_call`), the reduction slots, `min_trip`, the products on device arrays, `SCM2CPP_CUDA_DEBUG`. |
| `usage.cpp`, `list-test.cpp`, `equal-test.cpp` | Hand-written examples of the runtime header. |
| `ideal/stream-ideal-new.cpp` | The intended shape of generated code for delayed streams, written by hand. |

## 3. Tests

`run-tests.sh` is the suite (`./run-tests.sh`, expect `PASS=205 FAIL=0`;
183 without a CUDA device, 156 without `cblas.h`, 9 fewer without OpenMP).  Its order:

1. Analysis unit checks, no compiler: `test-liveness.rkt`,
   `test-incremental.rkt`, `test-internalize.rkt`,
   `test-precompute.rkt`, `test-normalize.rkt`, `test-lagsum.rkt`,
   `test-derive.rkt`, `test-contract.rkt`, `test-cost.rkt`,
   `test-raise.rkt`, `test-rel-infer.rkt` (each requires the module it
   names, see the graph above), `test-files-doc.rkt` (this inventory
   against the tree); `match-unit` (`raco test
   scm2cpp-match.scm`); `doc-unit` (`raco scribble
   scribblings/scm2cpp.scrbl`, whose `eval:check` examples run).
2. The `CASES=` programs: each translated, compiled, run, and its
   output diffed by `test-oracle.rkt` against the same program under
   Racket (numbers to a tolerance).  Includes are copied beside the
   case at the same relative path.  Then the same programs under
   `--inference relational` (`<name>-rel`).
3. The derivation rounds over `probe/derive-{lasso,enet,mt}.scm`,
   `probe/matmul.scm`, `probe/auto-lasso.scm`: plain, `--derive`,
   `--derive --blas` (where `cblas.h` is), `--derive --cublas` (where
   nvcc, cuBLAS and a device are); `matmul` and `auto-lasso` are never
   derived.
4. `pymodule-lasso`: `-M` on the moving-average covariance kernel,
   wrapper built without boost, `examples/kernel-only/tfs-fast-lasso.py`
   must land within tolerance of sklearn (where numpy is).
5. The CUDA case: the kernel-only covariance lasso through nvcc and
   `cuda/batch-lasso.cu` (where a device is).
6. `binding-check.rkt` over every checked-in binding
   (`examples/custom-template/foo-binding.scm`,
   `examples/std-binding/vec-binding.scm`, and the two `bindings/`
   files where their libraries are).

| file | role | requires |
|---|---|---|
| `run-tests.sh` | The suite as above. | everything |
| `tools/publish-master.sh` | Generates `master` from the `ja` branch: the tree of `ja` with every `;;[ja]` comment line deleted (Markdown and `vendor/` untouched), the suite run on it, one commit with a `Ja-Commit:` trailer if it passes. Nothing is pushed. | |
| `run-tests-omp.sh` | The same programs translated with `-P omp`, compiled with `-fopenmp`, each run several times; every run must agree with the oracle.  Separate because it needs an OpenMP compiler and doubles the time. | |
| `test-oracle.rkt` | `run PROG.scm` evaluates the program the way the pre-pass reads it (`racket/base` namespace, the built-in macros seeded); `diff A B` compares outputs with a numeric tolerance. | `scm-include.rkt` |
| `test-liveness.rkt` | The parameter-liveness pass of the emitter. | `scm2cpp-match.scm` |
| `test-incremental.rkt` | Finite differencing on fixed inputs. | `rewrite-incremental.scm` |
| `test-internalize.rkt` | Scratch internalisation. | `scratch-internalize.scm` |
| `test-precompute.rkt` | The two precompute rules. | `rewrite-precompute.scm` |
| `test-normalize.rkt` | The normalization rewrites. | `rewrite-normalize.scm`, `rewrite-incremental.scm` |
| `test-lagsum.rkt` | The lag-sum tables, on normalized input. | `rewrite-normalize.scm`, `rewrite-lagsum.scm` |
| `test-contract.rkt` | Array contraction, through the driver. | `rewrite-contract.scm`, `rewrite-driver.scm` |
| `test-cost.rkt` | The cost model and the objectives, through the driver. | `rewrite-cost.scm`, `rewrite-driver.scm` |
| `test-files-doc.rkt` | This file and `FILES.ja.md` against the tree: every module has a row, and each row's requires column equals the module's actual `require`s (by file name; names that are not modules of the tree are commentary). | -- |
| `test-derive.rkt` | The driver end to end on the lasso shapes. | `rewrite-driver.scm` |
| `test-raise.rkt` | Loop raising, and raised-then-derived against derived-from-the-layer. | `rewrite-raise`, `rewrite-driver`, `rewrite-derive`, `rewrite-incremental`, `scm-include.rkt` |
| `test-rel-infer.rkt` | The relational inferencer forwards and backwards. | `type-infer-rel.scm`, `scm-include.rkt` |
| `binding-check.rkt` | Runs each binding-test program twice, under the Scheme models and translated against the real header, and compares. | `custom-binding.scm` |
| `verify-tr.rkt` | Turns the inferred types into Typed Racket annotations and type-checks the program there: an independent witness for the HM pass. | `type-infer-match`, `scheme-macro-parser.rkt`, `scm-include.rkt` |
| `.github/workflows/tests.yml` | CI: Racket, Boost headers, astyle, g++; links the bundled rkanren; runs `./run-tests.sh` (no CUDA, no cblas: PASS=80). | |
| `notebooks/compare-sklearn.ipynb` | The Colab notebook behind the README's "Open in Colab" badge: installs the package (the wheel on a CPU runtime, the sdist with its CUDA builds on a GPU runtime) and times it against scikit-learn -- the lasso grid from zero, LassoCV, L-BFGS logistic regression, RFE(Ridge), LassoLarsIC, the estimators inside GridSearchCV and a Pipeline and, on a device, DerivedLasso -- each checked for agreement. | |
| `.github/workflows/wheels.yml` | The wheels, by hand (`gh workflow run wheels.yml`): cibuildwheel, manylinux x86_64, macOS arm64 and Windows AMD64, one `py3-none` wheel each, OpenBLAS bundled, no CUDA; `check-wheel.py` is the test; the wheels are the run's artifacts. | |
| `makefile` | Builds the hand-written C++ examples of section 2. | |

### Test programs (all read by the suite)

| directory | contents |
|---|---|
| `test-scm-code/` | The original small cases: `car-test`, `comp-test`, `delay-test`, `stream-test` (streams and promises), `def-def` (not in `CASES`). |
| `test-scm2cpp/fact.scm` | Factorial. |
| `long2/defdef{,2,3}.scm` | Nested defines; 2 and 3 are cases. |
| `bench/*.scm` | Cases that double as the README's timing programs: `psumnaive`/`psumfast` and `integnaive`/`integfast`/`integdata`/`integrect`/`integ3d`/`prefixsum1d` (box sums, the `-I` shapes at ranks 1-3), `sqrttest` (Newton), `nlet` (named let), `fft`/`fftrun`, `listtest`, `constest`, `collide` (not a case). |
| `probe/` | One case per subset feature (see each file's head comment): `letrec`, `higher-order`, `thunk-arg`, `global-set`, `unary-ops`, `vector-literal`, `promise-vector`, `promise-table`, `hash-memo` + `define-memo` (included), `fib`, `alias-binding`, `capture-const`, `inner-define` (not a case), `array-fold` (the macro layer), `matmul` (every product shape), `auto-lasso`, `derive-lasso`/`derive-lasso-wide` (p > n: the else branch of the derivation's guard)/`derive-lasso-inc` (the scratch incremented)/`derive-lasso-col` (the design stored n rows of p: column views)/`derive-lasso-design` (`lasso-design.scm`: norms and residual taken inside)/`derive-enet`/`derive-mt`/`derive-mt-col` (every matrix stored n rows: the residual updated a column at a time)/`derive-mt3` (the rank-3 residual, one fiber at a time)/`derive-mt-mixed` (X by rows, the residual by columns: a contraction with both operands transposed)/`derive-svm`, `derive-svm-wide` (the linear SVM, n > p and n < p: the kernel-form branch)/`svm-dual` (the hand-written kernel form, plain)/`svm-liblinear` (liblinear's solver whole, plain and `--derive`, which must not fire)/`svm-smo` (libsvm's SMO solver whole, plain)/`logistic-l1` (liblinear's L1 logistic regression whole, plain)/`svr-liblinear`, `svr-smo` (the epsilon-SVRs, liblinear's and libsvm's, plain)/`derive-nmf-half` (NMF's half step: the memo, the Gram and the residual fill distributed through the memo)/`dbscan` (DBSCAN by tiled products, plain)/`graphical-lasso`, `kmeans` (plain and `--blas`)/`ransac` (plain)/`sgd`, `lars` (plain)/`omp` (plain and `--blas`)/`lbfgs` (L-BFGS-B under the logistic and Huber objectives, plain and `--blas`)/`gmm`, `fastica`, `pca`, `ard` (plain and `--blas`)/`svm-l1` (liblinear's solve_l1r_l2_svc, plain)/`theilsen` (Theil-Sen over given subsets, plain)/`select` (F statistics, RFE, the Gram products; plain and `--blas`)/`cuda-loops` (the kernels `--cuda` emits, without products; plain and `--cuda`)/`cxx-keywords` (names that spell C++ keywords get `_scm`) (include the kernels under `examples/kernel-only/`). |
| `examples/tfs-lasso.scm` | A case: temporal feature selection on a synthetic series; includes `kernel-only/soft-threshold.scm`. |

## 4. Examples and kernels

| file | role |
|---|---|
| `examples/README.md` | Guide to the examples. |
| `examples/bitrev-permute.scm` | The bit-reversal permutation two ways. |
| `examples/tfs-lasso-reference.py` | numpy reference for the TFS check. |
| `examples/kernel-only/README.md` | The kernels without a `main`, meant to be called from C++/Python. |
| `kernel-only/soft-threshold.scm` | The soft-thresholding operator, included by every lasso kernel (once per program). |
| `kernel-only/lasso-kernel.scm` | Lasso coordinate descent in residual form, with `with-arrays` shapes; the input of `--derive`.  `lasso-kernel.expanded.scm` is its `-S` output. |
| `kernel-only/mt3-kernel.scm` | The multi-task kernel at rank 3: the tasks an nb x nt grid, W p x nb x nt, the residual n x nb x nt, everything stored the numpy way; the probe of the derivation with a tensor scratch. |
| `kernel-only/svm-kernel.scm` | The linear SVM by dual coordinate descent in primal form (liblinear's algorithm, no shrinking), X n rows of p; `--derive` turns it into the kernel-form solver over X X' under `(if (< n p) ..)`. |
| `kernel-only/svm-liblinear.scm` | liblinear's solver for the L1-loss SVM whole (random order, shrinking by index swaps, the projected-gradient stop): what `LinearSVC` runs, written in the subset; `--derive` leaves it alone. |
| `kernel-only/svm-smo.scm` | libsvm's SMO solver whole (`smo-solve`: WSS3 working-set selection, shrinking with gradient reconstruction, the bias rho) over a given kernel matrix, for any linear term and with 2n variables mapped onto n kernel rows; `svm-smo` is C-SVC on it (what `SVC` runs), `svr-smo` epsilon-SVR (what `SVR` runs). |
| `kernel-only/nmf-cd.scm` | NMF by coordinate descent (scikit-learn's `NMF(solver="cd")` iteration) written with the residual; `--derive` gives scikit-learn's `XHt - W HHt` form (the `distribute` rule removes the residual).  Behind `CDNMF`. |
| `kernel-only/dbscan.scm` | DBSCAN by brute-force neighbourhoods, the dot products as tiled `matmul`s, union-find over the core points; scikit-learn's labels exactly, no neighbourhood stored.  Not in the package (not faster). |
| `kernel-only/graphical-lasso.scm` | scikit-learn's `_graphical_lasso` (mode "cd") with `enet_coordinate_descent_gram` inside (the gap-safe rule included), its two matrix-vector products as `matmul`.  Behind `CDGraphicalLasso`. |
| `kernel-only/kmeans.scm` | Lloyd's k-means as `_kmeans_single_lloyd` runs it, the distances by tiled `matmul`s, empty clusters relocated as scikit-learn does.  Not in the package (level with scikit-learn). |
| `kernel-only/ransac.scm` | `RANSACRegressor.fit` around `LinearRegression` over given subsets, scikit-learn's dynamic trial bound.  Behind `LinearRANSAC`. |
| `kernel-only/sgd.scm` | scikit-learn's `_plain_sgd` for the L2 penalty: SGDClassifier's hinge / "optimal" and SGDRegressor's squared error / "invscaling", points in order.  Behind `SGDLinear*`. |
| `kernel-only/omp.scm` | `orthogonal_mp_gram` / `_gram_omp`, X'X and X'y as `matmul`.  Behind `GramOMP`. |
| `kernel-only/lars.scm` | `_lars_path_solver` with a Gram, "lar" and "lasso" (Givens downdate, `min_pos`, the 15-decimal rounding).  Behind `GramLars`, `GramLassoLars`. |
| `kernel-only/lbfgs.scm` | scipy's L-BFGS-B without bounds or with one variable bounded below (the two-loop direction, MINPACK-2's dcsrch/dcstep, the generalized Cauchy point and subspace step for that bound), calling `lbfgs-fg`. |
| `kernel-only/logistic-lbfgs.scm` | `LogisticRegression(solver="lbfgs")`'s objective (binomial and multinomial `LinearModelLoss`), products as `matmul`.  Behind `LBFGSLogisticRegression`. |
| `kernel-only/huber.scm` | `HuberRegressor`'s `_huber_loss_and_gradient`, the scale bounded at 10 eps.  Behind `LBFGSHuberRegressor`. |
| `kernel-only/gmm.scm` | `GaussianMixture(covariance_type="full")` by EM, the start's responsibilities given; products as `matmul`.  Behind `EMGaussianMixture`. |
| `kernel-only/fastica.scm` | `FastICA` at its defaults (parallel, logcosh, unit-variance; the whitening from X'X's eigenvectors).  Behind `ParallelFastICA`. |
| `kernel-only/pca.scm` | `PCA(svd_solver="covariance_eigh")`, svd_flip's signs.  Behind `CovPCA`. |
| `kernel-only/ard.scm` | `ARDRegression` for n >= p (pinvh by `sym-eigen.scm`), the kept Gram formed each iteration or hoisted.  Behind `CovARDRegression`. |
| `kernel-only/glm.scm` | `PoissonRegressor` / `GammaRegressor` / `TweedieRegressor`'s objective for `lbfgs.scm` (included by `lbfgs-objectives.scm`).  Behind `LBFGS*Regressor`. |
| `kernel-only/theilsen.scm` | `TheilSenRegressor`: the subsets' fits (exact, or minimum-norm through `sym-eigen.scm`) and the modified Weiszfeld spatial median.  Behind `WeiszfeldTheilSen`. |
| `kernel-only/fscore.scm` | `f_regression` (many targets in one product) and `f_classif`.  Behind `f_regression`, `f_classif`, `SelectKBest`, `SelectPercentile`. |
| `kernel-only/ridge-gcv.scm` | `RidgeCV`'s leave-one-out errors at every alpha from one eigenproblem (Xc'Xc tall, Xc Xc' wide) and two products.  Behind `GramRidgeCV`; `probe/ridge-gcv.scm` is its case (plain and `--blas`). |
| `kernel-only/kernel-pca.scm` | `KernelPCA`: the kernels over X Y', the centring, the eigenpairs by dsyevr (`sym-eigen-top`), by subspace iteration, or for the linear kernel through Xc'Xc.  Behind `GramKernelPCA`; `probe/kernel-pca.scm` is its case (plain, `--blas`, `-P omp`). |
| `kernel-only/rfe.scm` | `RFE` around `Ridge` / `LinearRegression` over the Gram, the Cholesky factor downdated (`lars.scm`'s `cholesky-delete`).  Behind `GramRFE`. |
| `kernel-only/gram.scm` | X'X and X'Y alone; with `--cublas` the device Gram of the Gram-route wrappers. |
| `kernel-only/svm-l1.scm` | liblinear's `solve_l1r_l2_svc` (`LinearSVC(penalty="l1")`), X by columns.  Behind `L1LinearSVM`. |
| `kernel-only/sym-eigen.scm` | The symmetric eigenproblem (tred2 + tqli) and `eig-order`; included by `fastica.scm`, `pca.scm`, `ard.scm` and `theilsen.scm`.  Under `--blas` its calls are LAPACK's dsyevd (`lower-library-calls`). |
| `kernel-only/sym-svd.scm` | The thin SVD by one-sided Jacobi (a wide matrix through its transpose), dgesdd's contract; under `--blas` its calls are LAPACK's dgesdd.  `probe/svd.scm` is its case (plain and `--blas`). |
| `kernel-only/lbfgs-objectives.scm` | `lbfgs-fg`, the dispatch to the two objectives; includes the three above.  What a program includes for the L-BFGS fits. |
| `kernel-only/svr-liblinear.scm` | liblinear's linear epsilon-SVR with the L1 loss whole (`solve_l2r_l1l2_svr`: dual coordinate descent, random order, shrinking): what `LinearSVR` runs. |
| `kernel-only/logistic-l1.scm` | liblinear's L1-regularized logistic regression whole (`solve_l1r_lr`, newGLMNET: Newton with line search over a coordinate-descent subproblem, random order, two levels of shrinking), X by columns: what `LogisticRegression(solver="liblinear")` runs. |
| `kernel-only/svm-dual.scm` | The kernel-form SVM by hand: the same sweep over a given K (any kernel), for the nonlinear SVM. |
| `kernel-only/lasso-design.scm` | The same descent over X as numpy holds it (n rows of p), the residual and the column norms taken inside; the kernel behind `DerivedLasso` in `python/scm2cpp-lasso` (`--derive` folds the norms into the Gram diagonal). |
| `kernel-only/enet-kernel.scm`, `mt-kernel.scm` | Elastic net and multi-task lasso in residual form; the other two derivation inputs. |
| `kernel-only/lasso-cov.scm` | Coordinate descent by covariance updates over a given Gram matrix, hand-written (`cov-descend`); the kernel behind `CovLasso` in `python/scm2cpp-lasso`. |
| `kernel-only/derived-check.py` | The derived `lasso-kernel.scm` against the plain one through the `-M` wrappers (the suite's `pymodule-derived`). |
| `kernel-only/lasso-auto.scm` | scikit-learn's `precompute='auto'` choice by hand: Gram route for n > p, residual route otherwise, products written as `matmul` forms; the reference for what `--derive` now emits (the same branch); translated with `--blas`/`--cublas`, not `--derive`. |
| `kernel-only/tfs-lasso-cov.scm`, `tfs-lasso-cov-multi.scm`, `tfs-lasso-cov-arrays.scm`, `tfs-lasso-fused.scm`, `tfs-predict.scm` | Lasso over moving-average features without forming the design (prefix sums); single series, several series, the array-layer rendering, the fused variant, prediction.  `python/scm2cpp-tfs` ships these. |
| `kernel-only/autocov.scm`, `levinson.scm`, `rolling-minmax.scm` | Autocovariances, Levinson-Durbin, sliding min/max; also shipped by `scm2cpp-tfs`. |
| `kernel-only/tfs-fast-lasso.py`, `tfs-lasso-cov-check.py`, `tfs-lasso-cov-multi-check.py` | Python drivers over the `-M` wrappers; the first is the suite's `pymodule-lasso`. |
| `examples/custom-template/` | `foo.hpp` (a user matrix class), `foo-binding.scm` (how it is seen from Scheme, with models and tests), `matdemo.scm`. |
| `examples/std-binding/` | `vec-binding.scm` (a `std::vector` binding accepted from `binding-propose.rkt`), `vecdemo.scm`. |

## 5. Authoring tools (not part of translation)

| file | role | requires |
|---|---|---|
| `memo-propose.rkt` | Asks a model what to store (a memo, a prefix sum, a Gram) and gates the proposal on output equality and a growth-rate timing test. | `scm-include.rkt` |
| `repeat-scan.rkt` | Lists the side-effect-free subexpressions computed more than once, with dependencies and reach counts. | `block-equiv.scm` |
| `clause-propose.rkt` | Asks a model for missing relational inference clauses (bare signatures) and gates them. | `type-infer-rel.scm`, `scm-include.rkt` |
| `binding-propose.rkt` | Asks a model for a whole binding of a kernel's unknown operations onto a std/boost class, then runs `binding-check`. | `type-infer-rel.scm`, `scm-include.rkt` |
| `--llm-hints CMD` (in `scm2cpp-file.scm`) | The only model hook inside the translator: proposes `-I` array names; wrong names are harmless. | |

## 6. Benchmarks (`bench/`, Python and CUDA)

| file | feeds |
|---|---|
| `bench/lasso-table.py` | README table 1 (n=1800, p=200, 4096 lambdas): residual kernel, covariance kernel warm/cold, GPU, sklearn. |
| `bench/lasso-compare.py` | The cold grid against sklearn/celer/skglm/cuML, the warm path, the `CovLassoCV` rows (`--cv-only`). |
| `bench/multitask-compare.py` | The multi-task table (`--cv` for the CV pair). |
| `bench/cv-grid-designs.py` | The GPU designs for a CV grid side by side (the comparison behind the block-per-problem kernel). |
| `bench/lasso-memory-compare.py` | Peak memory of the Gram route against the residual route; uses `bench/resid-cd.cu` (residual-form descent on the GPU) and the `_generated` kernels. |
| `bench/nmf-compare.py` | `nmf-cd.scm` plain and derived (`--blas`, `--cublas`) against `NMF(solver="cd")` from the same start; the README's NMF table. |
| `bench/glasso-compare.py`, `bench/kmeans-compare.py`, `bench/ransac-compare.py` | `graphical-lasso.scm`, `kmeans.scm`, `ransac.scm` against `GraphicalLasso`, `KMeans(lloyd)`, `RANSACRegressor`; the README's tables. |
| `bench/sgd-omp-lars-compare.py` | `sgd.scm`, `omp.scm`, `lars.scm` against `SGDClassifier`/`SGDRegressor`, `OrthogonalMatchingPursuit`, `Lars`/`LassoLars`; the README's table. |
| `bench/gmm-ica-pca-compare.py` | `EMGaussianMixture`, `ParallelFastICA`, `CovPCA` (the package) against `GaussianMixture`, `FastICA`, `PCA`; the README's table. |
| `bench/linear-variants-compare.py` | `SGDPerceptron`, the pa1 SGD options, `CovARDRegression`, `GramLassoLarsIC`, `L1LinearSVM` against scikit-learn; the README's table. |
| `bench/glm-cv-compare.py` | The GLMs, the CV compositions (`LBFGSLogisticRegressionCV`, `GramLarsCV`, `GramLassoLarsCV`, `GramOMPCV`) and `WeiszfeldTheilSen` against scikit-learn; the README's table. |
| `bench/cuda-compare.py` | The `--cuda` build of FastICA, the mixture and the L-BFGS fits against the CPU build and scikit-learn; the README's `--cuda` table. |
| `bench/eigen-compare.py` | `GramRidgeCV` against `RidgeCV` (tall and wide, 3 and 50 alphas) and `GramKernelPCA` against `KernelPCA` (rbf with few and many components, linear), `--threads 1` / `all`; the README's RidgeCV and KernelPCA tables. |
| `bench/select-compare.py` | `f_regression`, `SelectKBest`, `GramRFE` against scikit-learn; the device Gram against the CPU; the README's tables. |
| `bench/lbfgs-compare.py` | `LBFGSLogisticRegression` and `LBFGSHuberRegressor` (the package) against `LogisticRegression` and `HuberRegressor`; the README's L-BFGS table. |
| `bench/sklearn-compat-overhead.py` | What the scikit-learn interface costs: fit and predict of each estimator, old package against new, alternating processes on one core. |
| `bench/dbscan-compare.py` | `dbscan.scm` against `DBSCAN(algorithm="brute")` and the default; the README's DBSCAN table. |
| `bench/logistic-l1-compare.py` | `logistic-l1.scm` (built with `-M`) against `LogisticRegression(l1_ratio=1, solver="liblinear")`: objective, nonzeros and Newton iterations beside the times. |
| `bench/bayesian-ridge-compare.py` | `CovBayesianRidge` against `BayesianRidge`: whole fits with `sigma_`, one core, the iteration counts and coefficient agreement beside the times. |
| `bench/ridge-enet-compare.py` | The elastic-net path (`CovLasso`, `l1_ratio=0.5`) against `enet_path`, and the ridge path (`CovRidge`) against `Ridge` per alpha and `RidgeCV`; whole calls, one core. |
| `bench/svm-compare.py` | The derived linear SVM (built with `-M`) against `LinearSVC`, and the kernel-form SVM on an RBF kernel against `SVC`; whole calls, one core. |
| `bench/cv-hints-experiment.py` | Does a language model rediscover the CV optimisations? |
| `cuda/batch-lasso.cu` | The standalone batched lasso path over the translated covariance kernel, one thread per lambda (the suite's CUDA case).  `cuda/compare-sklearn.py` times it against sklearn. |

## 7. The Python packages (`python/`)

| file | role |
|---|---|
| `python/README.md`, `README.ja.md` | What the two packages are. |
| `python/PACKAGING.md`, `PACKAGING.ja.md` | From a Scheme kernel to `pip install`: writing for `-M`, the package layout to copy, the suite hook, publishing. |
| `scm2cpp-lasso/src/scm2cpp_lasso/__init__.py` | `CovLasso`, `CovLassoCV`, `CovRidge`, `CovLogistic`, `CovGroupLasso`, `CovMultiTaskLasso`, `CovMultiTaskLassoCV`: the covariance-route estimators over the translated `cov_descend`/`enet_descend`/`mt_descend`; `fit_path_batch`, `bootstrap` and the CV grids go to the GPU through `_grid_descend`.  `DerivedLasso`: X and y in, the derived kernel (`lasso-kernel.scm --derive` with cuBLAS, CBLAS or loops) does the rest.  `CovBayesianRidge`: `BayesianRidge`'s iteration in the eigenbasis of X'X (numpy).  `LinearSVM`, `KernelSVM`, `LinearSVR`, `KernelSVR`, `L1LogisticRegression`: the translated liblinear / libsvm solvers of `classifiers.*`.  `CDNMF`: the derived `nmf-cd.scm` (`nmf_cublas/`, `nmf_blas/`, `nmf_loops/`).  `CDGraphicalLasso`, `GramOMP` (`gramops_*/`), `LinearRANSAC`, `SGDLinearClassifier`, `SGDLinearRegressor`, `GramLars`, `GramLassoLars` (in `classifiers.*`). |
| `scm2cpp-lasso/src/scm2cpp_lasso/batch_capi.cu` | The CUDA kernels: `scm2cpp_cv_descend` (one block per problem, fold-indexed Grams; thread fallback), `scm2cpp_batch_descend` (one thread per problem, kept for comparison). |
| `scm2cpp-lasso/src/scm2cpp_lasso/_generated/` | The translator's output for `lasso-cov.scm` (`lasso_cov.cpp/.hpp`, `_capi.cpp`, `_loader.py`), for `lasso-kernel.scm` with `--derive --cublas` / `--derive --blas` / `--derive` (`derived_cublas/`, `derived_blas/`, `derived_loops/`, one `_loader_derived_*.py` each), for `svm-liblinear.scm` + `svm-smo.scm` + `logistic-l1.scm` + `svr-liblinear.scm` + `ransac.scm` + `sgd.scm` + `lars.scm` + `svm-l1.scm` + `theilsen.scm` in one library (`classifiers.cpp/.hpp`, `_capi.cpp`, `_loader_classifiers.py`), for `nmf-cd.scm` with `--derive --cublas` / `--derive --blas` / `--derive` (`nmf_cublas/`, `nmf_blas/`, `nmf_loops/`, one `_loader_nmf_*.py` each), for `graphical-lasso.scm` + `omp.scm` + `lbfgs-objectives.scm` + `gmm.scm` + `fastica.scm` + `pca.scm` + `ard.scm` + `fscore.scm` + `rfe.scm` + `gram.scm` + `ridge-gcv.scm` + `kernel-pca.scm` with `--blas` / plainly (`gramops_blas/`, `gramops_loops/`), for `fscore.scm` + `rfe.scm` + `pca.scm` + `gram.scm` with `--cublas` (`accel_cublas/`), for `fastica.scm` + `gmm.scm` + `lbfgs-objectives.scm` with `--cuda` (`gpu_cuda/`, compiled by nvcc into `libscm2cpp_gpu.so`), and copies of `scm2cpp.hpp`, `scm2cpp-blas.hpp`, `scm2cpp-cublas.hpp` and `scm2cpp-cuda.hpp`; committed so that pip needs no Racket.  `regenerate.sh` refreshes it. |
| `scm2cpp-lasso/src/scm2cpp_lasso/_libfind.py` | Locates the built shared libraries and binds the C entry points by name; `derived_backend()` reports which derived variant was built. |
| `scm2cpp-lasso/src/scm2cpp_lasso/_compat.py` | The scikit-learn interface with scikit-learn optional: `BaseEstimator` and the mixins (scikit-learn's, or a numpy-only stand-in), the input checks `fit_xy` / `fit_x` / `pred_x` (a plain float64 C-ordered array takes a direct path, anything else scikit-learn's `validate_data`), and the tags (`Tagged`). |
| `scm2cpp-lasso/setup.py`, `pyproject.toml` | Builds the C++ (the derived kernel's cuBLAS variant when the toolkit is there, its BLAS variant when a CBLAS compiles and links, else the loop variant) and, when nvcc is on PATH, `batch_capi.cu`. |
| `scm2cpp-lasso/check-wheel.py` | A wheel's smoke test (cibuildwheel's test command): the libraries load, and the two lasso paths, L-BFGS logistic regression, PCA and the kernel SVM agree with scikit-learn on a small problem. |
| `scm2cpp-lasso/check-gpu.py` | Every GPU path against its CPU path, expected to agree to 1e-12. |
| `scm2cpp-lasso/check-classifiers.py` | `LinearSVM`, `KernelSVM`, `LinearSVR`, `KernelSVR`, `L1LogisticRegression` against `LinearSVC`, `SVC`, `LinearSVR`, `SVR`, `LogisticRegression`: objectives, prediction agreement and times; the package README's classifier table. |
| `scm2cpp-lasso/check-derived.py` | `DerivedLasso` against `CovLasso` and sklearn, tall and wide, with whole-call times. |
| `scm2cpp-lasso/check-sklearn.py` | scikit-learn's `check_estimator` over every estimator, one process each, with the expected failures and their reasons. |
| `scm2cpp-lasso/README.md`, `README.ja.md` | The package's own documentation and tables. |
| `scm2cpp-tfs/` | The same layout for the moving-average (TFS) kernels: `autocov`, `levinson`, `rolling_minmax`, `tfs_predict`, `lasso_cov` under `_generated/`; `TemporalLasso` (with `bootstrap_windows`), `TemporalRidge`, `TemporalAR`, `TemporalLogistic`, `TemporalGroupLasso` and the `CovRidge`/`CovGroupLasso` they build on in `__init__.py`; `examples/pandas_demo.py`. |

## 8. Documentation and metadata

| file | role |
|---|---|
| `README.md`, `README.ja.md` | The project: what it does, the tables, the flags, the subset. |
| `CLAUDE.md` | The pipeline in order, the rules for committing, the subset when writing Scheme for translation.  Public. |
| `CHANGES.ja.md` | The numbered changelog (Japanese; with `*.ja.md` and `README.zh.md`, the non-ASCII files). |
| `README.zh.md` | The README's head in Chinese (the tables, replacing a scikit-learn estimator, installing, sklearnex, the first example); the details link to the English `docs/`. |
| `docs/lasso.md`, `docs/benchmarks.md`, `docs/translator.md` (and `.ja.md`) | What the README links to: the lasso in detail; each estimator family against scikit-learn (the tables the README's summary is drawn from); the translator itself -- installing, the command line and options, the subset, the tests, the Typed Racket check, the runtime header. |
| `DERIVATION.md`, `DERIVATION.ja.md` | How `DerivedLasso` is derived: every rule on the `--derive --blas` log line for `lasso-design.scm`, in firing order, with permalinks into the code and what each does there. |
| `CONTRIBUTING.md` | How to report a translation failure; what a contribution needs. |
| `scribblings/scm2cpp.scrbl` | The manual of the Racket interface; its examples run at build (`doc-unit`). |
| `joss/paper.md`, `paper.ja.md`, `paper.bib` | The JOSS paper draft. |
| `CITATION.cff`, `LICENSE`, `NOTICE` | Citation metadata, licence, third-party notices (Schlep, SLIB, On Lisp, rkanren). |
| `.gitignore` | Generated `*.cpp/*.hpp` beside sources, build products, venvs. |

## 9. Vendored and external dependencies

| what | where | why |
|---|---|---|
| rkanren | `vendor/rkanren/` | cKanren's constraint framework over the recursive miniKanren core; the relational inferencer and `rel-util.scm` need `nullo`/`never-pairo`, which the catalog `cKanren` lacks.  `raco link --user vendor/rkanren` or `PLTCOLLECTS=$PWD/vendor:`. |
| `amb.plt` | PLaneT (`(planet "amb.scm" ("wmfarr" "amb.plt" 1 0))` in `type-infer-util.scm`) | Nondeterministic choice in the inference utilities; fetched by PLaneT on first use. |
| Boost | system | `boost::function`, `boost::optional`, `boost::array` in the full runtime; the minimal runtime needs none. |
| astyle | system, optional | Indents the generated code; without it the output is one line but compiles. |
| cblas / OpenBLAS, CUDA + cuBLAS | system, optional | `--blas` / `--cublas` and the corresponding suite rounds. |
| numpy, scikit-learn (celer, skglm, cuML optional) | Python venv | The packages and the benchmarks; sklearn is the reference. |

## 10. Where a change goes

- A new subset feature: a case under `probe/`, a line in `CASES=`,
  the emission in `scm2cpp-match.scm`, its typing in `type-infer-hm.scm`
  (and a clause in `type-infer-rel.scm` if the relational route should
  keep up).
- A new rewrite: a `-maybe` function in `scm2cpp-match.scm` next to
  `derive-source-maybe`, a flag in `scm2cpp-file.scm` that sets an
  environment variable, that variable in the `--plain` clearing list,
  a `test-*.rkt` unit check listed in `run-tests.sh`.
- A new product shape for BLAS: a macro clause in `array-macros.scm`, a
  fold pattern in `rewrite-derive.scm` if the derivation writes it, a
  `defop` + model in both `bindings/` files, a case in
  `probe/matmul.scm`.
- A new kernel for Python: the `.scm` under `examples/kernel-only/`,
  its `-M` output under the package's `_generated/` via
  `regenerate.sh`, the estimator in `__init__.py`, a line in
  `check-gpu.py` if it has a GPU path.
- A change to a provided Racket function: its `@defproc` example in
  `scribblings/scm2cpp.scrbl`.
- A new or renamed module, or a changed `require`: its row here and in
  `FILES.ja.md` (`test-files-doc.rkt` fails otherwise).
