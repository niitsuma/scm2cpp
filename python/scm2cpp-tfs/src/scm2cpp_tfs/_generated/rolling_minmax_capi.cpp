// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o librolling_minmax.so rolling_minmax_capi.cpp
#include "rolling_minmax.hpp"
#include <vector>
#include <algorithm>

extern "C" int scm2cpp_rolling_min(double* x, int* q, double* out, int n, int w) {
  return rolling_min(x, q, out, n, w);
}
extern "C" int scm2cpp_rolling_max(double* x, int* q, double* out, int n, int w) {
  return rolling_max(x, q, out, n, w);
}
