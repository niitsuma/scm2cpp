"""Finding the compiled pieces at run time.

The CPU kernel is built as an extension module, so its file lands in
this package directory under whatever name the interpreter's ABI tag
gives it; ctypes loads it by path.  The CUDA library is built only when
nvcc was present at install time, so its absence is normal and means
the GPU path is simply unavailable.
"""
import ctypes
import functools
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent


# which libraries were built is fixed at install time, and the glob cost
# 20 us a call: _gram looked twice per fit, a third of a small GramRidge
@functools.lru_cache(maxsize=None)
def _find(stem):
    for pattern in (stem + ".*.so", stem + ".so", stem + ".*.pyd",
                    stem + ".dll", stem + ".*.dylib", stem + ".dylib"):
        hits = sorted(_HERE.glob(pattern))
        if hits:
            return hits[0]
    return None


def load_kernel_lib():
    """The translated covariance kernel.  Required."""
    path = _find("_lasso_cov")
    if path is None:
        raise ImportError(
            "scm2cpp_lasso: the compiled kernel is missing from "
            f"{_HERE}. Reinstall the package (pip install --force-reinstall "
            "scm2cpp-lasso); building it needs a C++17 compiler.")
    return ctypes.CDLL(str(path))


def load_classifier_lib():
    """The translated classifiers (svm-liblinear.scm, svm-smo.scm,
    logistic-l1.scm in one library).  Built with the package."""
    path = _find("_classifiers")
    if path is None:
        raise ImportError(
            "scm2cpp_lasso: the compiled classifiers are missing from "
            f"{_HERE}. Reinstall the package (pip install --force-reinstall "
            "scm2cpp-lasso); building it needs a C++17 compiler.")
    return ctypes.CDLL(str(path))


def gramops_backend():
    """The Gram-solver library variant that was built: blas or loops."""
    for v in ("blas", "loops"):
        if _find("_gramops_" + v) is not None:
            return v
    raise ImportError("scm2cpp_lasso: the BLAS solvers (graphical lasso, OMP, L-BFGS) were not built")


def load_gramops_lib(variant):
    path = _find("_gramops_" + variant)
    if path is None:
        raise ImportError(f"scm2cpp_lasso: the Gram solvers' {variant} variant was not built")
    return ctypes.CDLL(str(path))


NMF_VARIANTS = ("cublas", "blas", "loops")       # in order of preference


def nmf_backends():
    """The variants of the derived NMF that were built, best first."""
    return [v for v in NMF_VARIANTS if _find("_nmf_" + v) is not None]


def load_nmf_lib(variant):
    """One variant of the derived NMF (nmf-cd.scm --derive with --cublas,
    --blas or neither)."""
    path = _find("_nmf_" + variant)
    if path is None:
        raise ImportError(f"scm2cpp_lasso: the derived NMF's {variant} variant was not built")
    return ctypes.CDLL(str(path))


DERIVED_VARIANTS = ("cublas", "blas", "loops")   # in order of preference


def derived_backends():
    """The variants of the derived kernel that were built, best first."""
    return [v for v in DERIVED_VARIANTS if _find("_lasso_derived_" + v) is not None]


def load_derived_lib(variant):
    """One variant of the derived kernel (lasso-kernel.scm --derive
    with --cublas, --blas or neither).  Raises ImportError when that
    variant was not built; the package catches that per variant."""
    path = _find("_lasso_derived_" + variant)
    if path is None:
        raise ImportError(f"scm2cpp_lasso: the derived kernel's {variant} variant was not built")
    return ctypes.CDLL(str(path))


def load_batch_lib():
    """The CUDA batch path, or None when it was not built."""
    path = _find("libscm2cpp_batch")
    if path is None:
        return None
    try:
        lib = ctypes.CDLL(str(path))
    except OSError:
        return None
    lib.scm2cpp_batch_descend.restype = ctypes.c_int
    lib.scm2cpp_batch_descend.argtypes = [
        ctypes.POINTER(ctypes.c_double), ctypes.c_int,
        ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int,
        ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int,
        ctypes.c_double]
    # the grid entry, one block per problem: (g, n_grams, c, w, lam,
    # l1_ratio, batch, p, ntask, nobs, cap, chunk, tol, span, mode).
    # A library built from an older source lacks it; the callers ask.
    if hasattr(lib, "scm2cpp_cv_descend"):
        lib.scm2cpp_cv_descend.restype = ctypes.c_int
        lib.scm2cpp_cv_descend.argtypes = [
            ctypes.POINTER(ctypes.c_double), ctypes.c_int,
            ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int,
            ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int,
            ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int]
    return lib


def accel_built():
    """True when the --cublas build of the selection and Gram products was made."""
    return _find("_accel_cublas") is not None


def load_accel_lib():
    path = _find("_accel_cublas")
    if path is None:
        raise ImportError("scm2cpp_lasso: the cuBLAS products (accel_cublas) were not built")
    return ctypes.CDLL(str(path))


def gpu_built():
    """True when libscm2cpp_gpu.so (the --cuda translation) was built."""
    return (_HERE / "libscm2cpp_gpu.so").exists()


def load_gpu_lib():
    path = _HERE / "libscm2cpp_gpu.so"
    if not path.exists():
        raise ImportError("scm2cpp_lasso: the --cuda estimators (libscm2cpp_gpu.so) were not built")
    return ctypes.CDLL(str(path))
