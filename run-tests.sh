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
# relational route. Both need rkanren -- cKanren's constraint framework
# over the recursive miniKanren core -- which is bundled in vendor/: if the
# caller has not pointed PLTCOLLECTS somewhere and no rkanren collection is
# registered, fall back to the bundled copy, so the suite runs from a fresh
# clone with no setup.
cd "$(dirname "$0")" || exit 1
if [ -z "${PLTCOLLECTS:-}" ] &&
   ! racket -e '(require (only-in rkanren nullo never-pairo))' >/dev/null 2>&1; then
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
probe/promise-table.scm
probe/hash-memo.scm
probe/fib.scm
probe/alias-binding.scm
probe/capture-const.scm
probe/array-fold.scm
probe/matmul.scm
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
if racket test-raise.rkt >"$work/raise.log" 2>&1; then
    echo "PASS raise-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(raise-unit)   $(tail -1 "$work/raise.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
# The relational inferencer runs both ways, so the check does too: the types
# it derives forwards, and the terms it produces from a type backwards.
if racket test-rel-infer.rkt >"$work/rel-infer.log" 2>&1; then
    echo "PASS rel-infer-unit" | tee -a "$OUT"; pass=$((pass+1))
else
    echo "FAIL(rel-infer-unit)   $(tail -1 "$work/rel-infer.log")" | tee -a "$OUT"; fail=$((fail+1))
fi
# the cases are translated from copies, so what a case includes is
# copied beside them at the same relative path (tfs-lasso.scm includes
# kernel-only/soft-threshold.scm; hash-memo.scm and fib.scm include
# define-memo.scm)
mkdir -p "$work/kernel-only"
cp examples/kernel-only/soft-threshold.scm "$work/kernel-only/"
cp probe/define-memo.scm "$work/"
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
# The derivation (--derive): the derive-* probes include the plain
# residual-form kernels (lasso, elastic net, multi-task), whose bodies
# declare their array shapes.  Translated as is and translated with
# --derive each must print the same numbers as the Racket oracle, and
# the derivation must have fired (the log on stderr names the function
# and the rules).  The probes include their kernels by a relative
# path, so the copy mirrors the tree.  Where a CBLAS header is
# installed, a third round translates with --derive --blas, must emit
# the binding's Gram call (scm2cpp::blas_gram, one dsyrk) in place of
# the loop nest, and links the BLAS; where a CUDA toolchain with
# cuBLAS and a device are present, a fourth does the same with
# --cublas.  probe/matmul.scm, the plain case of the whole-array
# products (every matmul shape the lowering knows), is translated
# with --blas and --cublas in the same rounds.  probe/auto-lasso.scm
# (lasso-auto.scm: the Gram route or the residual route by n > p, the
# products written as matmul forms by hand) is translated plainly,
# with --blas and with --cublas but never with --derive, which would
# make both routes the Gram route; the two blas rounds must find the
# Gram call as the derived kernels' do.
mkdir -p "$work/dl/examples/kernel-only" "$work/dl/probe"
cp examples/kernel-only/lasso-kernel.scm examples/kernel-only/enet-kernel.scm \
   examples/kernel-only/mt-kernel.scm examples/kernel-only/soft-threshold.scm \
   examples/kernel-only/lasso-cov.scm examples/kernel-only/lasso-auto.scm \
   "$work/dl/examples/kernel-only/"
DERIVE_MODES="plain derive"; BLAS_LIBS=
if echo '#include <cblas.h>' | g++ -x c++ -E - >/dev/null 2>&1; then
    DERIVE_MODES="$DERIVE_MODES blas"
    BLAS_LIBS=$(pkg-config --libs openblas 2>/dev/null || echo -lopenblas)
else
    echo "SKIP derive-*-blas (no cblas.h)" | tee -a "$OUT"
fi
CUDA_HOME=; CUBLAS_INC=; CUBLAS_LIBS=
if command -v nvcc >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    CUDA_HOME=$(dirname "$(dirname "$(command -v nvcc)")")
fi
if [ -n "$CUDA_HOME" ] && [ -f "$CUDA_HOME/include/cublas_v2.h" ]; then
    DERIVE_MODES="$DERIVE_MODES cublas"
    CUBLAS_INC="-I$CUDA_HOME/include"
    CUBLAS_LIBS="-L$CUDA_HOME/lib64 -lcublas -lcudart"
