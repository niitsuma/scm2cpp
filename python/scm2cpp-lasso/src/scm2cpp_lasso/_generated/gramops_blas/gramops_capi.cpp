// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libgramops.so gramops_capi.cpp
#include "gramops.hpp"
#include <vector>
#include <algorithm>

extern "C" int scm2cpp_spd_inverse(double* a, double* inv, double* l, double* z, int p) {
  return spd_inverse(a, inv, l, z, p);
}
extern "C" int scm2cpp_enet_gap(double* w, double* q, double* qw, double* xta, double* out, double alpha, double ynorm2, int m) {
  return enet_gap(w, q, qw, xta, *reinterpret_cast<std::array<double,2>*>(out), alpha, ynorm2, m);
}
extern "C" int scm2cpp_enet_safe_rule(double* w, double* qm, double* qw, double* xta, int* active, int* excl, double* out, double alpha, int m) {
  return enet_safe_rule(w, qm, qw, xta, active, excl, *reinterpret_cast<std::array<double,2>*>(out), alpha, m);
}
extern "C" int scm2cpp_enet_gram(double* w, double* qm, double* q, double* qw, double* xta, int* active, int* excl, double* out, double alpha, int maxiter, double tol, int m) {
  return enet_gram(w, qm, q, qw, xta, active, excl, *reinterpret_cast<std::array<double,2>*>(out), alpha, maxiter, tol, m);
}
extern "C" int scm2cpp_graphical_lasso(double* emp, double* cov, double* prec, double alpha, int maxiter, double tol, double enettol, int p) {
  return graphical_lasso(emp, cov, prec, alpha, maxiter, tol, enettol, p);
}
extern "C" int scm2cpp_omp(double* x, double* y, double* coef, double* path, int rec, int kmax, int n, int p) {
  return omp(x, y, coef, path, rec, kmax, n, p);
}
extern "C" double scm2cpp_logistic_fg(double* coef, double* g, double* x, double* y, double* z, double l2, int multi, int fitint, int n, int p, int k) {
  return logistic_fg(coef, g, x, y, z, l2, multi, fitint, n, p, k);
}
extern "C" int scm2cpp_logistic_lbfgs(double* x, double* y, double* coef, double* out, double c, int maxiter, double tol, int multi, int fitint, int n, int p, int k) {
  return logistic_lbfgs(x, y, coef, out, c, maxiter, tol, multi, fitint, n, p, k);
}
extern "C" double scm2cpp_huber_fg(double* coef, double* g, double* x, double* y, double* z, double epsilon, double alpha, int fitint, int n, int p) {
  return huber_fg(coef, g, x, y, z, epsilon, alpha, fitint, n, p);
}
extern "C" int scm2cpp_huber(double* x, double* y, double* coef, double* out, double epsilon, double alpha, int maxiter, double tol, int fitint, int n, int p) {
  return huber(x, y, coef, out, epsilon, alpha, maxiter, tol, fitint, n, p);
}
extern "C" double scm2cpp_glm_fg(double* coef, double* g, double* x, double* y, double* z, int family, double power, double l2, int fitint, int n, int p) {
  return glm_fg(coef, g, x, y, z, family, power, l2, fitint, n, p);
}
extern "C" int scm2cpp_glm(double* x, double* y, double* coef, double* out, int family, double power, double alpha, int maxiter, double tol, int fitint, int n, int p) {
  return glm(x, y, coef, out, family, power, alpha, maxiter, tol, fitint, n, p);
}
extern "C" double scm2cpp_lb_abs(double a) {
  return lb_abs(a);
}
extern "C" double scm2cpp_lb_max(double a, double b) {
  return lb_max(a, b);
}
extern "C" double scm2cpp_lb_min(double a, double b) {
  return lb_min(a, b);
}
extern "C" int scm2cpp_lb_dcstep(double* cs, double fp, double dp, double stpmin, double stpmax) {
  return lb_dcstep(*reinterpret_cast<std::array<double,8>*>(cs), fp, dp, stpmin, stpmax);
}
extern "C" int scm2cpp_lb_search_start(double* ls, double f, double g, double stp, double stpmin, double stpmax, double ftol) {
  return lb_search_start(*reinterpret_cast<std::array<double,16>*>(ls), f, g, stp, stpmin, stpmax, ftol);
}
extern "C" int scm2cpp_lb_search_step(double* ls, double* cs, double f, double g, double ftol, double gtol, double xtol, double stpmin, double stpmax) {
  return lb_search_step(*reinterpret_cast<std::array<double,16>*>(ls), *reinterpret_cast<std::array<double,8>*>(cs), f, g, ftol, gtol, xtol, stpmin, stpmax);
}
extern "C" double scm2cpp_lb_dot(double* a, double* b, int nv) {
  return lb_dot(a, b, nv);
}
extern "C" double scm2cpp_lb_dot_row(double* mem, int slot, double* v, int nv) {
  return lb_dot_row(mem, slot, v, nv);
}
extern "C" double scm2cpp_lb_dot_rows(double* a, int ra, double* b, int rb, int nv) {
  return lb_dot_rows(a, ra, b, rb, nv);
}
extern "C" double scm2cpp_lb_projgr(double* g, double* w, int ib, double lbv, int nv) {
  return lb_projgr(g, w, ib, lbv, nv);
}
extern "C" int scm2cpp_lb_hv(double* q, double* smem, double* ymem, double* rho, double* al, double theta, int col, int head, int m, int nv) {
  return lb_hv(q, smem, ymem, rho, al, theta, col, head, m, nv);
}
extern "C" double scm2cpp_lb_vbv(double* v, double* smem, double* ymem, double* rho, double* bm, double* sb, double theta, int col, int head, int m, int nv) {
  return lb_vbv(v, smem, ymem, rho, bm, sb, theta, col, head, m, nv);
}
extern "C" int scm2cpp_lb_direction(double* w, double* g, double* d, double* q, double* e, double* smem, double* ymem, double* rho, double* al, double* bm, double* sb, double theta, int col, int head, int m, int ib, double lbv, int nv) {
  return lb_direction(w, g, d, q, e, smem, ymem, rho, al, bm, sb, theta, col, head, m, ib, lbv, nv);
}
extern "C" int scm2cpp_lbfgs(int kind, double* w, double* x, double* y, double* aux, double* work, double* out, int m, int maxiter, double pgtol, double ftol, int maxls, int ib, double lbv, int nv, int n, int p, int k) {
  return lbfgs(kind, w, x, y, *reinterpret_cast<std::array<double,4>*>(aux), work, out, m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k);
}
extern "C" double scm2cpp_lbfgs_fg(int kind, double* w, double* g, double* x, double* y, double* aux, double* work, int n, int p, int k) {
  return lbfgs_fg(kind, w, g, x, y, *reinterpret_cast<std::array<double,4>*>(aux), work, n, p, k);
}
extern "C" int scm2cpp_gmm_mstep(double* x, double* resp, double* weights, double* means, double* prec, double* dw, double* cov, double* l, double* u, double reg, int norm, int n, int p, int kc) {
  return gmm_mstep(x, resp, weights, means, prec, dw, cov, l, u, reg, norm, n, p, kc);
}
extern "C" double scm2cpp_gmm_estep(double* x, double* resp, double* weights, double* means, double* prec, double* wlp, double* y, double* u, double* mu, int n, int p, int kc) {
  return gmm_estep(x, resp, weights, means, prec, wlp, y, u, mu, n, p, kc);
}
extern "C" double scm2cpp_gmm_abs(double a) {
  return gmm_abs(a);
}
extern "C" int scm2cpp_gmm(double* x, double* resp, double* weights, double* means, double* prec, double* labels, double* out, int maxiter, double tol, double reg, int n, int p, int kc) {
  return gmm(x, resp, weights, means, prec, labels, out, maxiter, tol, reg, n, p, kc);
}
extern "C" double scm2cpp_eig_hypot(double a, double b) {
  return eig_hypot(a, b);
}
extern "C" int scm2cpp_sym_eigen(double* a, double* v, double* ev, double* e, int m) {
  return sym_eigen(a, v, ev, e, m);
}
extern "C" double scm2cpp_eig_abs(double a) {
  return eig_abs(a);
}
extern "C" int scm2cpp_eig_order(double* ev, int* ord, int m) {
  return eig_order(ev, ord, m);
}
extern "C" double scm2cpp_ica_tanh(double x) {
  return ica_tanh(x);
}
extern "C" int scm2cpp_ica_sym(double* w, double* a, double* v, double* ev, double* e, double* t, int m) {
  return ica_sym(w, a, v, ev, e, t, m);
}
extern "C" int scm2cpp_fastica(double* x, double* winit, double* comps, double* white, double* unmix, double* mean, int maxiter, double tol, int n, int p, int nc) {
  return fastica(x, winit, comps, white, unmix, mean, maxiter, tol, n, p, nc);
}
extern "C" int scm2cpp_pca(double* x, double* comps, double* ev, double* sv, double* mean, int n, int p) {
  return pca(x, comps, ev, sv, mean, n, p);
}
extern "C" int scm2cpp_ard_pinvh(double* a, double* s, double* v, double* ev, double* e, int k) {
  return ard_pinvh(a, s, v, ev, e, k);
}
extern "C" int scm2cpp_ard_sigma_coef(double* xy, int* idx, double* lam, double* coef, double* sigma, double* a, double* v, double* ev, double* e, double* gk, double alpha, int k) {
  return ard_sigma_coef(xy, idx, lam, coef, sigma, a, v, ev, e, gk, alpha, k);
}
extern "C" int scm2cpp_ard(double* x, double* y, double* coef, double* sigma, double* lam, double* out, int maxiter, double tol, double alpha1, double alpha2, double lambda1, double lambda2, double thresh, int hoist, int n, int p) {
  return ard(x, y, coef, sigma, lam, out, maxiter, tol, alpha1, alpha2, lambda1, lambda2, thresh, hoist, n, p);
}
extern "C" int scm2cpp_f_regression(double* x, double* y, double* r, double* f, int center, int n, int p, int q) {
  return f_regression(x, y, r, f, center, n, p, q);
}
extern "C" int scm2cpp_f_classif(double* x, int* lab, double* f, int n, int p, int k) {
  return f_classif(x, lab, f, n, p, k);
}
extern "C" double scm2cpp_min_pos(double* v, int m) {
  return min_pos(v, m);
}
extern "C" double scm2cpp_round_even(double y) {
  return round_even(y);
}
extern "C" int scm2cpp_cholesky_delete(double* l, int go, int n, int k) {
  return cholesky_delete(l, go, n, k);
}
extern "C" int scm2cpp_swap_rc(double* g, int a, int b, int p) {
  return swap_rc(g, a, b, p);
}
extern "C" int scm2cpp_lars(double* g, double* cov, double* coef, double* path, double* alphas, int rec, double nsamples, double alphamin, int method, int maxiter, double eps, int p) {
  return lars(g, cov, coef, path, alphas, rec, nsamples, alphamin, method, maxiter, eps, p);
}
extern "C" int scm2cpp_rfe_chol(double* g, int* idx, double* l, double alpha, int k, int p) {
  return rfe_chol(g, idx, l, alpha, k, p);
}
extern "C" int scm2cpp_rfe_solve(double* c, int* idx, double* w, double* l, int k, int p) {
  return rfe_solve(c, idx, w, l, k, p);
}
extern "C" int scm2cpp_rfe(double* x, double* y, double* coef, int* support, int* ranking, double alpha, int nsel, int step, int n, int p) {
  return rfe(x, y, coef, support, ranking, alpha, nsel, step, n, p);
}
extern "C" int scm2cpp_gram_xx(double* x, double* g, int n, int p) {
  return gram_xx(x, g, n, p);
}
extern "C" int scm2cpp_gram_xy(double* x, double* y, double* c, int n, int p, int q) {
  return gram_xy(x, y, c, n, p, q);
}
extern "C" int scm2cpp_ridge_gcv_primal(double* x, double* xm, double* yc, double* g, double* v, double* lam, double* z, double* r, int n, int p, int t) {
  return ridge_gcv_primal(x, xm, yc, g, v, lam, z, r, n, p, t);
}
extern "C" int scm2cpp_ridge_gcv_dual(double* k, double* q, double* mu, double* yc, double* z, double* r, int n, int t) {
  return ridge_gcv_dual(k, q, mu, yc, z, r, n, t);
}
extern "C" int scm2cpp_ridge_gcv_scan(double* z, double* lam, double* r, double* yc, double* alphas, double h0, double* mse, double* loo, int store, int n, int m, int t, int na) {
  return ridge_gcv_scan(z, lam, r, yc, alphas, h0, mse, loo, store, n, m, t, na);
}
extern "C" int scm2cpp_kpca_row_norms(double* x, double* s, int n, int p) {
  return kpca_row_norms(x, s, n, p);
}
extern "C" int scm2cpp_kpca_apply(double* g, double* sa, double* sb, int kind, double gamma, double degree, double coef0, int na, int nb) {
  return kpca_apply(g, sa, sb, kind, gamma, degree, coef0, na, nb);
}
extern "C" int scm2cpp_kpca_kernel(double* x, double* y, double* k, int kind, double gamma, double degree, double coef0, int na, int nb, int p) {
  return kpca_kernel(x, y, k, kind, gamma, degree, coef0, na, nb, p);
}
extern "C" int scm2cpp_kpca_kernel_self(double* x, double* k, int kind, double gamma, double degree, double coef0, int n, int p) {
  return kpca_kernel_self(x, k, kind, gamma, degree, coef0, n, p);
}
extern "C" int scm2cpp_kpca_centre(double* k, double* m, int n) {
  return kpca_centre(k, m, n);
}
extern "C" int scm2cpp_kpca_centre_new(double* k, double* m, int nb, int n) {
  return kpca_centre_new(k, m, nb, n);
}
extern "C" int scm2cpp_kpca_flip(double* vecs, double* vals, int n, int c) {
  return kpca_flip(vecs, vals, n, c);
}
extern "C" int scm2cpp_kpca_top_dense(double* k, double* vecs, double* vals, int n, int c) {
  return kpca_top_dense(k, vecs, vals, n, c);
}
extern "C" int scm2cpp_kpca_orth(double* y, double* g, int n, int b) {
  return kpca_orth(y, g, n, b);
}
extern "C" int scm2cpp_kpca_top_subspace(double* k, double* q, double* vecs, double* vals, int n, int b, int c, double tol, int maxit) {
  return kpca_top_subspace(k, q, vecs, vals, n, b, c, tol, maxit);
}
extern "C" int scm2cpp_kpca_linear(double* x, double* xm, double* g, double* vecs, double* vals, int n, int p, int c) {
  return kpca_linear(x, xm, g, vecs, vals, n, p, c);
}
extern "C" int scm2cpp_lda_moments(double* x, int* lab, double* g, double* means, double* counts, int n, int p, int k) {
  return lda_moments(x, lab, g, means, counts, n, p, k);
}
extern "C" int scm2cpp_lda_within(double* g, double* means, double* counts, double n, int p, int k) {
  return lda_within(g, means, counts, n, p, k);
}
extern "C" int scm2cpp_lda_svd_first(double* sw, double* std, double* v, double* s, int p) {
  return lda_svd_first(sw, std, v, s, p);
}
extern "C" int scm2cpp_lda_eigen(double* sb, double* sw, double* v, double* ev, int p) {
  return lda_eigen(sb, sw, v, ev, p);
}
