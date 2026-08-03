#!/bin/bash
# Regression suite. Each program is translated, the result is compiled, and the
# executable is run; a case passes only if all three succeed.
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

CXXFLAGS="-O2 -std=c++11 -I. -include boost/operators.hpp -include boost/optional.hpp"

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
"

work=/tmp/scm2cpp-t
rm -rf "$work"; mkdir -p "$work"
pass=0; fail=0
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
    echo "PASS $base   output=$(head -c 40 "$work/$base.out" | tr '\n' ' ')" | tee -a "$OUT"
    pass=$((pass+1))
done
echo "---- PASS=$pass FAIL=$fail" | tee -a "$OUT"
