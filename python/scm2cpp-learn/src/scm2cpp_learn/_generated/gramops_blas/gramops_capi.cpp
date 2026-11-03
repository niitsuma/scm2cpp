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

extern "C" std::int64_t scm2cpp_spd_inverse(double* a, double* inv, double* l, double* z, std::int64_t p) {
  return spd_inverse(a, inv, l, z, p);
}
extern "C" std::int64_t scm2cpp_enet_gap(double* w, double* q, double* qw, double* xta, double* out, double alpha, double ynorm2, std::int64_t m) {
  return enet_gap(w, q, qw, xta, *reinterpret_cast<std::array<double,2>*>(out), alpha, ynorm2, m);
}
extern "C" std::int64_t scm2cpp_enet_safe_rule(double* w, double* qm, double* qw, double* xta, int* active, int* excl, double* out, double alpha, std::int64_t m) {
  return enet_safe_rule(w, qm, qw, xta, active, excl, *reinterpret_cast<std::array<double,2>*>(out), alpha, m);
}
extern "C" std::int64_t scm2cpp_enet_gram(double* w, double* qm, double* q, double* qw, double* xta, int* active, int* excl, double* out, double alpha, std::int64_t maxiter, double tol, std::int64_t m) {
  return enet_gram(w, qm, q, qw, xta, active, excl, *reinterpret_cast<std::array<double,2>*>(out), alpha, maxiter, tol, m);
}
extern "C" std::int64_t scm2cpp_graphical_lasso(double* emp, double* cov, double* prec, double alpha, std::int64_t maxiter, double tol, double enettol, std::int64_t p) {
  return graphical_lasso(emp, cov, prec, alpha, maxiter, tol, enettol, p);
}
extern "C" std::int64_t scm2cpp_omp(double* x, double* y, double* coef, double* path, std::int64_t rec, std::int64_t kmax, std::int64_t n, std::int64_t p) {
  return omp(x, y, coef, path, rec, kmax, n, p);
}
extern "C" double scm2cpp_logistic_fg(double* coef, double* g, double* x, double* y, double* z, double l2, std::int64_t multi, std::int64_t fitint, std::int64_t n, std::int64_t p, std::int64_t k) {
  return logistic_fg(coef, g, x, y, z, l2, multi, fitint, n, p, k);
}
extern "C" std::int64_t scm2cpp_logistic_lbfgs(double* x, double* y, double* coef, double* out, double c, std::int64_t maxiter, double tol, std::int64_t multi, std::int64_t fitint, std::int64_t n, std::int64_t p, std::int64_t k) {
  return logistic_lbfgs(x, y, coef, out, c, maxiter, tol, multi, fitint, n, p, k);
}
extern "C" double scm2cpp_huber_fg(double* coef, double* g, double* x, double* y, double* z, double epsilon, double alpha, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  return huber_fg(coef, g, x, y, z, epsilon, alpha, fitint, n, p);
}
extern "C" std::int64_t scm2cpp_huber(double* x, double* y, double* coef, double* out, double epsilon, double alpha, std::int64_t maxiter, double tol, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  return huber(x, y, coef, out, epsilon, alpha, maxiter, tol, fitint, n, p);
}
extern "C" double scm2cpp_glm_fg(double* coef, double* g, double* x, double* y, double* z, std::int64_t family, double power, double l2, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  return glm_fg(coef, g, x, y, z, family, power, l2, fitint, n, p);
}
extern "C" std::int64_t scm2cpp_glm(double* x, double* y, double* coef, double* out, std::int64_t family, double power, double alpha, std::int64_t maxiter, double tol, std::int64_t fitint, std::int64_t n, std::int64_t p) {
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
extern "C" std::int64_t scm2cpp_lb_dcstep(double* cs, double fp, double dp, double stpmin, double stpmax) {
  return lb_dcstep(*reinterpret_cast<std::array<double,8>*>(cs), fp, dp, stpmin, stpmax);
}
extern "C" std::int64_t scm2cpp_lb_search_start(double* ls, double f, double g, double stp, double stpmin, double stpmax, double ftol) {
  return lb_search_start(*reinterpret_cast<std::array<double,16>*>(ls), f, g, stp, stpmin, stpmax, ftol);
}
extern "C" std::int64_t scm2cpp_lb_search_step(double* ls, double* cs, double f, double g, double ftol, double gtol, double xtol, double stpmin, double stpmax) {
  return lb_search_step(*reinterpret_cast<std::array<double,16>*>(ls), *reinterpret_cast<std::array<double,8>*>(cs), f, g, ftol, gtol, xtol, stpmin, stpmax);
}
extern "C" double scm2cpp_lb_dot(double* a, double* b, std::int64_t nv) {
  return lb_dot(a, b, nv);
}
extern "C" double scm2cpp_lb_dot_row(double* mem, std::int64_t slot, double* v, std::int64_t nv) {
  return lb_dot_row(mem, slot, v, nv);
}
extern "C" double scm2cpp_lb_dot_rows(double* a, std::int64_t ra, double* b, std::int64_t rb, std::int64_t nv) {
  return lb_dot_rows(a, ra, b, rb, nv);
}
extern "C" double scm2cpp_lb_projgr(double* g, double* w, std::int64_t ib, double lbv, std::int64_t nv) {
  return lb_projgr(g, w, ib, lbv, nv);
}
extern "C" std::int64_t scm2cpp_lb_hv(double* q, double* smem, double* ymem, double* rho, double* al, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t nv) {
  return lb_hv(q, smem, ymem, rho, al, theta, col, head, m, nv);
}
extern "C" double scm2cpp_lb_vbv(double* v, double* smem, double* ymem, double* rho, double* bm, double* sb, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t nv) {
  return lb_vbv(v, smem, ymem, rho, bm, sb, theta, col, head, m, nv);
}
extern "C" std::int64_t scm2cpp_lb_direction(double* w, double* g, double* d, double* q, double* e, double* smem, double* ymem, double* rho, double* al, double* bm, double* sb, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t ib, double lbv, std::int64_t nv) {
  return lb_direction(w, g, d, q, e, smem, ymem, rho, al, bm, sb, theta, col, head, m, ib, lbv, nv);
}
extern "C" std::int64_t scm2cpp_lbfgs(std::int64_t kind, double* w, double* x, double* y, double* aux, double* work, double* out, std::int64_t m, std::int64_t maxiter, double pgtol, double ftol, std::int64_t maxls, std::int64_t ib, double lbv, std::int64_t nv, std::int64_t n, std::int64_t p, std::int64_t k) {
  return lbfgs(kind, w, x, y, *reinterpret_cast<std::array<double,4>*>(aux), work, out, m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k);
}
extern "C" double scm2cpp_lbfgs_fg(std::int64_t kind, double* w, double* g, double* x, double* y, double* aux, double* work, std::int64_t n, std::int64_t p, std::int64_t k) {
  return lbfgs_fg(kind, w, g, x, y, *reinterpret_cast<std::array<double,4>*>(aux), work, n, p, k);
}
extern "C" std::int64_t scm2cpp_gmm_mstep(double* x, double* resp, double* weights, double* means, double* prec, double* dw, double* cov, double* l, double* u, double reg, std::int64_t norm, std::int64_t n, std::int64_t p, std::int64_t kc) {
  return gmm_mstep(x, resp, weights, means, prec, dw, cov, l, u, reg, norm, n, p, kc);
}
extern "C" double scm2cpp_gmm_estep(double* x, double* resp, double* weights, double* means, double* prec, double* wlp, double* y, double* u, double* mu, std::int64_t n, std::int64_t p, std::int64_t kc) {
  return gmm_estep(x, resp, weights, means, prec, wlp, y, u, mu, n, p, kc);
}
extern "C" double scm2cpp_gmm_abs(double a) {
  return gmm_abs(a);
}
extern "C" std::int64_t scm2cpp_gmm(double* x, double* resp, double* weights, double* means, double* prec, double* labels, double* out, std::int64_t maxiter, double tol, double reg, std::int64_t n, std::int64_t p, std::int64_t kc) {
  return gmm(x, resp, weights, means, prec, labels, out, maxiter, tol, reg, n, p, kc);
}
extern "C" double scm2cpp_eig_hypot(double a, double b) {
  return eig_hypot(a, b);
}
extern "C" std::int64_t scm2cpp_sym_eigen(double* a, double* v, double* ev, double* e, std::int64_t m) {
  return sym_eigen(a, v, ev, e, m);
}
extern "C" double scm2cpp_eig_abs(double a) {
  return eig_abs(a);
}
extern "C" std::int64_t scm2cpp_eig_order(double* ev, int* ord, std::int64_t m) {
  return eig_order(ev, ord, m);
}
extern "C" double scm2cpp_ica_tanh(double x) {
  return ica_tanh(x);
}
extern "C" std::int64_t scm2cpp_ica_sym(double* w, double* a, double* v, double* ev, double* e, double* t, std::int64_t m) {
  return ica_sym(w, a, v, ev, e, t, m);
}
extern "C" std::int64_t scm2cpp_fastica(double* x, double* winit, double* comps, double* white, double* unmix, double* mean, std::int64_t maxiter, double tol, std::int64_t n, std::int64_t p, std::int64_t nc) {
  return fastica(x, winit, comps, white, unmix, mean, maxiter, tol, n, p, nc);
}
extern "C" std::int64_t scm2cpp_pca(double* x, double* comps, double* ev, double* sv, double* mean, std::int64_t n, std::int64_t p) {
  return pca(x, comps, ev, sv, mean, n, p);
}
extern "C" std::int64_t scm2cpp_ard_pinvh(double* a, double* s, double* v, double* ev, double* e, std::int64_t k) {
  return ard_pinvh(a, s, v, ev, e, k);
}
extern "C" std::int64_t scm2cpp_ard_sigma_coef(double* xy, int* idx, double* lam, double* coef, double* sigma, double* a, double* v, double* ev, double* e, double* gk, double alpha, std::int64_t k) {
  return ard_sigma_coef(xy, idx, lam, coef, sigma, a, v, ev, e, gk, alpha, k);
}
extern "C" std::int64_t scm2cpp_ard(double* x, double* y, double* coef, double* sigma, double* lam, double* out, std::int64_t maxiter, double tol, double alpha1, double alpha2, double lambda1, double lambda2, double thresh, std::int64_t hoist, std::int64_t n, std::int64_t p) {
  return ard(x, y, coef, sigma, lam, out, maxiter, tol, alpha1, alpha2, lambda1, lambda2, thresh, hoist, n, p);
}
extern "C" std::int64_t scm2cpp_f_regression(double* x, double* y, double* r, double* f, std::int64_t center, std::int64_t n, std::int64_t p, std::int64_t q) {
  return f_regression(x, y, r, f, center, n, p, q);
}
extern "C" std::int64_t scm2cpp_f_classif(double* x, int* lab, double* f, std::int64_t n, std::int64_t p, std::int64_t k) {
  return f_classif(x, lab, f, n, p, k);
}
extern "C" double scm2cpp_min_pos(double* v, std::int64_t m) {
  return min_pos(v, m);
}
extern "C" double scm2cpp_round_even(double y) {
  return round_even(y);
}
extern "C" std::int64_t scm2cpp_cholesky_delete(double* l, std::int64_t go, std::int64_t n, std::int64_t k) {
  return cholesky_delete(l, go, n, k);
}
extern "C" std::int64_t scm2cpp_swap_rc(double* g, std::int64_t a, std::int64_t b, std::int64_t p) {
  return swap_rc(g, a, b, p);
}
extern "C" std::int64_t scm2cpp_lars(double* g, double* cov, double* coef, double* path, double* alphas, std::int64_t rec, double nsamples, double alphamin, std::int64_t method, std::int64_t maxiter, double eps, std::int64_t p) {
  return lars(g, cov, coef, path, alphas, rec, nsamples, alphamin, method, maxiter, eps, p);
}
extern "C" std::int64_t scm2cpp_rfe_chol(double* g, int* idx, double* l, double alpha, std::int64_t k, std::int64_t p) {
  return rfe_chol(g, idx, l, alpha, k, p);
}
extern "C" std::int64_t scm2cpp_rfe_solve(double* c, int* idx, double* w, double* l, std::int64_t k, std::int64_t p) {
  return rfe_solve(c, idx, w, l, k, p);
}
extern "C" std::int64_t scm2cpp_rfe(double* x, double* y, double* coef, int* support, int* ranking, double alpha, std::int64_t nsel, std::int64_t step, std::int64_t n, std::int64_t p) {
  return rfe(x, y, coef, support, ranking, alpha, nsel, step, n, p);
}
extern "C" std::int64_t scm2cpp_gram_xx(double* x, double* g, std::int64_t n, std::int64_t p) {
  return gram_xx(x, g, n, p);
}
extern "C" std::int64_t scm2cpp_gram_xy(double* x, double* y, double* c, std::int64_t n, std::int64_t p, std::int64_t q) {
  return gram_xy(x, y, c, n, p, q);
}
extern "C" std::int64_t scm2cpp_spd_solve(double* a, double* b, std::int64_t m, std::int64_t q) {
  return spd_solve(a, b, m, q);
}
extern "C" double scm2cpp_gram_abs(double x) {
  return gram_abs(x);
}
extern "C" double scm2cpp_spd_solve_rcond(double* a, double* b, std::int64_t m, std::int64_t q) {
  return spd_solve_rcond(a, b, m, q);
}
extern "C" std::int64_t scm2cpp_gram_ridge_solve(double* g, double* c, double alpha, std::int64_t m, std::int64_t q) {
  return gram_ridge_solve(g, c, alpha, m, q);
}
extern "C" std::int64_t scm2cpp_ridge_gcv_primal(double* x, double* xm, double* yc, double* g, double* v, double* lam, double* z, double* r, std::int64_t n, std::int64_t p, std::int64_t t) {
  return ridge_gcv_primal(x, xm, yc, g, v, lam, z, r, n, p, t);
}
extern "C" std::int64_t scm2cpp_ridge_gcv_dual(double* k, double* q, double* mu, double* yc, double* r, std::int64_t n, std::int64_t t, std::int64_t icpt) {
  return ridge_gcv_dual(k, q, mu, yc, r, n, t, icpt);
}
extern "C" std::int64_t scm2cpp_ridge_gcv_scan_dual(double* q, double* mu, double* r, double* alphas, std::int64_t drop, double* mse, double* loo, std::int64_t store, std::int64_t n, std::int64_t t, std::int64_t na) {
  return ridge_gcv_scan_dual(q, mu, r, alphas, drop, mse, loo, store, n, t, na);
}
extern "C" std::int64_t scm2cpp_ridge_gcv_scan(double* z, double* lam, double* r, double* yc, double* alphas, double h0, double* mse, double* loo, std::int64_t store, std::int64_t n, std::int64_t m, std::int64_t t, std::int64_t na) {
  return ridge_gcv_scan(z, lam, r, yc, alphas, h0, mse, loo, store, n, m, t, na);
}
extern "C" std::int64_t scm2cpp_kpca_row_norms(double* x, double* s, std::int64_t n, std::int64_t p) {
  return kpca_row_norms(x, s, n, p);
}
extern "C" std::int64_t scm2cpp_kpca_apply(double* g, double* sa, double* sb, std::int64_t kind, double gamma, double degree, double coef0, std::int64_t na, std::int64_t nb) {
  return kpca_apply(g, sa, sb, kind, gamma, degree, coef0, na, nb);
}
extern "C" std::int64_t scm2cpp_kpca_kernel(double* x, double* y, double* k, std::int64_t kind, double gamma, double degree, double coef0, std::int64_t na, std::int64_t nb, std::int64_t p) {
  return kpca_kernel(x, y, k, kind, gamma, degree, coef0, na, nb, p);
}
extern "C" std::int64_t scm2cpp_kpca_kernel_self(double* x, double* k, std::int64_t kind, double gamma, double degree, double coef0, std::int64_t n, std::int64_t p) {
  return kpca_kernel_self(x, k, kind, gamma, degree, coef0, n, p);
}
extern "C" std::int64_t scm2cpp_kpca_centre(double* k, double* m, std::int64_t n) {
  return kpca_centre(k, m, n);
}
extern "C" std::int64_t scm2cpp_kpca_centre_new(double* k, double* m, std::int64_t nb, std::int64_t n) {
  return kpca_centre_new(k, m, nb, n);
}
extern "C" std::int64_t scm2cpp_kpca_flip(double* vecs, double* vals, std::int64_t n, std::int64_t c) {
  return kpca_flip(vecs, vals, n, c);
}
extern "C" std::int64_t scm2cpp_kpca_top_dense(double* k, double* vecs, double* vals, std::int64_t n, std::int64_t c) {
  return kpca_top_dense(k, vecs, vals, n, c);
}
extern "C" std::int64_t scm2cpp_kpca_orth(double* y, double* g, std::int64_t n, std::int64_t b) {
  return kpca_orth(y, g, n, b);
}
extern "C" std::int64_t scm2cpp_kpca_top_subspace(double* k, double* q, double* vecs, double* vals, std::int64_t n, std::int64_t b, std::int64_t c, double tol, std::int64_t maxit) {
  return kpca_top_subspace(k, q, vecs, vals, n, b, c, tol, maxit);
}
extern "C" std::int64_t scm2cpp_kpca_linear(double* x, double* xm, double* g, double* vecs, double* vals, std::int64_t n, std::int64_t p, std::int64_t c) {
  return kpca_linear(x, xm, g, vecs, vals, n, p, c);
}
extern "C" std::int64_t scm2cpp_lda_moments(double* x, int* lab, double* g, double* means, double* counts, std::int64_t n, std::int64_t p, std::int64_t k) {
  return lda_moments(x, lab, g, means, counts, n, p, k);
}
extern "C" std::int64_t scm2cpp_lda_within(double* g, double* means, double* counts, double n, std::int64_t p, std::int64_t k) {
  return lda_within(g, means, counts, n, p, k);
}
extern "C" std::int64_t scm2cpp_lda_svd_first(double* sw, double* std, double* v, double* s, std::int64_t p) {
  return lda_svd_first(sw, std, v, s, p);
}
extern "C" std::int64_t scm2cpp_lda_eigen(double* sb, double* sw, double* v, double* ev, std::int64_t p) {
  return lda_eigen(sb, sw, v, ev, p);
}
extern "C" std::int64_t scm2cpp_tsvd_flip(double* v, double* z, std::int64_t n, std::int64_t p, std::int64_t k) {
  return tsvd_flip(v, z, n, p, k);
}
extern "C" std::int64_t scm2cpp_tsvd_tall(double* x, double* v, double* s, double* z, std::int64_t n, std::int64_t p, std::int64_t k) {
  return tsvd_tall(x, v, s, z, n, p, k);
}
extern "C" std::int64_t scm2cpp_tsvd_wide(double* x, double* v, double* s, double* z, std::int64_t n, std::int64_t p, std::int64_t k) {
  return tsvd_wide(x, v, s, z, n, p, k);
}
extern "C" std::int64_t scm2cpp_tsvd_gram(double* g, double* v, double* s, std::int64_t m, std::int64_t k) {
  return tsvd_gram(g, v, s, m, k);
}
extern "C" std::int64_t scm2cpp_svd_jacobi(double* w, double* q, std::int64_t r, std::int64_t c) {
  return svd_jacobi(w, q, r, c);
}
extern "C" std::int64_t scm2cpp_svd_collect(double* w, double* q, double* s, double* l, double* rr, int* ord, std::int64_t r, std::int64_t c) {
  return svd_collect(w, q, s, l, rr, ord, r, c);
}
extern "C" std::int64_t scm2cpp_sym_svd(double* a, double* u, double* s, double* vt, std::int64_t m, std::int64_t n) {
  return sym_svd(a, u, s, vt, m, n);
}
extern "C" std::int64_t scm2cpp_pls_pinv(double* a, double* pv, std::int64_t m) {
  return pls_pinv(a, pv, m);
}
extern "C" std::int64_t scm2cpp_pls_mv(double* a, double* x, double* y, std::int64_t m, std::int64_t n) {
  return pls_mv(a, x, y, m, n);
}
extern "C" std::int64_t scm2cpp_pls_mtv(double* a, double* x, double* y, std::int64_t m, std::int64_t n) {
  return pls_mtv(a, x, y, m, n);
}
extern "C" double scm2cpp_pls_dot(double* x, double* y, std::int64_t m) {
  return pls_dot(x, y, m);
}
extern "C" std::int64_t scm2cpp_pls_fit(double* cxx, double* cxy, double* cyy, double* xw, double* yw, double* xl, double* yl, int* niter, std::int64_t p, std::int64_t q, std::int64_t k, std::int64_t mode, std::int64_t canon, std::int64_t algo, std::int64_t maxit, double tol) {
  return pls_fit(cxx, cxy, cyy, xw, yw, xl, yl, niter, p, q, k, mode, canon, algo, maxit, tol);
}
extern "C" std::int64_t scm2cpp_fa_fit(double* c, double* var, double* psi, double* w, double* ll, double n, std::int64_t p, std::int64_t k, std::int64_t maxit, double tol) {
  return fa_fit(c, var, psi, w, ll, n, p, k, maxit, tol);
}
extern "C" std::int64_t scm2cpp_linreg_solve(double* g, double* b, double* coef, std::int64_t p, std::int64_t t, double ratio, double tol) {
  return linreg_solve(g, b, coef, p, t, ratio, tol);
}
extern "C" std::int64_t scm2cpp_linreg_singular(double* g, double* s, std::int64_t p, double tol) {
  return linreg_singular(g, s, p, tol);
}
extern "C" std::int64_t scm2cpp_csr_gram(int* rp, int* ci, double* v, double* g, std::int64_t p, std::int64_t r0, std::int64_t r1) {
  return csr_gram(rp, ci, v, g, p, r0, r1);
}
extern "C" std::int64_t scm2cpp_csr_mm(int* rp, int* ci, double* v, double* b, double* c, std::int64_t n, std::int64_t k) {
  return csr_mm(rp, ci, v, b, c, n, k);
}
