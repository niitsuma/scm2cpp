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
extern "C" int scm2cpp_sym_eigen_top(double* a, double* v, double* ev, double* e, int m, int k) {
  return sym_eigen_top(a, v, ev, e, m, k);
}
extern "C" int scm2cpp_pca(double* x, double* comps, double* ev, double* sv, double* mean, int n, int p) {
  return pca(x, comps, ev, sv, mean, n, p);
}
extern "C" int scm2cpp_gram_xx(double* x, double* g, int n, int p) {
  return gram_xx(x, g, n, p);
}
extern "C" int scm2cpp_gram_xy(double* x, double* y, double* c, int n, int p, int q) {
  return gram_xy(x, y, c, n, p, q);
}
