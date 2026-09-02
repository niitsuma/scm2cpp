# A kernel with no main

`lasso-kernel.scm` is meant to be called from elsewhere -- Python, or any
C++ of your own -- rather than run on its own. It therefore has no `main`,
and nothing in it says how long its arrays are.

The kernels in this directory share one definition, the soft-thresholding
operator, and each takes it by `(include "soft-threshold.scm")` rather
than by a copy: the translator splices the file in before anything reads
the program, and the path is relative to the file that includes it, so a
kernel copied elsewhere for translation takes `soft-threshold.scm` along
(as `run-tests.sh` and the pip package's `regenerate.sh` do).

Inference reads the array parameters off how they are used: indexing with
`vector-ref` says the parameter is a vector, and what is done with the
element says the element is a `double`. The extent stays open, so the
parameters come out as `std::vector<double>`, which `-M` can carry across
the C ABI as a pointer and a length:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/lasso-kernel.scm
$ g++ -O2 -std=c++11 -shared -fPIC -I. -include boost/operators.hpp \
      -include boost/optional.hpp -o liblasso-kernel.so lasso-kernel_capi.cpp
```

```python
import numpy as np, lasso_kernel
beta, resid = np.zeros(p), y.copy()          # the working state, warm-started along the path
lmax = np.abs(X.T @ y).max() / n_obs         # the penalty at which every coefficient is zero
lams = np.geomspace(lmax, 0.01 * lmax, 100)  # the penalties, largest first
betas = np.zeros(100 * p)                    # row l = the fit at lams[l]
lasso_kernel.lasso(xd, beta, resid, xnorm, lams, betas, 30, n_obs, p, 100)
```

The kernel takes a *path* of penalties and warm-starts each fit from
the one before; a single fit is the path of length one (`lams` of one
element, `betas` of `p` cells). Each fit runs at most `iters` sweeps
and stops early after a sweep in which no coordinate moved, since a
sweep that moves nothing has reached the fixed point and would move
nothing again; the residual update of a coordinate that did not move
is skipped by the same test, and the derivation below carries both
the skip and the stop over to the Gram form. The path is inside the
kernel rather than in a Python loop around it so that the derivation
can see it: the sweep `--derive` differences is the whole loop over
penalties, so the Gram matrix is built once in front of it and `c =
X'r` is carried across the warm starts -- one O(np^2) build and one
O(np) pass for `c`, then sweeps at O(p^2), and an O(np) pass at the
end to bring the residual current. Against scikit-learn's `Lasso(warm_start=True)`
along the same 50 penalties at 30 sweeps each, both forms agree to
2e-15; on the 1,800 x 200 problem the residual form takes 0.19 s and
the derived Gram form 0.04 s.

The same kernel used by a program that *does* create its arrays with
`make-vector` gets `boost::array<double,N>&` parameters instead: a known
extent is the better answer, and inference prefers it wherever a call
site supplies one. `examples/tfs-lasso.scm` is that case.

Checked against scikit-learn's `Lasso` on the same problem: the
coefficients agree to 5e-11.

This is also the memory-lean lasso: beyond X it keeps one n-vector,
where `lasso-cov.scm` below keeps a p x p Gram matrix.  It is the same
algorithm as scikit-learn's `Lasso(precompute=False)`, and
`bench/lasso-memory-compare.py` measures it against that at equal
sweeps -- the two run neck and neck once the kernel skips the
residual update of a coordinate that did not move (it does) and the
compiler is allowed to reorder the dot product's additions
(`-O3 -march=native -ffast-math`; the strict sequential sum the
translator writes is what scikit-learn's BLAS `ddot` does not have to
respect, and costs 20-30% here).  The numbers are in the main README
under "Trading the speed back for memory".

## lasso-fused.scm: the design matrix that is never built

In temporal feature selection the design matrix is not arbitrary: column
j is the moving average of one base sequence at window j+1, so

    X[row][j] = (ps[t] - ps[t-w]) / w,   t = wmax + row

is determined by the prefix sums `ps` and the window length. The solver
can recompute an element wherever it needs one and never allocate X at
all -- reading n numbers per sweep where the ordinary form reads n*p.
`lasso-fused.scm` does that, and agrees with scikit-learn's `Lasso` to
2e-13 on the same problem.

Two lessons from measuring it, both now reflected in the code:

- Dividing by the window once per element costs more than the memory the
  fusion saves. The reciprocal is computed once per column and
  multiplied.
- Reading through a small helper function cost about three times the
  loop it was helping, because generated functions were emitted into the
  header without `inline` and were not expanded. They now carry `inline`,
  which is also what lets the header be included from more than one
  translation unit at all.

Whether the fused form is faster than the materialised one depends on
the machine and the shape of the problem, and this repository has no
measurement worth quoting: the machine available while it was written
never went idle (load above 30 throughout), and repeated runs of the
same case varied by nearly 50%. The claim to take from here is the one
that is not about speed -- the fused form computes the same answer while
using O(n) memory instead of O(n*p).

## lasso-cov.scm: the sweeps stop depending on n

`lasso-fused.scm` avoids building X but still walks all n observations
for every coordinate of every sweep. `lasso-cov.scm` does not walk them
at all after the preparation, by keeping `c = X'r` instead of the
residual `r`: changing `beta[j]` by `d` changes `c` by `-d*G[:,j]`, so a
coordinate step is O(p).

That needs the Gram matrix `G = X'X`, which for a general design costs
O(n*p^2) to form -- more than the sweeps it saves. Here it does not.
Writing `S(a,b)` for the inner product of `ps` shifted by `a` and by `b`,

    G[j][k] = (S(0,0) - S(0,wk) - S(wj,0) + S(wj,wk)) / (wj*wk)

and fixing the lag `d = b-a` makes `S(a,a+d)` a sliding-window sum, so
one prefix-sum pass per lag yields every entry: O(n*p). `X'y` comes from
the same kind of pass. Measured on its own, building the Gram matrix this
way beat forming it from X by 26x at p=50 and 680x at p=200 -- the ratio
grows with p, as O(p) predicts.

Measured end to end from Python, on an idle machine, against
scikit-learn on the same problem (`-O3 -march=native`; all three agree
to 1e-10 or better):

| n | fused | covariance | scikit-learn |
|---|---|---|---|
| 4,000 | 87.7 ms | **1.77 ms** | 23.7 ms |
| 20,000 | 494.3 ms | **7.48 ms** | 141,753 ms |
| 50,000 | 603.4 ms | **17.86 ms** | 131,871 ms |

The sweeps themselves are under 0.1 ms at every size; what remains is the
O(n*p) preparation. scikit-learn's times at the larger sizes are not a
convergence artefact -- it stops after 35 iterations and returns the same
coefficients -- but they are one library on one problem, and should be
read as "this shape of problem is bad for a general solver", not as a
general ranking.

`lasso-cov-check.py` runs the whole pipeline from a raw series and
compares with scikit-learn.

`enet-descend` and `mt-descend` in the same file are the elastic net
and the multi-task lasso over the same `G` and `c`.  Their residual
forms -- the programs before the covariance update was written in by
hand -- are `enet-kernel.scm` and `mt-kernel.scm`.  Both derive
with `--derive`, from the shapes each declares at the head of its body:
`enet-kernel.scm` gives `enet-descend`'s step (the L1 share in the
threshold, the L2 share in the denominator, the guarded update of `c`,
the early stop), and on a 400 x 30 problem the derived and the
hand-written coefficients agree to 7e-16.  `mt-kernel.scm` declares
its residual as an `ntask` by `n` matrix updated one row at a time
(`row-dec!` once raised), so the memo is `ntask` by `p`, the row of `W`
that moves updates one row of it, and the restoration at the end walks
the coefficient matrix against a copy taken before the sweeps; the
residual form agrees with `mt-descend` to 9e-16 and runs about 50x
slower at that size, which is the gain the derivation carries over.
The suite's `probe/derive-{lasso,enet,mt}.scm` run each kernel plainly
and derived against the same Racket oracle.  Neither is a rewrite the search
finds by cost: as with the lasso, the Gram matrix is an investment the
source cannot price.

