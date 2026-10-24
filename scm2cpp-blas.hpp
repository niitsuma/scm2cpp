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

// SCM2CPP_MKL: Intel MKL's names for the same two interfaces (the
// package's setup.py defines it when it links MKL)
// MSVC's C++ has no C99 _Complex, which lapack.h falls back to; it
// takes std::complex when lapack_complex_* are defined first (nothing
// here calls a complex routine, so their layout never matters)
#if defined(_MSC_VER) && !defined(lapack_complex_float)
#include <complex>
#define lapack_complex_float std::complex<float>
#define lapack_complex_double std::complex<double>
#endif
#ifdef SCM2CPP_MKL
#include <mkl_cblas.h>
#include <mkl_lapacke.h>
#else
#include <cblas.h>
#include <lapacke.h>
#endif
#include <cstddef>
#include <vector>

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

// The symmetric eigenproblem as sym-eigen.scm states it: A (m x m,
// symmetric, row-major) is destroyed, V gets the eigenvectors as
// columns (V[j m + c] is entry j of vector c), EV the eigenvalues
// (ascending here; the callers order them themselves).  dsyevd, the
// divide and conquer that numpy's eigh runs, leaves the vectors in A
// in exactly that layout.  Returns 0, or LAPACK's info.
template <class A, class V, class E>
inline int lapack_syevd(A& a, V& v, E& ev, int m) {
  int info = LAPACKE_dsyevd(LAPACK_ROW_MAJOR, 'V', 'U', m, &a[0], m, &ev[0]);
  for (std::size_t t = 0; t < (std::size_t)m * m; ++t) v[t] = a[t];
  return info;
}

// The K largest eigenpairs as sym-eigen.scm's sym-eigen-top states
// them: A (m x m) destroyed, EV the values in decreasing order, V (m x
// K) the vectors as columns.  dsyevr over the index range m-K+1..m (what
// scipy's eigh with subset_by_index runs), which gives them increasing;
// reversed here.  Returns LAPACK's info.
template <class A, class V, class E>
inline int lapack_syevr_top(A& a, V& v, E& ev, int m, int k) {
  if (k <= 0) return 0;
  std::vector<double> w(m), z((std::size_t)m * k);
  std::vector<lapack_int> isuppz(2 * (std::size_t)k);
  lapack_int found = 0;
  int info = LAPACKE_dsyevr(LAPACK_ROW_MAJOR, 'V', 'I', 'U', m, &a[0], m, 0.0, 0.0,
                            m - k + 1, m, 0.0, &found, w.data(), z.data(), k, isuppz.data());
  for (int c = 0; c < k; ++c) {
    ev[c] = w[k - 1 - c];
    for (int j = 0; j < m; ++j) v[(std::size_t)j * k + c] = z[(std::size_t)j * k + (k - 1 - c)];
  }
  return info;
}

// The thin SVD as sym-svd.scm states it: A (m x n, row-major) is
// destroyed, S gets the k = min(m, n) values in decreasing order, U the
// m x k left vectors, VT the k x n right ones.  dgesdd, the divide and
// conquer that numpy's svd runs, with jobz 'S'.  Returns LAPACK's info.
template <class A, class U, class S, class VT>
inline int lapack_gesdd(A& a, U& u, S& s, VT& vt, int m, int n) {
  int k = m < n ? m : n;
  return LAPACKE_dgesdd(LAPACK_ROW_MAJOR, 'S', m, n, &a[0], n, &s[0], &u[0], k, &vt[0], n);
}

}  // namespace scm2cpp

#endif
