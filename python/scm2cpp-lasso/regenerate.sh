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

# NMF by coordinate descent (nmf-cd.scm, the half step written with the
# residual): --derive turns the half step into scikit-learn's form --
# the memo X HT - W HT'HT over the Gram, the residual never formed --
# and --blas / --cublas hand its products to (cu)BLAS.  Three variants,
# as for DerivedLasso, behind CDNMF.
for variant in blas cublas loops; do
    d=$tmp/nmf_$variant; mkdir -p "$d"
    cp examples/kernel-only/nmf-cd.scm "$d/nmf_cd.scm"
    case $variant in
        blas)   flags="--derive --blas";;
        cublas) flags="--derive --cublas";;
        loops)  flags="--derive";;
    esac
    racket scm2cpp-file.scm -t scm2c.typ $flags -M "$d/nmf_cd.scm" >/dev/null
    mkdir -p "$out/nmf_$variant"
    cp "$d/nmf_cd.hpp" "$d/nmf_cd.cpp" "$d/nmf_cd_capi.cpp" "$out/nmf_$variant/"
    cp "$d/nmf_cd.py" "$out/_loader_nmf_$variant.py"
    sed -i "s|^_lib = ctypes.CDLL(.*)\$|from .._libfind import load_nmf_lib as _load_nmf_lib\n\n_lib = _load_nmf_lib(\"$variant\")|" "$out/_loader_nmf_$variant.py"
done

# The solvers whose products go to BLAS: the graphical lasso
# (graphical-lasso.scm, scikit-learn's _graphical_lasso with
# enet_coordinate_descent_gram), orthogonal matching pursuit (omp.scm,
# orthogonal_mp_gram) and scipy's L-BFGS-B under scikit-learn's
# logistic, Huber and GLM objectives (lbfgs-objectives.scm), the Gaussian
# mixture by EM (gmm.scm), FastICA (fastica.scm) and PCA by the
# covariance's eigenvectors (pca.scm, over sym-eigen.scm) and ARD
# regression (ard.scm), the univariate F statistics (fscore.scm), RFE
# around ridge (rfe.scm) and the bare Gram products (gram.scm), each written
# out whole, in one library: --blas makes their products dgemm / dgemv /
# dsyrk; a loop variant for a machine without a CBLAS.  Behind
# CDGraphicalLasso, GramOMP, LBFGSLogisticRegression,
# LBFGSHuberRegressor, EMGaussianMixture, ParallelFastICA, CovPCA and
# CovARDRegression, f_regression / f_classif / SelectKBest /
# SelectPercentile and GramRFE.
for variant in blas loops; do
    d=$tmp/gramops_$variant; mkdir -p "$d"
    cp examples/kernel-only/graphical-lasso.scm examples/kernel-only/omp.scm \
       examples/kernel-only/lbfgs-objectives.scm examples/kernel-only/lbfgs.scm \
       examples/kernel-only/logistic-lbfgs.scm examples/kernel-only/huber.scm examples/kernel-only/glm.scm \
       examples/kernel-only/gmm.scm examples/kernel-only/fastica.scm \
       examples/kernel-only/pca.scm examples/kernel-only/sym-eigen.scm \
       examples/kernel-only/ard.scm examples/kernel-only/fscore.scm \
       examples/kernel-only/rfe.scm examples/kernel-only/lars.scm \
       examples/kernel-only/gram.scm examples/kernel-only/ridge-gcv.scm examples/kernel-only/kernel-pca.scm examples/kernel-only/lda.scm examples/kernel-only/truncated-svd.scm "$d/"
    printf '(include "graphical-lasso.scm")\n(include "omp.scm")\n(include "lbfgs-objectives.scm")\n(include "gmm.scm")\n(include "fastica.scm")\n(include "pca.scm")\n(include "ard.scm")\n(include "fscore.scm")\n(include "rfe.scm")\n(include "gram.scm")\n(include "ridge-gcv.scm")\n(include "kernel-pca.scm")\n(include "lda.scm")\n(include "truncated-svd.scm")\n' > "$d/gramops.scm"
    case $variant in
        blas)   flags="--blas";;
        loops)  flags="";;
    esac
    # -P omp: the loops the dependence test accepts carry their
    # directive (and its work guard); setup.py compiles them with
    # -fopenmp where the compiler takes it, serial elsewhere
    racket scm2cpp-file.scm -t scm2c.typ $flags -P omp -M "$d/gramops.scm" >/dev/null
    mkdir -p "$out/gramops_$variant"
    cp "$d/gramops.hpp" "$d/gramops.cpp" "$d/gramops_capi.cpp" "$out/gramops_$variant/"
    cp "$d/gramops.py" "$out/_loader_gramops_$variant.py"
    sed -i "s|^_lib = ctypes.CDLL(.*)\$|from .._libfind import load_gramops_lib as _load_gramops_lib\n\n_lib = _load_gramops_lib(\"$variant\")|" "$out/_loader_gramops_$variant.py"
done