### What was tried and did not pay

GPU: the fused kernel was also written in CUDA with `ps` and the residual
resident on the device. It loses badly below n = 100,000 -- coordinate
descent is sequential in j, so every coordinate costs two kernel launches
and one scalar readback -- and wins over the *fused CPU* version above
it (36x at n = 2,000,000). Against the covariance version it loses at
every size measured, because that one stops touching the n observations
altogether. The lesson is that the win came from the algorithm, not the
device.

## lasso-cov-multi.scm: several series, one target

The same construction with m series instead of one. The design matrix now
has m*wmax columns, one per pair of a series and a window, and a Gram
entry expands into inner products of two prefix-sum arrays that may
belong to different series:

    G[(c,w)][(c',w')] = (S(c,c',0,0) - S(c,c',0,w') - S(c,c',w,0)
                         + S(c,c',w,w')) / (w*w')

Fixing the lag makes each a sliding-window sum exactly as before, so one
prefix-sum pass per (series pair, lag) gives every entry: O(m^2*wmax*n)
against the O(n*(m*wmax)^2) of forming the matrix -- the same factor of
wmax the single-series case saves.

The prefix sums of all series are held end to end in one array, series c
occupying [c*n, (c+1)*n), because the subset has no arrays of arrays.

```python
ps = np.concatenate([np.cumsum(x) for x in xs])
lasso_cov_multi.build_S_multi(ps, s, q, cs, n, nobs, wmax, m)
lasso_cov_multi.build_P_multi(ps, y, pv, n, nobs, wmax, m)
lasso_cov_multi.build_G_multi(s, pv, g, c, wmax, m, p)
lasso_cov_multi.cov_descend_multi(g, c, beta, lam, sweeps, nobs, p)
```

Given three series where only series 0 at window 5 and series 2 at
window 9 generate the target, it recovers both with the other coefficients
two to three orders of magnitude smaller, and agrees with scikit-learn to
2e-12. `lasso-cov-multi-check.py` runs that check.

Timings taken on a loaded machine, so read them as an order of magnitude
rather than a measurement:

| series | wmax | columns | n | scm2cpp | scikit-learn |
|---|---|---|---|---|---|
| 3 | 12 | 36 | 400 | 0.4 ms | 9.6 ms |
| 5 | 20 | 100 | 2,000 | 5.6 ms | 59.8 ms |
| 8 | 20 | 160 | 4,000 | 37.4 ms | 272.4 ms |

One caution about the subset, met while writing this: a loop variable
named c alongside a parameter named c in another function was renamed
into a collision by alpha conversion, and the generated loop declared its
index as a vector. Distinct names for loop indices avoid it.
