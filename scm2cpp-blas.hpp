// The matrix products of the array algebra as cblas calls: what the
// ops of bindings/cblas-binding.scm expand to under --blas.
//
// A "p x n matrix" here is a flat row-major container of p*n doubles
// (row k at x[k*n .. k*n+n)), the layout the kernels use; the
// containers are any with operator[] over contiguous storage
// (std::vector, boost::array).  Link with -lopenblas or another cblas.
#ifndef SCM2CPP_BLAS_HPP
#define SCM2CPP_BLAS_HPP

#include <cblas.h>

namespace scm2cpp {

// g = x x^T   (g p x p, x p x n): the upper triangle by dsyrk, mirrored.
template <class G, class X>
inline void blas_gram(G& g, const X& x, int p, int n) {
  cblas_dsyrk(CblasRowMajor, CblasUpper, CblasNoTrans, p, n,
              1.0, &x[0], n, 0.0, &g[0], p);
  for (int i = 1; i < p; ++i)
    for (int j = 0; j < i; ++j)
      g[i * p + j] = g[j * p + i];
}

// c = x v   (c p, x p x n, v n)
template <class C, class X, class V>
inline void blas_gemv(C& c, const X& x, const V& v, int p, int n) {
  cblas_dgemv(CblasRowMajor, CblasNoTrans, p, n,
              1.0, &x[0], n, &v[0], 1, 0.0, &c[0], 1);
}

// r += alpha x^T d   (r n, x p x n, d p)
template <class R, class X, class D>
inline void blas_gemv_t_add(R& r, const X& x, const D& d, double alpha,
                            int p, int n) {
  cblas_dgemv(CblasRowMajor, CblasTrans, p, n,
              alpha, &x[0], n, &d[0], 1, 1.0, &r[0], 1);
}

// g = a b^T   (g p x q, a p x n, b q x n)
template <class G, class A, class B>
inline void blas_gemm_nt(G& g, const A& a, const B& b, int p, int q, int n) {
  cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasTrans, p, q, n,
              1.0, &a[0], n, &b[0], n, 0.0, &g[0], q);
}

// g = a b   (g p x q, a p x n, b n x q)
template <class G, class A, class B>
inline void blas_gemm_nn(G& g, const A& a, const B& b, int p, int q, int n) {
  cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, p, q, n,
              1.0, &a[0], n, &b[0], q, 0.0, &g[0], q);
}

// r += alpha d^T x   (r q x n, d p x q, x p x n)
template <class R, class D, class X>
inline void blas_gemm_tn_add(R& r, const D& d, const X& x, double alpha,
                             int p, int q, int n) {
  cblas_dgemm(CblasRowMajor, CblasTrans, CblasNoTrans, q, n, p,
              alpha, &d[0], q, &x[0], n, 1.0, &r[0], n);
}

}  // namespace scm2cpp

#endif
