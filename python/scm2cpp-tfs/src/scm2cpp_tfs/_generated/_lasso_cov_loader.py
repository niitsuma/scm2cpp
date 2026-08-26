# ctypes loader for liblasso_cov.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_kernel_lib as _load

_lib = _load()

_lib.scm2cpp_soft_threshold.restype = ctypes.c_double
_lib.scm2cpp_soft_threshold.argtypes = [ctypes.c_double, ctypes.c_double]
def soft_threshold(z, g):
    return _lib.scm2cpp_soft_threshold(z, g)

_lib.scm2cpp_build_S.restype = ctypes.c_int
_lib.scm2cpp_build_S.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def build_S(ps, s, q, cs, n, nobs, wmax):
    ps = np.ascontiguousarray(ps, dtype=np.float64)
    s = np.ascontiguousarray(s, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.float64)
    cs = np.ascontiguousarray(cs, dtype=np.float64)
    return _lib.scm2cpp_build_S(ps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), s.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cs.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, nobs, wmax)

_lib.scm2cpp_build_P.restype = ctypes.c_int
_lib.scm2cpp_build_P.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def build_P(ps, y, pv, nobs, wmax):
    ps = np.ascontiguousarray(ps, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    pv = np.ascontiguousarray(pv, dtype=np.float64)
    return _lib.scm2cpp_build_P(ps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), pv.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nobs, wmax)

_lib.scm2cpp_build_G.restype = ctypes.c_int
_lib.scm2cpp_build_G.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def build_G(s, pv, g, c, wmax, p):
    s = np.ascontiguousarray(s, dtype=np.float64)
    pv = np.ascontiguousarray(pv, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    return _lib.scm2cpp_build_G(s.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), pv.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), wmax, p)

_lib.scm2cpp_cov_descend.restype = ctypes.c_int
_lib.scm2cpp_cov_descend.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def cov_descend(g, c, beta, lam, iters, nobs, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    return _lib.scm2cpp_cov_descend(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lam, iters, nobs, p)

