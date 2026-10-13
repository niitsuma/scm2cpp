"""Finding the compiled pieces at run time.

The CPU kernel is built as an extension module, so its file lands in
this package directory under whatever name the interpreter's ABI tag
gives it; ctypes loads it by path.  The CUDA library is built only when
nvcc was present at install time, so its absence is normal and means
the GPU path is simply unavailable.
"""
import ctypes
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent


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


def load_derived_lib():
    """The derived kernel (lasso-kernel.scm --derive, BLAS or loops).

    Raises ImportError when neither variant was built; the package
    catches that and DerivedLasso says so when used.
    """
    for stem in ("_lasso_derived_blas", "_lasso_derived_loops"):
        path = _find(stem)
        if path is not None:
            return ctypes.CDLL(str(path))
    raise ImportError("scm2cpp_lasso: the derived kernel was not built")


def derived_backend():
    """'blas', 'loops', or None when the derived kernel is missing."""
    for stem, name in (("_lasso_derived_blas", "blas"),
                       ("_lasso_derived_loops", "loops")):
        if _find(stem) is not None:
            return name
    return None


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
