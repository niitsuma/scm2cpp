# ctypes loader for libgpu.so, generated alongside it.
# Arrays are numpy arrays of the declared dtype; they are made
# contiguous on the way in and mutated in place where the translated
# function mutates them.
import ctypes
import numpy as np
from pathlib import Path

from .._libfind import load_gpu_lib as _load_gpu_lib

_lib = _load_gpu_lib()

_lib.scm2cpp_eig_hypot.restype = ctypes.c_double
_lib.scm2cpp_eig_hypot.argtypes = [ctypes.c_double, ctypes.c_double]
def eig_hypot(a, b):
    return _lib.scm2cpp_eig_hypot(a, b)

_lib.scm2cpp_sym_eigen.restype = ctypes.c_int
_lib.scm2cpp_sym_eigen.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def sym_eigen(a, v, ev, e, m):
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    return _lib.scm2cpp_sym_eigen(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.size, v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.size, ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.size, e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.size, m)

_lib.scm2cpp_eig_abs.restype = ctypes.c_double
_lib.scm2cpp_eig_abs.argtypes = [ctypes.c_double]
def eig_abs(a):
    return _lib.scm2cpp_eig_abs(a)

_lib.scm2cpp_eig_order.restype = ctypes.c_int
_lib.scm2cpp_eig_order.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_int, ctypes.c_int]
def eig_order(ev, ord, m):
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    ord = np.ascontiguousarray(ord, dtype=np.int32)
    return _lib.scm2cpp_eig_order(ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.size, ord.ctypes.data_as(ctypes.POINTER(ctypes.c_int)), ord.size, m)

_lib.scm2cpp_ica_tanh.restype = ctypes.c_double
_lib.scm2cpp_ica_tanh.argtypes = [ctypes.c_double]
def ica_tanh(x):
    return _lib.scm2cpp_ica_tanh(x)

_lib.scm2cpp_ica_sym.restype = ctypes.c_int
_lib.scm2cpp_ica_sym.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def ica_sym(w, a, v, ev, e, t, m):
    w = np.ascontiguousarray(w, dtype=np.float64)
    a = np.ascontiguousarray(a, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    ev = np.ascontiguousarray(ev, dtype=np.float64)
    e = np.ascontiguousarray(e, dtype=np.float64)
    t = np.ascontiguousarray(t, dtype=np.float64)
    return _lib.scm2cpp_ica_sym(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.size, a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.size, v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.size, ev.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ev.size, e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.size, t.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), t.size, m)

_lib.scm2cpp_fastica.restype = ctypes.c_int
_lib.scm2cpp_fastica.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def fastica(x, winit, comps, white, unmix, mean, maxiter, tol, n, p, nc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    winit = np.ascontiguousarray(winit, dtype=np.float64)
    comps = np.ascontiguousarray(comps, dtype=np.float64)
    white = np.ascontiguousarray(white, dtype=np.float64)
    unmix = np.ascontiguousarray(unmix, dtype=np.float64)
    mean = np.ascontiguousarray(mean, dtype=np.float64)
    return _lib.scm2cpp_fastica(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, winit.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), winit.size, comps.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), comps.size, white.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), white.size, unmix.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), unmix.size, mean.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mean.size, maxiter, tol, n, p, nc)

_lib.scm2cpp_gmm_mstep.restype = ctypes.c_int
_lib.scm2cpp_gmm_mstep.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
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
    return _lib.scm2cpp_gmm_mstep(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.size, weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.size, means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.size, prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.size, dw.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), dw.size, cov.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), cov.size, l.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), l.size, u.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), u.size, reg, norm, n, p, kc)

_lib.scm2cpp_gmm_estep.restype = ctypes.c_double
_lib.scm2cpp_gmm_estep.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
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
    return _lib.scm2cpp_gmm_estep(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.size, weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.size, means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.size, prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.size, wlp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), wlp.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, u.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), u.size, mu.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mu.size, n, p, kc)

