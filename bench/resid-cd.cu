// Residual-form lasso coordinate descent on one GPU, for
// bench/lasso-memory-compare.py.  This is the algorithm of
// examples/kernel-only/lasso-kernel.scm -- no Gram matrix, X is read
// twice per coordinate -- with the two length-n loops of a coordinate
// step (the dot product and the residual update) spread over the whole
// grid.  Coordinate descent is sequential across coordinates, so every
// step ends in a grid-wide barrier: two per coordinate, and that
// barrier is the cost the CPU never pays.
//
// Not translator output.  It exists to measure what CUDA can buy the
// memory-lean form, nothing more.
//
//   nvcc -O3 -std=c++17 -shared -Xcompiler -fPIC -o libresid_cd.so resid-cd.cu
#include <cuda_runtime.h>
#include <cooperative_groups.h>

namespace cg = cooperative_groups;

__device__ __forceinline__ double soft_threshold(double z, double g) {
  if (z > g) return z - g;
  if (z < -g) return z + g;
  return 0.0;
}

__global__ void resid_cd_kernel(const double* x, double* beta,
                                double* resid, const double* xnorm,
                                double lam, int iters, int n, int p,
                                double* partial) {
  cg::grid_group grid = cg::this_grid();
  __shared__ double sh[32];
  const int tid = threadIdx.x, lane = tid & 31, wid = tid >> 5;
  const int nwarp = blockDim.x >> 5;
  const int gsize = gridDim.x * blockDim.x;
  const int gtid = blockIdx.x * blockDim.x + tid;
  const double lamn = lam * (double)n;
  for (int sweep = 0; sweep < iters; ++sweep) {
    for (int j = 0; j < p; ++j) {
      const double* xj = x + (size_t)j * n;
      // read before the barrier: thread 0 overwrites beta[j] after it,
      // and a block that is late to read would see the new value as old
      const double old = beta[j];
      double acc = 0.0;
      for (int i = gtid; i < n; i += gsize) acc += xj[i] * resid[i];
      for (int o = 16; o > 0; o >>= 1)
        acc += __shfl_down_sync(0xffffffffu, acc, o);
      if (lane == 0) sh[wid] = acc;
      __syncthreads();
      if (wid == 0) {
        acc = (lane < nwarp) ? sh[lane] : 0.0;
        for (int o = 16; o > 0; o >>= 1)
          acc += __shfl_down_sync(0xffffffffu, acc, o);
        if (tid == 0) partial[blockIdx.x] = acc;
      }
      grid.sync();
      double rho = 0.0;
      for (int b = 0; b < (int)gridDim.x; ++b) rho += partial[b];
      rho += old * xnorm[j];
      const double bnew = soft_threshold(rho, lamn) / xnorm[j];
      const double d = bnew - old;
      if (gtid == 0) beta[j] = bnew;
      if (d != 0.0)
        for (int i = gtid; i < n; i += gsize) resid[i] -= xj[i] * d;
      grid.sync();
    }
  }
}

struct resid_cd_ctx {
  double* x;
  double* xnorm;
  double* beta;
  double* resid;
  double* partial;
  int n, p, blocks, threads;
};

// Upload X once; the descent below reuses it across calls.  Returns
// NULL when there is no device or the cooperative launch is not
// available.
extern "C" resid_cd_ctx* resid_cd_new(const double* x, const double* xnorm,
                                      int n, int p) {
  int dev = 0, coop = 0, sms = 0;
  if (cudaGetDevice(&dev) != cudaSuccess) return 0;
  cudaDeviceGetAttribute(&coop, cudaDevAttrCooperativeLaunch, dev);
  cudaDeviceGetAttribute(&sms, cudaDevAttrMultiProcessorCount, dev);
  if (!coop) return 0;
  resid_cd_ctx* c = new resid_cd_ctx();
  c->n = n; c->p = p; c->threads = 256;
  int per_sm = 0;
  cudaOccupancyMaxActiveBlocksPerMultiprocessor(&per_sm, resid_cd_kernel,
                                                c->threads, 0);
  int want = (n + c->threads - 1) / c->threads;
  int cap = per_sm * sms;
  c->blocks = want < cap ? want : cap;
  if (c->blocks < 1) c->blocks = 1;
  size_t xs = (size_t)n * p * sizeof(double);
  if (cudaMalloc(&c->x, xs) != cudaSuccess ||
      cudaMalloc(&c->xnorm, p * sizeof(double)) != cudaSuccess ||
      cudaMalloc(&c->beta, p * sizeof(double)) != cudaSuccess ||
      cudaMalloc(&c->resid, n * sizeof(double)) != cudaSuccess ||
      cudaMalloc(&c->partial, c->blocks * sizeof(double)) != cudaSuccess) {
    delete c;
    return 0;
  }
  cudaMemcpy(c->x, x, xs, cudaMemcpyHostToDevice);
  cudaMemcpy(c->xnorm, xnorm, p * sizeof(double), cudaMemcpyHostToDevice);
  return c;
}

extern "C" int resid_cd_blocks(resid_cd_ctx* c) { return c ? c->blocks : 0; }

// beta and resid go in and come back, like the CPU kernel's.
extern "C" int resid_cd_run(resid_cd_ctx* c, double* beta, double* resid,
                            double lam, int iters) {
  cudaMemcpy(c->beta, beta, c->p * sizeof(double), cudaMemcpyHostToDevice);
  cudaMemcpy(c->resid, resid, c->n * sizeof(double), cudaMemcpyHostToDevice);
  void* args[] = {&c->x, &c->beta, &c->resid, &c->xnorm, &lam, &iters,
                  &c->n, &c->p, &c->partial};
  cudaError_t e = cudaLaunchCooperativeKernel(
      (void*)resid_cd_kernel, dim3(c->blocks), dim3(c->threads), args, 0, 0);
  if (e != cudaSuccess) return (int)e;
  e = cudaDeviceSynchronize();
  if (e != cudaSuccess) return (int)e;
  cudaMemcpy(beta, c->beta, c->p * sizeof(double), cudaMemcpyDeviceToHost);
  cudaMemcpy(resid, c->resid, c->n * sizeof(double), cudaMemcpyDeviceToHost);
  return 0;
}

extern "C" void resid_cd_free(resid_cd_ctx* c) {
  if (!c) return;
  cudaFree(c->x); cudaFree(c->xnorm); cudaFree(c->beta);
  cudaFree(c->resid); cudaFree(c->partial);
  delete c;
}
