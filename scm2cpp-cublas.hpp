// The contractions of the array algebra as cuBLAS calls: what the
// ops of bindings/cublas-binding.scm expand to under --cublas.
//
// The matrix operand of every product is a device_matrix, the copy
// of a row-major p x n host matrix that dmat_upload takes once at the
// entry of the scope using it; the vector operands are host
// containers, copied over per call and the result copied back.  A
// row-major p x n host matrix is the column-major n x p matrix cuBLAS
// reads (leading dimension n), so nothing is ever transposed in
// memory.  The one cuBLAS handle is created on first use.
// Compile with -I<cuda>/include, link with -lcublas -lcudart.
#ifndef SCM2CPP_CUBLAS_HPP
#define SCM2CPP_CUBLAS_HPP

#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <memory>

namespace scm2cpp {

inline void cuda_check(cudaError_t e, const char* what) {
  if (e != cudaSuccess) {
    std::fprintf(stderr, "scm2cpp-cublas: %s: %s\n", what, cudaGetErrorString(e));
    std::abort();
  }
}
inline void cublas_check(cublasStatus_t s, const char* what) {
  if (s != CUBLAS_STATUS_SUCCESS) {
    std::fprintf(stderr, "scm2cpp-cublas: %s: status %d\n", what, (int)s);
    std::abort();
  }
}

inline cublasHandle_t cublas_handle() {
  static cublasHandle_t h = 0;
  if (!h) cublas_check(cublasCreate(&h), "cublasCreate");
  return h;
}

// A device copy of len doubles, freed with the last handle to it.
struct device_buffer {
  std::shared_ptr<double> d;
  size_t len;
  device_buffer() : len(0) {}
  explicit device_buffer(size_t n) : len(n) {
    double* p = 0;
    cuda_check(cudaMalloc((void**)&p, n * sizeof(double)), "cudaMalloc");
    d.reset(p, cudaFree);
  }
  double* get() const { return d.get(); }
  template <class V>
  void upload(const V& v) {
    cuda_check(cudaMemcpy(get(), &v[0], len * sizeof(double), cudaMemcpyHostToDevice),
               "cudaMemcpy H2D");
  }
  template <class V>
  void download(V& v) const {
    cuda_check(cudaMemcpy(&v[0], get(), len * sizeof(double), cudaMemcpyDeviceToHost),
               "cudaMemcpy D2H");
  }
};

template <class V>
inline device_buffer to_device(const V& v, size_t n) {
  device_buffer b(n);
  b.upload(v);
  return b;
}

// A row-major p x n matrix on the device.
struct device_matrix {
  device_buffer buf;
  int p, n;
  device_matrix() : p(0), n(0) {}
  device_matrix(const device_buffer& b, int p_, int n_) : buf(b), p(p_), n(n_) {}
  double* get() const { return buf.get(); }
};

template <class X>
inline device_matrix dmat_upload(const X& x, int p, int n) {
  return device_matrix(to_device(x, (size_t)p * n), p, n);
}

// y (m x n host) = alpha op(a) op(b) + beta y, a and b on the device.
// A row-major m x n array is the column-major n x m array of the same
// buffer, so the row-major product is the column-major product of the
// operands swapped: C^T = op(b)^T op(a)^T.
template <class Y>
inline void blas_gemm(Y& y, const device_matrix& a, const device_matrix& b,
                      double alpha, double beta, int ta, int tb, int m, int n, int k) {
  device_buffer dy = beta != 0.0 ? to_device(y, (size_t)m * n)
                                 : device_buffer((size_t)m * n);
  cublas_check(cublasDgemm(cublas_handle(), tb ? CUBLAS_OP_T : CUBLAS_OP_N,
                           ta ? CUBLAS_OP_T : CUBLAS_OP_N, n, m, k,
                           &alpha, b.get(), tb ? k : n, a.get(), ta ? m : k,
                           &beta, dy.get(), n),
               "cublasDgemm");
  dy.download(y);
}

// y (m host) = alpha op(a) v + beta y   (a device, v k host)
template <class Y, class V>
inline void blas_gemv(Y& y, const device_matrix& a, const V& v, double alpha,
                      double beta, int ta, int m, int k) {
  device_buffer dv = to_device(v, k);
  device_buffer dy = beta != 0.0 ? to_device(y, m) : device_buffer(m);
  if (ta)
    cublas_check(cublasDgemv(cublas_handle(), CUBLAS_OP_N, m, k, &alpha, a.get(), m,
                             dv.get(), 1, &beta, dy.get(), 1), "cublasDgemv");
  else
    cublas_check(cublasDgemv(cublas_handle(), CUBLAS_OP_T, k, m, &alpha, a.get(), k,
                             dv.get(), 1, &beta, dy.get(), 1), "cublasDgemv");
  dy.download(y);
}

// y (m x m host) = alpha op(a) op(a)^T + beta y: one triangle by dsyrk
// over the column-major reading, the other mirrored on the host
template <class Y>
inline void blas_syrk(Y& y, const device_matrix& a, double alpha, double beta,
                      int ta, int m, int k) {
  device_buffer dy = beta != 0.0 ? to_device(y, (size_t)m * m)
                                 : device_buffer((size_t)m * m);
  cublas_check(cublasDsyrk(cublas_handle(), CUBLAS_FILL_MODE_UPPER,
                           ta ? CUBLAS_OP_N : CUBLAS_OP_T, m, k, &alpha, a.get(),
                           ta ? m : k, &beta, dy.get(), m),
               "cublasDsyrk");
  dy.download(y);
  for (int i = 0; i < m; ++i)
    for (int j = i + 1; j < m; ++j)
      y[i * m + j] = y[j * m + i];
}

}  // namespace scm2cpp

#endif