_lib.scm2cpp_gmm_abs.restype = ctypes.c_double
_lib.scm2cpp_gmm_abs.argtypes = [ctypes.c_double]
def gmm_abs(a):
    return _lib.scm2cpp_gmm_abs(a)

_lib.scm2cpp_gmm.restype = ctypes.c_int
_lib.scm2cpp_gmm.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def gmm(x, resp, weights, means, prec, labels, out, maxiter, tol, reg, n, p, kc):
    x = np.ascontiguousarray(x, dtype=np.float64)
    resp = np.ascontiguousarray(resp, dtype=np.float64)
    weights = np.ascontiguousarray(weights, dtype=np.float64)
    means = np.ascontiguousarray(means, dtype=np.float64)
    prec = np.ascontiguousarray(prec, dtype=np.float64)
    labels = np.ascontiguousarray(labels, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_gmm(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, resp.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), resp.size, weights.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), weights.size, means.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), means.size, prec.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), prec.size, labels.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), labels.size, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.size, maxiter, tol, reg, n, p, kc)

_lib.scm2cpp_logistic_fg.restype = ctypes.c_double
_lib.scm2cpp_logistic_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_fg(coef, g, x, y, z, l2, multi, fitint, n, p, k):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_logistic_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.size, l2, multi, fitint, n, p, k)

_lib.scm2cpp_logistic_lbfgs.restype = ctypes.c_int
_lib.scm2cpp_logistic_lbfgs.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def logistic_lbfgs(x, y, coef, out, c, maxiter, tol, multi, fitint, n, p, k):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_logistic_lbfgs(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.size, c, maxiter, tol, multi, fitint, n, p, k)

_lib.scm2cpp_huber_fg.restype = ctypes.c_double
_lib.scm2cpp_huber_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def huber_fg(coef, g, x, y, z, epsilon, alpha, fitint, n, p):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_huber_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.size, epsilon, alpha, fitint, n, p)

_lib.scm2cpp_huber.restype = ctypes.c_int
_lib.scm2cpp_huber.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def huber(x, y, coef, out, epsilon, alpha, maxiter, tol, fitint, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_huber(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.size, epsilon, alpha, maxiter, tol, fitint, n, p)

_lib.scm2cpp_glm_fg.restype = ctypes.c_double
_lib.scm2cpp_glm_fg.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def glm_fg(coef, g, x, y, z, family, power, l2, fitint, n, p):
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    z = np.ascontiguousarray(z, dtype=np.float64)
    return _lib.scm2cpp_glm_fg(coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, z.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), z.size, family, power, l2, fitint, n, p)

_lib.scm2cpp_glm.restype = ctypes.c_int
_lib.scm2cpp_glm.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def glm(x, y, coef, out, family, power, alpha, maxiter, tol, fitint, n, p):
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    coef = np.ascontiguousarray(coef, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_glm(x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, coef.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), coef.size, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.size, family, power, alpha, maxiter, tol, fitint, n, p)

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
_lib.scm2cpp_lb_dot.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def lb_dot(a, b, nv):
    a = np.ascontiguousarray(a, dtype=np.float64)
    b = np.ascontiguousarray(b, dtype=np.float64)
    return _lib.scm2cpp_lb_dot(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.size, b.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), b.size, nv)

_lib.scm2cpp_lb_dot_row.restype = ctypes.c_double
_lib.scm2cpp_lb_dot_row.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int]
def lb_dot_row(mem, slot, v, nv):
    mem = np.ascontiguousarray(mem, dtype=np.float64)
    v = np.ascontiguousarray(v, dtype=np.float64)
    return _lib.scm2cpp_lb_dot_row(mem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), mem.size, slot, v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.size, nv)

_lib.scm2cpp_lb_dot_rows.restype = ctypes.c_double
_lib.scm2cpp_lb_dot_rows.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lb_dot_rows(a, ra, b, rb, nv):
    a = np.ascontiguousarray(a, dtype=np.float64)
    b = np.ascontiguousarray(b, dtype=np.float64)
    return _lib.scm2cpp_lb_dot_rows(a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), a.size, ra, b.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), b.size, rb, nv)