else
    echo "SKIP derive-*-cublas (no nvcc, no device or no cublas_v2.h)" | tee -a "$OUT"
fi
for dk in lasso enet mt matmul auto; do
    if [ $dk = matmul ]; then
        # already a plain case above; only the lowering rounds here
        dbase=matmul; modes=$(echo "$DERIVE_MODES" | tr ' ' '\n' | grep -E '^(blas|cublas)$' | tr '\n' ' ')
        [ -n "$modes" ] || continue
    elif [ $dk = auto ]; then
        dbase=auto-lasso; modes=$(echo "$DERIVE_MODES" | grep -o 'plain\|blas\|cublas' | tr '\n' ' ')
    else
        dbase=derive-$dk; modes=$DERIVE_MODES
    fi
    cp "probe/$dbase.scm" "$work/dl/probe/"
    if ! timeout "$TIMEOUT" racket test-oracle.rkt run "probe/$dbase.scm" \
           >"$work/dl/$dbase.racket" 2>"$work/dl/$dbase.oracle.log" \
       || [ ! -s "$work/dl/$dbase.racket" ]; then
        echo "FAIL($dbase oracle)   $(head -1 "$work/dl/$dbase.oracle.log")" | tee -a "$OUT"
        fail=$((fail+$(echo $modes | wc -w))); continue
    fi
    for mode in $modes; do
        case $mode in
            plain) dflag=; dlibs=; dinc=;;
            derive) dflag=--derive; dlibs=; dinc=;;
            blas) dflag=--blas; dlibs=$BLAS_LIBS; dinc=;;
            cublas) dflag=--cublas; dlibs=$CUBLAS_LIBS; dinc=$CUBLAS_INC;;
        esac
        [ $dk = matmul ] || [ $dk = auto ] || [ $mode = plain ] || [ $mode = derive ] || dflag="--derive $dflag"
        dlog=$work/dl/$dbase.$mode.log; why=
        if timeout "$TIMEOUT" racket scm2cpp-file.scm -t scm2c.typ $dflag \
               "$work/dl/probe/$dbase.scm" >"$dlog" 2>&1 \
           && { [ $dk = matmul ] || [ $dk = auto ] || [ $mode = plain ] || grep -q "^derive: $dk: .*differencing" "$dlog"; } \
           && { [ $mode = plain ] || [ $mode = derive ] || grep -q "scm2cpp::blas_gram" "$work/dl/probe/$dbase.hpp"; } \
           && g++ $CXXFLAGS $dinc -o "$work/dl/$dbase.$mode.exe" "$work/dl/probe/$dbase.cpp" \
               $dlibs >"$work/dl/$dbase.$mode.cc.log" 2>&1 \
           && timeout 120 "$work/dl/$dbase.$mode.exe" >"$work/dl/$dbase.$mode.out" 2>&1 \
           && why=$(racket test-oracle.rkt diff "$work/dl/$dbase.racket" "$work/dl/$dbase.$mode.out"); then
            echo "PASS $dbase-$mode   output=$(head -c 40 "$work/dl/$dbase.$mode.out" | tr '\n' ' ')" | tee -a "$OUT"
            pass=$((pass+1))
        else
            why=${why:-$(grep -m1 -E 'error|:' "$dlog" "$work/dl/$dbase.$mode.cc.log" 2>/dev/null | head -1)}
            echo "FAIL($dbase-$mode)   ${why:0:80}" | tee -a "$OUT"
            fail=$((fail+1))
        fi
    done
done
# The Python path runs where numpy is: the moving-average covariance
# kernel is translated with -M, the wrapper built without any boost
# include, and examples/kernel-only/tfs-fast-lasso.py must select the
# two windows its target was built from and land within tolerance of
# sklearn.
if python3 -c "import numpy" >/dev/null 2>&1; then
    cp examples/kernel-only/tfs-lasso-cov.scm "$work/tfs-lasso-cov.scm"
    cp examples/kernel-only/lasso-cov.scm "$work/lasso-cov.scm"             # included by the kernel,
    cp examples/kernel-only/soft-threshold.scm "$work/soft-threshold.scm"   # and by that in turn
    cp examples/kernel-only/tfs-fast-lasso.py "$work/tfs-fast-lasso.py"
    if timeout "$TIMEOUT" racket scm2cpp-file.scm -t scm2c.typ -M \
           "$work/tfs-lasso-cov.scm" >"$work/py.log" 2>&1 \
       && g++ -O2 -std=c++17 -shared -fPIC -I. \
              -o "$work/libtfs-lasso-cov.so" "$work/tfs-lasso-cov_capi.cpp" \
              >>"$work/py.log" 2>&1 \
       && (cd "$work" && timeout 300 python3 tfs-fast-lasso.py) \
              >>"$work/py.log" 2>&1 \
       && grep -q "5, 20" "$work/py.log" \
       && grep -q "objective gap" "$work/py.log"; then
        echo "PASS pymodule-lasso   $(grep -m1 'scm2cpp path' "$work/py.log")" | tee -a "$OUT"
        pass=$((pass+1))
    else
        echo "FAIL(pymodule-lasso)   $(tail -1 "$work/py.log")" | tee -a "$OUT"
        fail=$((fail+1))
    fi
