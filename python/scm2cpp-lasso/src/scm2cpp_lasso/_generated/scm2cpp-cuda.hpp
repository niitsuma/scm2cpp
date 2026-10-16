// The device back end of --cuda: arrays that live on the device across
// statements, the kernels the translator emits for parallel loops, and
// the products of the array algebra on those device arrays.
//
// Every host array a device statement touches gets a mirror: a device
// buffer of the same length and two flags, host_ok and dev_ok, saying
// which side holds the current values.  The translator brackets each
// statement:
//
//   a device statement (a kernel launch, a product) takes dev(v) for
//   every array it uses -- uploading only when dev_ok is false -- and
//   marks the arrays it writes with wrote_dev(v) (host_ok false);
//
//   a host statement first calls need_host(v) for the arrays it uses --
//   downloading only when host_ok is false -- and then wrote_host(v) for
//   the arrays it may write (dev_ok false).
//
// So an array the host never touches between device statements stays on
// the device, and one only the host uses never goes there.  A fresh
// allocation calls fresh(v), which drops a mirror left at the same
// address by an array that no longer exists.  end_call() -- at the
// return of every extern "C" entry -- forgets what the host has not
// seen and frees every mirror; the caller may change its arrays before
// the next call, and nothing survives it.  (The wrapper first brings back
// the caller's arrays with need_host; end_call itself copies nothing.)
//
// Compile with nvcc; link with -lcublas.
#ifndef SCM2CPP_CUDA_HPP
#define SCM2CPP_CUDA_HPP

#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <type_traits>
#include <unordered_map>