# The products worth a device: fscore.scm, rfe.scm, pca.scm and gram.scm
# with --cublas, built only where the CUDA toolkit is; the wrappers take
# it when a device answers and the products are large (many targets for
# f_regression, a big Gram otherwise).
d=$tmp/accel_cublas; mkdir -p "$d"
cp examples/kernel-only/fscore.scm examples/kernel-only/rfe.scm examples/kernel-only/lars.scm \
   examples/kernel-only/pca.scm examples/kernel-only/sym-eigen.scm examples/kernel-only/gram.scm "$d/"
printf '(include "fscore.scm")\n(include "rfe.scm")\n(include "pca.scm")\n(include "gram.scm")\n' > "$d/accel.scm"
racket scm2cpp-file.scm -t scm2c.typ --cublas -M "$d/accel.scm" >/dev/null
mkdir -p "$out/accel_cublas"
cp "$d/accel.hpp" "$d/accel.cpp" "$d/accel_capi.cpp" "$out/accel_cublas/"
cp "$d/accel.py" "$out/_loader_accel_cublas.py"
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_accel_lib as _load_accel_lib\n\n_lib = _load_accel_lib()|' "$out/_loader_accel_cublas.py"

# The estimators whose iterations stay on a device: FastICA, the Gaussian
# mixture and the L-BFGS fits (logistic, Huber, GLMs) translated with
# --cuda -- their parallel loops CUDA kernels, their products cuBLAS on
# device-resident arrays.  setup.py compiles it with nvcc where the
# toolkit is (libscm2cpp_gpu.so); the wrappers take it when a device
# answers and the problem is large.
d=$tmp/gpu_cuda; mkdir -p "$d"
cp examples/kernel-only/fastica.scm examples/kernel-only/gmm.scm examples/kernel-only/sym-eigen.scm \
   examples/kernel-only/lbfgs-objectives.scm examples/kernel-only/lbfgs.scm \
   examples/kernel-only/logistic-lbfgs.scm examples/kernel-only/huber.scm \
   examples/kernel-only/glm.scm "$d/"
printf '(include "fastica.scm")\n(include "gmm.scm")\n(include "lbfgs-objectives.scm")\n' > "$d/gpu.scm"
racket scm2cpp-file.scm -t scm2c.typ --cuda -M "$d/gpu.scm" >/dev/null
mkdir -p "$out/gpu_cuda"
cp "$d/gpu.hpp" "$d/gpu.cpp" "$d/gpu_capi.cpp" "$out/gpu_cuda/"
cp "$d/gpu.py" "$out/_loader_gpu_cuda.py"
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_gpu_lib as _load_gpu_lib\n\n_lib = _load_gpu_lib()|' "$out/_loader_gpu_cuda.py"
cp scm2cpp-cuda.hpp "$out/"

# The classifiers and the SVRs: liblinear's L1-loss linear SVM
# (svm-liblinear.scm) and linear epsilon-SVR (svr-liblinear.scm),
# libsvm's SMO for C-SVC and epsilon-SVR over a kernel matrix
# (svm-smo.scm) and liblinear's L1 logistic regression
# (logistic-l1.scm), each the algorithm scikit-learn runs, written out
# in the subset and translated plainly into one library behind
# LinearSVM, KernelSVM, LinearSVR, KernelSVR and L1LogisticRegression;
# RANSAC for a linear model (ransac.scm) behind LinearRANSAC; SGD
# (sgd.scm) behind SGDLinearClassifier and SGDLinearRegressor; and least
# angle regression (lars.scm) behind GramLars, GramLassoLars and
# GramLassoLarsIC; and liblinear's L1-regularized L2-loss SVM
# (svm-l1.scm) behind L1LinearSVM; Theil-Sen (theilsen.scm) behind
# WeiszfeldTheilSen.
d=$tmp/classifiers; mkdir -p "$d"
cp examples/kernel-only/svm-liblinear.scm examples/kernel-only/svm-smo.scm \
   examples/kernel-only/logistic-l1.scm examples/kernel-only/svr-liblinear.scm \
   examples/kernel-only/ransac.scm examples/kernel-only/sgd.scm \
   examples/kernel-only/lars.scm examples/kernel-only/svm-l1.scm \
   examples/kernel-only/theilsen.scm examples/kernel-only/sym-eigen.scm "$d/"
cat > "$d/classifiers.scm" <<'SCM'
(include "svm-liblinear.scm")
(include "svm-smo.scm")
(include "logistic-l1.scm")
(include "svr-liblinear.scm")
(include "ransac.scm")
(include "sgd.scm")
(include "lars.scm")
(include "svm-l1.scm")
(include "theilsen.scm")
SCM
racket scm2cpp-file.scm -t scm2c.typ -P omp -M "$d/classifiers.scm" >/dev/null
cp "$d/classifiers.hpp" "$d/classifiers.cpp" "$d/classifiers_capi.cpp" "$out/"
cp "$d/classifiers.py" "$out/_loader_classifiers.py"
sed -i 's|^_lib = ctypes.CDLL(.*)$|from .._libfind import load_classifier_lib as _load_classifier_lib\n\n_lib = _load_classifier_lib()|' "$out/_loader_classifiers.py"
cp scm2cpp-blas.hpp scm2cpp-cublas.hpp "$out/"

echo "regenerated into $out"
