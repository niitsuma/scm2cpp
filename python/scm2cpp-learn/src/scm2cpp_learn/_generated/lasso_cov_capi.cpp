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
extern "C" int scm2cpp_cov_descend(double* g, double* c, double* beta, double lam, int iters, double nobs, int p) {
  return cov_descend(g, c, beta, lam, iters, nobs, p);
}
extern "C" int scm2cpp_enet_descend(double* g, double* c, double* beta, double lam1, double lam2, int iters, double nobs, int p) {
  return enet_descend(g, c, beta, lam1, lam2, iters, nobs, p);
}
extern "C" int scm2cpp_mt_descend(double* g, double* c, double* w, double lam1, double lam2, int iters, double nobs, int p, int ntask) {
  return mt_descend(g, c, w, lam1, lam2, iters, nobs, p, ntask);
}
