#!/bin/bash
# Regression suite. Each program is translated, the result is compiled, the
# executable is run, and its output is compared against what the same program
# prints under Racket; a case passes only if all four succeed.
#
# The comparison is what makes this a test of correctness rather than of
# survival: translating and compiling only shows the pipeline still works.
# Scheme is the specification, so there are no expected-output files to keep
# in step -- test-oracle.rkt runs the case and diffs the two outputs, with
# numbers compared to a tolerance because C++ prints six significant digits
# where Racket prints all of them.
#
# The default inference is Hindley-Milner; SCM2CPP_RELATIONAL=1 selects the
# original relational one. Both need cKanren, which is bundled in vendor/:
# if the caller has not pointed PLTCOLLECTS somewhere and no cKanren
# collection is registered, fall back to the bundled copy, so the suite
# runs from a fresh clone with no setup.
cd "$(dirname "$0")" || exit 1
# Testing that a cKanren collection merely exists is not enough: the package
# in the Racket catalog installs under that name but lacks the miniKanren
# layer this code calls, so probe for an identifier actually needed.
if [ -z "${PLTCOLLECTS:-}" ] &&
   ! racket -e '(require (only-in cKanren nullo never-pairo))' >/dev/null 2>&1; then
    PLTCOLLECTS="$PWD/vendor:"
fi
: "${PLTCOLLECTS:=}"
export PLTCOLLECTS
TIMEOUT=${TIMEOUT:-300}
OUT=${1:-/tmp/scm2cpp-testresult.txt}
: > "$OUT"

# C++17 is the floor for generated code: the closure and optional types
# are std::function and std::optional now, CUDA has compiled C++17 in
# device code since CUDA 11, and Boost.Math (which the full runtime
# drags in) has required C++14 since 1.82 anyway.  Deprecations are
# errors here so that a construct removed from a later standard cannot
# sit in scm2cpp.hpp unnoticed -- std::auto_ptr did exactly that,
# compiling only because libstdc++ still ships it as an extension.
# Override to check another level:  CXXSTD=c++20 ./run-tests.sh
: "${CXXSTD:=c++17}"
CXXFLAGS="-O2 -std=$CXXSTD -Werror=deprecated-declarations -I. -include boost/operators.hpp -include boost/optional.hpp"

CASES="
test-scm-code/car-test.scm
test-scm-code/comp-test.scm
test-scm-code/delay-test.scm
test-scm-code/stream-test.scm
test-scm2cpp/fact.scm
bench/psumnaive.scm
bench/psumfast.scm
bench/integnaive.scm
bench/integfast.scm
bench/integdata.scm
bench/prefixsum1d.scm
bench/integ3d.scm
bench/integrect.scm
examples/tfs-lasso.scm
bench/sqrttest.scm
bench/nlet.scm
bench/fft.scm
bench/listtest.scm
bench/constest.scm
long2/defdef2.scm
long2/defdef3.scm
probe/letrec.scm
probe/higher-order.scm
probe/thunk-arg.scm
probe/global-set.scm
probe/unary-ops.scm
probe/vector-literal.scm
probe/promise-vector.scm
probe/alias-binding.scm
probe/capture-const.scm
probe/array-fold.scm
"

work=/tmp/scm2cpp-t
rm -rf "$work"; mkdir -p "$work"
pass=0; fail=0

# Analysis unit checks run before the translation cases: they need no
# compiler and fail fast if an analysis regressed.
if racket test-liveness.rkt >"$work/liveness.log" 2>&1; then
    echo "PASS liveness-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(liveness-unit)   $(tail -1 "$work/liveness.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-incremental.rkt >"$work/incremental.log" 2>&1; then
    echo "PASS incremental-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(incremental-unit)   $(tail -1 "$work/incremental.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-internalize.rkt >"$work/internalize.log" 2>&1; then
    echo "PASS internalize-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(internalize-unit)   $(tail -1 "$work/internalize.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-precompute.rkt >"$work/precompute.log" 2>&1; then
    echo "PASS precompute-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(precompute-unit)   $(tail -1 "$work/precompute.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-normalize.rkt >"$work/normalize.log" 2>&1; then
    echo "PASS normalize-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(normalize-unit)   $(tail -1 "$work/normalize.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-lagsum.rkt >"$work/lagsum.log" 2>&1; then
    echo "PASS lagsum-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(lagsum-unit)   $(tail -1 "$work/lagsum.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-derive.rkt >"$work/derive.log" 2>&1; then
    echo "PASS derive-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(derive-unit)   $(tail -1 "$work/derive.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-contract.rkt >"$work/contract.log" 2>&1; then
    echo "PASS contract-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(contract-unit)   $(tail -1 "$work/contract.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
if racket test-cost.rkt >"$work/cost.log" 2>&1; then
    echo "PASS cost-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(cost-unit)   $(tail -1 "$work/cost.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
for src in $CASES; do
    [ -f "$src" ] || continue
    base=$(basename "$src" .scm)
    cp "$src" "$work/$base.scm"
    log=$work/$base.log

    if ! timeout "$TIMEOUT" racket scm2cpp-file.scm -t scm2c.typ "$work/$base.scm" >"$log" 2>&1; then
        why=$(grep -vE 'dconf|^$' "$log" | grep -m1 -E ':|break')
        echo "FAIL(translate) $base   ${why:0:80}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    if ! g++ $CXXFLAGS -o "$work/$base.exe" "$work/$base.cpp" >"$work/$base.cc.log" 2>&1; then
        why=$(grep -m1 'error' "$work/$base.cc.log")
        echo "FAIL(compile) $base   ${why:0:80}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    if ! timeout 120 "$work/$base.exe" >"$work/$base.out" 2>&1; then
        echo "FAIL(run) $base" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    # The oracle: the same program under Racket. A case that prints nothing
    # would compare equal to anything, so that counts as a failure -- it is
    # the hole this step exists to close.
    if ! timeout "$TIMEOUT" racket test-oracle.rkt run "$src" \
            >"$work/$base.racket" 2>"$work/$base.racket.log"; then
        why=$(grep -vE 'dconf|^$' "$work/$base.racket.log" | head -1)
        echo "FAIL(oracle) $base   ${why:0:80}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    if [ ! -s "$work/$base.racket" ]; then
        echo "FAIL(no output) $base   nothing to compare; make main print its result" \
            | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    if ! why=$(racket test-oracle.rkt diff "$work/$base.racket" "$work/$base.out"); then
        echo "FAIL(differs) $base   ${why:0:90}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    echo "PASS $base   output=$(head -c 40 "$work/$base.out" | tr '\n' ' ')" | tee -a "$OUT"
    pass=$((pass+1))
done
echo "---- PASS=$pass FAIL=$fail" | tee -a "$OUT"
[ "$fail" -eq 0 ] || exit 1
