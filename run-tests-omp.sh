#!/bin/bash
# The parallel back ends, checked the way the serial one is: translate with
# -P omp, compile with -fopenmp, run, and compare the output with what the
# same program prints under Racket. A directive placed on a loop whose
# iterations are not independent shows up here as a disagreement -- and,
# because a race need not lose every time, each case is run several times
# and every run must agree.
#
# Kept out of run-tests.sh because it needs an OpenMP compiler and doubles
# the translation time; it is the same programs and the same oracle.
#
#   ./run-tests-omp.sh [logfile]
#   RUNS=10 ./run-tests-omp.sh          # more repeats per case
#   SCM2CPP_OMP_MIN=1 ./run-tests-omp.sh   # take every guarded loop, however
#                                          # short, so the directives are
#                                          # actually exercised on small data
#
# Two threads, not twenty. A race needs only two to show, and forcing the
# threshold down to 1 puts a directive on loops far too short to pay for one:
# the coordinate descent in tfs-lasso opens two parallel regions per
# coordinate, and at twenty threads it takes over 200 s against 1.25 s
# serial. That slowdown is the profitability guard's reason for existing --
# here it is switched off on purpose, so the cost is paid deliberately.
cd "$(dirname "$0")" || exit 1
if [ -z "${PLTCOLLECTS:-}" ] &&
   ! racket -e '(require (only-in cKanren nullo never-pairo))' >/dev/null 2>&1; then
    PLTCOLLECTS="$PWD/vendor:"
fi
: "${PLTCOLLECTS:=}"
export PLTCOLLECTS
TIMEOUT=${TIMEOUT:-300}
RUNS=${RUNS:-3}
OUT=${1:-/tmp/scm2cpp-omp-testresult.txt}
: > "$OUT"

# Exercising the guarded directives on test-sized data needs the threshold
# lowered; the default of 1024 would leave most of them switched off.
export SCM2CPP_OMP_MIN=${SCM2CPP_OMP_MIN:-1}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-2}

# The generated code itself only needs C++11, and that stays the floor for
# anyone using this translator.  The suite compiles at C++17 because Boost
# does: Boost.Math has required C++14 since 1.82, so -std=c++11 now fails to
# compile every case before reaching any generated line.  Deprecations are
# errors here so that a construct removed from a later standard cannot sit in
# scm2cpp.hpp unnoticed -- std::auto_ptr did exactly that, compiling only
# because libstdc++ still ships it as an extension.  Override to check
# another level:  CXXSTD=c++20 ./run-tests.sh
: "${CXXSTD:=c++17}"
CXXFLAGS="-O2 -std=$CXXSTD -fopenmp -Werror=deprecated-declarations -I. -include boost/operators.hpp -include boost/optional.hpp"

# The cases with loops worth annotating. car-test and friends have none.
CASES="
bench/psumnaive.scm
bench/psumfast.scm
bench/integnaive.scm
bench/integfast.scm
bench/integdata.scm
bench/prefixsum1d.scm
bench/integ3d.scm
bench/integrect.scm
bench/fft.scm
bench/sqrttest.scm
bench/nlet.scm
examples/tfs-lasso.scm
probe/global-set.scm
probe/unary-ops.scm
probe/vector-literal.scm
"

work=/tmp/scm2cpp-omp
rm -rf "$work"; mkdir -p "$work"
pass=0; fail=0
for src in $CASES; do
    [ -f "$src" ] || continue
    base=$(basename "$src" .scm)
    cp "$src" "$work/$base.scm"

    if ! timeout "$TIMEOUT" racket scm2cpp-file.scm -t scm2c.typ -P omp \
            "$work/$base.scm" >"$work/$base.log" 2>&1; then
        why=$(grep -vE 'dconf|^$' "$work/$base.log" | grep -m1 -E ':|break')
        echo "FAIL(translate) $base   ${why:0:80}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    n_prag=$(grep -c 'pragma' "$work/$base.hpp" 2>/dev/null || true)
    if ! g++ $CXXFLAGS -o "$work/$base.exe" "$work/$base.cpp" >"$work/$base.cc.log" 2>&1; then
        why=$(grep -m1 'error' "$work/$base.cc.log")
        echo "FAIL(compile) $base   ${why:0:80}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    if ! timeout "$TIMEOUT" racket test-oracle.rkt run "$src" >"$work/$base.racket" 2>&1; then
        echo "FAIL(oracle) $base" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    bad=""
    for i in $(seq 1 "$RUNS"); do
        if ! timeout "${RUNTIMEOUT:-300}" "$work/$base.exe" >"$work/$base.out.$i" 2>&1; then
            bad="run $i crashed"; break
        fi
        if ! why=$(racket test-oracle.rkt diff "$work/$base.racket" "$work/$base.out.$i"); then
            bad="run $i: $why"; break
        fi
    done
    if [ -n "$bad" ]; then
        echo "FAIL(differs) $base   ${bad:0:90}" | tee -a "$OUT"; fail=$((fail+1)); continue
    fi
    echo "PASS $base   ${n_prag} directive(s), ${RUNS} runs agree" | tee -a "$OUT"
    pass=$((pass+1))
done
echo "---- PASS=$pass FAIL=$fail" | tee -a "$OUT"
[ "$fail" -eq 0 ] || exit 1
