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

_lib.scm2cpp_smo_solve.restype = ctypes.c_int
_lib.scm2cpp_smo_solve.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int]
def smo_solve(k, y2, lin, alpha, rho, cost, iters, eps, n, nk):
    k = np.ascontiguousarray(k, dtype=np.float64)
    y2 = np.ascontiguousarray(y2, dtype=np.float64)
    lin = np.ascontiguousarray(lin, dtype=np.float64)
    alpha = np.ascontiguousarray(alpha, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    assert rho.size == 1, "rho: expected 1 elements"
    return _lib.scm2cpp_smo_solve(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y2.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lin.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, iters, eps, n, nk)

_lib.scm2cpp_shrinkable_P.restype = ctypes.c_int
_lib.scm2cpp_shrinkable_P.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int]
def shrinkable_P(yy, a, g, cost, gmax1, gmax2, t):
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    return _lib.scm2cpp_shrinkable_P(yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, gmax1, gmax2, t)

_lib.scm2cpp_swap_position.restype = ctypes.c_int
_lib.scm2cpp_swap_position.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def swap_position(index, krow, pp, yy, a2, g, gbar, qd, s, t):
    index = np.ascontiguousarray(index, dtype=np.int32)
    krow = np.ascontiguousarray(krow, dtype=np.int32)
    pp = np.ascontiguousarray(pp, dtype=np.float64)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a2 = np.ascontiguousarray(a2, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    gbar = np.ascontiguousarray(gbar, dtype=np.float64)
    qd = np.ascontiguousarray(qd, dtype=np.float64)
    return _lib.scm2cpp_swap_position(index.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), krow.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), pp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a2.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), gbar.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qd.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), s, t)

_lib.scm2cpp_reconstruct_gradient.restype = ctypes.c_int
_lib.scm2cpp_reconstruct_gradient.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def reconstruct_gradient(k, krow, pp, yy, a, g, gbar, cost, active, n, nk):
    k = np.ascontiguousarray(k, dtype=np.float64)
    krow = np.ascontiguousarray(krow, dtype=np.int32)
    pp = np.ascontiguousarray(pp, dtype=np.float64)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    gbar = np.ascontiguousarray(gbar, dtype=np.float64)
    return _lib.scm2cpp_reconstruct_gradient(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), krow.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), pp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), gbar.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, active, n, nk)

_lib.scm2cpp_select_working_set.restype = ctypes.c_int
_lib.scm2cpp_select_working_set.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
def select_working_set(k, krow, yy, a, g, qd, cost, eps, active, nk, wi):
    k = np.ascontiguousarray(k, dtype=np.float64)
    krow = np.ascontiguousarray(krow, dtype=np.int32)
    yy = np.ascontiguousarray(yy, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    qd = np.ascontiguousarray(qd, dtype=np.float64)
    wi = np.ascontiguousarray(wi, dtype=np.int32)
    assert wi.size == 2, "wi: expected 2 elements"
    return _lib.scm2cpp_select_working_set(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), krow.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), yy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), qd.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, eps, active, nk, wi.ctypes.data_as(ctypes.POINTER(ctypes.c_int)))

_lib.scm2cpp_svr_smo.restype = ctypes.c_int
_lib.scm2cpp_svr_smo.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def svr_smo(k, z, beta, rho, cost, epsilon, iters, eps, n):
    k = np.ascontiguousarray(k, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    return _lib.scm2cpp_svr_smo(k.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, epsilon, iters, eps, n)

_lib.scm2cpp_logistic_l1.restype = ctypes.c_int
_lib.scm2cpp_logistic_l1.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_l1(x, y, w, cost, tol, maxnewton, seed, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    return _lib.scm2cpp_logistic_l1(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, tol, maxnewton, seed, n, p)

_lib.scm2cpp_svr_liblinear.restype = ctypes.c_int
_lib.scm2cpp_svr_liblinear.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def svr_liblinear(x, y, w, beta, xnorm, cost, epsilon, iters, tol, seed, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    beta = np.ascontiguousarray(beta, dtype=np.float64)
    xnorm = np.ascontiguousarray(xnorm, dtype=np.float64)
    return _lib.scm2cpp_svr_liblinear(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), beta.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xnorm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cost, epsilon, iters, tol, seed, n, p)

_lib.scm2cpp_ols_rows.restype = ctypes.c_double
_lib.scm2cpp_ols_rows.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def ols_rows(x, y, rows, m, w, g, c, l, z, xm, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    rows = np.ascontiguousarray(rows, dtype=np.int32)
    w = np.ascontiguousarray(w, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    c = np.ascontiguousarray(c, dtype=np.float64)
    l = np.ascontiguousarray(l, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    xm = np.ascontiguousarray(xm, dtype=np.float64)
    return _lib.scm2cpp_ols_rows(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rows.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), m, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p)

_lib.scm2cpp_ransac.restype = ctypes.c_int
_lib.scm2cpp_ransac.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int]
def ransac(x, y, subsets, coef, mask, out, maxtrials, minsamples, thresh, stopprob, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    subsets = np.ascontiguousarray(subsets, dtype=np.int32)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    mask = np.ascontiguousarray(mask, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_ransac(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), subsets.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mask.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), maxtrials, minsamples, thresh, stopprob, n, p)

_lib.scm2cpp_sgd_loss.restype = ctypes.c_double
_lib.scm2cpp_sgd_loss.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double]
def sgd_loss(loss, y, p):
    return _lib.scm2cpp_sgd_loss(loss, y, p)

_lib.scm2cpp_sgd_grad.restype = ctypes.c_double
_lib.scm2cpp_sgd_grad.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double]
def sgd_grad(loss, y, p):
    return _lib.scm2cpp_sgd_grad(loss, y, p)

_lib.scm2cpp_sgd.restype = ctypes.c_int
_lib.scm2cpp_sgd.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def sgd(x, y, w, out, loss, lr, alpha, eta0, powert, maxiter, tol, niternochange, fitint, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_sgd(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), loss, lr, alpha, eta0, powert, maxiter, tol, niternochange, fitint, n, p)

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
_lib.scm2cpp_lars.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def lars(g, cov, coef, nsamples, alphamin, method, maxiter, eps, p):
    g = np.ascontiguousarray(g, dtype=np.float64)
    cov = np.ascontiguousarray(cov, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    return _lib.scm2cpp_lars(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cov.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nsamples, alphamin, method, maxiter, eps, p)

