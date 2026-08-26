# ctypes loader for librolling_minmax.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load

_lib = _load()

_lib.scm2cpp_rolling_min.restype = ctypes.c_int
_lib.scm2cpp_rolling_min.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def rolling_min(x, q, out, n, w):
    x = np.ascontiguousarray(x, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.int32)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_rolling_min(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, w)

_lib.scm2cpp_rolling_max.restype = ctypes.c_int
_lib.scm2cpp_rolling_max.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def rolling_max(x, q, out, n, w):
    x = np.ascontiguousarray(x, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.int32)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_rolling_max(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, w)

