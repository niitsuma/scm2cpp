// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libautocov.so autocov_capi.cpp
#include "autocov.hpp"
#include <vector>
#include <algorithm>

extern "C" int scm2cpp_autocov(double* x, double* r, int n, int p) {
  return autocov(x, r, n, p);
}
