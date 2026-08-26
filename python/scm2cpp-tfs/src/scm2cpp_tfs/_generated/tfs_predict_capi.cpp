// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libtfs_predict.so tfs_predict_capi.cpp
#include "tfs_predict.hpp"
#include <vector>
#include <algorithm>

extern "C" int scm2cpp_tfs_predict(double* ps, double* beta, double* yhat, int nobs, int wmax, int p) {
  return tfs_predict(ps, beta, yhat, nobs, wmax, p);
}
