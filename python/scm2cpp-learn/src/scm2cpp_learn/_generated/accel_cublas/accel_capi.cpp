// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libaccel.so accel_capi.cpp
#include "accel.hpp"
#include <vector>
#include <algorithm>

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
extern "C" std::int64_t scm2cpp_sym_eigen_top(double* a, double* v, double* ev, double* e, std::int64_t m, std::int64_t k) {
  return sym_eigen_top(a, v, ev, e, m, k);
}
extern "C" std::int64_t scm2cpp_sym_eigen_gen(double* a, double* b, double* v, double* ev, double* e, std::int64_t m) {
  return sym_eigen_gen(a, b, v, ev, e, m);
}
extern "C" std::int64_t scm2cpp_pca(double* x, double* comps, double* ev, double* sv, double* mean, std::int64_t n, std::int64_t p) {
  return pca(x, comps, ev, sv, mean, n, p);
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
