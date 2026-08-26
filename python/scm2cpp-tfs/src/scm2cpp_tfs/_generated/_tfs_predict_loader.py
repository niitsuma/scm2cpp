# ctypes loader for libtfs_predict.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load

_lib = _load()

_lib.scm2cpp_tfs_predict.restype = ctypes.c_int
_lib.scm2cpp_tfs_predict.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def tfs_predict(ps, beta, yhat, nobs, wmax, p):
    ps = np.ascontiguousarray(ps, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    yhat = np.ascontiguousarray(yhat, dtype=np.float64)
    return _lib.scm2cpp_tfs_predict(ps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), yhat.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nobs, wmax, p)

