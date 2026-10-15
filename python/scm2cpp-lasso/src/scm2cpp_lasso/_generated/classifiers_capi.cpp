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

extern "C" int scm2cpp_svm_liblinear(double* x, double* y, double* w, double* alpha, double* xnorm, double cost, int iters, double tol, int seed, int n, int p) {
  return svm_liblinear(x, y, w, alpha, xnorm, cost, iters, tol, seed, n, p);
}
extern "C" int scm2cpp_svm_smo(double* k, double* y, double* alpha, double* rho, double cost, int iters, double eps, int n) {
  return svm_smo(k, y, alpha, rho, cost, iters, eps, n);
}
extern "C" int scm2cpp_shrinkable_P(double* yy, double* a, double* g, double cost, double gmax1, double gmax2, int t) {
  return shrinkable_P(yy, a, g, cost, gmax1, gmax2, t);
}
extern "C" int scm2cpp_swap_position(int* index, double* yy, double* a, double* g, double* gbar, double* qd, int s, int t) {
  return swap_position(index, yy, a, g, gbar, qd, s, t);
}
extern "C" int scm2cpp_reconstruct_gradient(double* k, int* index, double* yy, double* a, double* g, double* gbar, double cost, int active, int n) {
  return reconstruct_gradient(k, index, yy, a, g, gbar, cost, active, n);
}
extern "C" int scm2cpp_select_working_set(double* k, int* index, double* yy, double* a, double* g, double* qd, double cost, double eps, int active, int n, int* wi) {
  return select_working_set(k, index, yy, a, g, qd, cost, eps, active, n, *reinterpret_cast<std::array<int,2>*>(wi));
}
extern "C" int scm2cpp_logistic_l1(double* x, double* y, double* w, double cost, double tol, int maxnewton, int seed, int n, int p) {
  return logistic_l1(x, y, w, cost, tol, maxnewton, seed, n, p);
}
