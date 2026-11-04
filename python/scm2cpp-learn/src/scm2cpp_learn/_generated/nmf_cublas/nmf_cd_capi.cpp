// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libnmf_cd.so nmf_cd_capi.cpp
#include "nmf_cd.hpp"
#include <vector>
#include <algorithm>

extern "C" double scm2cpp_nmf_half(double* x, double* w, double* ht, std::int64_t n, std::int64_t p, std::int64_t k) {
  return nmf_half(x, w, ht, n, p, k);
}
extern "C" std::int64_t scm2cpp_nmf(double* x, double* xt, double* w, double* ht, std::int64_t iters, double tol, std::int64_t n, std::int64_t p, std::int64_t k) {
  return nmf(x, xt, w, ht, iters, tol, n, p, k);
}
