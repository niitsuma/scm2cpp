# ctypes loader for liblevinson.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load

_lib = _load()

_lib.scm2cpp_levinson.restype = ctypes.c_int
_lib.scm2cpp_levinson.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def levinson(r, phi, work, pacf, errs, p):
    r = np.ascontiguousarray(r, dtype=np.float64)
    phi = np.ascontiguousarray(phi, dtype=np.float64)
    work = np.ascontiguousarray(work, dtype=np.float64)
    pacf = np.ascontiguousarray(pacf, dtype=np.float64)
    errs = np.ascontiguousarray(errs, dtype=np.float64)
    return _lib.scm2cpp_levinson(r.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), phi.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), pacf.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), errs.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), p)

