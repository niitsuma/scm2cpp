# ctypes loader for liblasso_cov.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load_kernel_lib

_lib = _load_kernel_lib()

_lib.scm2cpp_soft_threshold.restype = ctypes.c_double
_lib.scm2cpp_soft_threshold.argtypes = [ctypes.c_double, ctypes.c_double]
def soft_threshold(z, g):
    return _lib.scm2cpp_soft_threshold(z, g)

_lib.scm2cpp_cov_descend.restype = ctypes.c_int
_lib.scm2cpp_cov_descend.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def cov_descend(g, c, beta, lam, iters, nobs, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    return _lib.scm2cpp_cov_descend(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lam, iters, nobs, p)

_lib.scm2cpp_enet_descend.restype = ctypes.c_int
_lib.scm2cpp_enet_descend.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def enet_descend(g, c, beta, lam1, lam2, iters, nobs, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    return _lib.scm2cpp_enet_descend(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lam1, lam2, iters, nobs, p)

_lib.scm2cpp_mt_descend.restype = ctypes.c_int
_lib.scm2cpp_mt_descend.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int]
def mt_descend(g, c, w, lam1, lam2, iters, nobs, p, ntask):
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    return _lib.scm2cpp_mt_descend(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lam1, lam2, iters, nobs, p, ntask)

