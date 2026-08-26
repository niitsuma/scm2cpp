// The GPU entry point the packages expose: a whole regularization path
// in one launch, one thread per lambda.  Coordinate descent is
// sequential inside a problem, so the parallelism is across the batch --
// the shape a cross-validation grid already has.  The translated
// enet_descend is called unchanged; it carries __host__ __device__
// because its body stays inside the device-safe subset, and with
// l1_ratio = 1 every operation is bit-identical to the pure lasso.
#include "_generated/lasso_cov.hpp"
#include <cuda_runtime.h>

__global__ void scm2cpp_batch_kernel(const double* g, double* c, double* beta,
                                     double* prev, const double* lam,
                                     double l1r, int cap, int chunk,
                                     double tol, double nobs, int p,
                                     int batch) {
  int t = blockIdx.x * blockDim.x + threadIdx.x;
  if (t >= batch) return;
  double* ct = c + (size_t)t * p;
  double* bt = beta + (size_t)t * p;
  double* pt = prev + (size_t)t * p;
  double lam1 = lam[t] * l1r;
  double lam2 = lam[t] * (1.0 - l1r);
  int swept = 0;
  while (swept < cap) {
    for (int j = 0; j < p; ++j) pt[j] = bt[j];
    enet_descend(scm2cpp::cspan<double>(g), scm2cpp::span<double>(ct),
                 scm2cpp::span<double>(bt), lam1, lam2, chunk, nobs, p);
    swept += chunk;
    double d = 0.0;
    for (int j = 0; j < p; ++j) {
      double e = bt[j] - pt[j];
      if (e < 0) e = -e;
      if (e > d) d = e;
    }
    if (d < tol) break;
  }
}

// Returns 0 on success, or the CUDA error code.  beta and c are
// batch x p, row-major, updated in place; the caller keeps ownership.
extern "C" int scm2cpp_batch_descend(const double* g, double* c, double* beta,
                                     const double* lam, double l1_ratio,
                                     int batch, int p, double nobs, int cap,
                                     int chunk, double tol) {
  size_t gsz = (size_t)p * p * sizeof(double);
  size_t bsz = (size_t)batch * p * sizeof(double);
  double *dg = 0, *dc = 0, *db = 0, *dp = 0, *dl = 0;
  cudaError_t e = cudaSuccess;
  #define TRY(call) do { e = (call); if (e != cudaSuccess) goto done; } while (0)
  TRY(cudaMalloc(&dg, gsz));
  TRY(cudaMalloc(&dc, bsz));
  TRY(cudaMalloc(&db, bsz));
  TRY(cudaMalloc(&dp, bsz));
  TRY(cudaMalloc(&dl, (size_t)batch * sizeof(double)));
  TRY(cudaMemcpy(dg, g, gsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(dc, c, bsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(db, beta, bsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(dl, lam, (size_t)batch * sizeof(double),
                 cudaMemcpyHostToDevice));
  scm2cpp_batch_kernel<<<(batch + 127) / 128, 128>>>(
      dg, dc, db, dp, dl, l1_ratio, cap, chunk, tol, nobs, p, batch);
  TRY(cudaDeviceSynchronize());
  TRY(cudaMemcpy(beta, db, bsz, cudaMemcpyDeviceToHost));
  TRY(cudaMemcpy(c, dc, bsz, cudaMemcpyDeviceToHost));
 done:
  #undef TRY
  if (dg) cudaFree(dg);
  if (dc) cudaFree(dc);
  if (db) cudaFree(db);
  if (dp) cudaFree(dp);
  if (dl) cudaFree(dl);
  return (int)e;
}
