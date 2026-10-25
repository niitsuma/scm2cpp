// The GPU entry point the packages expose: a whole regularization path
// in one launch, one thread per lambda.  Coordinate descent is
// sequential inside a problem, so the parallelism is across the batch --
// the shape a cross-validation grid already has.  The translated
// enet_descend is called unchanged; it carries __host__ __device__
// because its body stays inside the device-safe subset, and with
// l1_ratio = 1 every operation is bit-identical to the pure lasso.
#include "_generated/lasso_cov.hpp"
#include <cuda_runtime.h>

__global__ void scm2cpp_batch_kernel(const double* g, size_t g_stride,
                                     double* c, double* beta,
                                     double* prev, const double* lam,
                                     double l1r, int cap, int chunk,
                                     double tol, double nobs, int p,
                                     int batch) {
  int t = blockIdx.x * blockDim.x + threadIdx.x;
  if (t >= batch) return;
  const double* gt = g + (size_t)t * g_stride;   // 0: one shared Gram
  double* ct = c + (size_t)t * p;
  double* bt = beta + (size_t)t * p;
  double* pt = prev + (size_t)t * p;
  double lam1 = lam[t] * l1r;
  double lam2 = lam[t] * (1.0 - l1r);
  int swept = 0;
  while (swept < cap) {
    for (int j = 0; j < p; ++j) pt[j] = bt[j];
    enet_descend(scm2cpp::cspan<double>(gt), scm2cpp::span<double>(ct),
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
// n_grams is 1 for one shared Gram matrix, or batch for one per
// thread -- a bootstrap, where every resample has its own.
extern "C" int scm2cpp_batch_descend(const double* g, int n_grams,
                                     double* c, double* beta,
                                     const double* lam, double l1_ratio,
                                     int batch, int p, double nobs, int cap,
                                     int chunk, double tol) {
  size_t g_stride = (n_grams > 1) ? (size_t)p * p : 0;
  size_t gsz = (size_t)p * p * sizeof(double) * (size_t)(n_grams > 1 ? batch : 1);
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
      dg, g_stride, dc, db, dp, dl, l1_ratio, cap, chunk, tol, nobs, p,
      batch);
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

// ---- the cross-validation grid: one block per problem ----
//
// A CV grid is cv folds by num penalties, 500 problems at the usual
// sizes.  One thread each (the kernel above) leaves the device nearly
// idle and pays each problem the whole descent from zero at one
// thread's speed, which at p = 1000 loses to the CPU's warm path.
// Here a whole block serves one problem: the coordinate step itself
// stays sequential -- thread 0 does the soft threshold, the same
// arithmetic as the translated enet_descend -- and the O(p) update of
// the correlations after a coordinate moves is spread over the block.
// c and beta live in shared memory, the Gram rows stream from global
// memory one row per moved coordinate, and a coordinate that did not
// move costs one barrier.  Grams are indexed by fold: problem i reads
// Gram i / per_gram, so a grid carries cv Gram matrices and no copies.
// Consecutive problems of a fold can be walked warm in runs of `span`
// by one block, as the CPU path does; measured, span 1 is fastest at
// every size tried (the device has blocks to spare, and a warm descent
// still sweeps all p coordinates), so the callers pass 1.  The
// stopping test is the CPU path's relative one, max |db| < tol *
// max(1, max |b|), and the translated kernels' sweep loop, chunked and
// stopped when a sweep moves nothing, is kept.

__global__ void scm2cpp_cv_block_kernel(const double* g, size_t g_stride,
                                        int per_gram, double* c,
                                        double* beta, double* prev,
                                        const double* lam, double l1r,
                                        int cap, int chunk, double tol,
                                        double nobs, int p, int span) {
  extern __shared__ double sh[];
  double* sc = sh;                // p: correlations
  double* sb = sc + p;            // p: coefficients
  double* sdiag = sb + p;         // p: the Gram diagonal
  double* red = sdiag + p;        // blockDim: reduction scratch
  __shared__ double s_delta[2];   // by coordinate parity: a write for
  __shared__ int s_moved[2];      // j+1 never races a read for j
  const int tid = threadIdx.x, nt = blockDim.x;
  const int first = blockIdx.x * span;
  const double* gt = g + (size_t)(first / per_gram) * g_stride;
  double* sp = prev + (size_t)blockIdx.x * p;
  for (int k = tid; k < p; k += nt) {
    sc[k] = c[(size_t)first * p + k];
    sb[k] = beta[(size_t)first * p + k];
    sdiag[k] = gt[(size_t)k * p + k];
  }
  __syncthreads();
  for (int i = first; i < first + span; ++i) {
    const double lam1 = lam[i] * l1r * nobs;
    const double lam2 = lam[i] * (1.0 - l1r) * nobs;
    int swept = 0;
    while (swept < cap) {
      for (int k = tid; k < p; k += nt) sp[k] = sb[k];
      __syncthreads();
      for (int s = 0; s < chunk; ++s) {
        if (tid == 0) s_moved[s & 1] = 0;
        for (int j = 0; j < p; ++j) {
          if (tid == 0) {
            double gjj = sdiag[j];
            double old = sb[j];
            double bnew = soft_threshold(sc[j] + old * gjj, lam1)
                          / (gjj + lam2);
            sb[j] = bnew;
            double d = bnew - old;
            if (d != 0.0) s_moved[s & 1] = 1;
            s_delta[j & 1] = d;
          }
          __syncthreads();
          double d = s_delta[j & 1];
          if (d != 0.0) {
            const double* row = gt + (size_t)j * p;
            for (int k = tid; k < p; k += nt) sc[k] -= d * row[k];
            __syncthreads();
          }
        }
        __syncthreads();
        if (s_moved[s & 1] == 0) break;
      }
      swept += chunk;
      double dmax = 0.0, bmax = 1.0;
      for (int k = tid; k < p; k += nt) {
        double e = sb[k] - sp[k];
        if (e < 0) e = -e;
        if (e > dmax) dmax = e;
        double a = sb[k] < 0 ? -sb[k] : sb[k];
        if (a > bmax) bmax = a;
      }
      red[tid] = dmax;
      __syncthreads();
      for (int h = nt / 2; h > 0; h >>= 1) {
        if (tid < h && red[tid + h] > red[tid]) red[tid] = red[tid + h];
        __syncthreads();
      }
      dmax = red[0];
      __syncthreads();
      red[tid] = bmax;
      __syncthreads();
      for (int h = nt / 2; h > 0; h >>= 1) {
        if (tid < h && red[tid + h] > red[tid]) red[tid] = red[tid + h];
        __syncthreads();
      }
      bmax = red[0];
      __syncthreads();
      if (dmax < tol * bmax) break;
    }
    for (int k = tid; k < p; k += nt) {
      beta[(size_t)i * p + k] = sb[k];
      c[(size_t)i * p + k] = sc[k];
    }
  }
}

// The multi-task step, the translated mt_descend's arithmetic: thread 0
// forms the group norm over the tasks of coordinate j and the ntask
// moves; the block updates the p x ntask correlations.  c and w are
// row-major p x ntask, as the CPU kernel takes them.
__global__ void scm2cpp_cv_block_kernel_mt(const double* g, size_t g_stride,
                                           int per_gram, double* c,
                                           double* w, double* prev,
                                           const double* lam, double l1r,
                                           int cap, int chunk, double tol,
                                           double nobs, int p, int ntask,
                                           int span) {
  extern __shared__ double sh[];
  const int pt_ = p * ntask;
  double* sc = sh;
  double* sw = sc + pt_;
  double* sdiag = sw + pt_;
  double* red = sdiag + p;
  double* s_delta = red + blockDim.x;   // 2 * (ntask + 1), by parity:
                                        // ntask moves and an any-moved flag
  __shared__ int s_moved[2];
  const int tid = threadIdx.x, nt = blockDim.x;
  const int first = blockIdx.x * span;
  const double* gt = g + (size_t)(first / per_gram) * g_stride;
  double* sp = prev + (size_t)blockIdx.x * pt_;
  for (int k = tid; k < pt_; k += nt) {
    sc[k] = c[(size_t)first * pt_ + k];
    sw[k] = w[(size_t)first * pt_ + k];
  }
  for (int k = tid; k < p; k += nt) sdiag[k] = gt[(size_t)k * p + k];
  __syncthreads();
  for (int i = first; i < first + span; ++i) {
    const double thr = lam[i] * l1r * nobs;
    const double lam2 = lam[i] * (1.0 - l1r) * nobs;
    int swept = 0;
    while (swept < cap) {
      for (int k = tid; k < pt_; k += nt) sp[k] = sw[k];
      __syncthreads();
      for (int s = 0; s < chunk; ++s) {
        if (tid == 0) s_moved[s & 1] = 0;
        for (int j = 0; j < p; ++j) {
          double* dj = s_delta + (j & 1) * (ntask + 1);
          if (tid == 0) {
            double gjj = sdiag[j];
            double nrm2 = 0.0;
            for (int t = 0; t < ntask; ++t) {
              double z = sc[j * ntask + t] + gjj * sw[j * ntask + t];
              nrm2 = nrm2 + z * z;
            }
            double nrm = sqrt(nrm2);
            double scale = (nrm > thr) ? ((nrm - thr) / (nrm * (gjj + lam2)))
                                       : 0.0;
            int any = 0;
            for (int t = 0; t < ntask; ++t) {
              double old = sw[j * ntask + t];
              double wnew = scale * (sc[j * ntask + t] + gjj * old);
              sw[j * ntask + t] = wnew;
              double d = wnew - old;
              if (d != 0.0) any = 1;
              dj[t] = d;
            }
            if (any) s_moved[s & 1] = 1;
            dj[ntask] = any;
          }
          __syncthreads();
          if (dj[ntask] != 0.0) {
            const double* row = gt + (size_t)j * p;
            for (int idx = tid; idx < pt_; idx += nt) {
              int k = idx / ntask, t = idx - k * ntask;
              double d = dj[t];
              if (d != 0.0) sc[idx] -= d * row[k];
            }
            __syncthreads();
          }
        }
        __syncthreads();
        if (s_moved[s & 1] == 0) break;
      }
      swept += chunk;
      double dmax = 0.0, bmax = 1.0;
      for (int k = tid; k < pt_; k += nt) {
        double e = sw[k] - sp[k];
        if (e < 0) e = -e;
        if (e > dmax) dmax = e;
        double a = sw[k] < 0 ? -sw[k] : sw[k];
        if (a > bmax) bmax = a;
      }
      red[tid] = dmax;
      __syncthreads();
      for (int h = nt / 2; h > 0; h >>= 1) {
        if (tid < h && red[tid + h] > red[tid]) red[tid] = red[tid + h];
        __syncthreads();
      }
      dmax = red[0];
      __syncthreads();
      red[tid] = bmax;
      __syncthreads();
      for (int h = nt / 2; h > 0; h >>= 1) {
        if (tid < h && red[tid + h] > red[tid]) red[tid] = red[tid + h];
        __syncthreads();
      }
      bmax = red[0];
      __syncthreads();
      if (dmax < tol * bmax) break;
    }
    for (int k = tid; k < pt_; k += nt) {
      w[(size_t)i * pt_ + k] = sw[k];
      c[(size_t)i * pt_ + k] = sc[k];
    }
  }
}

// The fallback when the block's state does not fit in shared memory:
// one thread per run, the translated kernels unchanged, the same
// relative stopping test.  ntask = 0 selects enet_descend on p
// coefficients, otherwise mt_descend on p x ntask.
__global__ void scm2cpp_cv_thread_kernel(const double* g, size_t g_stride,
                                         int per_gram, double* c,
                                         double* w, double* prev,
                                         const double* lam, double l1r,
                                         int cap, int chunk, double tol,
                                         double nobs, int p, int ntask,
                                         int span, int nruns) {
  int u = blockIdx.x * blockDim.x + threadIdx.x;
  if (u >= nruns) return;
  const int pt_ = p * (ntask > 0 ? ntask : 1);
  int first = u * span;
  const double* gt = g + (size_t)(first / per_gram) * g_stride;
  double* pv = prev + (size_t)u * pt_;
  for (int i = first; i < first + span; ++i) {
    double* ct = c + (size_t)i * pt_;
    double* wt = w + (size_t)i * pt_;
    if (i > first) {          // warm: continue from the previous penalty
      for (int j = 0; j < pt_; ++j) { wt[j] = wt[j - pt_]; ct[j] = ct[j - pt_]; }
    }
    double lam1 = lam[i] * l1r;
    double lam2 = lam[i] * (1.0 - l1r);
    int swept = 0;
    while (swept < cap) {
      for (int j = 0; j < pt_; ++j) pv[j] = wt[j];
      if (ntask > 0)
        mt_descend(scm2cpp::cspan<double>(gt), scm2cpp::span<double>(ct),
                   scm2cpp::span<double>(wt), lam1, lam2, chunk, nobs, p,
                   ntask);
      else
        enet_descend(scm2cpp::cspan<double>(gt), scm2cpp::span<double>(ct),
                     scm2cpp::span<double>(wt), lam1, lam2, chunk, nobs, p);
      swept += chunk;
      double d = 0.0, m = 1.0;
      for (int j = 0; j < pt_; ++j) {
        double e = wt[j] - pv[j];
        if (e < 0) e = -e;
        if (e > d) d = e;
        double a = wt[j] < 0 ? -wt[j] : wt[j];
        if (a > m) m = a;
      }
      if (d < tol * m) break;
    }
  }
}

// The grid entry, single-task (ntask = 0) and multi-task.  g holds
// n_grams Gram matrices and problem i uses Gram i / per_gram with
// per_gram = batch / n_grams; c and w are batch x p (x ntask),
// c each problem's fold correlations and w its start, usually zero.
// Consecutive problems of a fold are walked warm by one block in runs
// of `span`, which must divide per_gram.  mode 0 forces the one-
// thread-per-run fallback; otherwise the block kernel runs whenever
// its state fits the device's shared memory.  Returns 0, a CUDA error
// code, or -1 for a shape it cannot take.
extern "C" int scm2cpp_cv_descend(const double* g, int n_grams, double* c,
                                  double* w, const double* lam,
                                  double l1_ratio, int batch, int p,
                                  int ntask, double nobs, int cap,
                                  int chunk, double tol, int span,
                                  int mode) {
  if (n_grams < 1 || batch % n_grams != 0) return -1;
  int per_gram = batch / n_grams;
  if (span < 1 || per_gram % span != 0) return -1;
  int nruns = batch / span;
  int width = p * (ntask > 0 ? ntask : 1);
  int bs = (width <= 128) ? 128 : 256;
  size_t shm = (ntask > 0)
      ? (size_t)(2 * width + p + bs + 2 * (ntask + 1)) * sizeof(double)
      : (size_t)(3 * p + bs) * sizeof(double);
  int dev = 0, optin = 0;
  cudaError_t e = cudaSuccess;
  #define TRY(call) do { e = (call); if (e != cudaSuccess) goto done; } while (0)
  double *dg = 0, *dc = 0, *dw = 0, *dp = 0, *dl = 0;
  size_t g_stride = (size_t)p * p;
  size_t gsz = g_stride * sizeof(double) * (size_t)n_grams;
  size_t bsz = (size_t)batch * width * sizeof(double);
  int block = 0;
  TRY(cudaGetDevice(&dev));
  TRY(cudaDeviceGetAttribute(&optin, cudaDevAttrMaxSharedMemoryPerBlockOptin,
                             dev));
  block = (mode != 0 && shm <= (size_t)optin);
  if (block) {
    TRY(cudaFuncSetAttribute(
        ntask > 0 ? (const void*)scm2cpp_cv_block_kernel_mt
                  : (const void*)scm2cpp_cv_block_kernel,
        cudaFuncAttributeMaxDynamicSharedMemorySize, (int)shm));
  }
  TRY(cudaMalloc(&dg, gsz));
  TRY(cudaMalloc(&dc, bsz));
  TRY(cudaMalloc(&dw, bsz));
  TRY(cudaMalloc(&dp, (size_t)nruns * width * sizeof(double)));
  TRY(cudaMalloc(&dl, (size_t)batch * sizeof(double)));
  TRY(cudaMemcpy(dg, g, gsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(dc, c, bsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(dw, w, bsz, cudaMemcpyHostToDevice));
  TRY(cudaMemcpy(dl, lam, (size_t)batch * sizeof(double),
                 cudaMemcpyHostToDevice));
  if (block && ntask > 0)
    scm2cpp_cv_block_kernel_mt<<<nruns, bs, shm>>>(
        dg, g_stride, per_gram, dc, dw, dp, dl, l1_ratio, cap, chunk, tol,
        nobs, p, ntask, span);
  else if (block)
    scm2cpp_cv_block_kernel<<<nruns, bs, shm>>>(
        dg, g_stride, per_gram, dc, dw, dp, dl, l1_ratio, cap, chunk, tol,
        nobs, p, span);
  else
    scm2cpp_cv_thread_kernel<<<(nruns + 127) / 128, 128>>>(
        dg, g_stride, per_gram, dc, dw, dp, dl, l1_ratio, cap, chunk, tol,
        nobs, p, ntask, span, nruns);
  TRY(cudaGetLastError());
  TRY(cudaDeviceSynchronize());
  TRY(cudaMemcpy(w, dw, bsz, cudaMemcpyDeviceToHost));
  TRY(cudaMemcpy(c, dc, bsz, cudaMemcpyDeviceToHost));
 done:
  #undef TRY
  if (dg) cudaFree(dg);
  if (dc) cudaFree(dc);
  if (dw) cudaFree(dw);
  if (dp) cudaFree(dp);
  if (dl) cudaFree(dl);
  return (int)e;
}
