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

_lib.scm2cpp_logistic_fg.restype = ctypes.c_double
_lib.scm2cpp_logistic_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_fg(coef, g, x, y, z, l2, multi, fitint, n, p, k):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_logistic_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l2, multi, fitint, n, p, k)

_lib.scm2cpp_logistic_lbfgs.restype = ctypes.c_int
_lib.scm2cpp_logistic_lbfgs.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_lbfgs(x, y, coef, out, c, maxiter, tol, multi, fitint, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_logistic_lbfgs(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), c, maxiter, tol, multi, fitint, n, p, k)

_lib.scm2cpp_huber_fg.restype = ctypes.c_double
_lib.scm2cpp_huber_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def huber_fg(coef, g, x, y, z, epsilon, alpha, fitint, n, p):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_huber_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), epsilon, alpha, fitint, n, p)

_lib.scm2cpp_huber.restype = ctypes.c_int
_lib.scm2cpp_huber.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def huber(x, y, coef, out, epsilon, alpha, maxiter, tol, fitint, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_huber(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), epsilon, alpha, maxiter, tol, fitint, n, p)

_lib.scm2cpp_lb_abs.restype = ctypes.c_double
_lib.scm2cpp_lb_abs.argtypes = [ctypes.c_double]
def lb_abs(a):
    return _lib.scm2cpp_lb_abs(a)

_lib.scm2cpp_lb_max.restype = ctypes.c_double
_lib.scm2cpp_lb_max.argtypes = [ctypes.c_double, ctypes.c_double]
def lb_max(a, b):
    return _lib.scm2cpp_lb_max(a, b)

_lib.scm2cpp_lb_min.restype = ctypes.c_double
_lib.scm2cpp_lb_min.argtypes = [ctypes.c_double, ctypes.c_double]
def lb_min(a, b):
    return _lib.scm2cpp_lb_min(a, b)

_lib.scm2cpp_lb_dcstep.restype = ctypes.c_int
_lib.scm2cpp_lb_dcstep.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
def lb_dcstep(cs, fp, dp, stpmin, stpmax):
    cs = np.ascontiguousarray(cs, dtype=np.float64)
    assert cs.size == 8, "cs: expected 8 elements"
    return _lib.scm2cpp_lb_dcstep(cs.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), fp, dp, stpmin, stpmax)

_lib.scm2cpp_lb_search_start.restype = ctypes.c_int
_lib.scm2cpp_lb_search_start.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
def lb_search_start(ls, f, g, stp, stpmin, stpmax, ftol):
    ls = np.ascontiguousarray(ls, dtype=np.float64)
    assert ls.size == 16, "ls: expected 16 elements"
    return _lib.scm2cpp_lb_search_start(ls.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), f, g, stp, stpmin, stpmax, ftol)

_lib.scm2cpp_lb_search_step.restype = ctypes.c_int
_lib.scm2cpp_lb_search_step.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double]
def lb_search_step(ls, cs, f, g, ftol, gtol, xtol, stpmin, stpmax):
    ls = np.ascontiguousarray(ls, dtype=np.float64)
    assert ls.size == 16, "ls: expected 16 elements"
    cs = np.ascontiguousarray(cs, dtype=np.float64)
    assert cs.size == 8, "cs: expected 8 elements"
    return _lib.scm2cpp_lb_search_step(ls.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cs.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), f, g, ftol, gtol, xtol, stpmin, stpmax)

_lib.scm2cpp_lb_dot.restype = ctypes.c_double
_lib.scm2cpp_lb_dot.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def lb_dot(a, b, nv):
    a = np.ascontiguousarray(a, dtype=np.float64)
    b = np.ascontiguousarray(b, dtype=np.float64)
    return _lib.scm2cpp_lb_dot(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), b.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nv)

_lib.scm2cpp_lb_dot_row.restype = ctypes.c_double
_lib.scm2cpp_lb_dot_row.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def lb_dot_row(mem, slot, v, nv):
    mem = np.ascontiguousarray(mem, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    return _lib.scm2cpp_lb_dot_row(mem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), slot, v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), nv)

