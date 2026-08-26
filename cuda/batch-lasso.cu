// A batched lasso path on the GPU, over the translated covariance
// kernel -- the same generated functions the CPU suite runs, compiled
// by nvcc through the minimal runtime.  One thread owns one lambda:
// coordinate descent is sequential inside a problem, so the
// parallelism is across the batch, which is exactly the shape of a
// cross-validation grid.  Host and device run identical code; the
// comparison at the end is between the two executions of the same
// arithmetic.
//
//   nvcc -O2 -std=c++17 -I <repo> -I <dir-with-generated-hpp> \
//        batch-lasso.cu -o batch-lasso
//
// Sizes are compile-time macros so the suite can run a small instance
// and a benchmark a large one.

#include "lasso-cov.hpp"
#include <cstdio>
#include <chrono>
#include <cuda_runtime.h>

#ifndef LP
#define LP 200          // p = wmax: candidate windows
#endif
#ifndef LNOBS
#define LNOBS 1800
#endif
#ifndef LITERS
#define LITERS 50
#endif
#ifndef LBATCH
#define LBATCH 4096     // lambdas in flight, one thread each
#endif

#define LN (LP + LNOBS) // base series length

static void check(cudaError_t e, const char* what) {
  if (e != cudaSuccess) {
    std::fprintf(stderr, "%s: %s\n", what, cudaGetErrorString(e));
    std::exit(1);
  }
}

__global__ void batch_descend(const double* g, double* c, double* beta,
                              const double* lam, int iters, double nobs,
                              int p, int batch) {
  int t = blockIdx.x * blockDim.x + threadIdx.x;
  if (t < batch)
    cov_descend(scm2cpp::cspan<double>(g),
                scm2cpp::span<double>(c + (size_t)t * p),
                scm2cpp::span<double>(beta + (size_t)t * p),
                lam[t], iters, nobs, p);
}

int main() {
  const int p = LP, wmax = LP, nobs = LNOBS, n = LN, iters = LITERS;
  const int batch = LBATCH;

  // data: a bounded pseudo-random walk and its prefix sums
  std::vector<double> ps(n), y(nobs);
  {
    long seed = 98765; double acc = 0.0;
    for (int k = 0; k < n; ++k) {
      seed = (16807 * seed) % 2147483647L;
      acc += 10.0 * (double)seed / 2147483647.0;
      ps[k] = acc;
    }
    for (int r = 0; r < nobs; ++r) {
      int t = wmax + r;
      y[r] = 2.0 * (ps[t] - ps[t - 5]) / 5.0
           - 1.5 * (ps[t] - ps[t - 20]) / 20.0;
    }
  }

  // the shared problem: S, P, G, c through the translated builders
  std::vector<double> s((wmax + 1) * (wmax + 1)), q(n), cs(n + 1);
  std::vector<double> pv(wmax + 1), g((size_t)p * p), c0(p);
  build_S(ps, s, q, cs, n, nobs, wmax);
  build_P(ps, y, pv, nobs, wmax);
  build_G(s, pv, g, c0, wmax, p);

  // the lambda path, log-spaced
  std::vector<double> lam(batch);
  for (int t = 0; t < batch; ++t)
    lam[t] = 0.5 * std::pow(0.999, t);

  // per-thread state: every lambda starts from the same c, zero beta
  std::vector<double> c((size_t)batch * p), beta((size_t)batch * p, 0.0);
  for (int t = 0; t < batch; ++t)
    std::copy(c0.begin(), c0.end(), c.begin() + (size_t)t * p);

  // ---- CPU reference: the same batch, one core, same functions ----
  std::vector<double> c_ref(c), beta_ref(beta);
  auto t0 = std::chrono::steady_clock::now();
  for (int t = 0; t < batch; ++t)
    cov_descend(g, scm2cpp::span<double>(c_ref.data() + (size_t)t * p),
                scm2cpp::span<double>(beta_ref.data() + (size_t)t * p),
                lam[t], iters, (double)nobs, p);
  auto t1 = std::chrono::steady_clock::now();
  double cpu_s = std::chrono::duration<double>(t1 - t0).count();

  // ---- GPU: one thread per lambda ----
  double *dg, *dc, *dbeta, *dlam;
  check(cudaMalloc(&dg, g.size() * 8), "malloc g");
  check(cudaMalloc(&dc, c.size() * 8), "malloc c");
  check(cudaMalloc(&dbeta, beta.size() * 8), "malloc beta");
  check(cudaMalloc(&dlam, lam.size() * 8), "malloc lam");
  check(cudaMemcpy(dg, g.data(), g.size() * 8, cudaMemcpyHostToDevice), "cp g");
  check(cudaMemcpy(dc, c.data(), c.size() * 8, cudaMemcpyHostToDevice), "cp c");
  check(cudaMemcpy(dbeta, beta.data(), beta.size() * 8,
                   cudaMemcpyHostToDevice), "cp beta");
  check(cudaMemcpy(dlam, lam.data(), lam.size() * 8,
                   cudaMemcpyHostToDevice), "cp lam");

  batch_descend<<<(batch + 127) / 128, 128>>>(dg, dc, dbeta, dlam,
                                              iters, (double)nobs, p, batch);
  check(cudaDeviceSynchronize(), "warmup");
  check(cudaMemcpy(dc, c.data(), c.size() * 8, cudaMemcpyHostToDevice), "re c");
  check(cudaMemcpy(dbeta, beta.data(), beta.size() * 8,
                   cudaMemcpyHostToDevice), "re beta");

  auto t2 = std::chrono::steady_clock::now();
  batch_descend<<<(batch + 127) / 128, 128>>>(dg, dc, dbeta, dlam,
                                              iters, (double)nobs, p, batch);
  check(cudaDeviceSynchronize(), "kernel");
  auto t3 = std::chrono::steady_clock::now();
  double gpu_s = std::chrono::duration<double>(t3 - t2).count();

  std::vector<double> beta_gpu(beta.size());
  check(cudaMemcpy(beta_gpu.data(), dbeta, beta.size() * 8,
                   cudaMemcpyDeviceToHost), "cp back");

  double maxdiff = 0.0;
  for (size_t i = 0; i < beta_gpu.size(); ++i) {
    double d = std::abs(beta_gpu[i] - beta_ref[i]);
    if (d > maxdiff) maxdiff = d;
  }
  int nz = 0;
  for (size_t i = 0; i < beta_gpu.size(); ++i)
    if (std::abs(beta_gpu[i]) > 1e-9) ++nz;

  std::printf("batch=%d p=%d iters=%d  cpu(1core)=%.3fs  gpu=%.3fs  "
              "speedup=%.1fx  maxdiff=%.3g  nonzeros=%d\n",
              batch, p, iters, cpu_s, gpu_s, cpu_s / gpu_s, maxdiff, nz);
  if (maxdiff > 1e-9) { std::printf("FAIL: divergence\n"); return 1; }
  std::printf("PASS\n");
  return 0;
}
