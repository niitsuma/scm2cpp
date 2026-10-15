#!/bin/sh
# Regenerate the C++ this package ships.  Needs Racket and the
# translator; installing the package does not -- the generated sources
# are committed, so pip only ever needs a C++ compiler.
#
# Run from this package directory:  ./regenerate.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$here/src/scm2cpp_lasso/_generated

cd "$repo"
: "${PLTCOLLECTS:=}"
if [ -z "$PLTCOLLECTS" ] &&
   ! racket -e '(require (only-in rkanren nullo never-pairo))' >/dev/null 2>&1; then
    PLTCOLLECTS="$repo/vendor:"
fi
export PLTCOLLECTS

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# lasso-cov.scm is the descent alone -- cov-descend, enet-descend,
# mt-descend over a Gram matrix the caller built from any design.  The
# moving-average builders live in tfs-lasso-cov.scm and belong to the
# scm2cpp-tfs package, not to this one.
cp examples/kernel-only/lasso-cov.scm "$tmp/lasso_cov.scm"
cp examples/kernel-only/soft-threshold.scm "$tmp/"   # included by the kernel
racket scm2cpp-file.scm -t scm2c.typ -M "$tmp/lasso_cov.scm" >/dev/null

cp "$tmp/lasso_cov.hpp" "$tmp/lasso_cov.cpp" "$tmp/lasso_cov_capi.cpp" "$out/"
cp "$tmp/lasso_cov.py" "$out/_loader.py"
# the packaged loader finds the built extension by path instead of
# expecting a fixed library name beside it
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_kernel_lib as _load_kernel_lib\n\n_lib = _load_kernel_lib()|' "$out/_loader.py"
cp scm2cpp.hpp "$out/"

# lasso-design.scm is the plain residual-form coordinate descent, the
# algorithm of scikit-learn's Lasso(precompute=False) written as flat
# loops over X as numpy holds it (n rows of p), the residual and the
# column norms taken inside; --derive turns it into the Gram form (the
# memo c = X'r over a hoisted Gram, the norms folded into its
# diagonal, under (if (< p n) ..)), and --blas hands the three
# products to CBLAS.  DerivedLasso wraps this one; it is the
# translator's output end to end, nothing of it hand-written at the
# Gram level, and nothing prepared in numpy.  Three variants are committed: with --blas for a machine
# that has cblas.h at install time, with --cublas for one with the
# CUDA toolkit (the products on the device, X uploaded per call), and
# with neither for one that has none of it (correct, but the Gram is a
# scalar loop nest there); setup.py builds what the machine allows and
# DerivedLasso picks.  The loaders are the same text per variant (same
# functions, same signatures), each bound to its own library.
for variant in blas cublas loops; do
    d=$tmp/$variant; mkdir -p "$d"
    cp examples/kernel-only/lasso-design.scm "$d/lasso_design.scm"
    cp examples/kernel-only/soft-threshold.scm "$d/"
    case $variant in
        blas)   flags="--derive --blas";;
        cublas) flags="--derive --cublas";;
        loops)  flags="--derive";;
    esac
    racket scm2cpp-file.scm -t scm2c.typ $flags -M "$d/lasso_design.scm" >/dev/null
    mkdir -p "$out/derived_$variant"
    rm -f "$out/derived_$variant"/lasso_kernel*
    cp "$d/lasso_design.hpp" "$d/lasso_design.cpp" "$d/lasso_design_capi.cpp" "$out/derived_$variant/"
    cp "$d/lasso_design.py" "$out/_loader_derived_$variant.py"
    sed -i "s|^_lib = ctypes.CDLL(.*)\$|from .._libfind import load_derived_lib as _load_derived_lib\n\n_lib = _load_derived_lib(\"$variant\")|" "$out/_loader_derived_$variant.py"
done
rm -f "$out/_loader_derived.py"

# The classifiers: liblinear's L1-loss linear SVM (svm-liblinear.scm),
# libsvm's SMO for C-SVC over a kernel matrix (svm-smo.scm) and
# liblinear's L1 logistic regression (logistic-l1.scm), each the
# algorithm scikit-learn runs, written out in the subset and
# translated plainly into one library behind LinearSVM, KernelSVM and
# L1LogisticRegression.
d=$tmp/classifiers; mkdir -p "$d"
cp examples/kernel-only/svm-liblinear.scm examples/kernel-only/svm-smo.scm \
   examples/kernel-only/logistic-l1.scm "$d/"
cat > "$d/classifiers.scm" <<'SCM'
(include "svm-liblinear.scm")
(include "svm-smo.scm")
(include "logistic-l1.scm")
SCM
racket scm2cpp-file.scm -t scm2c.typ -M "$d/classifiers.scm" >/dev/null
cp "$d/classifiers.hpp" "$d/classifiers.cpp" "$d/classifiers_capi.cpp" "$out/"
cp "$d/classifiers.py" "$out/_loader_classifiers.py"
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_classifier_lib as _load_classifier_lib\n\n_lib = _load_classifier_lib()|' "$out/_loader_classifiers.py"
cp scm2cpp-blas.hpp scm2cpp-cublas.hpp "$out/"

echo "regenerated into $out"
