// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o liblasso_cov.so lasso_cov_capi.cpp
#include "lasso_cov.hpp"
#include <vector>
#include <algorithm>

extern "C" double scm2cpp_soft_threshold(double z, double g) {
  return soft_threshold(z, g);
}
extern "C" int scm2cpp_build_S(double* ps, double* s, double* q, double* cs, int n, int nobs, int wmax) {
  return build_S(ps, s, q, cs, n, nobs, wmax);
}
extern "C" int scm2cpp_build_P(double* ps, double* y, double* pv, int nobs, int wmax) {
  return build_P(ps, y, pv, nobs, wmax);
}
extern "C" int scm2cpp_build_G(double* s, double* pv, double* g, double* c, int wmax, int p) {
  return build_G(s, pv, g, c, wmax, p);
}
extern "C" int scm2cpp_cov_descend(double* g, double* c, double* beta, double lam, int iters, double nobs, int p) {
  return cov_descend(g, c, beta, lam, iters, nobs, p);
}
