# ctypes loader for libaccel.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_accel_lib as _load_accel_lib

_lib = _load_accel_lib()

_lib.scm2cpp_f_regression.restype = ctypes.c_int
_lib.scm2cpp_f_regression.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def f_regression(x, y, r, f, center, n, p, q):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    r = np.ascontiguousarray(r, dtype=np.float64)
    f = np.ascontiguousarray(f, dtype=np.float64)
    return _lib.scm2cpp_f_regression(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), r.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), f.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), center, n, p, q)

_lib.scm2cpp_f_classif.restype = ctypes.c_int
_lib.scm2cpp_f_classif.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def f_classif(x, lab, f, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    lab = np.ascontiguousarray(lab, dtype=np.int32)
    f = np.ascontiguousarray(f, dtype=np.float64)
    return _lib.scm2cpp_f_classif(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lab.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), f.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, k)

_lib.scm2cpp_min_pos.restype = ctypes.c_double
_lib.scm2cpp_min_pos.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def min_pos(v, m):
    v = np.ascontiguousarray(v, dtype=np.float64)
    return _lib.scm2cpp_min_pos(v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m)

_lib.scm2cpp_round_even.restype = ctypes.c_double
_lib.scm2cpp_round_even.argtypes = [ctypes.c_double]
def round_even(y):
    return _lib.scm2cpp_round_even(y)

_lib.scm2cpp_cholesky_delete.restype = ctypes.c_int
_lib.scm2cpp_cholesky_delete.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def cholesky_delete(l, go, n, k):
    l = np.ascontiguousarray(l, dtype=np.float64)
    return _lib.scm2cpp_cholesky_delete(l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), go, n, k)

_lib.scm2cpp_swap_rc.restype = ctypes.c_int
_lib.scm2cpp_swap_rc.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def swap_rc(g, a, b, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    return _lib.scm2cpp_swap_rc(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a, b, p)

_lib.scm2cpp_lars.restype = ctypes.c_int
_lib.scm2cpp_lars.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def lars(g, cov, coef, path, alphas, rec, nsamples, alphamin, method, maxiter, eps, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    cov = np.ascontiguousarray(cov, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    path = np.ascontiguousarray(path, dtype=np.float64)
    alphas = np.ascontiguousarray(alphas, dtype=np.float64)
    return _lib.scm2cpp_lars(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cov.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), path.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alphas.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rec, nsamples, alphamin, method, maxiter, eps, p)

_lib.scm2cpp_rfe_chol.restype = ctypes.c_int
_lib.scm2cpp_rfe_chol.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int]
def rfe_chol(g, idx, l, alpha, k, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    idx = np.ascontiguousarray(idx, dtype=np.int32)
    l = np.ascontiguousarray(l, dtype=np.float64)
    return _lib.scm2cpp_rfe_chol(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), idx.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, k, p)

_lib.scm2cpp_rfe_solve.restype = ctypes.c_int
_lib.scm2cpp_rfe_solve.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def rfe_solve(c, idx, w, l, k, p):
    c = np.ascontiguousarray(c, dtype=np.float64)
    idx = np.ascontiguousarray(idx, dtype=np.int32)
    w = np.ascontiguousarray(w, dtype=np.float64)
    l = np.ascontiguousarray(l, dtype=np.float64)
    return _lib.scm2cpp_rfe_solve(c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), idx.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), k, p)

_lib.scm2cpp_rfe.restype = ctypes.c_int
_lib.scm2cpp_rfe.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def rfe(x, y, coef, support, ranking, alpha, nsel, step, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    support = np.ascontiguousarray(support, dtype=np.int32)
    ranking = np.ascontiguousarray(ranking, dtype=np.int32)
    return _lib.scm2cpp_rfe(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), support.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), ranking.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), alpha, nsel, step, n, p)

_lib.scm2cpp_eig_hypot.restype = ctypes.c_double
_lib.scm2cpp_eig_hypot.argtypes = [ctypes.c_double, ctypes.c_double]
def eig_hypot(a, b):
    return _lib.scm2cpp_eig_hypot(a, b)

_lib.scm2cpp_sym_eigen.restype = ctypes.c_int
_lib.scm2cpp_sym_eigen.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def sym_eigen(a, v, ev, e, m):
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    return _lib.scm2cpp_sym_eigen(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m)

_lib.scm2cpp_eig_abs.restype = ctypes.c_double
_lib.scm2cpp_eig_abs.argtypes = [ctypes.c_double]
def eig_abs(a):
    return _lib.scm2cpp_eig_abs(a)

_lib.scm2cpp_eig_order.restype = ctypes.c_int
_lib.scm2cpp_eig_order.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.c_int]
def eig_order(ev, ord, m):
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    ord = np.ascontiguousarray(ord, dtype=np.int32)
    return _lib.scm2cpp_eig_order(ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ord.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), m)

_lib.scm2cpp_sym_eigen_top.restype = ctypes.c_int
_lib.scm2cpp_sym_eigen_top.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def sym_eigen_top(a, v, ev, e, m, k):
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    return _lib.scm2cpp_sym_eigen_top(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m, k)

_lib.scm2cpp_sym_eigen_gen.restype = ctypes.c_int
_lib.scm2cpp_sym_eigen_gen.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def sym_eigen_gen(a, b, v, ev, e, m):
    a = np.ascontiguousarray(a, dtype=np.float64)
    b = np.ascontiguousarray(b, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    return _lib.scm2cpp_sym_eigen_gen(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), b.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m)

_lib.scm2cpp_pca.restype = ctypes.c_int
_lib.scm2cpp_pca.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def pca(x, comps, ev, sv, mean, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    comps = np.ascontiguousarray(comps, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    sv = np.ascontiguousarray(sv, dtype=np.float64)
    mean = np.ascontiguousarray(mean, dtype=np.float64)
    return _lib.scm2cpp_pca(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), comps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sv.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mean.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p)

_lib.scm2cpp_gram_xx.restype = ctypes.c_int
_lib.scm2cpp_gram_xx.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def gram_xx(x, g, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    return _lib.scm2cpp_gram_xx(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p)

_lib.scm2cpp_gram_xy.restype = ctypes.c_int
_lib.scm2cpp_gram_xy.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def gram_xy(x, y, c, n, p, q):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    return _lib.scm2cpp_gram_xy(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, q)

