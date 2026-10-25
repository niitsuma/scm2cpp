# ctypes loader for libnmf_cd.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_nmf_lib as _load_nmf_lib

_lib = _load_nmf_lib("cublas")

_lib.scm2cpp_nmf_half.restype = ctypes.c_double
_lib.scm2cpp_nmf_half.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def nmf_half(x, w, ht, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    ht = np.ascontiguousarray(ht, dtype=np.float64)
    return _lib.scm2cpp_nmf_half(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ht.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, k)

_lib.scm2cpp_nmf.restype = ctypes.c_int
_lib.scm2cpp_nmf.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def nmf(x, xt, w, ht, iters, tol, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    xt = np.ascontiguousarray(xt, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    ht = np.ascontiguousarray(ht, dtype=np.float64)
    return _lib.scm2cpp_nmf(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xt.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ht.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), iters, tol, n, p, k)

