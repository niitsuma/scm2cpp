# ctypes loader for liblasso_kernel.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_derived_lib as _load_derived_lib

_lib = _load_derived_lib()

_lib.scm2cpp_soft_threshold.restype = ctypes.c_double
_lib.scm2cpp_soft_threshold.argtypes = [ctypes.c_double, ctypes.c_double]
def soft_threshold(z, g):
    return _lib.scm2cpp_soft_threshold(z, g)

_lib.scm2cpp_lasso.restype = ctypes.c_int
_lib.scm2cpp_lasso.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lasso(x, beta, resid, xnorm, lams, betas, iters, tol, n, p, nlam):
    x = np.ascontiguousarray(x, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    resid = np.ascontiguousarray(resid, dtype=np.float64)
    xnorm = np.ascontiguousarray(xnorm, dtype=np.float64)
    lams = np.ascontiguousarray(lams, dtype=np.float64)
    betas = np.ascontiguousarray(betas, dtype=np.float64)
    return _lib.scm2cpp_lasso(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resid.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xnorm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lams.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), betas.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), iters, tol, n, p, nlam)

