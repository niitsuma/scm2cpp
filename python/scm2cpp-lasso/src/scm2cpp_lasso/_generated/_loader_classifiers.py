# ctypes loader for libclassifiers.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_classifier_lib as _load_classifier_lib

_lib = _load_classifier_lib()

_lib.scm2cpp_svm_liblinear.restype = ctypes.c_int
_lib.scm2cpp_svm_liblinear.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def svm_liblinear(x, y, w, alpha, xnorm, cost, iters, tol, seed, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    alpha = np.ascontiguousarray(alpha, dtype=np.float64)
    xnorm = np.ascontiguousarray(xnorm, dtype=np.float64)
    return _lib.scm2cpp_svm_liblinear(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xnorm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, iters, tol, seed, n, p)

_lib.scm2cpp_svm_smo.restype = ctypes.c_int
_lib.scm2cpp_svm_smo.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def svm_smo(k, y, alpha, rho, cost, iters, eps, n):
    k = np.ascontiguousarray(k, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    alpha = np.ascontiguousarray(alpha, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    return _lib.scm2cpp_svm_smo(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, iters, eps, n)

_lib.scm2cpp_shrinkable_P.restype = ctypes.c_int
_lib.scm2cpp_shrinkable_P.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int]
def shrinkable_P(yy, a, g, cost, gmax1, gmax2, t):
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    return _lib.scm2cpp_shrinkable_P(yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, gmax1, gmax2, t)

_lib.scm2cpp_swap_position.restype = ctypes.c_int
_lib.scm2cpp_swap_position.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def swap_position(index, yy, a, g, gbar, qd, s, t):
    index = np.ascontiguousarray(index, dtype=np.int32)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    gbar = np.ascontiguousarray(gbar, dtype=np.float64)
    qd = np.ascontiguousarray(qd, dtype=np.float64)
    return _lib.scm2cpp_swap_position(index.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), gbar.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qd.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), s, t)

_lib.scm2cpp_reconstruct_gradient.restype = ctypes.c_int
_lib.scm2cpp_reconstruct_gradient.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int]
def reconstruct_gradient(k, index, yy, a, g, gbar, cost, active, n):
    k = np.ascontiguousarray(k, dtype=np.float64)
    index = np.ascontiguousarray(index, dtype=np.int32)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    gbar = np.ascontiguousarray(gbar, dtype=np.float64)
    return _lib.scm2cpp_reconstruct_gradient(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), index.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), gbar.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, active, n)

_lib.scm2cpp_select_working_set.restype = ctypes.c_int
_lib.scm2cpp_select_working_set.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
def select_working_set(k, index, yy, a, g, qd, cost, eps, active, n, wi):
    k = np.ascontiguousarray(k, dtype=np.float64)
    index = np.ascontiguousarray(index, dtype=np.int32)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    qd = np.ascontiguousarray(qd, dtype=np.float64)
    wi = np.ascontiguousarray(wi, dtype=np.int32)
    assert wi.size == 2, "wi: expected 2 elements"
    return _lib.scm2cpp_select_working_set(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), index.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qd.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, eps, active, n, wi.ctypes.data_as(ctypes.POINTER(ctypes.c_int)))

_lib.scm2cpp_logistic_l1.restype = ctypes.c_int
_lib.scm2cpp_logistic_l1.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_l1(x, y, w, cost, tol, maxnewton, seed, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    return _lib.scm2cpp_logistic_l1(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, tol, maxnewton, seed, n, p)

