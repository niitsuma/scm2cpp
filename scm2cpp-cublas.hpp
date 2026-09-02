// The matrix products of the array algebra as cuBLAS calls: what the
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

// g = x x^T   (g p x p host, x p x n device): dsyrk over the
// column-major n x p reading, one triangle, mirrored on the host.
template <class G>
inline void blas_gram(G& g, const device_matrix& x, int p, int n) {
  const double one = 1.0, zero = 0.0;
  device_buffer dg((size_t)p * p);
  cublas_check(cublasDsyrk(cublas_handle(), CUBLAS_FILL_MODE_UPPER, CUBLAS_OP_T,
                           p, n, &one, x.get(), n, &zero, dg.get(), p),
               "cublasDsyrk");
  dg.download(g);
  for (int i = 0; i < p; ++i)
    for (int j = i + 1; j < p; ++j)
      g[i * p + j] = g[j * p + i];
}

// c = x v   (c p, x p x n device, v n)
template <class C, class V>
inline void blas_gemv(C& c, const device_matrix& x, const V& v, int p, int n) {
  const double one = 1.0, zero = 0.0;
  device_buffer dv = to_device(v, n), dc(p);
  cublas_check(cublasDgemv(cublas_handle(), CUBLAS_OP_T, n, p, &one, x.get(), n,
                           dv.get(), 1, &zero, dc.get(), 1),
               "cublasDgemv");
  dc.download(c);
}

// r += alpha x^T d   (r n, x p x n device, d p)
template <class R, class D>
inline void blas_gemv_t_add(R& r, const device_matrix& x, const D& d, double alpha,
                            int p, int n) {
  const double one = 1.0;
  device_buffer dd = to_device(d, p), dr = to_device(r, n);
  cublas_check(cublasDgemv(cublas_handle(), CUBLAS_OP_N, n, p, &alpha, x.get(), n,
                           dd.get(), 1, &one, dr.get(), 1),
               "cublasDgemv");
  dr.download(r);
}

// g = a b^T   (g p x q, a p x n device, b q x n device)
template <class G>
inline void blas_gemm_nt(G& g, const device_matrix& a, const device_matrix& b,
                         int p, int q, int n) {
  const double one = 1.0, zero = 0.0;
  device_buffer dg((size_t)p * q);
  cublas_check(cublasDgemm(cublas_handle(), CUBLAS_OP_T, CUBLAS_OP_N, q, p, n,
                           &one, b.get(), n, a.get(), n, &zero, dg.get(), q),
               "cublasDgemm");
  dg.download(g);
}

// g = a b   (g p x q, a p x n device, b n x q device)
template <class G>
inline void blas_gemm_nn(G& g, const device_matrix& a, const device_matrix& b,
                         int p, int q, int n) {
  const double one = 1.0, zero = 0.0;
  device_buffer dg((size_t)p * q);
  cublas_check(cublasDgemm(cublas_handle(), CUBLAS_OP_N, CUBLAS_OP_N, q, p, n,
                           &one, b.get(), q, a.get(), n, &zero, dg.get(), q),
               "cublasDgemm");
  dg.download(g);
}

// r += alpha d^T x   (r q x n, d p x q host, x p x n device)
template <class R, class D>
inline void blas_gemm_tn_add(R& r, const D& d, const device_matrix& x, double alpha,
                             int p, int q, int n) {
  const double one = 1.0;
  device_buffer dd = to_device(d, (size_t)p * q), dr = to_device(r, (size_t)q * n);
  cublas_check(cublasDgemm(cublas_handle(), CUBLAS_OP_N, CUBLAS_OP_T, n, q, p,
                           &alpha, x.get(), n, dd.get(), q, &one, dr.get(), n),
               "cublasDgemm");
  dr.download(r);
}

}  // namespace scm2cpp

#endif
