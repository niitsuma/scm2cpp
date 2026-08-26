# ctypes loader for libautocov.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load

_lib = _load()

_lib.scm2cpp_autocov.restype = ctypes.c_int
_lib.scm2cpp_autocov.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def autocov(x, r, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    r = np.ascontiguousarray(r, dtype=np.float64)
    return _lib.scm2cpp_autocov(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), r.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p)

