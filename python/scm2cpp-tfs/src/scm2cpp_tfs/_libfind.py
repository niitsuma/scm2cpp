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
    """The translated kernels, all in one extension.  Required."""
    path = _find("_tfs_kernel")
    if path is None:
        raise ImportError(
            "scm2cpp_tfs: the compiled kernel is missing from "
            f"{_HERE}. Reinstall the package (pip install --force-reinstall "
            "scm2cpp-tfs); building it needs a C++17 compiler.")
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
        ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int,
        ctypes.c_int, ctypes.c_double]
    return lib
