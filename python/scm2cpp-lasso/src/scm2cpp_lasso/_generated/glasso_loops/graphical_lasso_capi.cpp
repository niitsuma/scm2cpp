// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libgraphical_lasso.so graphical_lasso_capi.cpp
#include "graphical_lasso.hpp"
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
