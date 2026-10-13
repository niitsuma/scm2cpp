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

# lasso-kernel.scm is the plain residual-form coordinate descent, the
# algorithm of scikit-learn's Lasso(precompute=False) written as flat
# loops; --derive turns it into the Gram form (the memo c = X'r over a
# hoisted Gram, under (if (< p n) ..)), and --blas hands the three
# products to CBLAS.  DerivedLasso wraps this one; it is the
# translator's output end to end, nothing of it hand-written at the
# Gram level.  Two variants are committed: with --blas for a machine
# that has cblas.h at install time, and without for one that does not
# (correct, but the Gram is a scalar loop nest there); setup.py picks.
for variant in blas loops; do
    d=$tmp/$variant; mkdir -p "$d"
    cp examples/kernel-only/lasso-kernel.scm "$d/lasso_kernel.scm"
    cp examples/kernel-only/soft-threshold.scm "$d/"
    flags=--derive; [ $variant = blas ] && flags="--derive --blas"
    racket scm2cpp-file.scm -t scm2c.typ $flags -M "$d/lasso_kernel.scm" >/dev/null
    mkdir -p "$out/derived_$variant"
    cp "$d/lasso_kernel.hpp" "$d/lasso_kernel.cpp" "$d/lasso_kernel_capi.cpp" "$out/derived_$variant/"
done
# the two loaders are the same text (same functions, same signatures)
cp "$tmp/blas/lasso_kernel.py" "$out/_loader_derived.py"
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_derived_lib as _load_derived_lib\n\n_lib = _load_derived_lib()|' "$out/_loader_derived.py"
cp scm2cpp-blas.hpp "$out/"

echo "regenerated into $out"