_lib.scm2cpp_lb_dot_rows.restype = ctypes.c_double
_lib.scm2cpp_lb_dot_rows.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def lb_dot_rows(a, ra, b, rb, nv):
    a = np.ascontiguousarray(a, dtype=np.float64)
    b = np.ascontiguousarray(b, dtype=np.float64)
    return _lib.scm2cpp_lb_dot_rows(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ra, b.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rb, nv)

_lib.scm2cpp_lb_projgr.restype = ctypes.c_double
_lib.scm2cpp_lb_projgr.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int]
def lb_projgr(g, w, ib, lbv, nv):
    g = np.ascontiguousarray(g, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    return _lib.scm2cpp_lb_projgr(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ib, lbv, nv)

_lib.scm2cpp_lb_hv.restype = ctypes.c_int
_lib.scm2cpp_lb_hv.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lb_hv(q, smem, ymem, rho, al, theta, col, head, m, nv):
    q = np.ascontiguousarray(q, dtype=np.float64)
    smem = np.ascontiguousarray(smem, dtype=np.float64)
    ymem = np.ascontiguousarray(ymem, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    al = np.ascontiguousarray(al, dtype=np.float64)
    return _lib.scm2cpp_lb_hv(q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), al.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), theta, col, head, m, nv)

_lib.scm2cpp_lb_vbv.restype = ctypes.c_double
_lib.scm2cpp_lb_vbv.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lb_vbv(v, smem, ymem, rho, bm, sb, theta, col, head, m, nv):
    v = np.ascontiguousarray(v, dtype=np.float64)
    smem = np.ascontiguousarray(smem, dtype=np.float64)
    ymem = np.ascontiguousarray(ymem, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    bm = np.ascontiguousarray(bm, dtype=np.float64)
    sb = np.ascontiguousarray(sb, dtype=np.float64)
    return _lib.scm2cpp_lb_vbv(v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), bm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sb.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), theta, col, head, m, nv)

_lib.scm2cpp_lb_direction.restype = ctypes.c_int
_lib.scm2cpp_lb_direction.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def lb_direction(w, g, d, q, e, smem, ymem, rho, al, bm, sb, theta, col, head, m, ib, lbv, nv):
    w = np.ascontiguousarray(w, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    d = np.ascontiguousarray(d, dtype=np.float64)
    q = np.ascontiguousarray(q, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    smem = np.ascontiguousarray(smem, dtype=np.float64)
    ymem = np.ascontiguousarray(ymem, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    al = np.ascontiguousarray(al, dtype=np.float64)
    bm = np.ascontiguousarray(bm, dtype=np.float64)
    sb = np.ascontiguousarray(sb, dtype=np.float64)
    return _lib.scm2cpp_lb_direction(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), d.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), al.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), bm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sb.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), theta, col, head, m, ib, lbv, nv)

_lib.scm2cpp_lbfgs.restype = ctypes.c_int
_lib.scm2cpp_lbfgs.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lbfgs(kind, w, x, y, aux, work, out, m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k):
    w = np.ascontiguousarray(w, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    aux = np.ascontiguousarray(aux, dtype=np.float64)
    assert aux.size == 3, "aux: expected 3 elements"
    work = np.ascontiguousarray(work, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_lbfgs(kind, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), aux.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k)

_lib.scm2cpp_lbfgs_fg.restype = ctypes.c_double
_lib.scm2cpp_lbfgs_fg.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lbfgs_fg(kind, w, g, x, y, aux, work, n, p, k):
    w = np.ascontiguousarray(w, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    aux = np.ascontiguousarray(aux, dtype=np.float64)
    assert aux.size == 3, "aux: expected 3 elements"
    work = np.ascontiguousarray(work, dtype=np.float64)
    return _lib.scm2cpp_lbfgs_fg(kind, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), aux.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, k)

