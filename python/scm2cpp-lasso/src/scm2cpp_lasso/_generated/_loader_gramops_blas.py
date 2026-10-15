# ctypes loader for libgramops.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_gramops_lib as _load_gramops_lib

_lib = _load_gramops_lib("blas")

_lib.scm2cpp_spd_inverse.restype = ctypes.c_int
_lib.scm2cpp_spd_inverse.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def spd_inverse(a, inv, l, z, p):
    a = np.ascontiguousarray(a, dtype=np.float64)
    inv = np.ascontiguousarray(inv, dtype=np.float64)
    l = np.ascontiguousarray(l, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_spd_inverse(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), inv.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), p)

_lib.scm2cpp_enet_gap.restype = ctypes.c_int
_lib.scm2cpp_enet_gap.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int]
def enet_gap(w, q, qw, xta, out, alpha, ynorm2, m):
    w = np.ascontiguousarray(w, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.float64)
    qw = np.ascontiguousarray(qw, dtype=np.float64)
    xta = np.ascontiguousarray(xta, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    assert out.size == 2, "out: expected 2 elements"
    return _lib.scm2cpp_enet_gap(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qw.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, ynorm2, m)

_lib.scm2cpp_enet_safe_rule.restype = ctypes.c_int
_lib.scm2cpp_enet_safe_rule.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int]
def enet_safe_rule(w, qm, qw, xta, active, excl, out, alpha, m):
    w = np.ascontiguousarray(w, dtype=np.float64)
    qm = np.ascontiguousarray(qm, dtype=np.float64)
    qw = np.ascontiguousarray(qw, dtype=np.float64)
    xta = np.ascontiguousarray(xta, dtype=np.float64)
    active = np.ascontiguousarray(active, dtype=np.int32)
    excl = np.ascontiguousarray(excl, dtype=np.int32)
    out = np.ascontiguousarray(out, dtype=np.float64)
    assert out.size == 2, "out: expected 2 elements"
    return _lib.scm2cpp_enet_safe_rule(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qw.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), active.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), excl.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, m)

_lib.scm2cpp_enet_gram.restype = ctypes.c_int
_lib.scm2cpp_enet_gram.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def enet_gram(w, qm, q, qw, xta, active, excl, out, alpha, maxiter, tol, m):
    w = np.ascontiguousarray(w, dtype=np.float64)
    qm = np.ascontiguousarray(qm, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.float64)
    qw = np.ascontiguousarray(qw, dtype=np.float64)
    xta = np.ascontiguousarray(xta, dtype=np.float64)
    active = np.ascontiguousarray(active, dtype=np.int32)
    excl = np.ascontiguousarray(excl, dtype=np.int32)
    out = np.ascontiguousarray(out, dtype=np.float64)
    assert out.size == 2, "out: expected 2 elements"
    return _lib.scm2cpp_enet_gram(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qw.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), active.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), excl.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, maxiter, tol, m)

_lib.scm2cpp_graphical_lasso.restype = ctypes.c_int
_lib.scm2cpp_graphical_lasso.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int]
def graphical_lasso(emp, cov, prec, alpha, maxiter, tol, enettol, p):
    emp = np.ascontiguousarray(emp, dtype=np.float64)
    cov = np.ascontiguousarray(cov, dtype=np.float64)
    prec = np.ascontiguousarray(prec, dtype=np.float64)
    return _lib.scm2cpp_graphical_lasso(emp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cov.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, maxiter, tol, enettol, p)

_lib.scm2cpp_omp.restype = ctypes.c_int
_lib.scm2cpp_omp.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def omp(x, y, coef, kmax, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    return _lib.scm2cpp_omp(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), kmax, n, p)

