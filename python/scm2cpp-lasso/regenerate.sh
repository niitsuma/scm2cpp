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

echo "regenerated into $out"