else
    echo "SKIP pymodule-lasso (no numpy)" | tee -a "$OUT"
fi
# The CUDA path runs only where a toolchain and a device exist: the
# kernel-only covariance lasso is translated, compiled by nvcc through
# the minimal runtime, and a small batched lambda path must agree with
# the same functions run on the host.
if command -v nvcc >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    cp examples/kernel-only/tfs-lasso-cov.scm "$work/cuda-lasso-cov.scm"
    cp examples/kernel-only/lasso-cov.scm "$work/lasso-cov.scm"
    cp examples/kernel-only/soft-threshold.scm "$work/soft-threshold.scm"
    if timeout "$TIMEOUT" racket scm2cpp-file.scm -t scm2c.typ \
           "$work/cuda-lasso-cov.scm" >"$work/cuda.log" 2>&1 \
       && sed 's/tfs-lasso-cov.hpp/cuda-lasso-cov.hpp/' cuda/batch-lasso.cu \
              >"$work/batch-lasso.cu" \
       && nvcc -O2 -std=c++17 -I. -I"$work" -DLBATCH=512 -DLITERS=20 \
               "$work/batch-lasso.cu" -o "$work/batch-lasso" \
               -Wno-deprecated-gpu-targets -diag-suppress 174 \
               >>"$work/cuda.log" 2>&1 \
       && timeout 300 "$work/batch-lasso" >>"$work/cuda.log" 2>&1; then
        echo "PASS cuda-batch   $(grep -o 'speedup=[0-9.]*x' "$work/cuda.log" | tail -1)" | tee -a "$OUT"
        pass=$((pass+1))
    else
        echo "FAIL(cuda-batch)   $(tail -1 "$work/cuda.log")" | tee -a "$OUT"
        fail=$((fail+1))
    fi
else
    echo "SKIP cuda-batch (no nvcc or no device)" | tee -a "$OUT"
fi
# Every checked-in binding must still agree with its models: this is the
# case that catches the span rewrite eating a binding type that happens
# to spell std::vector (the parameter became a view with none of the
# class's operations).  The BLAS bindings --blas/--cublas load are
# checked the same way where their libraries are (the models are the
# products in Scheme; the C++ is the cblas / cuBLAS call).
BIND_CASES="examples/custom-template/foo-binding.scm examples/std-binding/vec-binding.scm"
[ -z "$BLAS_LIBS" ] || BIND_CASES="$BIND_CASES bindings/cblas-binding.scm"
[ -z "$CUBLAS_LIBS" ] || BIND_CASES="$BIND_CASES bindings/cublas-binding.scm"
for bind in $BIND_CASES; do
    bdir=$(dirname "$bind"); bopts=()
    case $bind in
        bindings/cblas-*)  bopts=(-l "$BLAS_LIBS");;
        bindings/cublas-*) bopts=(-I "$CUDA_HOME/include" -l "$CUBLAS_LIBS");;
    esac
    if timeout "$TIMEOUT" racket binding-check.rkt -I "$bdir" "${bopts[@]}" "$bind" \
           >"$work/bind.log" 2>&1; then
        echo "PASS binding-check $(basename "$bind")" | tee -a "$OUT"
        pass=$((pass+1))
    else
        echo "FAIL(binding-check $(basename "$bind"))   $(tail -1 "$work/bind.log")" | tee -a "$OUT"
        fail=$((fail+1))
    fi
done
echo "---- PASS=$pass FAIL=$fail" | tee -a "$OUT"
[ "$fail" -eq 0 ] || exit 1
