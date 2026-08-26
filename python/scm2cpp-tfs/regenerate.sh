#!/bin/sh
# Regenerate the C++ this package ships.  Needs Racket and the
# translator; installing the package does not -- the generated sources
# are committed, so pip only ever needs a C++ compiler.
#
# Run from this package directory:  ./regenerate.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$here/src/scm2cpp_tfs/_generated

cd "$repo"
: "${PLTCOLLECTS:=}"
if [ -z "$PLTCOLLECTS" ] &&
   ! racket -e '(require (only-in cKanren nullo never-pairo))' >/dev/null 2>&1; then
    PLTCOLLECTS="$repo/vendor:"
fi
export PLTCOLLECTS

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# lasso-cov.scm carries the whole covariance route -- the builders that
# exploit the moving-average design and the descent over what they
# build -- and tfs-predict.scm the fitted values, likewise without ever
# forming the design.  The descent is also in scm2cpp-lasso; carrying a
# second copy keeps this package installable on its own.
cp examples/kernel-only/lasso-cov.scm "$tmp/lasso_cov.scm"
cp examples/kernel-only/tfs-predict.scm "$tmp/tfs_predict.scm"
cp examples/kernel-only/autocov.scm "$tmp/autocov.scm"
cp examples/kernel-only/levinson.scm "$tmp/levinson.scm"
for k in lasso_cov tfs_predict autocov levinson; do
    racket scm2cpp-file.scm -t scm2c.typ -M "$tmp/$k.scm" >/dev/null
    cp "$tmp/$k.hpp" "$tmp/$k.cpp" "$tmp/${k}_capi.cpp" "$out/"
    cp "$tmp/$k.py" "$out/_${k}_loader.py"
    # the packaged loaders share one built extension, found by path
    sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_kernel_lib as _load\n\n_lib = _load()|' \
        "$out/_${k}_loader.py"
done
cp scm2cpp.hpp "$out/"
echo "regenerated into $out"
