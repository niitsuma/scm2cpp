# ctypes loader for libgramops.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_gramops_lib as _load_gramops_lib

_lib = _load_gramops_lib("loops")

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
_lib.scm2cpp_omp.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def omp(x, y, coef, path, rec, kmax, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    path = np.ascontiguousarray(path, dtype=np.float64)
    return _lib.scm2cpp_omp(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), path.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rec, kmax, n, p)

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

_lib.scm2cpp_glm_fg.restype = ctypes.c_double
_lib.scm2cpp_glm_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def glm_fg(coef, g, x, y, z, family, power, l2, fitint, n, p):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_glm_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), family, power, l2, fitint, n, p)

_lib.scm2cpp_glm.restype = ctypes.c_int
_lib.scm2cpp_glm.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def glm(x, y, coef, out, family, power, alpha, maxiter, tol, fitint, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_glm(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), family, power, alpha, maxiter, tol, fitint, n, p)

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
    assert aux.size == 4, "aux: expected 4 elements"
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
    assert aux.size == 4, "aux: expected 4 elements"
    work = np.ascontiguousarray(work, dtype=np.float64)
    return _lib.scm2cpp_lbfgs_fg(kind, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), aux.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, k)

_lib.scm2cpp_gmm_mstep.restype = ctypes.c_int
_lib.scm2cpp_gmm_mstep.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def gmm_mstep(x, resp, weights, means, prec, dw, cov, l, u, reg, norm, n, p, kc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    resp = np.ascontiguousarray(resp, dtype=np.float64)
    weights = np.ascontiguousarray(weights, dtype=np.float64)
    means = np.ascontiguousarray(means, dtype=np.float64)
    prec = np.ascontiguousarray(prec, dtype=np.float64)
    dw = np.ascontiguousarray(dw, dtype=np.float64)
    cov = np.ascontiguousarray(cov, dtype=np.float64)
    l = np.ascontiguousarray(l, dtype=np.float64)
    u = np.ascontiguousarray(u, dtype=np.float64)
    return _lib.scm2cpp_gmm_mstep(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), dw.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cov.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), u.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), reg, norm, n, p, kc)

_lib.scm2cpp_gmm_estep.restype = ctypes.c_double
_lib.scm2cpp_gmm_estep.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def gmm_estep(x, resp, weights, means, prec, wlp, y, u, mu, n, p, kc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    resp = np.ascontiguousarray(resp, dtype=np.float64)
    weights = np.ascontiguousarray(weights, dtype=np.float64)
    means = np.ascontiguousarray(means, dtype=np.float64)
    prec = np.ascontiguousarray(prec, dtype=np.float64)
    wlp = np.ascontiguousarray(wlp, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    u = np.ascontiguousarray(u, dtype=np.float64)
    mu = np.ascontiguousarray(mu, dtype=np.float64)
    return _lib.scm2cpp_gmm_estep(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), wlp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), u.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mu.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p, kc)

_lib.scm2cpp_gmm_abs.restype = ctypes.c_double
_lib.scm2cpp_gmm_abs.argtypes = [ctypes.c_double]
def gmm_abs(a):
    return _lib.scm2cpp_gmm_abs(a)

_lib.scm2cpp_gmm.restype = ctypes.c_int
_lib.scm2cpp_gmm.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def gmm(x, resp, weights, means, prec, labels, out, maxiter, tol, reg, n, p, kc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    resp = np.ascontiguousarray(resp, dtype=np.float64)
    weights = np.ascontiguousarray(weights, dtype=np.float64)
    means = np.ascontiguousarray(means, dtype=np.float64)
    prec = np.ascontiguousarray(prec, dtype=np.float64)
    labels = np.ascontiguousarray(labels, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_gmm(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), labels.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), maxiter, tol, reg, n, p, kc)

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

_lib.scm2cpp_ica_tanh.restype = ctypes.c_double
_lib.scm2cpp_ica_tanh.argtypes = [ctypes.c_double]
def ica_tanh(x):
    return _lib.scm2cpp_ica_tanh(x)

_lib.scm2cpp_ica_sym.restype = ctypes.c_int
_lib.scm2cpp_ica_sym.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def ica_sym(w, a, v, ev, e, t, m):
    w = np.ascontiguousarray(w, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    t = np.ascontiguousarray(t, dtype=np.float64)
    return _lib.scm2cpp_ica_sym(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), t.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), m)

_lib.scm2cpp_fastica.restype = ctypes.c_int
_lib.scm2cpp_fastica.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def fastica(x, winit, comps, white, unmix, mean, maxiter, tol, n, p, nc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    winit = np.ascontiguousarray(winit, dtype=np.float64)
    comps = np.ascontiguousarray(comps, dtype=np.float64)
    white = np.ascontiguousarray(white, dtype=np.float64)
    unmix = np.ascontiguousarray(unmix, dtype=np.float64)
    mean = np.ascontiguousarray(mean, dtype=np.float64)
    return _lib.scm2cpp_fastica(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), winit.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), comps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), white.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), unmix.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mean.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), maxiter, tol, n, p, nc)

_lib.scm2cpp_pca.restype = ctypes.c_int
_lib.scm2cpp_pca.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def pca(x, comps, ev, sv, mean, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    comps = np.ascontiguousarray(comps, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    sv = np.ascontiguousarray(sv, dtype=np.float64)
    mean = np.ascontiguousarray(mean, dtype=np.float64)
    return _lib.scm2cpp_pca(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), comps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sv.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mean.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), n, p)

_lib.scm2cpp_ard_pinvh.restype = ctypes.c_int
_lib.scm2cpp_ard_pinvh.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int]
def ard_pinvh(a, s, v, ev, e, k):
    a = np.ascontiguousarray(a, dtype=np.float64)
    s = np.ascontiguousarray(s, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    return _lib.scm2cpp_ard_pinvh(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), s.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), k)

_lib.scm2cpp_ard_sigma_coef.restype = ctypes.c_int
_lib.scm2cpp_ard_sigma_coef.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def ard_sigma_coef(x, g, xy, idx, lam, coef, sigma, a, v, ev, e, xk, gk, alpha, hoist, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    xy = np.ascontiguousarray(xy, dtype=np.float64)
    idx = np.ascontiguousarray(idx, dtype=np.int32)
    lam = np.ascontiguousarray(lam, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    sigma = np.ascontiguousarray(sigma, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    xk = np.ascontiguousarray(xk, dtype=np.float64)
    gk = np.ascontiguousarray(gk, dtype=np.float64)
    return _lib.scm2cpp_ard_sigma_coef(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xy.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), idx.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), lam.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sigma.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), xk.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), gk.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), alpha, hoist, n, p, k)

_lib.scm2cpp_ard.restype = ctypes.c_int
_lib.scm2cpp_ard.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def ard(x, y, coef, sigma, lam, out, maxiter, tol, alpha1, alpha2, lambda1, lambda2, thresh, hoist, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    sigma = np.ascontiguousarray(sigma, dtype=np.float64)
    lam = np.ascontiguousarray(lam, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_ard(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sigma.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), lam.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), maxiter, tol, alpha1, alpha2, lambda1, lambda2, thresh, hoist, n, p)