_lib.scm2cpp_lb_projgr.restype = ctypes.c_double
_lib.scm2cpp_lb_projgr.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int]
def lb_projgr(g, w, ib, lbv, nv):
    g = np.ascontiguousarray(g, dtype=np.float64)
    w = np.ascontiguousarray(w, dtype=np.float64)
    return _lib.scm2cpp_lb_projgr(g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.size, ib, lbv, nv)

_lib.scm2cpp_lb_hv.restype = ctypes.c_int
_lib.scm2cpp_lb_hv.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lb_hv(q, smem, ymem, rho, al, theta, col, head, m, nv):
    q = np.ascontiguousarray(q, dtype=np.float64)
    smem = np.ascontiguousarray(smem, dtype=np.float64)
    ymem = np.ascontiguousarray(ymem, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    al = np.ascontiguousarray(al, dtype=np.float64)
    return _lib.scm2cpp_lb_hv(q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.size, smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.size, ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.size, rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.size, al.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), al.size, theta, col, head, m, nv)

_lib.scm2cpp_lb_vbv.restype = ctypes.c_double
_lib.scm2cpp_lb_vbv.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lb_vbv(v, smem, ymem, rho, bm, sb, theta, col, head, m, nv):
    v = np.ascontiguousarray(v, dtype=np.float64)
    smem = np.ascontiguousarray(smem, dtype=np.float64)
    ymem = np.ascontiguousarray(ymem, dtype=np.float64)
    rho = np.ascontiguousarray(rho, dtype=np.float64)
    bm = np.ascontiguousarray(bm, dtype=np.float64)
    sb = np.ascontiguousarray(sb, dtype=np.float64)
    return _lib.scm2cpp_lb_vbv(v.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), v.size, smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.size, ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.size, rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.size, bm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), bm.size, sb.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sb.size, theta, col, head, m, nv)

_lib.scm2cpp_lb_direction.restype = ctypes.c_int
_lib.scm2cpp_lb_direction.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int]
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
    return _lib.scm2cpp_lb_direction(w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.size, g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, d.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), d.size, q.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), q.size, e.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), e.size, smem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), smem.size, ymem.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), ymem.size, rho.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), rho.size, al.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), al.size, bm.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), bm.size, sb.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), sb.size, theta, col, head, m, ib, lbv, nv)

_lib.scm2cpp_lbfgs.restype = ctypes.c_int
_lib.scm2cpp_lbfgs.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_double, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lbfgs(kind, w, x, y, aux, work, out, m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k):
    w = np.ascontiguousarray(w, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    aux = np.ascontiguousarray(aux, dtype=np.float64)
    assert aux.size == 4, "aux: expected 4 elements"
    work = np.ascontiguousarray(work, dtype=np.float64)
    out = np.ascontiguousarray(out, dtype=np.float64)
    return _lib.scm2cpp_lbfgs(kind, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.size, x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, aux.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.size, out.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), out.size, m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k)

_lib.scm2cpp_lbfgs_fg.restype = ctypes.c_double
_lib.scm2cpp_lbfgs_fg.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
def lbfgs_fg(kind, w, g, x, y, aux, work, n, p, k):
    w = np.ascontiguousarray(w, dtype=np.float64)
    g = np.ascontiguousarray(g, dtype=np.float64)
    x = np.ascontiguousarray(x, dtype=np.float64)
    y = np.ascontiguousarray(y, dtype=np.float64)
    aux = np.ascontiguousarray(aux, dtype=np.float64)
    assert aux.size == 4, "aux: expected 4 elements"
    work = np.ascontiguousarray(work, dtype=np.float64)
    return _lib.scm2cpp_lbfgs_fg(kind, w.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), w.size, g.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), g.size, x.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), x.size, y.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), y.size, aux.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), work.size, n, p, k)

