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
$ ./run-tests.sh                      # full regression suite; expect PASS=65 FAIL=0 (60 without a CUDA device, 55 without cblas.h either)
```

Translate and run one program (this is also how to run a single test case
from the suite -- the suite is just this loop over the files listed in
`CASES=` inside `run-tests.sh`):

```console
$ racket scm2cpp-file.scm -t scm2c.typ prog.scm      # writes prog.hpp + prog.cpp
$ g++ -std=c++11 -I. -include boost/operators.hpp -include boost/optional.hpp \
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

## Before committing

Run `./run-tests.sh` and expect PASS=65 FAIL=0 (PASS=60 on a machine
without a CUDA device and cuBLAS, 55 without `cblas.h` either: the
`*-cublas` / `*-blas` rounds and their binding checks are skipped).
Comments and identifiers
in committed code are ASCII; `CHANGES.ja.md` is the one exception (it is
the Japanese changelog, and substantive changes get a numbered section
there). New subset features get a case under `probe/` and a line in
`run-tests.sh`'s `CASES=`.

## Architecture

The pipeline, in order (all inside `scm2cpp-file.scm` ->
`scm2cpp-match.scm`):

0. **Include splice** (`scm-include.rkt`) -- a top-level
   `(include "file.scm")` is replaced by that file's text, relative to
   the including file, before anything reads the program. Every reader
   of a source program (the translator, the relational gate's
   `source-forms`, `test-oracle.rkt`, the proposers, the tests) goes
   through `read-source-forms`/`read-source-string`; a new reader must
   too, and a script that copies a kernel elsewhere must copy what it
   includes.
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
   `array-dec!`/`row-dec!` by a scaled row) is found, its update is
   differenced into a memo over a hoisted Gram matrix, and the result
   goes back under the same `with-arrays` for the ordinary expansion.
   Restoration of the scratch follows the parameter-liveness pass. The
   kernels in `examples/kernel-only/` (lasso, enet, mt) derive this way;
   `probe/derive-*.scm` are the suite's cases, translated plainly,
   with `--derive`, with `--derive --blas` and (where a device is)
   `--derive --cublas` against the same oracle.
   The loop nests the differencing hoists are folded to whole-array
   products (`fold-matmul` in `rewrite-derive.scm`): `(array-set! g
   (matmul x (transpose x)))`, `(array-set! c (matmul x resid))`,
   `(array-dec! resid (matmul (transpose x) d))`, and the matrix forms
   of the same for the multi-task kernel. `array-macros.scm` expands
   each to its nest (the Gram to the upper triangle plus mirror).
   `--blas` / `--cublas` (`rewrite-blas.scm`, run on the source before
   macro expansion when `SCM2CPP_BLAS` is set) replace each product by
   one call of an op that `bindings/cblas-binding.scm` /
   `bindings/cublas-binding.scm` declares through the ordinary
   custom-binding mechanism (`blas-gram!`, `blas-gemv!`,
   `blas-gemv-t-add!`, `blas-gemm-nt!`, `blas-gemm-nn!`,
   `blas-gemm-tn-add!`; the C++ is `scm2cpp-blas.hpp` /
   `scm2cpp-cublas.hpp`), so nothing in the emitter matches a loop
   for BLAS. Under cuBLAS a matrix the scope only reads is uploaded
   once at scope entry, one it writes is copied at the call. A new
   product shape means: a macro clause, a fold pattern if the
   derivation writes it, a `defop` + model in both bindings, and a
   case in `probe/matmul.scm`. The null-update guard
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
   scope) -- per top-level form. Functions go through `cdeffun`;
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
- `bnew` not `new`: generated identifiers are not escaped against C++
  keywords.
- Column-major flat matrices indexed `j*n+i` suit kernels whose sweeps
  touch one column at a time (see `examples/kernel-only/`).
- A definition several programs share is written once and taken by
  `(include "file.scm")`, never copied (`soft-threshold.scm`).
- Memoisation over an integer index is a vector of promises
  (`probe/promise-table.scm`); over anything else it is a hash table
  (`make-hash`/`hash-ref`/`hash-set!`/`hash-has-key?`/`hash-count`,
  `probe/hash-memo.scm`). `even?` has no emission rule -- write
  `(= (remainder n 2) 0)`; and `(let ((x (begin ..))) ..)` emits a
  call to a nonexistent `begin`, so keep statements in statement
  position.
