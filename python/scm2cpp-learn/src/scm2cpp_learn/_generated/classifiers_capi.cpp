// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libclassifiers.so classifiers_capi.cpp
#include "classifiers.hpp"
#include <vector>
#include <algorithm>

extern "C" std::int64_t scm2cpp_svm_liblinear(double* x, double* y, double* w, double* alpha, double* xnorm, double cost, std::int64_t iters, double tol, std::int64_t seed, std::int64_t n, std::int64_t p) {
  return svm_liblinear(x, y, w, alpha, xnorm, cost, iters, tol, seed, n, p);
}
extern "C" std::int64_t scm2cpp_svm_smo(double* k, double* y, double* alpha, double* rho, double cost, std::int64_t iters, double eps, std::int64_t n) {
  return svm_smo(k, y, alpha, rho, cost, iters, eps, n);
}
extern "C" std::int64_t scm2cpp_smo_solve(double* k, double* y, double* lin, double* alpha, double* rho, double cost, std::int64_t iters, double eps, std::int64_t n, std::int64_t nk) {
  return smo_solve(k, y, lin, alpha, *reinterpret_cast<std::array<double,1>*>(rho), cost, iters, eps, n, nk);
}
extern "C" std::int64_t scm2cpp_shrinkable_P(double* yy, double* a, double* g, double cost, double gmax1, double gmax2, std::int64_t t) {
  return shrinkable_P(yy, a, g, cost, gmax1, gmax2, t);
}
extern "C" std::int64_t scm2cpp_swap_position(int* index, int* krow, double* pp, double* yy, double* a, double* g, double* gbar, double* qd, std::int64_t s, std::int64_t t) {
  return swap_position(index, krow, pp, yy, a, g, gbar, qd, s, t);
}
extern "C" std::int64_t scm2cpp_reconstruct_gradient(double* k, int* krow, double* pp, double* yy, double* a, double* g, double* gbar, double cost, std::int64_t active, std::int64_t n, std::int64_t nk) {
  return reconstruct_gradient(k, krow, pp, yy, a, g, gbar, cost, active, n, nk);
}
extern "C" std::int64_t scm2cpp_select_working_set(double* k, int* krow, double* yy, double* a, double* g, double* qd, double cost, double eps, std::int64_t active, std::int64_t nk, int* wi) {
  return select_working_set(k, krow, yy, a, g, qd, cost, eps, active, nk, *reinterpret_cast<std::array<int,2>*>(wi));
}
extern "C" std::int64_t scm2cpp_svr_smo(double* k, double* z, double* beta, double* rho, double cost, double epsilon, std::int64_t iters, double eps, std::int64_t n) {
  return svr_smo(k, z, beta, rho, cost, epsilon, iters, eps, n);
}
extern "C" std::int64_t scm2cpp_rbf_from_products(double* g, double* sa, double* sb, double gamma, std::int64_t na, std::int64_t nb) {
  return rbf_from_products(g, sa, sb, gamma, na, nb);
}
extern "C" std::int64_t scm2cpp_logistic_l1(double* x, double* y, double* w, double cost, double tol, std::int64_t maxnewton, std::int64_t seed, std::int64_t n, std::int64_t p) {
  return logistic_l1(x, y, w, cost, tol, maxnewton, seed, n, p);
}
extern "C" std::int64_t scm2cpp_svr_liblinear(double* x, double* y, double* w, double* beta, double* xnorm, double cost, double epsilon, std::int64_t iters, double tol, std::int64_t seed, std::int64_t n, std::int64_t p) {
  return svr_liblinear(x, y, w, beta, xnorm, cost, epsilon, iters, tol, seed, n, p);
}
extern "C" double scm2cpp_ols_rows(double* x, double* y, int* rows, std::int64_t m, double* w, double* g, double* c, double* l, double* z, double* xm, std::int64_t n, std::int64_t p) {
  return ols_rows(x, y, rows, m, w, g, c, l, z, xm, n, p);
}
extern "C" std::int64_t scm2cpp_ransac(double* x, double* y, int* subsets, double* coef, double* mask, double* out, double maxtrials, std::int64_t minsamples, double thresh, double stopprob, std::int64_t n, std::int64_t p) {
  return ransac(x, y, subsets, coef, mask, out, maxtrials, minsamples, thresh, stopprob, n, p);
}
extern "C" double scm2cpp_sgd_loss(std::int64_t loss, double y, double p, double epsilon) {
  return sgd_loss(loss, y, p, epsilon);
}
extern "C" double scm2cpp_sgd_grad(std::int64_t loss, double y, double p, double epsilon) {
  return sgd_grad(loss, y, p, epsilon);
}
extern "C" std::int64_t scm2cpp_sgd(double* x, double* y, double* w, double* out, std::int64_t loss, std::int64_t lr, std::int64_t pen, double alpha, double eta0, double powert, double epsilon, std::int64_t maxiter, double tol, std::int64_t niternochange, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  return sgd(x, y, w, out, loss, lr, pen, alpha, eta0, powert, epsilon, maxiter, tol, niternochange, fitint, n, p);
}
extern "C" double scm2cpp_sgd_min(double a, double b) {
  return sgd_min(a, b);
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
extern "C" std::int64_t scm2cpp_svm_l1(double* x, double* y, double* w, double cost, double tol, std::int64_t maxiter, std::int64_t seed, std::int64_t n, std::int64_t p) {
  return svm_l1(x, y, w, cost, tol, maxiter, seed, n, p);
}
extern "C" double scm2cpp_svm_l1_abs(double a) {
  return svm_l1_abs(a);
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
extern "C" std::int64_t scm2cpp_ts_minnorm(double* x, double* y, int* idx, double* w, double* aa, double* v, double* ev, double* e, double* ab, std::int64_t s, std::int64_t ns, std::int64_t fitint, std::int64_t p, std::int64_t d) {
  return ts_minnorm(x, y, idx, w, aa, v, ev, e, ab, s, ns, fitint, p, d);
}
extern "C" std::int64_t scm2cpp_ts_fit(double* x, double* y, int* idx, double* w, double* a, double* b, double* aa, double* v, double* ev, double* e, double* ab, std::int64_t s, std::int64_t ns, std::int64_t fitint, std::int64_t p, std::int64_t d) {
  return ts_fit(x, y, idx, w, a, b, aa, v, ev, e, ab, s, ns, fitint, p, d);
}
extern "C" double scm2cpp_ts_abs(double v) {
  return ts_abs(v);
}
extern "C" std::int64_t scm2cpp_theilsen(double* x, double* y, int* idx, double* w, double* coef, std::int64_t nsub, std::int64_t ns, std::int64_t fitint, std::int64_t maxiter, double tol, std::int64_t p) {
  return theilsen(x, y, idx, w, coef, nsub, ns, fitint, maxiter, tol, p);
}
