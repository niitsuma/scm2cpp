// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o liblasso_design.so lasso_design_capi.cpp
#include "lasso_design.hpp"
#include <vector>
#include <algorithm>

extern "C" double scm2cpp_soft_threshold(double z, double g) {
  return soft_threshold(z, g);
}
extern "C" int scm2cpp_lasso_design(double* x, double* y, double* resid, double* xnorm, double* beta, double* lams, double* betas, int iters, double tol, int n, int p, int nlam) {
  return lasso_design(x, y, resid, xnorm, beta, lams, betas, iters, tol, n, p, nlam);
}
