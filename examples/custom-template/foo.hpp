// A user-supplied matrix class, standing in for any library the
// translator has never heard of. Not part of Scm2Cpp.
#ifndef FOO_HPP
#define FOO_HPP
#include <vector>
namespace foo {
  template<typename T> class Matrix {
    int r, c;
    std::vector<T> d;
  public:
    Matrix(int rr, int cc) : r(rr), c(cc), d(rr*cc, T(0)) {}
    T at(int i, int j) const { return d[i*c+j]; }
    void set(int i, int j, T v) { d[i*c+j] = v; }
    int rows() const { return r; }
    int cols() const { return c; }
  };
}
#endif