namespace scm2cpp {
namespace cu {

inline void check(cudaError_t e, const char* what) {
  if (e != cudaSuccess) {
    std::fprintf(stderr, "scm2cpp-cuda: %s: %s\n", what, cudaGetErrorString(e));
    std::abort();
  }
}
inline void check_blas(cublasStatus_t s, const char* what) {
  if (s != CUBLAS_STATUS_SUCCESS) {
    std::fprintf(stderr, "scm2cpp-cuda: %s: status %d\n", what, (int)s);
    std::abort();
  }
}

// SCM2CPP_CUDA_DEBUG=1: every launch synchronised and checked, every
// transfer reported, on stderr
inline bool debug() {
  static int d = -1;
  if (d < 0) d = std::getenv("SCM2CPP_CUDA_DEBUG") ? 1 : 0;
  return d == 1;
}

inline cublasHandle_t handle() {
  static cublasHandle_t h = 0;
  if (!h) check_blas(cublasCreate(&h), "cublasCreate");
  return h;
}

struct mirror {
  void* d;
  size_t bytes;
  bool host_ok, dev_ok;
};

inline std::unordered_map<const void*, mirror>& registry() {
  static std::unordered_map<const void*, mirror> r;
  return r;
}

// Containers are anything with data() and size(); a scalar takes the
// no-op overloads, so the translator may pass every variable a statement
// mentions without knowing which are arrays.
template <class V, class = void>
struct is_array : std::false_type {};
template <class V>
struct is_array<V, std::void_t<decltype(std::declval<V&>().data()),
                               decltype(std::declval<V&>().size())>> : std::true_type {};

template <class V>
inline mirror& entry(V& v) {
  const void* key = (const void*)v.data();
  auto& r = registry();
  auto it = r.find(key);
  size_t bytes = v.size() * sizeof(*v.data());
  if (it != r.end() && it->second.bytes == bytes) return it->second;
  if (it != r.end()) {
    cudaFree(it->second.d);
    r.erase(it);
  }
  mirror m{nullptr, bytes, true, false};
  if (bytes) check(cudaMalloc(&m.d, bytes), "cudaMalloc");
  return r.emplace(key, m).first->second;
}

template <class V>
inline auto dev(V& v) -> typename std::remove_reference<decltype(*v.data())>::type* {
  typedef typename std::remove_reference<decltype(*v.data())>::type T;
  mirror& m = entry(v);
  if (!m.dev_ok) {
    if (debug()) std::fprintf(stderr, "cu: upload %p %zu bytes\n", (const void*)v.data(), m.bytes);
    if (m.bytes)
      check(cudaMemcpy(m.d, (const void*)v.data(), m.bytes, cudaMemcpyHostToDevice), "upload");
    m.dev_ok = true;
  }
  return (T*)m.d;
}

template <class V>
inline void wrote_dev(V& v) {
  mirror& m = entry(v);
  m.dev_ok = true;
  m.host_ok = false;
}

template <class V>
inline typename std::enable_if<is_array<V>::value>::type need_host(V& v) {
  auto& r = registry();
  auto it = r.find((const void*)v.data());
  if (it == r.end() || it->second.host_ok) return;
  if (debug()) std::fprintf(stderr, "cu: download %p %zu bytes (span %zu)\n", (const void*)v.data(), it->second.bytes, v.size() * sizeof(*v.data()));
  check(cudaMemcpy((void*)v.data(), it->second.d, it->second.bytes, cudaMemcpyDeviceToHost),
        "download");
  it->second.host_ok = true;
}
template <class V>
inline typename std::enable_if<!is_array<V>::value>::type need_host(const V&) {}

template <class V>
inline typename std::enable_if<is_array<V>::value>::type wrote_host(V& v) {
  auto& r = registry();
  auto it = r.find((const void*)v.data());
  if (it == r.end()) return;
  it->second.dev_ok = false;
  it->second.host_ok = true;
}
template <class V>
inline typename std::enable_if<!is_array<V>::value>::type wrote_host(const V&) {}

template <class V>
inline void fresh(V& v) {
  auto& r = registry();
  auto it = r.find((const void*)v.data());
  if (it == r.end()) return;
  cudaFree(it->second.d);
  r.erase(it);
}

// Every mirror goes, nothing copied back: the end of one extern "C" call,
// after the wrapper has called need_host on the caller's own arrays (the
// other mirrors belong to arrays that no longer exist, and copying into
// them would write freed memory).
inline void end_call() {
  auto& r = registry();
  for (auto& kv : r) cudaFree(kv.second.d);
  r.clear();
}

// The sums the kernels' reductions add into: K doubles on the device,
// zeroed before a launch and read back after it.
inline double* reduction_slots(int k) {
  static double* d = nullptr;
  static int cap = 0;
  if (k > cap) {
    if (d) cudaFree(d);
    check(cudaMalloc(&d, k * sizeof(double)), "cudaMalloc reduction");
    cap = k;
  }
  check(cudaMemset(d, 0, k * sizeof(double)), "cudaMemset reduction");
  return d;
}
inline double reduction_value(const double* d, int i) {
  double v;
  check(cudaMemcpy(&v, d + i, sizeof(double), cudaMemcpyDeviceToHost), "reduction read");
  return v;
}

// The reductions' atomic sum: the hardware's on sm_60 and later, a
// compare-and-swap loop before that (nvcc's default target is older).
__device__ inline double atomic_add(double* a, double v) {
#if !defined(__CUDA_ARCH__) || __CUDA_ARCH__ >= 600
  return atomicAdd(a, v);
#else
  unsigned long long* p = (unsigned long long*)a;
  unsigned long long old = *p, assumed;
  do {
    assumed = old;
    old = atomicCAS(p, assumed, __double_as_longlong(v + __longlong_as_double(assumed)));
  } while (assumed != old);
  return __longlong_as_double(old);
#endif
}

inline void launched(const char* what) {
  check(cudaGetLastError(), what);
  if (debug()) {
    check(cudaDeviceSynchronize(), what);
    std::fprintf(stderr, "cu: ran %s\n", what);
  }
}

// Below this many iterations a parallel loop runs on the host (the launch
// and the transfer it may force cost more than the loop); SCM2CPP_CUDA_MIN
// overrides it.
inline long min_trip() {
  static long m = -1;
  if (m < 0) {
    const char* s = std::getenv("SCM2CPP_CUDA_MIN");
    m = s ? std::atol(s) : 4096;
  }
  return m;
}

// The products, on device arrays: the same signatures as the cblas back
// end (scm2cpp-blas.hpp), every operand through dev(), the result marked.
template <class Y, class A, class B>
inline void blas_gemm(Y& y, A& a, B& b, double alpha, double beta, int ta, int tb, int m,
                      int n, int k) {
  double* dy = beta != 0.0 ? dev(y) : (wrote_dev(y), (double*)entry(y).d);
  check_blas(cublasDgemm(handle(), tb ? CUBLAS_OP_T : CUBLAS_OP_N, ta ? CUBLAS_OP_T : CUBLAS_OP_N,
                         n, m, k, &alpha, dev(b), tb ? k : n, dev(a), ta ? m : k, &beta, dy, n),
             "cublasDgemm");
  wrote_dev(y);
}

template <class Y, class A, class B>
inline void blas_gemm_batched(Y& y, A& a, B& b, double alpha, double beta, int ta, int tb,
                              int m, int n, int k, int batch) {
  double* dy = beta != 0.0 ? dev(y) : (wrote_dev(y), (double*)entry(y).d);
  check_blas(cublasDgemmStridedBatched(
                 handle(), tb ? CUBLAS_OP_T : CUBLAS_OP_N, ta ? CUBLAS_OP_T : CUBLAS_OP_N, n, m,
                 k, &alpha, dev(b), tb ? k : n, (long long)k * n, dev(a), ta ? m : k,
                 (long long)m * k, &beta, dy, n, (long long)m * n, batch),
             "cublasDgemmStridedBatched");
  wrote_dev(y);
}

template <class Y, class A, class V>
inline void blas_gemv(Y& y, A& a, V& v, double alpha, double beta, int ta, int m, int k) {
  double* dy = beta != 0.0 ? dev(y) : (wrote_dev(y), (double*)entry(y).d);
  if (ta)
    check_blas(cublasDgemv(handle(), CUBLAS_OP_N, m, k, &alpha, dev(a), m, dev(v), 1, &beta, dy,
                           1),
               "cublasDgemv");
  else
    check_blas(cublasDgemv(handle(), CUBLAS_OP_T, k, m, &alpha, dev(a), k, dev(v), 1, &beta, dy,
                           1),
               "cublasDgemv");
  wrote_dev(y);
}

// the row-major upper triangle from the lower one dsyrk wrote (a template
// so that the header may be included from several translation units)
template <int = 0>
__global__ void mirror_upper(double* y, int m) {
  int i = blockIdx.y, j = blockIdx.x * blockDim.x + threadIdx.x;
  if (j < m && j > i) y[i * m + j] = y[j * m + i];
}

// y (m x m) = alpha op(a) op(a)^T + beta y: dsyrk fills one triangle of
// the column-major reading, a kernel mirrors it, all on the device.
template <class Y, class A>
inline void blas_syrk(Y& y, A& a, double alpha, double beta, int ta, int m, int k) {
  double* dy = beta != 0.0 ? dev(y) : (wrote_dev(y), (double*)entry(y).d);
  check_blas(cublasDsyrk(handle(), CUBLAS_FILL_MODE_UPPER, ta ? CUBLAS_OP_N : CUBLAS_OP_T, m, k,
                         &alpha, dev(a), ta ? m : k, &beta, dy, m),
             "cublasDsyrk");
  dim3 grid((m + 255) / 256, m);
  mirror_upper<<<grid, 256>>>(dy, m);
  launched("mirror_upper");
  wrote_dev(y);
}

}  // namespace cu
}  // namespace scm2cpp

#endif
