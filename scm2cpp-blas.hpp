// The contractions of the array algebra as cblas calls: what the ops
// of bindings/cblas-binding.scm expand to under --blas.
//
// Every array is a flat row-major container of doubles (std::vector,
// boost::array, anything with operator[] over contiguous storage).
// A contraction whose summed axes sit at the front or the back of
// each operand is one dgemm over the matrices the other axes flatten
// to: ta says the left operand is stored k x m (op(a) = a^T) rather
// than m x k, tb that the right one is stored n x k rather than k x n.
// Link with -lopenblas or another cblas.
#ifndef SCM2CPP_BLAS_HPP
#define SCM2CPP_BLAS_HPP

#include <cblas.h>

namespace scm2cpp {

// y (m x n) = alpha op(a) op(b) + beta y.  A product whose m or n is 1
// at run time (one class of a logistic regression, say) is a dgemv: the
// vector operand is contiguous either way, and OpenBLAS's dgemm with a
// unit dimension costs a third more than its dgemv.
template <class Y, class A, class B>
inline void blas_gemm(Y& y, const A& a, const B& b, double alpha, double beta,
                      int ta, int tb, int m, int n, int k) {
  if (n == 1)
    cblas_dgemv(CblasRowMajor, ta ? CblasTrans : CblasNoTrans, ta ? k : m, ta ? m : k,
                alpha, &a[0], ta ? m : k, &b[0], 1, beta, &y[0], 1);
  else if (m == 1)
    cblas_dgemv(CblasRowMajor, tb ? CblasNoTrans : CblasTrans, tb ? n : k, tb ? k : n,
                alpha, &b[0], tb ? k : n, &a[0], 1, beta, &y[0], 1);
  else
    cblas_dgemm(CblasRowMajor, ta ? CblasTrans : CblasNoTrans,
                tb ? CblasTrans : CblasNoTrans, m, n, k,
                alpha, &a[0], ta ? m : k, &b[0], tb ? k : n, beta, &y[0], n);
}

// y (m) = alpha op(a) v + beta y   (v k)
template <class Y, class A, class V>
inline void blas_gemv(Y& y, const A& a, const V& v, double alpha, double beta,
                      int ta, int m, int k) {
  if (ta)
    cblas_dgemv(CblasRowMajor, CblasTrans, k, m, alpha, &a[0], m, &v[0], 1,
                beta, &y[0], 1);
  else
    cblas_dgemv(CblasRowMajor, CblasNoTrans, m, k, alpha, &a[0], k, &v[0], 1,
                beta, &y[0], 1);
}

// batch slabs of the same: y[l] (m x n) = alpha op(a[l]) op(b[l]) +
// beta y[l] for l below batch, the slabs contiguous (strides m*k,
// k*n, m*n): a contraction whose leading labels are shared by both
// operands and the result
template <class Y, class A, class B>
inline void blas_gemm_batched(Y& y, const A& a, const B& b, double alpha, double beta,
                              int ta, int tb, int m, int n, int k, int batch) {
  for (int l = 0; l < batch; ++l)
    cblas_dgemm(CblasRowMajor, ta ? CblasTrans : CblasNoTrans,
                tb ? CblasTrans : CblasNoTrans, m, n, k,
                alpha, &a[(size_t)l * m * k], ta ? m : k,
                &b[(size_t)l * k * n], tb ? k : n, beta, &y[(size_t)l * m * n], n);
}

// y (m x m) = alpha op(a) op(a)^T + beta y: the Gram matrix, one
// triangle by dsyrk and the other mirrored
template <class Y, class A>
inline void blas_syrk(Y& y, const A& a, double alpha, double beta, int ta,
                      int m, int k) {
  cblas_dsyrk(CblasRowMajor, CblasUpper, ta ? CblasTrans : CblasNoTrans, m, k,
              alpha, &a[0], ta ? m : k, beta, &y[0], m);
  for (int i = 1; i < m; ++i)
    for (int j = 0; j < i; ++j)
      y[i * m + j] = y[j * m + i];
}

}  // namespace scm2cpp

#endif
