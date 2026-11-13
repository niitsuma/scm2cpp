
#ifndef GRAMOPS_HPP
#define GRAMOPS_HPP
#define SCM2CPP_MINIMAL
#include	<cmath>
#include	"scm2cpp-blas.hpp"
#include	<array>
#include	<math.h>
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN std::int64_t
spd_inverse( scm2cpp::cspan<double> a,  scm2cpp::span<double> inv,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  std::int64_t  p );
SCM2CPP_FN std::int64_t
enet_gap( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::cspan<double> qw,  scm2cpp::span<double> xta,  std::array<double,2> & out,  double  alpha,  double  ynorm2,  std::int64_t  m );
SCM2CPP_FN std::int64_t
enet_safe_rule( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::span<double> qw,  scm2cpp::cspan<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  const std::array<double,2> & out,  double  alpha,  std::int64_t  m );
SCM2CPP_FN std::int64_t
enet_gram( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::cspan<double> q,  scm2cpp::span<double> qw,  scm2cpp::span<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  std::array<double,2> & out,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  m );
std::int64_t
graphical_lasso( scm2cpp::cspan<double> emp,  scm2cpp::span<double> cov,  scm2cpp::span<double> prec,  double  alpha,  std::int64_t  maxiter,  double  tol,  double  enettol,  std::int64_t  p );
std::int64_t
omp_scm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  std::int64_t  rec,  std::int64_t  kmax,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  std::int64_t  maxiter,  double  tol,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
std::int64_t
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  std::int64_t  family,  double  power,  double  l2,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
std::int64_t
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  std::int64_t  family,  double  power,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN double
lb_abs( double  a );
SCM2CPP_FN double
lb_max( double  a,  double  b );
SCM2CPP_FN double
lb_min( double  a,  double  b );
SCM2CPP_FN std::int64_t
lb_dcstep( std::array<double,8> & cs,  double  fp,  double  dp,  double  stpmin,  double  stpmax );
SCM2CPP_FN std::int64_t
lb_search_start( std::array<double,16> & ls,  double  f,  double  g,  double  stp,  double  stpmin,  double  stpmax,  double  ftol );
SCM2CPP_FN std::int64_t
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax );
SCM2CPP_FN double
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  std::int64_t  nv );
SCM2CPP_FN double
lb_dot_row( scm2cpp::cspan<double> mem,  std::int64_t  slot,  scm2cpp::cspan<double> v,  std::int64_t  nv );
SCM2CPP_FN double
lb_dot_rows( scm2cpp::cspan<double> a,  std::int64_t  ra,  scm2cpp::cspan<double> b,  std::int64_t  rb,  std::int64_t  nv );
SCM2CPP_FN double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  std::int64_t  ib,  double  lbv,  std::int64_t  nv );
SCM2CPP_FN std::int64_t
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv );
SCM2CPP_FN double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv );
SCM2CPP_FN std::int64_t
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  ib,  double  lbv,  std::int64_t  nv );
std::int64_t
lbfgs( std::int64_t  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  std::int64_t  m,  std::int64_t  maxiter,  double  pgtol,  double  ftol,  std::int64_t  maxls,  std::int64_t  ib,  double  lbv,  std::int64_t  nv,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN double
lbfgs_fg( std::int64_t  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN std::int64_t
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  std::int64_t  norm,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
SCM2CPP_FN double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
SCM2CPP_FN double
gmm_abs( double  a );
std::int64_t
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  reg,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
SCM2CPP_FN double
eig_hypot( double  a,  double  b );
SCM2CPP_FN std::int64_t
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m );
SCM2CPP_FN double
eig_abs( double  a );
SCM2CPP_FN std::int64_t
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  std::int64_t  m );
template< typename Unknown_type3800Type > std::int64_t
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  Unknown_type3800Type  e,  std::int64_t  m,  std::int64_t  k );
template< typename Unknown_type3799Type > std::int64_t
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  Unknown_type3799Type  e,  std::int64_t  m );
SCM2CPP_FN double
ica_tanh( double  x );
SCM2CPP_FN std::int64_t
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  scm2cpp::span<double> t,  std::int64_t  m );
std::int64_t
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  std::int64_t  maxiter,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nc );
std::int64_t
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN std::int64_t
ard_pinvh( scm2cpp::span<double> a,  scm2cpp::span<double> s,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  std::int64_t  k );
SCM2CPP_FN std::int64_t
ard_sigma_coef( scm2cpp::cspan<double> xy,  scm2cpp::cspan<int> idx,  scm2cpp::cspan<double> lam,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  scm2cpp::cspan<double> gk,  double  alpha,  std::int64_t  k );
std::int64_t
ard( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> lam,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  alpha1,  double  alpha2,  double  lambda1,  double  lambda2,  double  thresh,  std::int64_t  hoist,  std::int64_t  n,  std::int64_t  p );
std::int64_t
f_regression( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> r,  scm2cpp::span<double> f,  std::int64_t  center,  std::int64_t  n,  std::int64_t  p,  std::int64_t  q );
std::int64_t
f_classif( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> f,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN double
min_pos( scm2cpp::cspan<double> v,  std::int64_t  m );
SCM2CPP_FN double
round_even( double  y );
SCM2CPP_FN std::int64_t
cholesky_delete( scm2cpp::span<double> l,  std::int64_t  go,  std::int64_t  n,  std::int64_t  k );
SCM2CPP_FN std::int64_t
swap_rc( scm2cpp::span<double> g,  std::int64_t  a,  std::int64_t  b,  std::int64_t  p );
std::int64_t
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  std::int64_t  rec,  double  nsamples,  double  alphamin,  std::int64_t  method,  std::int64_t  maxiter,  double  eps,  std::int64_t  p );
SCM2CPP_FN std::int64_t
rfe_chol( scm2cpp::cspan<double> g,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> l,  double  alpha,  std::int64_t  k,  std::int64_t  p );
SCM2CPP_FN std::int64_t
rfe_solve( scm2cpp::cspan<double> c,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::cspan<double> l,  std::int64_t  k,  std::int64_t  p );
std::int64_t
rfe( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<int> support,  scm2cpp::span<int> ranking,  double  alpha,  std::int64_t  nsel,  std::int64_t  step,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN std::int64_t
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN std::int64_t
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  std::int64_t  n,  std::int64_t  p,  std::int64_t  q );
SCM2CPP_FN std::int64_t
spd_solve( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  m,  std::int64_t  q );
SCM2CPP_FN double
gram_abs( double  x );
double
spd_solve_rcond( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  m,  std::int64_t  q );
std::int64_t
gram_ridge_solve( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  double  alpha,  std::int64_t  m,  std::int64_t  q );
std::int64_t
ridge_gcv_primal( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xm,  scm2cpp::cspan<double> yc,  scm2cpp::span<double> g,  scm2cpp::span<double> v,  scm2cpp::span<double> lam,  scm2cpp::span<double> z,  scm2cpp::span<double> r,  std::int64_t  n,  std::int64_t  p,  std::int64_t  t );
std::int64_t
ridge_gcv_dual( scm2cpp::span<double> k,  scm2cpp::span<double> q,  scm2cpp::span<double> mu,  scm2cpp::cspan<double> yc,  scm2cpp::span<double> r,  std::int64_t  n,  std::int64_t  t,  std::int64_t  icpt );
std::int64_t
ridge_gcv_scan_dual( scm2cpp::cspan<double> q,  scm2cpp::cspan<double> mu,  scm2cpp::cspan<double> r,  scm2cpp::cspan<double> alphas,  std::int64_t  drop,  scm2cpp::span<double> mse,  scm2cpp::span<double> loo,  std::int64_t  store,  std::int64_t  n,  std::int64_t  t,  std::int64_t  na );
std::int64_t
ridge_gcv_scan( scm2cpp::cspan<double> z,  scm2cpp::cspan<double> lam,  scm2cpp::cspan<double> r,  scm2cpp::cspan<double> yc,  scm2cpp::cspan<double> alphas,  double  h0,  scm2cpp::span<double> mse,  scm2cpp::span<double> loo,  std::int64_t  store,  std::int64_t  n,  std::int64_t  m,  std::int64_t  t,  std::int64_t  na );
SCM2CPP_FN std::int64_t
kpca_row_norms( scm2cpp::cspan<double> x,  scm2cpp::span<double> s,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN std::int64_t
kpca_apply( scm2cpp::span<double> g,  scm2cpp::cspan<double> sa,  scm2cpp::cspan<double> sb,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  na,  std::int64_t  nb );
std::int64_t
kpca_kernel( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> k,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  na,  std::int64_t  nb,  std::int64_t  p );
std::int64_t
kpca_kernel_self( scm2cpp::cspan<double> x,  scm2cpp::span<double> k,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN std::int64_t
kpca_centre( scm2cpp::span<double> k,  scm2cpp::span<double> m,  std::int64_t  n );
SCM2CPP_FN std::int64_t
kpca_centre_new( scm2cpp::span<double> k,  scm2cpp::cspan<double> m,  std::int64_t  nb,  std::int64_t  n );
SCM2CPP_FN std::int64_t
kpca_flip( scm2cpp::span<double> vecs,  scm2cpp::cspan<double> vals,  std::int64_t  n,  std::int64_t  c );
std::int64_t
kpca_top_dense( scm2cpp::span<double> k,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  c );
SCM2CPP_FN std::int64_t
kpca_orth( scm2cpp::span<double> y,  scm2cpp::span<double> g,  std::int64_t  n,  std::int64_t  b );
std::int64_t
kpca_top_subspace( scm2cpp::cspan<double> k,  scm2cpp::span<double> q,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  b,  std::int64_t  c,  double  tol,  std::int64_t  maxit );
std::int64_t
kpca_linear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xm,  scm2cpp::span<double> g,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  p,  std::int64_t  c );
SCM2CPP_FN std::int64_t
lda_moments( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> g,  scm2cpp::span<double> means,  scm2cpp::span<double> counts,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN std::int64_t
lda_within( scm2cpp::span<double> g,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> counts,  double  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
lda_svd_first( scm2cpp::cspan<double> sw,  scm2cpp::span<double> std,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  std::int64_t  p );
std::int64_t
lda_eigen( scm2cpp::span<double> sb,  scm2cpp::span<double> sw,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  std::int64_t  p );
SCM2CPP_FN std::int64_t
tsvd_flip( scm2cpp::span<double> v,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
tsvd_tall( scm2cpp::cspan<double> x,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
tsvd_wide( scm2cpp::cspan<double> x,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
tsvd_gram( scm2cpp::span<double> g,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  std::int64_t  m,  std::int64_t  k );
SCM2CPP_FN std::int64_t
svd_jacobi( scm2cpp::span<double> w,  scm2cpp::span<double> q,  std::int64_t  r,  std::int64_t  c );
std::int64_t
svd_collect( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::span<double> s,  scm2cpp::span<double> l,  scm2cpp::span<double> rr,  scm2cpp::span<int> ord,  std::int64_t  r,  std::int64_t  c );
std::int64_t
sym_svd( scm2cpp::span<double> a,  scm2cpp::span<double> u,  scm2cpp::span<double> s,  scm2cpp::span<double> vt,  std::int64_t  m,  std::int64_t  n );
std::int64_t
pls_pinv( scm2cpp::cspan<double> a,  scm2cpp::span<double> pv,  std::int64_t  m );
SCM2CPP_FN std::int64_t
pls_mv( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> x,  scm2cpp::span<double> y,  std::int64_t  m,  std::int64_t  n );
SCM2CPP_FN std::int64_t
pls_mtv( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> x,  scm2cpp::span<double> y,  std::int64_t  m,  std::int64_t  n );
SCM2CPP_FN double
pls_dot( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  std::int64_t  m );
std::int64_t
pls_fit( scm2cpp::span<double> cxx,  scm2cpp::span<double> cxy,  scm2cpp::span<double> cyy,  scm2cpp::span<double> xw,  scm2cpp::span<double> yw,  scm2cpp::span<double> xl,  scm2cpp::span<double> yl,  scm2cpp::span<int> niter,  std::int64_t  p,  std::int64_t  q,  std::int64_t  k,  std::int64_t  mode,  std::int64_t  canon,  std::int64_t  algo,  std::int64_t  maxit,  double  tol );
std::int64_t
fa_fit( scm2cpp::cspan<double> c,  scm2cpp::cspan<double> var,  scm2cpp::span<double> psi,  scm2cpp::span<double> w,  scm2cpp::span<double> ll,  double  n,  std::int64_t  p,  std::int64_t  k,  std::int64_t  maxit,  double  tol );
std::int64_t
linreg_solve( scm2cpp::span<double> g,  scm2cpp::span<double> b,  scm2cpp::span<double> coef,  std::int64_t  p,  std::int64_t  t,  double  ratio,  double  tol );
std::int64_t
linreg_singular( scm2cpp::span<double> g,  scm2cpp::span<double> s,  std::int64_t  p,  double  tol );
SCM2CPP_FN std::int64_t
csr_gram( scm2cpp::cspan<std::int64_t> rp,  scm2cpp::cspan<int> ci,  scm2cpp::cspan<double> v,  scm2cpp::span<double> g,  std::int64_t  p,  std::int64_t  r0,  std::int64_t  r1 );
SCM2CPP_FN std::int64_t
csr_mm( scm2cpp::cspan<std::int64_t> rp,  scm2cpp::cspan<int> ci,  scm2cpp::cspan<double> v,  scm2cpp::cspan<double> b,  scm2cpp::span<double> c,  std::int64_t  n,  std::int64_t  k );
SCM2CPP_FN std::int64_t
lu_solve( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  n );
std::int64_t
quantile_fn( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> c,  scm2cpp::span<double> x,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  tol,  std::int64_t  maxit,  std::int64_t  n,  std::int64_t  m );



SCM2CPP_FN inline std::int64_t
spd_inverse( scm2cpp::cspan<double> a,  scm2cpp::span<double> inv,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  std::int64_t  p )
{   for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
        double s = a[(((long long)j*p)+j)];
        for( std::int64_t k = 0 ; !(k == j) ; k = (k+1) ) {
            s = (s-(l[(((long long)j*p)+k)]*l[(((long long)j*p)+k)]))  ;
        }  ;
        l[ (((long long)j*p)+j) ] = sqrt(s)   ;
        for( std::int64_t i = (j+1) ; !(i >= p) ; i = (i+1) ) {
            double t = a[(((long long)i*p)+j)];
            for( std::int64_t k = 0 ; !(k == j) ; k = (k+1) ) {
                t = (t-(l[(((long long)i*p)+k)]*l[(((long long)j*p)+k)]))  ;
            }  ;
            l[ (((long long)i*p)+j) ] = (t/l[(((long long)j*p)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( std::int64_t c = 0 ; !(c == p) ; c = (c+1) ) {
        for( std::int64_t i = 0 ; !(i == p) ; i = (i+1) ) {
            double t = ( ( i == c ) ? (1.0) : (0.0) );
            for( std::int64_t k = 0 ; !(k == i) ; k = (k+1) ) {
                t = (t-(l[(((long long)i*p)+k)]*z[k]))  ;
            }  ;
            z[ i ] = (t/l[(((long long)i*p)+i)])   ;
            ;
        }  ;
        for( std::int64_t ii = 0 ; !(ii == p) ; ii = (ii+1) ) {
            std::int64_t i = ((p-1)-ii);
            double t = z[i];
            for( std::int64_t k = (i+1) ; !(k >= p) ; k = (k+1) ) {
                t = (t-(l[(((long long)k*p)+i)]*inv[(((long long)k*p)+c)]))  ;
            }  ;
            inv[ (((long long)i*p)+c) ] = (t/l[(((long long)i*p)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
enet_gap( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::cspan<double> qw,  scm2cpp::span<double> xta,  std::array<double,2> & out,  double  alpha,  double  ynorm2,  std::int64_t  m )
{   double qdotw = 0.0;
    double wqw = 0.0;
    double l1 = 0.0;
    double dn = 0.0;
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        double wj = w[j];
        qdotw = (qdotw+(wj*q[j]))  ;
        wqw = (wqw+(wj*qw[j]))  ;
        l1 = (l1+( ( wj < 0.0 ) ? ((0.0-wj)) : (wj) ))  ;
        double x = (q[j]-qw[j]);
        xta[ j ] = x   ;
        double ax = ( ( x < 0.0 ) ? ((0.0-x)) : (x) );
        if( ax > dn ) {
            dn = ax  ;
        } else {
            0  ;
        }  ;
        ;
        ;
        ;
    }  ;
    double rnorm2 = ((ynorm2+wqw)-(2.0*qdotw));
    double ry = (ynorm2-qdotw);
    double scale = ( ( dn > alpha ) ? ((alpha/dn)) : (1.0) );
    out[ 0 ] = (((0.5*rnorm2)+(alpha*l1))-((-0.5*((scale*scale)*rnorm2))+(scale*ry)))   ;
    out[ 1 ] = dn   ;
    ;
    ;
    ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
enet_safe_rule( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::span<double> qw,  scm2cpp::cspan<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  const std::array<double,2> & out,  double  alpha,  std::int64_t  m )
{
    struct let3808 {
        let3808() {}
        double operator()( double  g  )
        {
            if( g < 0.0 ) {
                return (0.0-g) ;
            }
            else {
                return g ;
            }
        }
    }  ;
    double radius = (sqrt((2.0*let3808()(out[0])))/alpha);
    double dn = out[1];
    std::int64_t nact = 0;
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        if( excl[j] == 0 ) {
            double xjt = (xta[j]/( ( alpha > dn ) ? (alpha) : (dn) ));
            double dj = ((1.0-( ( xjt < 0.0 ) ? ((0.0-xjt)) : (xjt) ))/sqrt(qm[(((long long)j*m)+j)]));
            if( dj <= radius ) {
                active[ nact ] = j   ;
                nact = (nact+1)  ;
            } else {
                if( !(w[j] == 0.0) ) {
                    double wj = w[j];
                    if( m > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t r = 0 ; r < m ; r += 1 ) {
                            qw[ r ] = (qw[r]-(wj*qm[(((long long)j*m)+r)]))   ;
                        }
                    } else {
                        for( std::int64_t r = 0 ; r < m ; r += 1 ) {
                            qw[ r ] = (qw[r]-(wj*qm[(((long long)j*m)+r)]))   ;
                        }
                    }  ;
                    w[ j ] = 0.0   ;
                    ;
                } else {
                    0  ;
                }  ;
                excl[ j ] = 1   ;
            }  ;
            ;
            ;
        } else {
            0  ;
        }  ;
    }  ;
    return nact ;
}


SCM2CPP_FN inline std::int64_t
enet_gram( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::cspan<double> q,  scm2cpp::span<double> qw,  scm2cpp::span<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  std::array<double,2> & out,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  m )
{   double ynorm2 = 0.0;
    double dwtol = tol;
    std::int64_t nact = 0;
    std::int64_t done = 0;
    std::int64_t iter = 0;
    if( m > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:ynorm2)
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            ynorm2 = (ynorm2+(q[j]*q[j]))  ;
            excl[ j ] = 0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            ynorm2 = (ynorm2+(q[j]*q[j]))  ;
            excl[ j ] = 0   ;
        }
    }  ;
    scm2cpp::blas_gemv(qw, qm, w, 1.0, 0.0, 0, m, m)  ;
    double gtol = (tol*ynorm2);
    enet_gap(w,q,qw,xta,out,alpha,ynorm2,m)  ;
    if( (out[0] >= 0.0 && out[0] <= gtol) ) {
        done = 1  ;
    } else {
        if( m > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                if( qm[(((long long)j*m)+j)] == 0.0 ) {
                    w[ j ] = 0.0   ;
                    excl[ j ] = 1   ;
                } else {
                    0  ;
                }  ;
            }
        } else {
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                if( qm[(((long long)j*m)+j)] == 0.0 ) {
                    w[ j ] = 0.0   ;
                    excl[ j ] = 1   ;
                } else {
                    0  ;
                }  ;
            }
        }  ;
        nact = enet_safe_rule(w,qm,qw,xta,active,excl,out,alpha,m)  ;
    }  ;
    for(  ; !((done == 1 || iter >= maxiter)) ;  ) {
        double wmax = 0.0;
        double dwmax = 0.0;
        for( std::int64_t f = 0 ; !(f == nact) ; f = (f+1) ) {
            std::int64_t j = active[f];
            double qjj = qm[(((long long)j*m)+j)];
            if( !(qjj == 0.0) ) {
                double wj = w[j];
                double tmp = ((q[j]-qw[j])+(wj*qjj));
                double mag = (( ( tmp < 0.0 ) ? ((0.0-tmp)) : (tmp) )-alpha);
                double wn = ( ( mag > 0.0 ) ? ((( ( tmp < 0.0 ) ? ((0.0-mag)) : (mag) )/qjj)) : (0.0) );
                w[ j ] = wn   ;
                if( !(wn == wj) ) {
                    if( m > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t r = 0 ; r < m ; r += 1 ) {
                            qw[ r ] = (qw[r]+((wn-wj)*qm[(((long long)j*m)+r)]))   ;
                        }
                    } else {
                        for( std::int64_t r = 0 ; r < m ; r += 1 ) {
                            qw[ r ] = (qw[r]+((wn-wj)*qm[(((long long)j*m)+r)]))   ;
                        }
                    }  ;
                } else {
                    0  ;
                }  ;
                double dw = ( ( wn < wj ) ? ((wj-wn)) : ((wn-wj)) );
                double aw = ( ( wn < 0.0 ) ? ((0.0-wn)) : (wn) );
                if( dw > dwmax ) {
                    dwmax = dw  ;
                } else {
                    0  ;
                }  ;
                if( aw > wmax ) {
                    wmax = aw  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
                ;
                ;
                ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( (wmax == 0.0 || (dwmax/wmax) <= dwtol || iter == (maxiter-1)) ) {
            enet_gap(w,q,qw,xta,out,alpha,ynorm2,m)  ;
            if( out[0] <= gtol ) {
                done = 1  ;
            } else {
                nact = enet_safe_rule(w,qm,qw,xta,active,excl,out,alpha,m)  ;
            }  ;
        } else {
            0  ;
        }  ;
        iter = (iter+1)  ;
        ;
    }  ;
    ;
    return iter ;
}


inline std::int64_t
graphical_lasso( scm2cpp::cspan<double> emp,  scm2cpp::span<double> cov,  scm2cpp::span<double> prec,  double  alpha,  std::int64_t  maxiter,  double  tol,  double  enettol,  std::int64_t  p )
{   std::int64_t m = (p-1);
    std::vector<double> sub((m*m),0.0);
    std::vector<double> row(m,0.0);
    std::vector<double> b(m,0.0);
    std::vector<double> bnew(m,0.0);
    std::vector<double> qw(m,0.0);
    std::vector<double> xta(m,0.0);
    std::vector<int> active(m,0);
    std::vector<int> excl(m,0);
    std::array<double,2> out = scm2cpp::filled_array<double,2>(0.0);
    std::vector<double> l((p*p),0.0);
    std::vector<double> z(p,0.0);
    std::int64_t done = 0;
    std::int64_t it = 0;
    std::int64_t innermax = ( ( maxiter > 20 ) ? (maxiter) : (20) );
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                cov[ (((long long)i*p)+j) ] = ( ( i == j ) ? (emp[(((long long)i*p)+j)]) : ((0.95*emp[(((long long)i*p)+j)])) )   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                cov[ (((long long)i*p)+j) ] = ( ( i == j ) ? (emp[(((long long)i*p)+j)]) : ((0.95*emp[(((long long)i*p)+j)])) )   ;
            }  ;
        }
    }  ;
    spd_inverse(cov,prec,l,z,p)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        for( std::int64_t idx = 0 ; !(idx == p) ; idx = (idx+1) ) {
            if( idx > 0 ) {
                std::int64_t di = (idx-1);
                for( std::int64_t s = 0 ; !(s == m) ; s = (s+1) ) {
                    std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                    sub[ (((long long)di*m)+s) ] = cov[(((long long)di*p)+o)]   ;
                    sub[ (((long long)s*m)+di) ] = cov[(((long long)o*p)+di)]   ;
                    ;
                }  ;
                ;
            } else {
                if( (m*m) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                        for( std::int64_t t = 0 ; !(t == m) ; t = (t+1) ) {
                            sub[ (((long long)s*m)+t) ] = cov[(((long long)((s+1))*p)+(t+1))]   ;
                        }  ;
                    }
                } else {
                    for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                        for( std::int64_t t = 0 ; !(t == m) ; t = (t+1) ) {
                            sub[ (((long long)s*m)+t) ] = cov[(((long long)((s+1))*p)+(t+1))]   ;
                        }  ;
                    }
                }  ;
            }  ;
            double pii = prec[(((long long)idx*p)+idx)];
            if( m > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                    std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                    row[ s ] = emp[(((long long)idx*p)+o)]   ;
                    b[ s ] = (0.0-(prec[(((long long)o*p)+idx)]/(pii+(1000.0*2.220446049250313e-16))))   ;
                    ;
                }
            } else {
                for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                    std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                    row[ s ] = emp[(((long long)idx*p)+o)]   ;
                    b[ s ] = (0.0-(prec[(((long long)o*p)+idx)]/(pii+(1000.0*2.220446049250313e-16))))   ;
                    ;
                }
            }  ;
            ;
            enet_gram(b,sub,row,qw,xta,active,excl,out,alpha,innermax,enettol,m)  ;
            double acc = 0.0;
            if( m > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
                for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                    std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                    acc = (acc+(cov[(((long long)o*p)+idx)]*b[s]))  ;
                    ;
                }
            } else {
                for( std::int64_t s = 0 ; s < m ; s += 1 ) {
                    std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                    acc = (acc+(cov[(((long long)o*p)+idx)]*b[s]))  ;
                    ;
                }
            }  ;
            double pnew = (1.0/(cov[(((long long)idx*p)+idx)]-acc));
            prec[ (((long long)idx*p)+idx) ] = pnew   ;
            for( std::int64_t s = 0 ; !(s == m) ; s = (s+1) ) {
                std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                prec[ (((long long)o*p)+idx) ] = (0.0-(pnew*b[s]))   ;
                prec[ (((long long)idx*p)+o) ] = (0.0-(pnew*b[s]))   ;
                ;
            }  ;
            ;
            ;
            scm2cpp::blas_gemv(bnew, sub, b, 1.0, 0.0, 0, m, m)  ;
            for( std::int64_t s = 0 ; !(s == m) ; s = (s+1) ) {
                std::int64_t o = ( ( s < idx ) ? (s) : ((s+1)) );
                cov[ (((long long)idx*p)+o) ] = bnew[s]   ;
                cov[ (((long long)o*p)+idx) ] = bnew[s]   ;
                ;
            }  ;
        }  ;
        double tr = 0.0;
        double offl1 = 0.0;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:tr) reduction(+:offl1)
            for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double t = prec[(((long long)i*p)+j)];
                    tr = (tr+(emp[(((long long)i*p)+j)]*t))  ;
                    if( !(i == j) ) {
                        offl1 = (offl1+( ( t < 0.0 ) ? ((0.0-t)) : (t) ))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double t = prec[(((long long)i*p)+j)];
                    tr = (tr+(emp[(((long long)i*p)+j)]*t))  ;
                    if( !(i == j) ) {
                        offl1 = (offl1+( ( t < 0.0 ) ? ((0.0-t)) : (t) ))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
            }
        }  ;
        double gap = ((tr-(1.0*p))+(alpha*offl1));
        it = (it+1)  ;
        if( ( ( gap < 0.0 ) ? ((0.0-gap)) : (gap) ) < tol ) {
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
        ;
    }  ;
    return it ;
}


inline std::int64_t
omp_scm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  std::int64_t  rec,  std::int64_t  kmax,  std::int64_t  n,  std::int64_t  p )
{   std::vector<double> g((p*p),0.0);
    std::vector<double> xy(p,0.0);
    std::vector<double> alpha(p,0.0);
    std::vector<double> beta(p,0.0);
    std::vector<int> index(p,0);
    std::vector<double> l((kmax*kmax),0.0);
    std::vector<double> gamma(kmax,0.0);
    std::vector<double> z(kmax,0.0);
    double eps = 2.220446049250313e-16;
    std::int64_t na = 0;
    std::int64_t done = 0;
    scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    scm2cpp::blas_gemv(xy, x, y, 1.0, 0.0, 1, p, n)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            index[ j ] = j   ;
            alpha[ j ] = xy[j]   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            index[ j ] = j   ;
            alpha[ j ] = xy[j]   ;
        }
    }  ;
    for(  ; !(done == 1) ;  ) {
        std::int64_t lam = 0;
        double best = -1.0;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double a = alpha[j];
            double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
            if( aa > best ) {
                best = aa  ;
                lam = j  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( (lam < na || (alpha[lam]*alpha[lam]) < eps) ) {
            done = 1  ;
        } else {
            if( na > 0 ) {
                double v = 0.0;
                for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                    double t = g[(((long long)lam*p)+i)];
                    for( std::int64_t s = 0 ; !(s == i) ; s = (s+1) ) {
                        t = (t-(l[(((long long)i*kmax)+s)]*l[(((long long)na*kmax)+s)]))  ;
                    }  ;
                    double li = (t/l[(((long long)i*kmax)+i)]);
                    l[ (((long long)na*kmax)+i) ] = li   ;
                    v = (v+(li*li))  ;
                    ;
                    ;
                }  ;
                double lkk = (g[(((long long)lam*p)+lam)]-v);
                if( lkk <= eps ) {
                    done = 1  ;
                } else {
                    l[ (((long long)na*kmax)+na) ] = sqrt(lkk)   ;
                }  ;
                ;
                ;
            } else {
                l[ 0 ] = sqrt(g[(((long long)lam*p)+lam)])   ;
            }  ;
            if( done == 0 ) {
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double grow = g[(((long long)na*p)+j)];
                    g[ (((long long)na*p)+j) ] = g[(((long long)lam*p)+j)]   ;
                    g[ (((long long)lam*p)+j) ] = grow   ;
                    ;
                }  ;
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double gcol = g[(((long long)j*p)+na)];
                    g[ (((long long)j*p)+na) ] = g[(((long long)j*p)+lam)]   ;
                    g[ (((long long)j*p)+lam) ] = gcol   ;
                    ;
                }  ;
                std::int64_t itmp = index[na];
                index[ na ] = index[lam]   ;
                index[ lam ] = itmp   ;
                ;
                double xtmp = xy[na];
                xy[ na ] = xy[lam]   ;
                xy[ lam ] = xtmp   ;
                ;
                na = (na+1)  ;
                for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                    double t = xy[i];
                    for( std::int64_t s = 0 ; !(s == i) ; s = (s+1) ) {
                        t = (t-(l[(((long long)i*kmax)+s)]*z[s]))  ;
                    }  ;
                    z[ i ] = (t/l[(((long long)i*kmax)+i)])   ;
                    ;
                }  ;
                for( std::int64_t ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                    std::int64_t i = ((na-1)-ii);
                    double t = z[i];
                    for( std::int64_t s = (i+1) ; !(s >= na) ; s = (s+1) ) {
                        t = (t-(l[(((long long)s*kmax)+i)]*gamma[s]))  ;
                    }  ;
                    gamma[ i ] = (t/l[(((long long)i*kmax)+i)])   ;
                    ;
                    ;
                }  ;
                if( rec == 1 ) {
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            path[ (((long long)((na-1))*p)+j) ] = 0.0   ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            path[ (((long long)((na-1))*p)+j) ] = 0.0   ;
                        }
                    }  ;
                    for( std::int64_t s = 0 ; !(s == na) ; s = (s+1) ) {
                        path[ (((long long)((na-1))*p)+index[s]) ] = gamma[s]   ;
                    }  ;
                } else {
                    0  ;
                }  ;
                if( (p*na) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                        double acc = 0.0;
                        for( std::int64_t s = 0 ; !(s == na) ; s = (s+1) ) {
                            acc = (acc+(g[(((long long)j*p)+s)]*gamma[s]))  ;
                        }  ;
                        beta[ j ] = acc   ;
                        alpha[ j ] = (xy[j]-acc)   ;
                        ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                        double acc = 0.0;
                        for( std::int64_t s = 0 ; !(s == na) ; s = (s+1) ) {
                            acc = (acc+(g[(((long long)j*p)+s)]*gamma[s]))  ;
                        }  ;
                        beta[ j ] = acc   ;
                        alpha[ j ] = (xy[j]-acc)   ;
                        ;
                    }
                }  ;
                if( na == kmax ) {
                    done = 1  ;
                } else {
                    0  ;
                }  ;
            } else {
                0  ;
            }  ;
        }  ;
        ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    for( std::int64_t s = 0 ; !(s == na) ; s = (s+1) ) {
        coef[ index[s] ] = gamma[s]   ;
    }  ;
    return na ;
}


SCM2CPP_FN inline double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   double loss = 0.0;
    double pen = 0.0;
    scm2cpp::blas_gemm(z, x, coef, 1.0, 0.0, 0, 1, n, k, p)  ;
    if( (n*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]+coef[(((long long)k*p)+c)])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]+coef[(((long long)k*p)+c)])   ;
            }  ;
        }
    }  ;
    if( multi == 0 ) {
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:loss)
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double zi = z[i];
                double yi = y[i];
                if( zi <= -2.0 ) {
                    double e1 = exp(zi);
                    if( zi <= -37.0 ) {
                        loss = (loss+(e1-(yi*zi)))  ;
                        z[ i ] = (e1-yi)   ;
                    } else {
                        loss = (loss+(log((1.0+e1))-(yi*zi)))  ;
                        z[ i ] = ((((1.0-yi)*e1)-yi)/(1.0+e1))   ;
                    }  ;
                    ;
                } else {
                    double e2 = exp((0.0-zi));
                    loss = (loss+(( ( zi <= 18.0 ) ? (log((1.0+e2))) : (e2) )+((1.0-yi)*zi)))  ;
                    z[ i ] = (((1.0-yi)-(yi*e2))/(1.0+e2))   ;
                    ;
                }  ;
                ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double zi = z[i];
                double yi = y[i];
                if( zi <= -2.0 ) {
                    double e1 = exp(zi);
                    if( zi <= -37.0 ) {
                        loss = (loss+(e1-(yi*zi)))  ;
                        z[ i ] = (e1-yi)   ;
                    } else {
                        loss = (loss+(log((1.0+e1))-(yi*zi)))  ;
                        z[ i ] = ((((1.0-yi)*e1)-yi)/(1.0+e1))   ;
                    }  ;
                    ;
                } else {
                    double e2 = exp((0.0-zi));
                    loss = (loss+(( ( zi <= 18.0 ) ? (log((1.0+e2))) : (e2) )+((1.0-yi)*zi)))  ;
                    z[ i ] = (((1.0-yi)-(yi*e2))/(1.0+e2))   ;
                    ;
                }  ;
                ;
            }
        }  ;
    } else {
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double zmax = z[((long long)i*k)];
            double se = 0.0;
            double yc = y[i];
            for( std::int64_t c = 1 ; !(c == k) ; c = (c+1) ) {
                if( z[(((long long)i*k)+c)] > zmax ) {
                    zmax = z[(((long long)i*k)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            loss = (loss-z[(((long long)i*k)+std::int64_t(yc))])  ;
            if( k > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:se)
                for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                    double ec = exp((z[(((long long)i*k)+c)]-zmax));
                    z[ (((long long)i*k)+c) ] = ec   ;
                    se = (se+ec)  ;
                    ;
                }
            } else {
                for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                    double ec = exp((z[(((long long)i*k)+c)]-zmax));
                    z[ (((long long)i*k)+c) ] = ec   ;
                    se = (se+ec)  ;
                    ;
                }
            }  ;
            loss = (loss+(zmax+log(se)))  ;
            if( k > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                    z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]/se)   ;
                }
            } else {
                for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                    z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]/se)   ;
                }
            }  ;
            std::int64_t iy = ((i*k)+std::int64_t(yc));
            z[ iy ] = (z[iy]-1.0)   ;
            ;
            ;
        }  ;
    }  ;
    scm2cpp::blas_gemm(g, z, x, 1.0, 0.0, 1, 0, k, p, n)  ;
    if( (k*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:pen)
        for( std::int64_t t = 0 ; t < (k*p) ; t += 1 ) {
            double wt = coef[t];
            pen = (pen+(wt*wt))  ;
            g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
            ;
        }
    } else {
        for( std::int64_t t = 0 ; t < (k*p) ; t += 1 ) {
            double wt = coef[t];
            pen = (pen+(wt*wt))  ;
            g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
            ;
        }
    }  ;
    if( k > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            double acc = 0.0;
            if( fitint == 1 ) {
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    acc = (acc+z[(((long long)i*k)+c)])  ;
                }  ;
            } else {
                0  ;
            }  ;
            g[ (((long long)k*p)+c) ] = (acc/double(n))   ;
            ;
        }
    } else {
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            double acc = 0.0;
            if( fitint == 1 ) {
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    acc = (acc+z[(((long long)i*k)+c)])  ;
                }  ;
            } else {
                0  ;
            }  ;
            g[ (((long long)k*p)+c) ] = (acc/double(n))   ;
            ;
        }
    }  ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}


inline std::int64_t
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  std::int64_t  maxiter,  double  tol,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work((n*k),0.0);
    aux[ 0 ] = (1.0/(c*double(n)))   ;
    aux[ 1 ] = ( ( multi == 1 ) ? (1.0) : (0.0) )   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    return lbfgs(0,coef,x,y,aux,work,out,10,maxiter,tol,(64.0*2.220446049250313e-16),50,-1,0.0,(k*(p+1)),n,p,k) ;
}


SCM2CPP_FN inline double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   double b = coef[p];
    double sigma = coef[(p+1)];
    std::int64_t nout = 0;
    double outsum = 0.0;
    double sq = 0.0;
    double csum = 0.0;
    double ww = 0.0;
    scm2cpp::blas_gemv(z, x, coef, 1.0, 0.0, 0, n, p)  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:nout) reduction(+:outsum) reduction(+:sq) reduction(+:csum)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double r = ((y[i]-z[i])-b);
            double a = lb_abs(r);
            if( a > (epsilon*sigma) ) {
                nout = (nout+1)  ;
                outsum = (outsum+a)  ;
                z[ i ] = (-2.0*(epsilon*( ( r < 0.0 ) ? (-1.0) : (1.0) )))   ;
            } else {
                sq = (sq+(r*r))  ;
                z[ i ] = ((-2.0*r)/sigma)   ;
            }  ;
            csum = (csum+z[i])  ;
            ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double r = ((y[i]-z[i])-b);
            double a = lb_abs(r);
            if( a > (epsilon*sigma) ) {
                nout = (nout+1)  ;
                outsum = (outsum+a)  ;
                z[ i ] = (-2.0*(epsilon*( ( r < 0.0 ) ? (-1.0) : (1.0) )))   ;
            } else {
                sq = (sq+(r*r))  ;
                z[ i ] = ((-2.0*r)/sigma)   ;
            }  ;
            csum = (csum+z[i])  ;
            ;
            ;
        }
    }  ;
    scm2cpp::blas_gemv(g, x, z, 1.0, 0.0, 1, p, n)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:ww)
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double wj = coef[j];
            ww = (ww+(wj*wj))  ;
            g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double wj = coef[j];
            ww = (ww+(wj*wj))  ;
            g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
            ;
        }
    }  ;
    g[ p ] = ( ( fitint == 1 ) ? (csum) : (0.0) )   ;
    double sqloss = (sq/sigma);
    double eps2 = (epsilon*epsilon);
    g[ (p+1) ] = ((double(n)-(double(nout)*eps2))-(sqloss/sigma))   ;
    return ((((double(n)*sigma)+sqloss)+((2.0*(epsilon*outsum))-(sigma*(double(nout)*eps2))))+(alpha*ww)) ;
}


inline std::int64_t
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work(n,0.0);
    aux[ 0 ] = epsilon   ;
    aux[ 1 ] = alpha   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    return lbfgs(1,coef,x,y,aux,work,out,10,maxiter,tol,(10000000.0*2.220446049250313e-16),20,(p+1),(10.0*2.220446049250313e-16),(p+2),n,p,1) ;
}


SCM2CPP_FN inline double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  std::int64_t  family,  double  power,  double  l2,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   double loss = 0.0;
    double pen = 0.0;
    double b = coef[p];
    scm2cpp::blas_gemv(z, x, coef, 1.0, 0.0, 0, n, p)  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:loss)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double zi = (z[i]+b);
            double yi = y[i];
            if( (family == 0 || (family == 2 && power == 1.0)) ) {
                double e = exp(zi);
                loss = (loss+(e-(yi*zi)))  ;
                z[ i ] = (e-yi)   ;
                ;
            } else {
                if( (family == 1 || (family == 2 && power == 2.0)) ) {
                    double e2 = exp((0.0-zi));
                    loss = (loss+(zi+(yi*e2)))  ;
                    z[ i ] = (1.0-(yi*e2))   ;
                    ;
                } else {
                    if( family == 3 ) {
                        double r = (zi-yi);
                        loss = (loss+(0.5*(r*r)))  ;
                        z[ i ] = r   ;
                        ;
                    } else {
                        if( power == 0.0 ) {
                            double e3 = exp(zi);
                            loss = (loss+(0.5*((e3-yi)*(e3-yi))))  ;
                            z[ i ] = (e3*(e3-yi))   ;
                            ;
                        } else {
                            double e1 = exp(((1.0-power)*zi));
                            double e4 = exp(((2.0-power)*zi));
                            loss = (loss+((e4/(2.0-power))-((yi*e1)/(1.0-power))))  ;
                            z[ i ] = (e4-(yi*e1))   ;
                            ;
                        }  ;
                    }  ;
                }  ;
            }  ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double zi = (z[i]+b);
            double yi = y[i];
            if( (family == 0 || (family == 2 && power == 1.0)) ) {
                double e = exp(zi);
                loss = (loss+(e-(yi*zi)))  ;
                z[ i ] = (e-yi)   ;
                ;
            } else {
                if( (family == 1 || (family == 2 && power == 2.0)) ) {
                    double e2 = exp((0.0-zi));
                    loss = (loss+(zi+(yi*e2)))  ;
                    z[ i ] = (1.0-(yi*e2))   ;
                    ;
                } else {
                    if( family == 3 ) {
                        double r = (zi-yi);
                        loss = (loss+(0.5*(r*r)))  ;
                        z[ i ] = r   ;
                        ;
                    } else {
                        if( power == 0.0 ) {
                            double e3 = exp(zi);
                            loss = (loss+(0.5*((e3-yi)*(e3-yi))))  ;
                            z[ i ] = (e3*(e3-yi))   ;
                            ;
                        } else {
                            double e1 = exp(((1.0-power)*zi));
                            double e4 = exp(((2.0-power)*zi));
                            loss = (loss+((e4/(2.0-power))-((yi*e1)/(1.0-power))))  ;
                            z[ i ] = (e4-(yi*e1))   ;
                            ;
                        }  ;
                    }  ;
                }  ;
            }  ;
            ;
        }
    }  ;
    scm2cpp::blas_gemv(g, x, z, 1.0, 0.0, 1, p, n)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:pen)
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double wj = coef[j];
            pen = (pen+(wj*wj))  ;
            g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double wj = coef[j];
            pen = (pen+(wj*wj))  ;
            g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
            ;
        }
    }  ;
    double acc = 0.0;
    if( fitint == 1 ) {
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                acc = (acc+z[i])  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                acc = (acc+z[i])  ;
            }
        }  ;
    } else {
        0  ;
    }  ;
    g[ p ] = (acc/double(n))   ;
    ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}


inline std::int64_t
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  std::int64_t  family,  double  power,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work(n,0.0);
    double ym = 0.0;
    aux[ 0 ] = alpha   ;
    aux[ 1 ] = double(family)   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    aux[ 3 ] = power   ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:ym)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ym = (ym+y[i])  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ym = (ym+y[i])  ;
        }
    }  ;
    ym = (ym/double(n))  ;
    coef[ p ] = ( ( fitint == 1 ) ? (( ( family == 3 ) ? (ym) : (log(ym)) )) : (0.0) )   ;
    return lbfgs(2,coef,x,y,aux,work,out,10,maxiter,tol,(64.0*2.220446049250313e-16),50,-1,0.0,(p+1),n,p,1) ;
}


SCM2CPP_FN inline double
lb_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}


SCM2CPP_FN inline double
lb_max( double  a,  double  b )
{
    if( a > b ) {
        return a ;
    }
    else {
        return b ;
    }
}


SCM2CPP_FN inline double
lb_min( double  a,  double  b )
{
    if( a < b ) {
        return a ;
    }
    else {
        return b ;
    }
}


SCM2CPP_FN inline std::int64_t
lb_dcstep( std::array<double,8> & cs,  double  fp,  double  dp,  double  stpmin,  double  stpmax )
{   double stx = cs[0];
    double fx = cs[1];
    double dx = cs[2];
    double sty = cs[3];
    double fy = cs[4];
    double dy = cs[5];
    double stp = cs[6];
    double brackt = cs[7];
    double stpf = 0.0;
    double sgnd = (dp*(dx/lb_abs(dx)));
    if( fp > fx ) {
        double th1 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
        double s1 = lb_max(lb_abs(th1),lb_max(lb_abs(dx),lb_abs(dp)));
        double ga1 = (s1*sqrt((((th1/s1)*(th1/s1))-((dx/s1)*(dp/s1)))));
        double gm1 = ( ( stp < stx ) ? ((0.0-ga1)) : (ga1) );
        double r1 = (((gm1-dx)+th1)/(((gm1-dx)+gm1)+dp));
        double stpc1 = (stx+(r1*(stp-stx)));
        double stpq1 = (stx+(((dx/(((fx-fp)/(stp-stx))+dx))/2.0)*(stp-stx)));
        if( lb_abs(double((stpc1-stx))) < lb_abs(double((stpq1-stx))) ) {
            stpf = stpc1  ;
        } else {
            stpf = (stpc1+((stpq1-stpc1)/2.0))  ;
        }  ;
        brackt = 1.0  ;
        ;
        ;
        ;
        ;
        ;
        ;
        0  ;
    } else {
        if( sgnd < 0.0 ) {
            double th2 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
            double s2 = lb_max(lb_abs(th2),lb_max(lb_abs(dx),lb_abs(dp)));
            double ga2 = (s2*sqrt((((th2/s2)*(th2/s2))-((dx/s2)*(dp/s2)))));
            double gm2 = ( ( stp > stx ) ? ((0.0-ga2)) : (ga2) );
            double r2 = (((gm2-dp)+th2)/(((gm2-dp)+gm2)+dx));
            double stpc2 = (stp+(r2*(stx-stp)));
            double stpq2 = (stp+((dp/(dp-dx))*(stx-stp)));
            if( lb_abs(double((stpc2-stp))) > lb_abs(double((stpq2-stp))) ) {
                stpf = stpc2  ;
            } else {
                stpf = stpq2  ;
            }  ;
            brackt = 1.0  ;
            ;
            ;
            ;
            ;
            ;
            ;
            0  ;
        } else {
            if( lb_abs(dp) < lb_abs(dx) ) {
                double th3 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
                double s3 = lb_max(lb_abs(th3),lb_max(lb_abs(dx),lb_abs(dp)));
                double ga3 = (s3*sqrt(lb_max(0.0,double((((th3/s3)*(th3/s3))-((dx/s3)*(dp/s3)))))));
                double gm3 = ( ( stp > stx ) ? ((0.0-ga3)) : (ga3) );
                double r3 = (((gm3-dp)+th3)/((gm3+(dx-dp))+gm3));
                double stpc3 = ( ( (r3 < 0.0 && !(gm3 == 0.0)) ) ? ((stp+(r3*(stx-stp)))) : (( ( stp > stx ) ? (stpmax) : (stpmin) )) );
                double stpq3 = (stp+((dp/(dp-dx))*(stx-stp)));
                if( brackt == 1.0 ) {
                    if( lb_abs(double((stpc3-stp))) < lb_abs(double((stpq3-stp))) ) {
                        stpf = stpc3  ;
                    } else {
                        stpf = stpq3  ;
                    }  ;
                    if( stp > stx ) {
                        stpf = lb_min(double((stp+(0.66*(sty-stp)))),stpf)  ;
                    } else {
                        stpf = lb_max(double((stp+(0.66*(sty-stp)))),stpf)  ;
                    }  ;
                } else {
                    if( lb_abs(double((stpc3-stp))) > lb_abs(double((stpq3-stp))) ) {
                        stpf = stpc3  ;
                    } else {
                        stpf = stpq3  ;
                    }  ;
                    stpf = lb_min(stpmax,stpf)  ;
                    stpf = lb_max(stpmin,stpf)  ;
                }  ;
                ;
                ;
                ;
                ;
                ;
                ;
                0  ;
            } else {
                if( brackt == 1.0 ) {
                    double th4 = ((((3.0*(fp-fy))/(sty-stp))+dy)+dp);
                    double s4 = lb_max(lb_abs(th4),lb_max(lb_abs(dy),lb_abs(dp)));
                    double ga4 = (s4*sqrt((((th4/s4)*(th4/s4))-((dy/s4)*(dp/s4)))));
                    double gm4 = ( ( stp > sty ) ? ((0.0-ga4)) : (ga4) );
                    double r4 = (((gm4-dp)+th4)/(((gm4-dp)+gm4)+dy));
                    stpf = (stp+(r4*(sty-stp)))  ;
                    ;
                    ;
                    ;
                    ;
                    ;
                    0  ;
                } else {
                    if( stp > stx ) {
                        stpf = stpmax  ;
                    } else {
                        stpf = stpmin  ;
                    }  ;
                }  ;
            }  ;
        }  ;
    }  ;
    if( fp > fx ) {
        cs[ 3 ] = stp   ;
        cs[ 4 ] = fp   ;
        cs[ 5 ] = dp   ;
    } else {
        if( sgnd < 0.0 ) {
            cs[ 3 ] = stx   ;
            cs[ 4 ] = fx   ;
            cs[ 5 ] = dx   ;
        } else {
            0  ;
        }  ;
        cs[ 0 ] = stp   ;
        cs[ 1 ] = fp   ;
        cs[ 2 ] = dp   ;
    }  ;
    cs[ 6 ] = stpf   ;
    cs[ 7 ] = brackt   ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lb_search_start( std::array<double,16> & ls,  double  f,  double  g,  double  stp,  double  stpmin,  double  stpmax,  double  ftol )
{   ls[ 0 ] = 0.0   ;
    ls[ 1 ] = f   ;
    ls[ 2 ] = g   ;
    ls[ 3 ] = 0.0   ;
    ls[ 4 ] = f   ;
    ls[ 5 ] = g   ;
    ls[ 6 ] = 0.0   ;
    ls[ 7 ] = 1.0   ;
    ls[ 8 ] = f   ;
    ls[ 9 ] = g   ;
    ls[ 10 ] = (ftol*g)   ;
    ls[ 11 ] = (stpmax-stpmin)   ;
    ls[ 12 ] = ((stpmax-stpmin)/0.5)   ;
    ls[ 13 ] = 0.0   ;
    ls[ 14 ] = (stp+(4.0*stp))   ;
    ls[ 15 ] = stp   ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax )
{   double stp = ls[15];
    double finit = ls[8];
    double ginit = ls[9];
    double gtest = ls[10];
    std::int64_t task = 0;
    double ftest = (finit+(stp*gtest));
    if( (ls[7] == 1.0 && (f <= ftest && g >= 0.0)) ) {
        ls[ 7 ] = 2.0   ;
    } else {
        0  ;
    }  ;
    if( (ls[6] == 1.0 && (stp <= ls[13] || stp >= ls[14])) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (ls[6] == 1.0 && (ls[14]-ls[13]) <= (xtol*ls[14])) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (stp == stpmax && (f <= ftest && g <= gtest)) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (stp == stpmin && (f > ftest || g >= gtest)) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (f <= ftest && lb_abs(g) <= (gtol*(0.0-ginit))) ) {
        task = 1  ;
    } else {
        0  ;
    }  ;
    if( task == 0 ) {
        cs[ 0 ] = ls[0]   ;
        cs[ 3 ] = ls[3]   ;
        cs[ 6 ] = stp   ;
        cs[ 7 ] = ls[6]   ;
        if( (ls[7] == 1.0 && (f <= ls[1] && f > ftest)) ) {
            cs[ 1 ] = (ls[1]-(ls[0]*gtest))   ;
            cs[ 2 ] = (ls[2]-gtest)   ;
            cs[ 4 ] = (ls[4]-(ls[3]*gtest))   ;
            cs[ 5 ] = (ls[5]-gtest)   ;
            lb_dcstep(cs,double((f-(stp*gtest))),double((g-gtest)),ls[13],ls[14])  ;
            ls[ 1 ] = (cs[1]+(cs[0]*gtest))   ;
            ls[ 2 ] = (cs[2]+gtest)   ;
            ls[ 4 ] = (cs[4]+(cs[3]*gtest))   ;
            ls[ 5 ] = (cs[5]+gtest)   ;
        } else {
            cs[ 1 ] = ls[1]   ;
            cs[ 2 ] = ls[2]   ;
            cs[ 4 ] = ls[4]   ;
            cs[ 5 ] = ls[5]   ;
            lb_dcstep(cs,f,g,ls[13],ls[14])  ;
            ls[ 1 ] = cs[1]   ;
            ls[ 2 ] = cs[2]   ;
            ls[ 4 ] = cs[4]   ;
            ls[ 5 ] = cs[5]   ;
        }  ;
        ls[ 0 ] = cs[0]   ;
        ls[ 3 ] = cs[3]   ;
        ls[ 6 ] = cs[7]   ;
        double nstp = cs[6];
        double stx = cs[0];
        double sty = cs[3];
        if( ls[6] == 1.0 ) {
            if( lb_abs(double((sty-stx))) >= (0.66*ls[12]) ) {
                nstp = (stx+(0.5*(sty-stx)))  ;
            } else {
                0  ;
            }  ;
            ls[ 12 ] = ls[11]   ;
            ls[ 11 ] = lb_abs(double((sty-stx)))   ;
        } else {
            0  ;
        }  ;
        if( ls[6] == 1.0 ) {
            ls[ 13 ] = lb_min(stx,sty)   ;
            ls[ 14 ] = lb_max(stx,sty)   ;
        } else {
            ls[ 13 ] = (nstp+(1.1*(nstp-stx)))   ;
            ls[ 14 ] = (nstp+(4.0*(nstp-stx)))   ;
        }  ;
        nstp = lb_max(nstp,stpmin)  ;
        nstp = lb_min(nstp,stpmax)  ;
        if( (ls[6] == 1.0 && ((nstp <= ls[13] || nstp >= ls[14]) || (ls[14]-ls[13]) <= (xtol*ls[14]))) ) {
            nstp = stx  ;
        } else {
            0  ;
        }  ;
        ls[ 15 ] = nstp   ;
        ;
    } else {
        0  ;
    }  ;
    return task ;
}


SCM2CPP_FN inline double
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  std::int64_t  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(a[j]*b[j]))  ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(a[j]*b[j]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_row( scm2cpp::cspan<double> mem,  std::int64_t  slot,  scm2cpp::cspan<double> v,  std::int64_t  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(mem[(((long long)slot*nv)+j)]*v[j]))  ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(mem[(((long long)slot*nv)+j)]*v[j]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_rows( scm2cpp::cspan<double> a,  std::int64_t  ra,  scm2cpp::cspan<double> b,  std::int64_t  rb,  std::int64_t  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(a[(((long long)ra*nv)+j)]*b[(((long long)rb*nv)+j)]))  ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            acc = (acc+(a[(((long long)ra*nv)+j)]*b[(((long long)rb*nv)+j)]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  std::int64_t  ib,  double  lbv,  std::int64_t  nv )
{   double acc = 0.0;
    for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
        double gj = g[j];
        double gp = ( ( (j == ib && gj >= 0.0) ) ? (lb_min(double((w[j]-lbv)),gj)) : (gj) );
        double v = lb_abs(gp);
        if( v > acc ) {
            acc = v  ;
        } else {
            0  ;
        }  ;
        ;
        ;
        ;
    }  ;
    return acc ;
}


SCM2CPP_FN inline std::int64_t
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv )
{   for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t slot = ((head+((col-1)-ii)) % m);
        double a = (rho[slot]*lb_dot_row(smem,slot,q,nv));
        al[ slot ] = a   ;
        if( nv > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                q[ j ] = (q[j]-(a*ymem[(((long long)slot*nv)+j)]))   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                q[ j ] = (q[j]-(a*ymem[(((long long)slot*nv)+j)]))   ;
            }
        }  ;
        ;
        ;
    }  ;
    if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            q[ j ] = (q[j]/theta)   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            q[ j ] = (q[j]/theta)   ;
        }
    }  ;
    for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t slot2 = ((head+ii) % m);
        double bb = (rho[slot2]*lb_dot_row(ymem,slot2,q,nv));
        if( nv > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                q[ j ] = (q[j]+((al[slot2]-bb)*smem[(((long long)slot2*nv)+j)]))   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                q[ j ] = (q[j]+((al[slot2]-bb)*smem[(((long long)slot2*nv)+j)]))   ;
            }
        }  ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv )
{   for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t si = ((head+ii) % m);
        if( nv > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                bm[ (((long long)ii*nv)+j) ] = (theta*smem[(((long long)si*nv)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                bm[ (((long long)ii*nv)+j) ] = (theta*smem[(((long long)si*nv)+j)])   ;
            }
        }  ;
        for( std::int64_t jj = 0 ; !(jj == ii) ; jj = (jj+1) ) {
            std::int64_t sj = ((head+jj) % m);
            double cb = (lb_dot_rows(bm,jj,smem,si,nv)/sb[jj]);
            double cy = (rho[sj]*lb_dot_rows(ymem,sj,smem,si,nv));
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                bm[ (((long long)ii*nv)+j) ] = ((bm[(((long long)ii*nv)+j)]-(cb*bm[(((long long)jj*nv)+j)]))+(cy*ymem[(((long long)sj*nv)+j)]))   ;
            }  ;
            ;
            ;
        }  ;
        sb[ ii ] = lb_dot_rows(bm,ii,smem,si,nv)   ;
        ;
    }  ;
    double acc = (theta*lb_dot(v,v,nv));
    for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t si2 = ((head+ii) % m);
        double bv = lb_dot_row(bm,ii,v,nv);
        double yv = lb_dot_row(ymem,si2,v,nv);
        acc = ((acc-((bv*bv)/sb[ii]))+(rho[si2]*(yv*yv)))  ;
        ;
        ;
    }  ;
    return acc ;
}


SCM2CPP_FN inline std::int64_t
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  ib,  double  lbv,  std::int64_t  nv )
{   if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            q[ j ] = g[j]   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            q[ j ] = g[j]   ;
        }
    }  ;
    lb_hv(q,smem,ymem,rho,al,theta,col,head,m,nv)  ;
    if( nv > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            d[ j ] = (0.0-q[j])   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
            d[ j ] = (0.0-q[j])   ;
        }
    }  ;
    if( ib >= 0 ) {
        double gs = g[ib];
        double tl = (w[ib]-lbv);
        std::int64_t fixed = 0;
        double delta = 0.0;
        double dtm = 0.0;
        if( (tl <= 0.0 && gs >= 0.0) ) {
            fixed = 1  ;
        } else {
            dtm = (lb_dot(g,g,nv)/lb_vbv(g,smem,ymem,rho,bm,sb,theta,col,head,m,nv))  ;
            if( (gs > 0.0 && dtm >= (tl/gs)) ) {
                fixed = 1  ;
                delta = (0.0-tl)  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( fixed == 1 ) {
            if( nv > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    e[ j ] = 0.0   ;
                }
            } else {
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    e[ j ] = 0.0   ;
                }
            }  ;
            e[ ib ] = 1.0   ;
            lb_hv(e,smem,ymem,rho,al,theta,col,head,m,nv)  ;
            double lam = ((delta+q[ib])/e[ib]);
            if( nv > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    d[ j ] = (d[j]+(lam*e[j]))   ;
                }
            } else {
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    d[ j ] = (d[j]+(lam*e[j]))   ;
                }
            }  ;
            ;
            d[ ib ] = delta   ;
        } else {
            if( (w[ib]+d[ib]) < lbv ) {
                double ddp = ((lb_dot(d,g,nv)-(d[ib]*gs))+((lbv-w[ib])*gs));
                if( ddp > 0.0 ) {
                    double dus = (d[ib]-((0.0-dtm)*gs));
                    double xcps = (w[ib]-(dtm*gs));
                    double alpha = 1.0;
                    if( dus < 0.0 ) {
                        double temp2 = (lbv-xcps);
                        if( temp2 >= 0.0 ) {
                            alpha = 0.0  ;
                        } else {
                            if( dus < temp2 ) {
                                alpha = (temp2/dus)  ;
                            } else {
                                0  ;
                            }  ;
                        }  ;
                        ;
                    } else {
                        0  ;
                    }  ;
                    if( nv > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            double xcpj = ((0.0-dtm)*g[j]);
                            d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
                            ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            double xcpj = ((0.0-dtm)*g[j]);
                            d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
                            ;
                        }
                    }  ;
                    if( alpha < 1.0 ) {
                        d[ ib ] = (lbv-w[ib])   ;
                    } else {
                        0  ;
                    }  ;
                    ;
                } else {
                    d[ ib ] = (lbv-w[ib])   ;
                }  ;
                ;
            } else {
                0  ;
            }  ;
        }  ;
        ;
    } else {
        0  ;
    }  ;
    return 0 ;
}


inline std::int64_t
lbfgs( std::int64_t  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  std::int64_t  m,  std::int64_t  maxiter,  double  pgtol,  double  ftol,  std::int64_t  maxls,  std::int64_t  ib,  double  lbv,  std::int64_t  nv,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::vector<double> g(nv,0.0);
    std::vector<double> gold(nv,0.0);
    std::vector<double> d(nv,0.0);
    std::vector<double> t(nv,0.0);
    std::vector<double> q(nv,0.0);
    std::vector<double> e(nv,0.0);
    std::vector<double> smem((m*nv),0.0);
    std::vector<double> ymem((m*nv),0.0);
    std::vector<double> bm((m*nv),0.0);
    std::vector<double> rho(m,0.0);
    std::vector<double> sb(m,0.0);
    std::vector<double> al(m,0.0);
    std::array<double,16> ls = scm2cpp::filled_array<double,16>(0.0);
    std::array<double,8> cs = scm2cpp::filled_array<double,8>(0.0);
    double eps = 2.220446049250313e-16;
    std::int64_t iter = 0;
    std::int64_t col = 0;
    std::int64_t head = 0;
    double theta = 1.0;
    std::int64_t nfg = 0;
    std::int64_t done = 0;
    double f = lbfgs_fg(kind,w,g,x,y,aux,work,n,p,k);
    nfg = 1  ;
    if( lb_projgr(g,w,ib,lbv,nv) <= pgtol ) {
        done = 1  ;
    } else {
        0  ;
    }  ;
    for(  ; !(done == 1) ;  ) {
        lb_direction(w,g,d,q,e,smem,ymem,rho,al,bm,sb,theta,col,head,m,ib,lbv,nv)  ;
        if( nv > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                t[ j ] = w[j]   ;
                gold[ j ] = g[j]   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                t[ j ] = w[j]   ;
                gold[ j ] = g[j]   ;
            }
        }  ;
        double fold = f;
        double dnorm = sqrt(lb_dot(d,d,nv));
        double gdold = lb_dot(g,d,nv);
        double stpmx = 10000000000.0;
        double gd = 0.0;
        std::int64_t task = 0;
        std::int64_t ifun = 0;
        std::int64_t fail = 0;
        if( ib >= 0 ) {
            if( iter == 0 ) {
                stpmx = 1.0  ;
            } else {
                if( d[ib] < 0.0 ) {
                    double a2 = (lbv-w[ib]);
                    if( a2 >= 0.0 ) {
                        stpmx = 0.0  ;
                    } else {
                        if( (d[ib]*stpmx) < a2 ) {
                            stpmx = (a2/d[ib])  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
            }  ;
        } else {
            0  ;
        }  ;
        if( gdold >= 0.0 ) {
            fail = 1  ;
        } else {
            lb_search_start(ls,f,gdold,( ( iter == 0 ) ? (lb_min(double((1.0/dnorm)),stpmx)) : (1.0) ),0.0,stpmx,0.001)  ;
            for(  ; !((fail == 1 || !(task == 0))) ;  ) {
                ifun = (ifun+1)  ;
                if( ifun > maxls ) {
                    fail = 1  ;
                } else {
                    double stp = ls[15];
                    if( nv > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            w[ j ] = (t[j]+(stp*d[j]))   ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            w[ j ] = (t[j]+(stp*d[j]))   ;
                        }
                    }  ;
                    f = lbfgs_fg(kind,w,g,x,y,aux,work,n,p,k)  ;
                    nfg = (nfg+1)  ;
                    gd = lb_dot(g,d,nv)  ;
                    task = lb_search_step(ls,cs,f,gd,0.001,0.9,0.1,0.0,stpmx)  ;
                    ;
                }  ;
            }  ;
        }  ;
        if( fail == 1 ) {
            if( nv > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    w[ j ] = t[j]   ;
                    g[ j ] = gold[j]   ;
                }
            } else {
                for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                    w[ j ] = t[j]   ;
                    g[ j ] = gold[j]   ;
                }
            }  ;
            f = fold  ;
            if( col == 0 ) {
                done = 1  ;
            } else {
                col = 0  ;
                head = 0  ;
                theta = 1.0  ;
            }  ;
        } else {
            double stp2 = ls[15];
            iter = (iter+1)  ;
            if( iter >= maxiter ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            if( lb_projgr(g,w,ib,lbv,nv) <= pgtol ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            if( (fold-f) <= (ftol*lb_max(lb_max(lb_abs(fold),lb_abs(f)),1.0)) ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            if( done == 0 ) {
                double dr = ((gd-gdold)*stp2);
                double ddum = ((0.0-gdold)*stp2);
                if( dr > (eps*ddum) ) {
                    std::int64_t slot3 = ( ( col < m ) ? (((head+col) % m)) : (head) );
                    double rr = 0.0;
                    if( nv > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:rr)
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            double yj = (g[j]-gold[j]);
                            smem[ (((long long)slot3*nv)+j) ] = (stp2*d[j])   ;
                            ymem[ (((long long)slot3*nv)+j) ] = yj   ;
                            rr = (rr+(yj*yj))  ;
                            ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < nv ; j += 1 ) {
                            double yj = (g[j]-gold[j]);
                            smem[ (((long long)slot3*nv)+j) ] = (stp2*d[j])   ;
                            ymem[ (((long long)slot3*nv)+j) ] = yj   ;
                            rr = (rr+(yj*yj))  ;
                            ;
                        }
                    }  ;
                    rho[ slot3 ] = (1.0/dr)   ;
                    theta = (rr/dr)  ;
                    if( col < m ) {
                        col = (col+1)  ;
                    } else {
                        head = ((head+1) % m)  ;
                    }  ;
                    ;
                    ;
                    0  ;
                } else {
                    0  ;
                }  ;
                ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        ;
    }  ;
    out[ 0 ] = f   ;
    out[ 1 ] = double(nfg)   ;
    return iter ;
}


SCM2CPP_FN inline double
lbfgs_fg( std::int64_t  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{
    if( kind == 0 ) {
        return logistic_fg(w,g,x,y,work,aux[0],( ( aux[1] == 1.0 ) ? (1) : (0) ),( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p,k) ;
    }
    else {
        if( kind == 1 ) {
            return huber_fg(w,g,x,y,work,aux[0],aux[1],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
        else {
            return glm_fg(w,g,x,y,work,std::int64_t(aux[1]),aux[3],aux[0],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
    }
}


SCM2CPP_FN inline std::int64_t
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  std::int64_t  norm,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   double tot = 0.0;
    if( kc > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = 0.0   ;
        }
    } else {
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = 0.0   ;
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        if( kc > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
                weights[ c ] = (weights[c]+resp[(((long long)i*kc)+c)])   ;
            }
        } else {
            for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
                weights[ c ] = (weights[c]+resp[(((long long)i*kc)+c)])   ;
            }
        }  ;
    }  ;
    if( kc > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:tot)
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
            tot = (tot+weights[c])  ;
        }
    } else {
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
            tot = (tot+weights[c])  ;
        }
    }  ;
    scm2cpp::blas_gemm(means, resp, x, 1.0, 0.0, 1, 0, kc, p, n)  ;
    for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
        double nk = weights[c];
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/nk)   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/nk)   ;
            }
        }  ;
        if( (n*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double r = resp[(((long long)i*kc)+c)];
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double dv = (x[(((long long)i*p)+j)]-means[(((long long)c*p)+j)]);
                    u[ (((long long)i*p)+j) ] = dv   ;
                    dw[ (((long long)i*p)+j) ] = (r*dv)   ;
                    ;
                }  ;
                ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double r = resp[(((long long)i*kc)+c)];
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double dv = (x[(((long long)i*p)+j)]-means[(((long long)c*p)+j)]);
                    u[ (((long long)i*p)+j) ] = dv   ;
                    dw[ (((long long)i*p)+j) ] = (r*dv)   ;
                    ;
                }  ;
                ;
            }
        }  ;
        scm2cpp::blas_gemm(cov, dw, u, 1.0, 0.0, 1, 0, p, p, n)  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                cov[ t ] = (cov[t]/nk)   ;
            }
        } else {
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                cov[ t ] = (cov[t]/nk)   ;
            }
        }  ;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            cov[ (((long long)j*p)+j) ] = (cov[(((long long)j*p)+j)]+reg)   ;
        }  ;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double s = cov[(((long long)j*p)+j)];
            for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
                s = (s-(l[(((long long)j*p)+m)]*l[(((long long)j*p)+m)]))  ;
            }  ;
            l[ (((long long)j*p)+j) ] = sqrt(s)   ;
            for( std::int64_t i = (j+1) ; !(i >= p) ; i = (i+1) ) {
                double t2 = cov[(((long long)i*p)+j)];
                for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
                    t2 = (t2-(l[(((long long)i*p)+m)]*l[(((long long)j*p)+m)]))  ;
                }  ;
                l[ (((long long)i*p)+j) ] = (t2/l[(((long long)j*p)+j)])   ;
                ;
            }  ;
            ;
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                prec[ (((long long)c*(p*p))+t) ] = 0.0   ;
            }
        } else {
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                prec[ (((long long)c*(p*p))+t) ] = 0.0   ;
            }
        }  ;
        for( std::int64_t e = 0 ; !(e == p) ; e = (e+1) ) {
            for( std::int64_t i = e ; !(i == p) ; i = (i+1) ) {
                double t3 = ( ( i == e ) ? (1.0) : (0.0) );
                for( std::int64_t m = e ; !(m == i) ; m = (m+1) ) {
                    t3 = (t3-(l[(((long long)i*p)+m)]*prec[(((long long)c*(p*p))+(((long long)e*p)+m))]))  ;
                }  ;
                prec[ (((long long)c*(p*p))+(((long long)e*p)+i)) ] = (t3/l[(((long long)i*p)+i)])   ;
                ;
            }  ;
        }  ;
        ;
    }  ;
    if( kc > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
        }
    } else {
        for( std::int64_t c = 0 ; c < kc ; c += 1 ) {
            weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
        double logdet = 0.0;
        double lw = log(weights[c]);
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                u[ t ] = prec[(((long long)c*(p*p))+t)]   ;
            }
        } else {
            for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
                u[ t ] = prec[(((long long)c*(p*p))+t)]   ;
            }
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:logdet)
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                logdet = (logdet+log(u[(((long long)j*p)+j)]))  ;
                double acc = 0.0;
                for( std::int64_t m = 0 ; !(m == p) ; m = (m+1) ) {
                    acc = (acc+(means[(((long long)c*p)+m)]*u[(((long long)m*p)+j)]))  ;
                }  ;
                mu[ j ] = acc   ;
                ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                logdet = (logdet+log(u[(((long long)j*p)+j)]))  ;
                double acc = 0.0;
                for( std::int64_t m = 0 ; !(m == p) ; m = (m+1) ) {
                    acc = (acc+(means[(((long long)c*p)+m)]*u[(((long long)m*p)+j)]))  ;
                }  ;
                mu[ j ] = acc   ;
                ;
            }
        }  ;
        scm2cpp::blas_gemm(y, x, u, 1.0, 0.0, 0, 0, n, p, p)  ;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double sq = 0.0;
            if( p > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:sq)
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    double v = (y[(((long long)i*p)+j)]-mu[j]);
                    sq = (sq+(v*v))  ;
                    ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    double v = (y[(((long long)i*p)+j)]-mu[j]);
                    sq = (sq+(v*v))  ;
                    ;
                }
            }  ;
            wlp[ (((long long)i*kc)+c) ] = (((-0.5*((double(p)*1.8378770664093453)+sq))+logdet)+lw)   ;
            ;
        }  ;
        ;
    }  ;
    double lb = 0.0;
    if( (n*(kc-1)) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:lb)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double amax = wlp[((long long)i*kc)];
            double se = 0.0;
            for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( wlp[(((long long)i*kc)+c)] > amax ) {
                    amax = wlp[(((long long)i*kc)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                se = (se+exp((wlp[(((long long)i*kc)+c)]-amax)))  ;
            }  ;
            double lse = (log(se)+amax);
            lb = (lb+lse)  ;
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                resp[ (((long long)i*kc)+c) ] = exp((wlp[(((long long)i*kc)+c)]-lse))   ;
            }  ;
            ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double amax = wlp[((long long)i*kc)];
            double se = 0.0;
            for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( wlp[(((long long)i*kc)+c)] > amax ) {
                    amax = wlp[(((long long)i*kc)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                se = (se+exp((wlp[(((long long)i*kc)+c)]-amax)))  ;
            }  ;
            double lse = (log(se)+amax);
            lb = (lb+lse)  ;
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                resp[ (((long long)i*kc)+c) ] = exp((wlp[(((long long)i*kc)+c)]-lse))   ;
            }  ;
            ;
            ;
        }
    }  ;
    return (lb/double(n)) ;
}


SCM2CPP_FN inline double
gmm_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}


inline std::int64_t
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  reg,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   std::vector<double> dw((n*p),0.0);
    std::vector<double> y((n*p),0.0);
    std::vector<double> wlp((n*kc),0.0);
    std::vector<double> cov((p*p),0.0);
    std::vector<double> l((p*p),0.0);
    std::vector<double> u((p*p),0.0);
    std::vector<double> mu(p,0.0);
    double lb = -1e+300;
    std::int64_t it = 0;
    std::int64_t conv = 0;
    std::int64_t done = 0;
    gmm_mstep(x,resp,weights,means,prec,dw,cov,l,y,reg,1,n,p,kc)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        double prev = lb;
        lb = gmm_estep(x,resp,weights,means,prec,wlp,y,u,mu,n,p,kc)  ;
        gmm_mstep(x,resp,weights,means,prec,dw,cov,l,y,reg,0,n,p,kc)  ;
        it = (it+1)  ;
        if( (it > 1 && gmm_abs(double((lb-prev))) < tol) ) {
            conv = 1  ;
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    gmm_estep(x,resp,weights,means,prec,wlp,y,u,mu,n,p,kc)  ;
    if( (n*(kc-1)) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            std::int64_t best = 0;
            double bv = resp[((long long)i*kc)];
            for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( resp[(((long long)i*kc)+c)] > bv ) {
                    bv = resp[(((long long)i*kc)+c)]  ;
                    best = c  ;
                } else {
                    0  ;
                }  ;
            }  ;
            labels[ i ] = double(best)   ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            std::int64_t best = 0;
            double bv = resp[((long long)i*kc)];
            for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( resp[(((long long)i*kc)+c)] > bv ) {
                    bv = resp[(((long long)i*kc)+c)]  ;
                    best = c  ;
                } else {
                    0  ;
                }  ;
            }  ;
            labels[ i ] = double(best)   ;
            ;
        }
    }  ;
    out[ 0 ] = lb   ;
    out[ 1 ] = double(conv)   ;
    return it ;
}


SCM2CPP_FN inline double
eig_hypot( double  a,  double  b )
{
    double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
    double bb = ( ( b < 0.0 ) ? ((0.0-b)) : (b) );
    if( aa > bb ) {
        return (aa*sqrt((1.0+((bb/aa)*(bb/aa))))) ;
    }
    else {
        if( bb == 0.0 ) {
            return 0.0 ;
        }
        else {
            return (bb*sqrt((1.0+((aa/bb)*(aa/bb))))) ;
        }
    }
}


SCM2CPP_FN inline std::int64_t
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m )
{   for( std::int64_t ii = 0 ; !(ii == (m-1)) ; ii = (ii+1) ) {
        std::int64_t i = ((m-1)-ii);
        std::int64_t l = (i-1);
        double h = 0.0;
        double scale = 0.0;
        if( l > 0 ) {
            if( (l+1) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:scale)
                for( std::int64_t k = 0 ; k <= l ; k += 1 ) {
                    double ak = a[(((long long)i*m)+k)];
                    scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                    ;
                }
            } else {
                for( std::int64_t k = 0 ; k <= l ; k += 1 ) {
                    double ak = a[(((long long)i*m)+k)];
                    scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                    ;
                }
            }  ;
            if( scale == 0.0 ) {
                e[ i ] = a[(((long long)i*m)+l)]   ;
            } else {
                if( (l+1) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:h)
                    for( std::int64_t k = 0 ; k <= l ; k += 1 ) {
                        a[ (((long long)i*m)+k) ] = (a[(((long long)i*m)+k)]/scale)   ;
                        h = (h+(a[(((long long)i*m)+k)]*a[(((long long)i*m)+k)]))  ;
                    }
                } else {
                    for( std::int64_t k = 0 ; k <= l ; k += 1 ) {
                        a[ (((long long)i*m)+k) ] = (a[(((long long)i*m)+k)]/scale)   ;
                        h = (h+(a[(((long long)i*m)+k)]*a[(((long long)i*m)+k)]))  ;
                    }
                }  ;
                double f = a[(((long long)i*m)+l)];
                double g = ( ( f >= 0.0 ) ? ((0.0-sqrt(h))) : (sqrt(h)) );
                e[ i ] = (scale*g)   ;
                h = (h-(f*g))  ;
                a[ (((long long)i*m)+l) ] = (f-g)   ;
                double ff = 0.0;
                for( std::int64_t j = 0 ; !(j > l) ; j = (j+1) ) {
                    a[ (((long long)j*m)+i) ] = (a[(((long long)i*m)+j)]/h)   ;
                    double gg = 0.0;
                    if( (j+1) > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:gg)
                        for( std::int64_t k = 0 ; k <= j ; k += 1 ) {
                            gg = (gg+(a[(((long long)j*m)+k)]*a[(((long long)i*m)+k)]))  ;
                        }
                    } else {
                        for( std::int64_t k = 0 ; k <= j ; k += 1 ) {
                            gg = (gg+(a[(((long long)j*m)+k)]*a[(((long long)i*m)+k)]))  ;
                        }
                    }  ;
                    if( ((l+1)-(j+1)) > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:gg)
                        for( std::int64_t k = (j+1) ; k <= l ; k += 1 ) {
                            gg = (gg+(a[(((long long)k*m)+j)]*a[(((long long)i*m)+k)]))  ;
                        }
                    } else {
                        for( std::int64_t k = (j+1) ; k <= l ; k += 1 ) {
                            gg = (gg+(a[(((long long)k*m)+j)]*a[(((long long)i*m)+k)]))  ;
                        }
                    }  ;
                    e[ j ] = (gg/h)   ;
                    ff = (ff+(e[j]*a[(((long long)i*m)+j)]))  ;
                    ;
                }  ;
                double hh = (ff/(h+h));
                for( std::int64_t j = 0 ; !(j > l) ; j = (j+1) ) {
                    double f2 = a[(((long long)i*m)+j)];
                    double g2 = (e[j]-(hh*f2));
                    e[ j ] = g2   ;
                    for( std::int64_t k = 0 ; !(k > j) ; k = (k+1) ) {
                        a[ (((long long)j*m)+k) ] = (a[(((long long)j*m)+k)]-((f2*e[k])+(g2*a[(((long long)i*m)+k)])))   ;
                    }  ;
                    ;
                    ;
                }  ;
                ;
                ;
                ;
                ;
            }  ;
        } else {
            e[ i ] = a[(((long long)i*m)+l)]   ;
        }  ;
        ev[ i ] = h   ;
        ;
        ;
    }  ;
    ev[ 0 ] = 0.0   ;
    e[ 0 ] = 0.0   ;
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        if( !(ev[i] == 0.0) ) {
            for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
                double g3 = 0.0;
                if( i > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:g3)
                    for( std::int64_t k = 0 ; k < i ; k += 1 ) {
                        g3 = (g3+(a[(((long long)i*m)+k)]*a[(((long long)k*m)+j)]))  ;
                    }
                } else {
                    for( std::int64_t k = 0 ; k < i ; k += 1 ) {
                        g3 = (g3+(a[(((long long)i*m)+k)]*a[(((long long)k*m)+j)]))  ;
                    }
                }  ;
                for( std::int64_t k = 0 ; !(k == i) ; k = (k+1) ) {
                    a[ (((long long)k*m)+j) ] = (a[(((long long)k*m)+j)]-(g3*a[(((long long)k*m)+i)]))   ;
                }  ;
                ;
            }  ;
        } else {
            0  ;
        }  ;
        ev[ i ] = a[(((long long)i*m)+i)]   ;
        a[ (((long long)i*m)+i) ] = 1.0   ;
        for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
            a[ (((long long)j*m)+i) ] = 0.0   ;
            a[ (((long long)i*m)+j) ] = 0.0   ;
        }  ;
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ (((long long)j*m)+i) ] = a[(((long long)i*m)+j)]   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ (((long long)j*m)+i) ] = a[(((long long)i*m)+j)]   ;
            }  ;
        }
    }  ;
    for( std::int64_t i = 1 ; !(i == m) ; i = (i+1) ) {
        e[ (i-1) ] = e[i]   ;
    }  ;
    e[ (m-1) ] = 0.0   ;
    for( std::int64_t l = 0 ; !(l == m) ; l = (l+1) ) {
        std::int64_t fin = 0;
        std::int64_t iter = 0;
        for(  ; !((fin == 1 || iter > 60)) ;  ) {
            std::int64_t mm = l;
            std::int64_t found = 0;
            for(  ; !((found == 1 || mm >= (m-1))) ;  ) {
                double dd = (eig_abs(ev[mm])+eig_abs(ev[(mm+1)]));
                if( (eig_abs(e[mm])+dd) == dd ) {
                    found = 1  ;
                } else {
                    mm = (mm+1)  ;
                }  ;
                ;
            }  ;
            if( mm == l ) {
                fin = 1  ;
            } else {
                iter = (iter+1)  ;
                double g = ((ev[(l+1)]-ev[l])/(2.0*e[l]));
                double r = eig_hypot(g,1.0);
                double g4 = ((ev[mm]-ev[l])+(e[l]/(g+( ( g >= 0.0 ) ? (eig_abs(r)) : ((0.0-eig_abs(r))) ))));
                double s = 1.0;
                double c = 1.0;
                double pp = 0.0;
                double gq = g4;
                std::int64_t under = 0;
                std::int64_t i = (mm-1);
                for(  ; !((under == 1 || i < l)) ;  ) {
                    double f = (s*e[i]);
                    double b = (c*e[i]);
                    double r2 = eig_hypot(f,gq);
                    e[ (i+1) ] = r2   ;
                    if( r2 == 0.0 ) {
                        ev[ (i+1) ] = (ev[(i+1)]-pp)   ;
                        e[ mm ] = 0.0   ;
                        under = 1  ;
                    } else {
                        s = (f/r2)  ;
                        c = (gq/r2)  ;
                        double g5 = (ev[(i+1)]-pp);
                        double r3 = (((ev[i]-g5)*s)+(2.0*(c*b)));
                        pp = (s*r3)  ;
                        ev[ (i+1) ] = (g5+pp)   ;
                        gq = ((c*r3)-b)  ;
                        ;
                        ;
                        for( std::int64_t k = 0 ; !(k == m) ; k = (k+1) ) {
                            double zf = v[(((long long)((i+1))*m)+k)];
                            double zi = v[(((long long)i*m)+k)];
                            v[ (((long long)((i+1))*m)+k) ] = ((s*zi)+(c*zf))   ;
                            v[ (((long long)i*m)+k) ] = ((c*zi)-(s*zf))   ;
                            ;
                        }  ;
                        i = (i-1)  ;
                    }  ;
                    ;
                    ;
                }  ;
                if( under == 0 ) {
                    ev[ l ] = (ev[l]-pp)   ;
                    e[ l ] = gq   ;
                    e[ mm ] = 0.0   ;
                } else {
                    0  ;
                }  ;
                ;
                ;
                ;
                ;
            }  ;
            ;
        }  ;
        ;
    }  ;
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        for( std::int64_t j = (i+1) ; !(j >= m) ; j = (j+1) ) {
            double tmp = v[(((long long)i*m)+j)];
            v[ (((long long)i*m)+j) ] = v[(((long long)j*m)+i)]   ;
            v[ (((long long)j*m)+i) ] = tmp   ;
            ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
eig_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}


SCM2CPP_FN inline std::int64_t
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  std::int64_t  m )
{   if( m > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            ord[ j ] = j   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            ord[ j ] = j   ;
        }
    }  ;
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        std::int64_t best = j;
        for( std::int64_t r = (j+1) ; !(r >= m) ; r = (r+1) ) {
            if( ev[ord[r]] > ev[ord[best]] ) {
                best = r  ;
            } else {
                0  ;
            }  ;
        }  ;
        std::int64_t tmp = ord[j];
        ord[ j ] = ord[best]   ;
        ord[ best ] = tmp   ;
        ;
        ;
    }  ;
    return 0 ;
}

template< typename Unknown_type3800Type >
std::int64_t
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  Unknown_type3800Type  e,  std::int64_t  m,  std::int64_t  k )
{   std::vector<double> vf((m*m),0.0);
    std::vector<double> evf(m,0.0);
    std::vector<int> ord(m,0);
    scm2cpp::lapack_syevd(a, vf, evf, m)  ;
    eig_order(evf,ord,m)  ;
    if( (k*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            std::int64_t col = ord[c];
            ev[ c ] = evf[col]   ;
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ (((long long)j*k)+c) ] = vf[(((long long)j*m)+col)]   ;
            }  ;
            ;
        }
    } else {
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            std::int64_t col = ord[c];
            ev[ c ] = evf[col]   ;
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ (((long long)j*k)+c) ] = vf[(((long long)j*m)+col)]   ;
            }  ;
            ;
        }
    }  ;
    return 0 ;
}

template< typename Unknown_type3799Type >
std::int64_t
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  Unknown_type3799Type  e,  std::int64_t  m )
{   for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        double d = b[(((long long)j*m)+j)];
        for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
            d = (d-(b[(((long long)j*m)+l)]*b[(((long long)j*m)+l)]))  ;
        }  ;
        b[ (((long long)j*m)+j) ] = sqrt(d)   ;
        for( std::int64_t i = (j+1) ; !(i >= m) ; i = (i+1) ) {
            double s = b[(((long long)i*m)+j)];
            for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*b[(((long long)j*m)+l)]))  ;
            }  ;
            b[ (((long long)i*m)+j) ] = (s/b[(((long long)j*m)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[(((long long)i*m)+c)];
            for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*a[(((long long)l*m)+c)]))  ;
            }  ;
            a[ (((long long)i*m)+c) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
        }  ;
    }  ;
    for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[(((long long)r*m)+i)];
            for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*a[(((long long)r*m)+l)]))  ;
            }  ;
            a[ (((long long)r*m)+i) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
        }  ;
    }  ;
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
            double s = (0.5*(a[(((long long)i*m)+j)]+a[(((long long)j*m)+i)]));
            a[ (((long long)i*m)+j) ] = s   ;
            a[ (((long long)j*m)+i) ] = s   ;
            ;
        }  ;
    }  ;
    scm2cpp::lapack_syevd(a, v, ev, m)  ;
    for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
        for( std::int64_t ii = 0 ; !(ii == m) ; ii = (ii+1) ) {
            std::int64_t i = ((m-1)-ii);
            double s = v[(((long long)i*m)+c)];
            for( std::int64_t l = (i+1) ; !(l >= m) ; l = (l+1) ) {
                s = (s-(b[(((long long)l*m)+i)]*v[(((long long)l*m)+c)]))  ;
            }  ;
            v[ (((long long)i*m)+c) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
ica_tanh( double  x )
{
    return (1.0-(2.0/(exp((2.0*x))+1.0))) ;
}


SCM2CPP_FN inline std::int64_t
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  scm2cpp::span<double> t,  std::int64_t  m )
{   if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
                }  ;
                a[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
                }  ;
                a[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    scm2cpp::lapack_syevd(a, v, ev, m)  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                    acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
                    ;
                }  ;
                t[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                    acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
                    ;
                }  ;
                t[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
                }  ;
                a[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
                }  ;
                a[ (((long long)i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t t2 = 0 ; t2 < (m*m) ; t2 += 1 ) {
            w[ t2 ] = a[t2]   ;
        }
    } else {
        for( std::int64_t t2 = 0 ; t2 < (m*m) ; t2 += 1 ) {
            w[ t2 ] = a[t2]   ;
        }
    }  ;
    return 0 ;
}


inline std::int64_t
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  std::int64_t  maxiter,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nc )
{   std::vector<double> xc((n*p),0.0);
    std::vector<double> g((p*p),0.0);
    std::vector<double> u((p*p),0.0);
    std::vector<double> ev(p,0.0);
    std::vector<int> ord(p,0);
    std::vector<double> x1((nc*n),0.0);
    std::vector<double> gw((nc*n),0.0);
    std::vector<double> w1((nc*nc),0.0);
    std::vector<double> gx(nc,0.0);
    std::vector<double> sa((nc*nc),0.0);
    std::vector<double> sv((nc*nc),0.0);
    std::vector<double> se(nc,0.0);
    std::vector<double> se2(nc,0.0);
    std::vector<double> pe(p,0.0);
    std::vector<double> st((nc*nc),0.0);
    std::int64_t it = 0;
    std::int64_t done = 0;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = 0.0   ;
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    }  ;
    if( (n*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mean[j])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mean[j])   ;
            }  ;
        }
    }  ;
    scm2cpp::blas_syrk(g, xc, 1.0, 0.0, 1, p, n)  ;
    scm2cpp::lapack_syevd(g, u, ev, p)  ;
    eig_order(ev,ord,p)  ;
    if( (nc*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            std::int64_t col = ord[c];
            double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
            double d = sqrt(ev[col]);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                white[ (((long long)c*p)+j) ] = ((sg*u[(((long long)j*p)+col)])/d)   ;
            }  ;
            ;
            ;
        }
    } else {
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            std::int64_t col = ord[c];
            double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
            double d = sqrt(ev[col]);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                white[ (((long long)c*p)+j) ] = ((sg*u[(((long long)j*p)+col)])/d)   ;
            }  ;
            ;
            ;
        }
    }  ;
    scm2cpp::blas_gemm(x1, white, xc, 1.0, 0.0, 0, 1, nc, n, p)  ;
    double sn = sqrt(double(n));
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t t = 0 ; t < (nc*n) ; t += 1 ) {
            x1[ t ] = (x1[t]*sn)   ;
        }
    } else {
        for( std::int64_t t = 0 ; t < (nc*n) ; t += 1 ) {
            x1[ t ] = (x1[t]*sn)   ;
        }
    }  ;
    ;
    if( (nc*nc) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t t = 0 ; t < (nc*nc) ; t += 1 ) {
            unmix[ t ] = winit[t]   ;
        }
    } else {
        for( std::int64_t t = 0 ; t < (nc*nc) ; t += 1 ) {
            unmix[ t ] = winit[t]   ;
        }
    }  ;
    ica_sym(unmix,sa,sv,se,se2,st,nc)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        scm2cpp::blas_gemm(gw, unmix, x1, 1.0, 0.0, 0, 0, nc, n, nc)  ;
        if( (nc*n) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
                double acc = 0.0;
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    double th = ica_tanh(gw[(((long long)c*n)+i)]);
                    gw[ (((long long)c*n)+i) ] = th   ;
                    acc = (acc+(1.0-(th*th)))  ;
                    ;
                }  ;
                gx[ c ] = (acc/double(n))   ;
                ;
            }
        } else {
            for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
                double acc = 0.0;
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    double th = ica_tanh(gw[(((long long)c*n)+i)]);
                    gw[ (((long long)c*n)+i) ] = th   ;
                    acc = (acc+(1.0-(th*th)))  ;
                    ;
                }  ;
                gx[ c ] = (acc/double(n))   ;
                ;
            }
        }  ;
        scm2cpp::blas_gemm(w1, gw, x1, 1.0, 0.0, 0, 1, nc, nc, n)  ;
        if( (nc*nc) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
                for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                    w1[ (((long long)c*nc)+j) ] = ((w1[(((long long)c*nc)+j)]/double(n))-(gx[c]*unmix[(((long long)c*nc)+j)]))   ;
                }  ;
            }
        } else {
            for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
                for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                    w1[ (((long long)c*nc)+j) ] = ((w1[(((long long)c*nc)+j)]/double(n))-(gx[c]*unmix[(((long long)c*nc)+j)]))   ;
                }  ;
            }
        }  ;
        ica_sym(w1,sa,sv,se,se2,st,nc)  ;
        double lim = 0.0;
        for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
            double acc = 0.0;
            if( nc > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
                for( std::int64_t j = 0 ; j < nc ; j += 1 ) {
                    acc = (acc+(w1[(((long long)c*nc)+j)]*unmix[(((long long)c*nc)+j)]))  ;
                }
            } else {
                for( std::int64_t j = 0 ; j < nc ; j += 1 ) {
                    acc = (acc+(w1[(((long long)c*nc)+j)]*unmix[(((long long)c*nc)+j)]))  ;
                }
            }  ;
            double dv = (( ( acc < 0.0 ) ? ((0.0-acc)) : (acc) )-1.0);
            double av = ( ( dv < 0.0 ) ? ((0.0-dv)) : (dv) );
            if( av > lim ) {
                lim = av  ;
            } else {
                0  ;
            }  ;
            ;
            ;
            ;
        }  ;
        if( (nc*nc) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t t = 0 ; t < (nc*nc) ; t += 1 ) {
                unmix[ t ] = w1[t]   ;
            }
        } else {
            for( std::int64_t t = 0 ; t < (nc*nc) ; t += 1 ) {
                unmix[ t ] = w1[t]   ;
            }
        }  ;
        it = (it+1)  ;
        if( lim < tol ) {
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    if( (nc*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                }  ;
                comps[ (((long long)c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                }  ;
                comps[ (((long long)c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(gw, comps, xc, 1.0, 0.0, 0, 1, nc, n, p)  ;
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            double m1 = 0.0;
            double v1 = 0.0;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                m1 = (m1+gw[(((long long)c*n)+i)])  ;
            }  ;
            m1 = (m1/double(n))  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double dd = (gw[(((long long)c*n)+i)]-m1);
                v1 = (v1+(dd*dd))  ;
                ;
            }  ;
            double sd = sqrt((v1/double(n)));
            for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                unmix[ (((long long)c*nc)+j) ] = (unmix[(((long long)c*nc)+j)]/sd)   ;
            }  ;
            ;
            ;
        }
    } else {
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            double m1 = 0.0;
            double v1 = 0.0;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                m1 = (m1+gw[(((long long)c*n)+i)])  ;
            }  ;
            m1 = (m1/double(n))  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double dd = (gw[(((long long)c*n)+i)]-m1);
                v1 = (v1+(dd*dd))  ;
                ;
            }  ;
            double sd = sqrt((v1/double(n)));
            for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                unmix[ (((long long)c*nc)+j) ] = (unmix[(((long long)c*nc)+j)]/sd)   ;
            }  ;
            ;
            ;
        }
    }  ;
    if( (nc*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                }  ;
                comps[ (((long long)c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t c = 0 ; c < nc ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                }  ;
                comps[ (((long long)c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    return it ;
}


inline std::int64_t
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  std::int64_t  n,  std::int64_t  p )
{   std::vector<double> c((p*p),0.0);
    std::vector<double> v((p*p),0.0);
    std::vector<double> e(p,0.0);
    std::vector<double> sc(p,0.0);
    std::vector<int> ord(p,0);
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = 0.0   ;
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    }  ;
    scm2cpp::blas_syrk(c, x, 1.0, 0.0, 1, p, n)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                c[ (((long long)i*p)+j) ] = ((c[(((long long)i*p)+j)]-(double(n)*(mean[i]*mean[j])))/double((n-1)))   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                c[ (((long long)i*p)+j) ] = ((c[(((long long)i*p)+j)]-(double(n)*(mean[i]*mean[j])))/double((n-1)))   ;
            }  ;
        }
    }  ;
    scm2cpp::lapack_syevd(c, v, e, p)  ;
    eig_order(e,ord,p)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            double lam = ( ( e[col] < 0.0 ) ? (0.0) : (e[col]) );
            std::int64_t big = 0;
            double bv = -1.0;
            ev[ r ] = lam   ;
            sv[ r ] = sqrt((lam*double((n-1))))   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double a = v[(((long long)j*p)+col)];
                double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
                if( aa > bv ) {
                    bv = aa  ;
                    big = j  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
            }  ;
            double sg = ( ( v[(((long long)big*p)+col)] < 0.0 ) ? (-1.0) : (1.0) );
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                comps[ (((long long)r*p)+j) ] = (sg*v[(((long long)j*p)+col)])   ;
            }  ;
            ;
            ;
            ;
        }
    } else {
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            double lam = ( ( e[col] < 0.0 ) ? (0.0) : (e[col]) );
            std::int64_t big = 0;
            double bv = -1.0;
            ev[ r ] = lam   ;
            sv[ r ] = sqrt((lam*double((n-1))))   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double a = v[(((long long)j*p)+col)];
                double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
                if( aa > bv ) {
                    bv = aa  ;
                    big = j  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
            }  ;
            double sg = ( ( v[(((long long)big*p)+col)] < 0.0 ) ? (-1.0) : (1.0) );
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                comps[ (((long long)r*p)+j) ] = (sg*v[(((long long)j*p)+col)])   ;
            }  ;
            ;
            ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
ard_pinvh( scm2cpp::span<double> a,  scm2cpp::span<double> s,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  std::int64_t  k )
{   scm2cpp::lapack_syevd(a, v, ev, k)  ;
    double mx = 0.0;
    for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
        double av = ( ( ev[r] < 0.0 ) ? ((0.0-ev[r])) : (ev[r]) );
        if( av > mx ) {
            mx = av  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    double cut = (mx*(double(k)*2.220446049250313e-16));
    if( (k*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < k ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == k) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                    double er = ev[r];
                    if( ( ( er < 0.0 ) ? ((0.0-er)) : (er) ) > cut ) {
                        acc = (acc+((v[(((long long)i*k)+r)]*v[(((long long)j*k)+r)])/er))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
                s[ (((long long)i*k)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < k ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == k) ; j = (j+1) ) {
                double acc = 0.0;
                for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                    double er = ev[r];
                    if( ( ( er < 0.0 ) ? ((0.0-er)) : (er) ) > cut ) {
                        acc = (acc+((v[(((long long)i*k)+r)]*v[(((long long)j*k)+r)])/er))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
                s[ (((long long)i*k)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    ;
    ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
ard_sigma_coef( scm2cpp::cspan<double> xy,  scm2cpp::cspan<int> idx,  scm2cpp::cspan<double> lam,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::cspan<double> e,  scm2cpp::cspan<double> gk,  double  alpha,  std::int64_t  k )
{   if( (k*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                a[ (((long long)r*k)+c) ] = (( ( r == c ) ? (lam[idx[r]]) : (0.0) )+(alpha*gk[(((long long)r*k)+c)]))   ;
            }  ;
        }
    } else {
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                a[ (((long long)r*k)+c) ] = (( ( r == c ) ? (lam[idx[r]]) : (0.0) )+(alpha*gk[(((long long)r*k)+c)]))   ;
            }  ;
        }
    }  ;
    ard_pinvh(a,sigma,v,ev,e,k)  ;
    for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
        double acc = 0.0;
        if( k > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
            for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                acc = (acc+(sigma[(((long long)r*k)+c)]*xy[idx[c]]))  ;
            }
        } else {
            for( std::int64_t c = 0 ; c < k ; c += 1 ) {
                acc = (acc+(sigma[(((long long)r*k)+c)]*xy[idx[c]]))  ;
            }
        }  ;
        coef[ idx[r] ] = (alpha*acc)   ;
        ;
    }  ;
    return 0 ;
}


inline std::int64_t
ard( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> lam,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  alpha1,  double  alpha2,  double  lambda1,  double  lambda2,  double  thresh,  std::int64_t  hoist,  std::int64_t  n,  std::int64_t  p )
{   std::vector<double> g(( ( hoist == 1 ) ? ((p*p)) : (1) ),0.0);
    std::vector<double> xy(p,0.0);
    std::vector<double> xk(( ( hoist == 1 ) ? (1) : ((n*p)) ),0.0);
    std::vector<double> gk((p*p),0.0);
    std::vector<double> a((p*p),0.0);
    std::vector<double> v((p*p),0.0);
    std::vector<double> ev(p,0.0);
    std::vector<double> e(p,0.0);
    std::vector<double> r(n,0.0);
    std::vector<int> idx(p,0);
    std::vector<int> keep(p,1);
    std::vector<double> old(p,0.0);
    double alpha = 0.0;
    std::int64_t k = p;
    std::int64_t it = 0;
    std::int64_t done = 0;
    if( hoist == 1 ) {
        scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    } else {
        0  ;
    }  ;
    scm2cpp::blas_gemv(xy, x, y, 1.0, 0.0, 1, p, n)  ;
    double ym = 0.0;
    double vy = 0.0;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:ym)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ym = (ym+y[i])  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ym = (ym+y[i])  ;
        }
    }  ;
    ym = (ym/double(n))  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:vy)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            vy = (vy+((y[i]-ym)*(y[i]-ym)))  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            vy = (vy+((y[i]-ym)*(y[i]-ym)))  ;
        }
    }  ;
    alpha = (1.0/((vy/double(n))+2.220446049250313e-16))  ;
    ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            lam[ j ] = 1.0   ;
            coef[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            lam[ j ] = 1.0   ;
            coef[ j ] = 0.0   ;
        }
    }  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        k = 0  ;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            if( keep[j] == 1 ) {
                idx[ k ] = j   ;
                k = (k+1)  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( hoist == 1 ) {
            if( (k*k) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ (((long long)r*k)+c) ] = g[(((long long)(idx[r])*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ (((long long)r*k)+c) ] = g[(((long long)(idx[r])*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
        } else {
            if( (n*k) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ (((long long)i*k)+c) ] = x[(((long long)i*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ (((long long)i*k)+c) ] = x[(((long long)i*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
            scm2cpp::blas_syrk(gk, xk, 1.0, 0.0, 1, k, n)  ;
        }  ;
        ard_sigma_coef(xy,idx,lam,coef,sigma,a,v,ev,e,gk,alpha,k)  ;
        scm2cpp::blas_gemv(r, x, coef, 1.0, 0.0, 0, n, p)  ;
        double sse = 0.0;
        double gsum = 0.0;
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:sse)
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double d = (y[i]-r[i]);
                sse = (sse+(d*d))  ;
                ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double d = (y[i]-r[i]);
                sse = (sse+(d*d))  ;
                ;
            }
        }  ;
        for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
            std::int64_t j = idx[c];
            double gm = (1.0-(lam[j]*sigma[(((long long)c*k)+c)]));
            gsum = (gsum+gm)  ;
            lam[ j ] = ((gm+(2.0*lambda1))/((coef[j]*coef[j])+(2.0*lambda2)))   ;
            ;
            ;
        }  ;
        alpha = (((double(n)-gsum)+(2.0*alpha1))/(sse+(2.0*alpha2)))  ;
        ;
        std::int64_t nk = 0;
        double moved = 0.0;
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:nk) reduction(+:moved)
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                if( lam[j] < thresh ) {
                    keep[ j ] = 1   ;
                    nk = (nk+1)  ;
                } else {
                    keep[ j ] = 0   ;
                    coef[ j ] = 0.0   ;
                }  ;
                double dv = (old[j]-coef[j]);
                moved = (moved+( ( dv < 0.0 ) ? ((0.0-dv)) : (dv) ))  ;
                ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                if( lam[j] < thresh ) {
                    keep[ j ] = 1   ;
                    nk = (nk+1)  ;
                } else {
                    keep[ j ] = 0   ;
                    coef[ j ] = 0.0   ;
                }  ;
                double dv = (old[j]-coef[j]);
                moved = (moved+( ( dv < 0.0 ) ? ((0.0-dv)) : (dv) ))  ;
                ;
            }
        }  ;
        if( (it > 0 && moved < tol) ) {
            done = 1  ;
        } else {
            if( p > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    old[ j ] = coef[j]   ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    old[ j ] = coef[j]   ;
                }
            }  ;
            if( nk == 0 ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
        }  ;
        ;
        it = (it+1)  ;
    }  ;
    k = 0  ;
    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
        if( keep[j] == 1 ) {
            idx[ k ] = j   ;
            k = (k+1)  ;
        } else {
            0  ;
        }  ;
    }  ;
    if( k > 0 ) {
        if( hoist == 1 ) {
            if( (k*k) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ (((long long)r*k)+c) ] = g[(((long long)(idx[r])*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ (((long long)r*k)+c) ] = g[(((long long)(idx[r])*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
        } else {
            if( (n*k) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ (((long long)i*k)+c) ] = x[(((long long)i*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ (((long long)i*k)+c) ] = x[(((long long)i*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
            scm2cpp::blas_syrk(gk, xk, 1.0, 0.0, 1, k, n)  ;
        }  ;
        ard_sigma_coef(xy,idx,lam,coef,sigma,a,v,ev,e,gk,alpha,k)  ;
    } else {
        0  ;
    }  ;
    out[ 0 ] = alpha   ;
    out[ 1 ] = double(k)   ;
    return it ;
}


inline std::int64_t
f_regression( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> r,  scm2cpp::span<double> f,  std::int64_t  center,  std::int64_t  n,  std::int64_t  p,  std::int64_t  q )
{   std::vector<double> mx(p,0.0);
    std::vector<double> sx(p,0.0);
    std::vector<double> yc((n*q),0.0);
    std::vector<double> yn(q,0.0);
    double dof = double((n-( ( center == 1 ) ? (2) : (1) )));
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                double v = x[(((long long)i*p)+j)];
                mx[ j ] = (mx[j]+v)   ;
                sx[ j ] = (sx[j]+(v*v))   ;
                ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                double v = x[(((long long)i*p)+j)];
                mx[ j ] = (mx[j]+v)   ;
                sx[ j ] = (sx[j]+(v*v))   ;
                ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    }  ;
    if( (q*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t t = 0 ; t < q ; t += 1 ) {
            double m = 0.0;
            double s = 0.0;
            if( center == 1 ) {
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    m = (m+y[(((long long)i*q)+t)])  ;
                }  ;
                m = (m/double(n))  ;
            } else {
                0  ;
            }  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double v = (y[(((long long)i*q)+t)]-m);
                yc[ (((long long)i*q)+t) ] = v   ;
                s = (s+(v*v))  ;
                ;
            }  ;
            yn[ t ] = sqrt(s)   ;
            ;
        }
    } else {
        for( std::int64_t t = 0 ; t < q ; t += 1 ) {
            double m = 0.0;
            double s = 0.0;
            if( center == 1 ) {
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    m = (m+y[(((long long)i*q)+t)])  ;
                }  ;
                m = (m/double(n))  ;
            } else {
                0  ;
            }  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double v = (y[(((long long)i*q)+t)]-m);
                yc[ (((long long)i*q)+t) ] = v   ;
                s = (s+(v*v))  ;
                ;
            }  ;
            yn[ t ] = sqrt(s)   ;
            ;
        }
    }  ;
    scm2cpp::blas_gemm(r, x, yc, 1.0, 0.0, 1, 0, p, q, n)  ;
    if( (p*q) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double xn = sqrt(( ( center == 1 ) ? ((sx[j]-(double(n)*(mx[j]*mx[j])))) : (sx[j]) ));
            for( std::int64_t t = 0 ; !(t == q) ; t = (t+1) ) {
                double rr = ((r[(((long long)j*q)+t)]/xn)/yn[t]);
                r[ (((long long)j*q)+t) ] = rr   ;
                f[ (((long long)j*q)+t) ] = (((rr*rr)/(1.0-(rr*rr)))*dof)   ;
                ;
            }  ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double xn = sqrt(( ( center == 1 ) ? ((sx[j]-(double(n)*(mx[j]*mx[j])))) : (sx[j]) ));
            for( std::int64_t t = 0 ; !(t == q) ; t = (t+1) ) {
                double rr = ((r[(((long long)j*q)+t)]/xn)/yn[t]);
                r[ (((long long)j*q)+t) ] = rr   ;
                f[ (((long long)j*q)+t) ] = (((rr*rr)/(1.0-(rr*rr)))*dof)   ;
                ;
            }  ;
            ;
        }
    }  ;
    return 0 ;
}


inline std::int64_t
f_classif( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> f,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::vector<double> oh((n*k),0.0);
    std::vector<double> cs((k*p),0.0);
    std::vector<double> cnt(k,0.0);
    std::vector<double> ss(p,0.0);
    std::vector<double> tot(p,0.0);
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        std::int64_t c = lab[i];
        oh[ (((long long)i*k)+c) ] = 1.0   ;
        cnt[ c ] = (cnt[c]+1.0)   ;
        ;
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                double v = x[(((long long)i*p)+j)];
                ss[ j ] = (ss[j]+(v*v))   ;
                ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                double v = x[(((long long)i*p)+j)];
                ss[ j ] = (ss[j]+(v*v))   ;
                ;
            }
        }  ;
    }  ;
    scm2cpp::blas_gemm(cs, oh, x, 1.0, 0.0, 1, 0, k, p, n)  ;
    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                tot[ j ] = (tot[j]+cs[(((long long)c*p)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                tot[ j ] = (tot[j]+cs[(((long long)c*p)+j)])   ;
            }
        }  ;
    }  ;
    if( (p*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double sq = ((tot[j]*tot[j])/double(n));
            double ssbn = 0.0;
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                ssbn = (ssbn+((cs[(((long long)c*p)+j)]*cs[(((long long)c*p)+j)])/cnt[c]))  ;
            }  ;
            ssbn = (ssbn-sq)  ;
            double sswn = ((ss[j]-sq)-ssbn);
            f[ j ] = ((ssbn/double((k-1)))/(sswn/double((n-k))))   ;
            ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double sq = ((tot[j]*tot[j])/double(n));
            double ssbn = 0.0;
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                ssbn = (ssbn+((cs[(((long long)c*p)+j)]*cs[(((long long)c*p)+j)])/cnt[c]))  ;
            }  ;
            ssbn = (ssbn-sq)  ;
            double sswn = ((ss[j]-sq)-ssbn);
            f[ j ] = ((ssbn/double((k-1)))/(sswn/double((n-k))))   ;
            ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
min_pos( scm2cpp::cspan<double> v,  std::int64_t  m )
{   double r = 1.7976931348623157e+308;
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        double x = v[i];
        if( (x > 0.0 && x < r) ) {
            r = x  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return r ;
}


SCM2CPP_FN inline double
round_even( double  y )
{
    double r = std::floor(y);
    double d = (y-r);
    if( d > 0.5 ) {
        return (r+1.0) ;
    }
    else {
        if( d < 0.5 ) {
            return r ;
        }
        else {
            if( (2.0*std::floor((0.5*r))) == r ) {
                return r ;
            }
            else {
                return (r+1.0) ;
            }
        }
    }
}


SCM2CPP_FN inline std::int64_t
cholesky_delete( scm2cpp::span<double> l,  std::int64_t  go,  std::int64_t  n,  std::int64_t  k )
{   for( std::int64_t i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        for( std::int64_t j = 0 ; !(j == (i+2)) ; j = (j+1) ) {
            l[ (((long long)i*k)+j) ] = l[(((long long)((i+1))*k)+j)]   ;
        }  ;
    }  ;
    for( std::int64_t i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        double a = l[(((long long)i*k)+i)];
        double b = l[(((long long)i*k)+(i+1))];
        double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
        double ab = ( ( b < 0.0 ) ? ((0.0-b)) : (b) );
        double roe = ( ( aa > ab ) ? (a) : (b) );
        double scale = (aa+ab);
        double r = ( ( scale == 0.0 ) ? (0.0) : ((( ( roe < 0.0 ) ? (-1.0) : (1.0) )*(scale*sqrt((((a/scale)*(a/scale))+((b/scale)*(b/scale))))))) );
        double c = ( ( scale == 0.0 ) ? (1.0) : ((a/r)) );
        double s = ( ( scale == 0.0 ) ? (0.0) : ((b/r)) );
        double cc = ( ( r < 0.0 ) ? ((0.0-c)) : (c) );
        double ss = ( ( r < 0.0 ) ? ((0.0-s)) : (s) );
        l[ (((long long)i*k)+i) ] = ( ( r < 0.0 ) ? ((0.0-r)) : (r) )   ;
        l[ (((long long)i*k)+(i+1)) ] = 0.0   ;
        for( std::int64_t t = (i+1) ; !(t >= n) ; t = (t+1) ) {
            double x = l[(((long long)t*k)+i)];
            double y = l[(((long long)t*k)+(i+1))];
            l[ (((long long)t*k)+i) ] = ((cc*x)+(ss*y))   ;
            l[ (((long long)t*k)+(i+1)) ] = ((cc*y)-(ss*x))   ;
            ;
        }  ;
        ;
        ;
        ;
        ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
swap_rc( scm2cpp::span<double> g,  std::int64_t  a,  std::int64_t  b,  std::int64_t  p )
{   for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
        double rv = g[(((long long)a*p)+j)];
        g[ (((long long)a*p)+j) ] = g[(((long long)b*p)+j)]   ;
        g[ (((long long)b*p)+j) ] = rv   ;
        ;
    }  ;
    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
        double cv = g[(((long long)j*p)+a)];
        g[ (((long long)j*p)+a) ] = g[(((long long)j*p)+b)]   ;
        g[ (((long long)j*p)+b) ] = cv   ;
        ;
    }  ;
    return 0 ;
}


inline std::int64_t
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  std::int64_t  rec,  double  nsamples,  double  alphamin,  std::int64_t  method,  std::int64_t  maxiter,  double  eps,  std::int64_t  p )
{   std::vector<double> g0((p*p),0.0);
    std::vector<double> cov0(p,0.0);
    std::vector<double> cbuf(p,0.0);
    std::vector<int> index(p,0);
    std::vector<int> active(p,0);
    std::vector<double> sign(p,0.0);
    std::int64_t kmax = ( ( maxiter < p ) ? (maxiter) : (p) );
    std::vector<double> prev(p,0.0);
    std::vector<double> dir(p,0.0);
    std::vector<double> ls(p,0.0);
    std::vector<double> zz(p,0.0);
    std::vector<double> ratio(p,0.0);
    std::vector<int> idx(p,0);
    std::vector<int> dropv(p,0);
    std::int64_t cs = 0;
    std::int64_t na = 0;
    std::int64_t niter = 0;
    std::int64_t drop = 0;
    std::int64_t done = 0;
    double alpha = 0.0;
    double prevalpha = 0.0;
    double tiny32 = 1.1754943508222875e-38;
    double eqtol = 1.1920928955078125e-7;
    std::vector<double> l((kmax*kmax),0.0);
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
            g0[ t ] = g[t]   ;
        }
    } else {
        for( std::int64_t t = 0 ; t < (p*p) ; t += 1 ) {
            g0[ t ] = g[t]   ;
        }
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            cov0[ j ] = cov[j]   ;
            cbuf[ j ] = cov[j]   ;
            index[ j ] = j   ;
            coef[ j ] = 0.0   ;
            if( rec == 1 ) {
                path[ j ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            cov0[ j ] = cov[j]   ;
            cbuf[ j ] = cov[j]   ;
            index[ j ] = j   ;
            coef[ j ] = 0.0   ;
            if( rec == 1 ) {
                path[ j ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    }  ;
    for(  ; !(done == 1) ;  ) {
        std::int64_t clen = (p-cs);
        std::int64_t cidx = 0;
        double cval = 0.0;
        double cabs = 0.0;
        for( std::int64_t t = 0 ; !(t == clen) ; t = (t+1) ) {
            double v = cbuf[(cs+t)];
            double av = ( ( v < 0.0 ) ? ((0.0-v)) : (v) );
            if( av > cabs ) {
                cabs = av  ;
                cidx = t  ;
                cval = v  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        alpha = (cabs/(1.0*nsamples))  ;
        if( rec == 1 ) {
            alphas[ niter ] = alpha   ;
        } else {
            0  ;
        }  ;
        if( alpha <= (alphamin+eqtol) ) {
            if( ( ( (alpha-alphamin) < 0.0 ) ? ((alphamin-alpha)) : ((alpha-alphamin)) ) > eqtol ) {
                if( niter > 0 ) {
                    double ss = ((prevalpha-alphamin)/(prevalpha-alpha));
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            coef[ j ] = (prev[j]+(ss*(coef[j]-prev[j])))   ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            coef[ j ] = (prev[j]+(ss*(coef[j]-prev[j])))   ;
                        }
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
                alpha = alphamin  ;
                if( rec == 1 ) {
                    alphas[ niter ] = alphamin   ;
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            path[ (((long long)niter*p)+j) ] = coef[j]   ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                            path[ (((long long)niter*p)+j) ] = coef[j]   ;
                        }
                    }  ;
                } else {
                    0  ;
                }  ;
            } else {
                0  ;
            }  ;
            done = 1  ;
        } else {
            if( (niter >= maxiter || na >= p) ) {
                done = 1  ;
            } else {
                std::int64_t degenerate = 0;
                if( drop == 0 ) {
                    std::int64_t m = na;
                    std::int64_t nn = (cidx+na);
                    sign[ na ] = ( ( cval > 0.0 ) ? (1.0) : (( ( cval < 0.0 ) ? (-1.0) : (0.0) )) )   ;
                    double tc = cbuf[(cs+cidx)];
                    cbuf[ (cs+cidx) ] = cbuf[cs]   ;
                    cbuf[ cs ] = tc   ;
                    ;
                    std::int64_t ti = index[nn];
                    index[ nn ] = index[m]   ;
                    index[ m ] = ti   ;
                    ;
                    cs = (cs+1)  ;
                    swap_rc(g,m,nn,p)  ;
                    double c = g[(((long long)na*p)+na)];
                    double v = 0.0;
                    for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                        double t = g[(((long long)na*p)+i)];
                        for( std::int64_t s = 0 ; !(s == i) ; s = (s+1) ) {
                            t = (t-(l[(((long long)i*kmax)+s)]*l[(((long long)na*kmax)+s)]))  ;
                        }  ;
                        double li = (t/l[(((long long)i*kmax)+i)]);
                        l[ (((long long)na*kmax)+i) ] = li   ;
                        v = (v+(li*li))  ;
                        ;
                        ;
                    }  ;
                    double dd = sqrt(( ( (c-v) < 0.0 ) ? ((v-c)) : ((c-v)) ));
                    double dg = ( ( dd > (1.0*eps) ) ? (dd) : ((1.0*eps)) );
                    l[ (((long long)na*kmax)+na) ] = dg   ;
                    if( dg < 1e-7 ) {
                        cs = (cs-1)  ;
                        cbuf[ cs ] = 0.0   ;
                        double tc = cbuf[(cs+cidx)];
                        cbuf[ (cs+cidx) ] = cbuf[cs]   ;
                        cbuf[ cs ] = tc   ;
                        ;
                        degenerate = 1  ;
                    } else {
                        active[ na ] = index[na]   ;
                        na = (na+1)  ;
                    }  ;
                    ;
                    ;
                    ;
                    ;
                } else {
                    false  ;
                }  ;
                if( degenerate == 0 ) {
                    if( (method == 1 && niter > 0 && prevalpha < alpha) ) {
                        done = 1  ;
                    } else {
                        double aa = 0.0;
                        std::int64_t clen2 = (p-cs);
                        for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                            double t = sign[i];
                            for( std::int64_t s = 0 ; !(s == i) ; s = (s+1) ) {
                                t = (t-(l[(((long long)i*kmax)+s)]*zz[s]))  ;
                            }  ;
                            zz[ i ] = (t/l[(((long long)i*kmax)+i)])   ;
                            ;
                        }  ;
                        for( std::int64_t ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                            std::int64_t i = ((na-1)-ii);
                            double t = zz[i];
                            for( std::int64_t s = (i+1) ; !(s >= na) ; s = (s+1) ) {
                                t = (t-(l[(((long long)s*kmax)+i)]*ls[s]))  ;
                            }  ;
                            ls[ i ] = (t/l[(((long long)i*kmax)+i)])   ;
                            ;
                            ;
                        }  ;
                        if( (na == 1 && ls[0] == 0.0) ) {
                            ls[ 0 ] = 1.0   ;
                            aa = 1.0  ;
                        } else {
                            double sm = 0.0;
                            if( na > 65536 ) {
                                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:sm)
                                for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                    sm = (sm+(ls[i]*sign[i]))  ;
                                }
                            } else {
                                for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                    sm = (sm+(ls[i]*sign[i]))  ;
                                }
                            }  ;
                            aa = (1.0/sqrt(sm))  ;
                            if( na > 65536 ) {
                                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                                for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                    ls[ i ] = (aa*ls[i])   ;
                                }
                            } else {
                                for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                    ls[ i ] = (aa*ls[i])   ;
                                }
                            }  ;
                            ;
                        }  ;
                        if( (clen2*na) > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                double acc = 0.0;
                                for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                                    acc = (acc+(g[(((long long)i*p)+(na+t))]*ls[i]))  ;
                                }  ;
                                dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                                ;
                            }
                        } else {
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                double acc = 0.0;
                                for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                                    acc = (acc+(g[(((long long)i*p)+(na+t))]*ls[i]))  ;
                                }  ;
                                dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                                ;
                            }
                        }  ;
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                            }
                        } else {
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                            }
                        }  ;
                        double gfirst = min_pos(ratio,clen2);
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                            }
                        } else {
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                            }
                        }  ;
                        double gsecond = min_pos(ratio,clen2);
                        double gam = ( ( ( ( gfirst < gsecond ) ? (gfirst) : (gsecond) ) < (cabs/aa) ) ? (( ( gfirst < gsecond ) ? (gfirst) : (gsecond) )) : ((cabs/aa)) );
                        std::int64_t nidx = 0;
                        drop = 0  ;
                        if( na > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
                            }
                        } else {
                            for( std::int64_t i = 0 ; i < na ; i += 1 ) {
                                zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
                            }
                        }  ;
                        double zpos = min_pos(zz,na);
                        if( zpos < gam ) {
                            for( std::int64_t ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                                std::int64_t i = ((na-1)-ii);
                                if( zz[i] == zpos ) {
                                    idx[ nidx ] = i   ;
                                    nidx = (nidx+1)  ;
                                } else {
                                    0  ;
                                }  ;
                                ;
                            }  ;
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                std::int64_t i = idx[r];
                                sign[ i ] = (0.0-sign[i])   ;
                                ;
                            }  ;
                            if( method == 1 ) {
                                gam = zpos  ;
                            } else {
                                0  ;
                            }  ;
                            drop = 1  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        niter = (niter+1)  ;
                        prevalpha = alpha  ;
                        if( p > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                                prev[ j ] = coef[j]   ;
                                coef[ j ] = 0.0   ;
                            }
                        } else {
                            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                                prev[ j ] = coef[j]   ;
                                coef[ j ] = 0.0   ;
                            }
                        }  ;
                        for( std::int64_t i = 0 ; !(i == na) ; i = (i+1) ) {
                            std::int64_t a = active[i];
                            coef[ a ] = (prev[a]+(gam*ls[i]))   ;
                            ;
                        }  ;
                        if( (drop == 1 && method == 1) ) {
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                coef[ active[idx[r]] ] = 0.0   ;
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        if( rec == 1 ) {
                            if( p > 65536 ) {
                                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                                    path[ (((long long)niter*p)+j) ] = coef[j]   ;
                                }
                            } else {
                                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                                    path[ (((long long)niter*p)+j) ] = coef[j]   ;
                                }
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
                            }
                        } else {
                            for( std::int64_t t = 0 ; t < clen2 ; t += 1 ) {
                                cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
                            }
                        }  ;
                        if( (drop == 1 && method == 1) ) {
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                cholesky_delete(l,idx[r],na,kmax)  ;
                            }  ;
                            na = (na-1)  ;
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                std::int64_t ii = idx[r];
                                std::int64_t dropped = active[ii];
                                for( std::int64_t i = ii ; !(i >= na) ; i = (i+1) ) {
                                    active[ i ] = active[(i+1)]   ;
                                }  ;
                                dropv[ r ] = dropped   ;
                                ;
                                ;
                            }  ;
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                std::int64_t ii = idx[r];
                                for( std::int64_t i = ii ; !(i >= na) ; i = (i+1) ) {
                                    std::int64_t ti = index[i];
                                    index[ i ] = index[(i+1)]   ;
                                    index[ (i+1) ] = ti   ;
                                    ;
                                    swap_rc(g,i,std::int64_t((i+1)),p)  ;
                                }  ;
                                ;
                            }  ;
                            for( std::int64_t rr = 0 ; !(rr == nidx) ; rr = (rr+1) ) {
                                std::int64_t r = ((nidx-1)-rr);
                                std::int64_t d = dropv[r];
                                double t = cov0[d];
                                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                                    t = (t-(g0[(((long long)d*p)+j)]*coef[j]))  ;
                                }  ;
                                cs = (cs-1)  ;
                                cbuf[ cs ] = t   ;
                                ;
                                ;
                                ;
                            }  ;
                            for( std::int64_t r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                std::int64_t ii = idx[r];
                                for( std::int64_t i = ii ; !(i >= (p-1)) ; i = (i+1) ) {
                                    sign[ i ] = sign[(i+1)]   ;
                                }  ;
                                sign[ (p-1) ] = 0.0   ;
                                ;
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        ;
                        ;
                        ;
                    }  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
        }  ;
        ;
    }  ;
    ;
    return niter ;
}


SCM2CPP_FN inline std::int64_t
rfe_chol( scm2cpp::cspan<double> g,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> l,  double  alpha,  std::int64_t  k,  std::int64_t  p )
{   for( std::int64_t j = 0 ; !(j == k) ; j = (j+1) ) {
        double s = (g[(((long long)(idx[j])*p)+idx[j])]+alpha);
        for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
            s = (s-(l[(((long long)j*p)+m)]*l[(((long long)j*p)+m)]))  ;
        }  ;
        l[ (((long long)j*p)+j) ] = sqrt(s)   ;
        for( std::int64_t i = (j+1) ; !(i >= k) ; i = (i+1) ) {
            double t = g[(((long long)(idx[i])*p)+idx[j])];
            for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
                t = (t-(l[(((long long)i*p)+m)]*l[(((long long)j*p)+m)]))  ;
            }  ;
            l[ (((long long)i*p)+j) ] = (t/l[(((long long)j*p)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
rfe_solve( scm2cpp::cspan<double> c,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::cspan<double> l,  std::int64_t  k,  std::int64_t  p )
{   for( std::int64_t i = 0 ; !(i == k) ; i = (i+1) ) {
        double t = c[idx[i]];
        for( std::int64_t m = 0 ; !(m == i) ; m = (m+1) ) {
            t = (t-(l[(((long long)i*p)+m)]*w[m]))  ;
        }  ;
        w[ i ] = (t/l[(((long long)i*p)+i)])   ;
        ;
    }  ;
    for( std::int64_t ii = 0 ; !(ii == k) ; ii = (ii+1) ) {
        std::int64_t i = ((k-1)-ii);
        double t = w[i];
        for( std::int64_t m = (i+1) ; !(m >= k) ; m = (m+1) ) {
            t = (t-(l[(((long long)m*p)+i)]*w[m]))  ;
        }  ;
        w[ i ] = (t/l[(((long long)i*p)+i)])   ;
        ;
        ;
    }  ;
    return 0 ;
}


inline std::int64_t
rfe( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<int> support,  scm2cpp::span<int> ranking,  double  alpha,  std::int64_t  nsel,  std::int64_t  step,  std::int64_t  n,  std::int64_t  p )
{   std::vector<double> xc((n*p),0.0);
    std::vector<double> yc(n,0.0);
    std::vector<double> mx(p,0.0);
    std::vector<double> g((p*p),0.0);
    std::vector<double> c(p,0.0);
    std::vector<double> l((p*p),0.0);
    std::vector<double> w(p,0.0);
    std::vector<int> idx(p,0);
    std::vector<int> ord(p,0);
    std::vector<int> gone(p,0);
    double ym = 0.0;
    std::int64_t rounds = 0;
    std::int64_t k = p;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        ym = (ym+y[i])  ;
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mx[ j ] = (mx[j]+x[(((long long)i*p)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                mx[ j ] = (mx[j]+x[(((long long)i*p)+j)])   ;
            }
        }  ;
    }  ;
    ym = (ym/double(n))  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    }  ;
    if( (n*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            yc[ i ] = (y[i]-ym)   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mx[j])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            yc[ i ] = (y[i]-ym)   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mx[j])   ;
            }  ;
        }
    }  ;
    scm2cpp::blas_syrk(g, xc, 1.0, 0.0, 1, p, n)  ;
    scm2cpp::blas_gemv(c, xc, yc, 1.0, 0.0, 1, p, n)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            support[ j ] = 1   ;
            ranking[ j ] = 1   ;
            idx[ j ] = j   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            support[ j ] = 1   ;
            ranking[ j ] = 1   ;
            idx[ j ] = j   ;
        }
    }  ;
    rfe_chol(g,idx,l,alpha,p,p)  ;
    for(  ; !(k <= nsel) ;  ) {
        rfe_solve(c,idx,w,l,k,p)  ;
        for( std::int64_t i = 0 ; !(i == k) ; i = (i+1) ) {
            double key = (w[i]*w[i]);
            std::int64_t jj = (i-1);
            for(  ; !((jj < 0 || (w[ord[jj]]*w[ord[jj]]) <= key)) ;  ) {
                ord[ (jj+1) ] = ord[jj]   ;
                jj = (jj-1)  ;
            }  ;
            ord[ (jj+1) ] = i   ;
            ;
        }  ;
        std::int64_t thr = ( ( step < (k-nsel) ) ? (step) : ((k-nsel)) );
        for( std::int64_t r = 0 ; !(r == thr) ; r = (r+1) ) {
            support[ idx[ord[r]] ] = 0   ;
        }  ;
        if( k > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t t = 0 ; t < k ; t += 1 ) {
                gone[ t ] = 0   ;
            }
        } else {
            for( std::int64_t t = 0 ; t < k ; t += 1 ) {
                gone[ t ] = 0   ;
            }
        }  ;
        for( std::int64_t r = 0 ; !(r == thr) ; r = (r+1) ) {
            gone[ ord[r] ] = 1   ;
        }  ;
        std::int64_t cur = k;
        for( std::int64_t tt = 0 ; !(tt == k) ; tt = (tt+1) ) {
            std::int64_t pos = ((k-1)-tt);
            if( gone[pos] == 1 ) {
                cholesky_delete(l,pos,cur,p)  ;
                for( std::int64_t u = pos ; !(u >= (cur-1)) ; u = (u+1) ) {
                    idx[ u ] = idx[(u+1)]   ;
                }  ;
                cur = (cur-1)  ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        ;
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                if( support[j] == 0 ) {
                    ranking[ j ] = (ranking[j]+1)   ;
                } else {
                    0  ;
                }  ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                if( support[j] == 0 ) {
                    ranking[ j ] = (ranking[j]+1)   ;
                } else {
                    0  ;
                }  ;
            }
        }  ;
        k = (k-thr)  ;
        rounds = (rounds+1)  ;
        ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    rfe_solve(c,idx,w,l,k,p)  ;
    for( std::int64_t i = 0 ; !(i == k) ; i = (i+1) ) {
        coef[ idx[i] ] = w[i]   ;
    }  ;
    return rounds ;
}


SCM2CPP_FN inline std::int64_t
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  std::int64_t  n,  std::int64_t  p )
{   scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  std::int64_t  n,  std::int64_t  p,  std::int64_t  q )
{   scm2cpp::blas_gemm(c, x, y, 1.0, 0.0, 1, 0, p, q, n)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
spd_solve( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  m,  std::int64_t  q )
{   std::int64_t info = 0;
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        double d = a[(((long long)j*m)+j)];
        for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
            d = (d-(a[(((long long)j*m)+l)]*a[(((long long)j*m)+l)]))  ;
        }  ;
        if( d > 0.0 ) {
            a[ (((long long)j*m)+j) ] = sqrt(d)   ;
        } else {
            if( info == 0 ) {
                info = (j+1)  ;
            } else {
                0  ;
            }  ;
            a[ (((long long)j*m)+j) ] = 1.0   ;
        }  ;
        for( std::int64_t i = (j+1) ; !(i >= m) ; i = (i+1) ) {
            double s = a[(((long long)i*m)+j)];
            for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(a[(((long long)i*m)+l)]*a[(((long long)j*m)+l)]))  ;
            }  ;
            a[ (((long long)i*m)+j) ] = (s/a[(((long long)j*m)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( std::int64_t c = 0 ; !(c == q) ; c = (c+1) ) {
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = b[(((long long)i*q)+c)];
            for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(a[(((long long)i*m)+l)]*b[(((long long)l*q)+c)]))  ;
            }  ;
            b[ (((long long)i*q)+c) ] = (s/a[(((long long)i*m)+i)])   ;
            ;
        }  ;
        for( std::int64_t ii = 0 ; !(ii == m) ; ii = (ii+1) ) {
            std::int64_t i = ((m-1)-ii);
            double s = b[(((long long)i*q)+c)];
            for( std::int64_t l = (i+1) ; !(l >= m) ; l = (l+1) ) {
                s = (s-(a[(((long long)l*m)+i)]*b[(((long long)l*q)+c)]))  ;
            }  ;
            b[ (((long long)i*q)+c) ] = (s/a[(((long long)i*m)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    return info ;
}


SCM2CPP_FN inline double
gram_abs( double  x )
{
    if( x < 0.0 ) {
        return (0.0-x) ;
    }
    else {
        return x ;
    }
}


inline double
spd_solve_rcond( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  m,  std::int64_t  q )
{   double anorm = 0.0;
    double inorm = 0.0;
    std::vector<double> x(m,0.0);
    for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
        double acc = 0.0;
        if( m > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                acc = (acc+gram_abs(a[(((long long)i*m)+c)]))  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                acc = (acc+gram_abs(a[(((long long)i*m)+c)]))  ;
            }
        }  ;
        if( acc > anorm ) {
            anorm = acc  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    if( scm2cpp::lapack_posv(a, b, m, q) == 0 ) {
        for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                double s = ( ( i == c ) ? (1.0) : (0.0) );
                for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                    s = (s-(a[(((long long)i*m)+l)]*x[l]))  ;
                }  ;
                x[ i ] = (s/a[(((long long)i*m)+i)])   ;
                ;
            }  ;
            for( std::int64_t ii = 0 ; !(ii == m) ; ii = (ii+1) ) {
                std::int64_t i = ((m-1)-ii);
                double s = x[i];
                for( std::int64_t l = (i+1) ; !(l >= m) ; l = (l+1) ) {
                    s = (s-(a[(((long long)l*m)+i)]*x[l]))  ;
                }  ;
                x[ i ] = (s/a[(((long long)i*m)+i)])   ;
                ;
                ;
            }  ;
            double acc = 0.0;
            if( m > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
                for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                    acc = (acc+gram_abs(x[i]))  ;
                }
            } else {
                for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                    acc = (acc+gram_abs(x[i]))  ;
                }
            }  ;
            if( acc > inorm ) {
                inorm = acc  ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        return (1.0/(anorm*inorm)) ;
    }
    else {
        return -1.0 ;
    }
}


inline std::int64_t
gram_ridge_solve( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  double  alpha,  std::int64_t  m,  std::int64_t  q )
{   std::vector<double> a((m*m),0.0);
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t s = 0 ; s < (m*m) ; s += 1 ) {
            a[ s ] = g[s]   ;
        }
    } else {
        for( std::int64_t s = 0 ; s < (m*m) ; s += 1 ) {
            a[ s ] = g[s]   ;
        }
    }  ;
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        a[ (((long long)j*m)+j) ] = (a[(((long long)j*m)+j)]+alpha)   ;
    }  ;
    return scm2cpp::lapack_posv(a, c, m, q) ;
}


inline std::int64_t
ridge_gcv_primal( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xm,  scm2cpp::cspan<double> yc,  scm2cpp::span<double> g,  scm2cpp::span<double> v,  scm2cpp::span<double> lam,  scm2cpp::span<double> z,  scm2cpp::span<double> r,  std::int64_t  n,  std::int64_t  p,  std::int64_t  t )
{   std::vector<double> e(p,0.0);
    std::vector<double> s(p,0.0);
    scm2cpp::lapack_syevd(g, v, lam, p)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t k = 0 ; k < p ; k += 1 ) {
            if( lam[k] < 0.0 ) {
                lam[ k ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    } else {
        for( std::int64_t k = 0 ; k < p ; k += 1 ) {
            if( lam[k] < 0.0 ) {
                lam[ k ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(z, x, v, 1.0, 0.0, 0, 0, n, p, p)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t k = 0 ; k < p ; k += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(xm[j]*v[(((long long)j*p)+k)]))  ;
            }  ;
            s[ k ] = acc   ;
            ;
        }
    } else {
        for( std::int64_t k = 0 ; k < p ; k += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(xm[j]*v[(((long long)j*p)+k)]))  ;
            }  ;
            s[ k ] = acc   ;
            ;
        }
    }  ;
    if( (n*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t k = 0 ; !(k == p) ; k = (k+1) ) {
                z[ (((long long)i*p)+k) ] = (z[(((long long)i*p)+k)]-s[k])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t k = 0 ; !(k == p) ; k = (k+1) ) {
                z[ (((long long)i*p)+k) ] = (z[(((long long)i*p)+k)]-s[k])   ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(r, z, yc, 1.0, 0.0, 1, 0, p, t, n)  ;
    return 0 ;
}


inline std::int64_t
ridge_gcv_dual( scm2cpp::span<double> k,  scm2cpp::span<double> q,  scm2cpp::span<double> mu,  scm2cpp::cspan<double> yc,  scm2cpp::span<double> r,  std::int64_t  n,  std::int64_t  t,  std::int64_t  icpt )
{   std::vector<double> e(n,0.0);
    scm2cpp::lapack_syevd(k, q, mu, n)  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < n ; c += 1 ) {
            if( mu[c] < 0.0 ) {
                mu[ c ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    } else {
        for( std::int64_t c = 0 ; c < n ; c += 1 ) {
            if( mu[c] < 0.0 ) {
                mu[ c ] = 0.0   ;
            } else {
                0  ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(r, q, yc, 1.0, 0.0, 1, 0, n, t, n)  ;
    if( icpt == 1 ) {
        std::int64_t best = 0;
        double top = -1.0;
        for( std::int64_t c = 0 ; !(c == n) ; c = (c+1) ) {
            double acc = 0.0;
            if( n > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    acc = (acc+q[(((long long)i*n)+c)])  ;
                }
            } else {
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    acc = (acc+q[(((long long)i*n)+c)])  ;
                }
            }  ;
            if( std::abs(acc) > top ) {
                top = std::abs(acc)  ;
                best = c  ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        return best ;
    }
    else {
        return -1 ;
    }
}


inline std::int64_t
ridge_gcv_scan_dual( scm2cpp::cspan<double> q,  scm2cpp::cspan<double> mu,  scm2cpp::cspan<double> r,  scm2cpp::cspan<double> alphas,  std::int64_t  drop,  scm2cpp::span<double> mse,  scm2cpp::span<double> loo,  std::int64_t  store,  std::int64_t  n,  std::int64_t  t,  std::int64_t  na )
{   std::vector<double> q2((n*n),0.0);
    std::vector<double> w((n*na),0.0);
    std::vector<double> rw((n*na),0.0);
    std::vector<double> gd((n*na),0.0);
    std::vector<double> c((n*na),0.0);
    if( (n*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t s = 0 ; s < (n*n) ; s += 1 ) {
            q2[ s ] = (q[s]*q[s])   ;
        }
    } else {
        for( std::int64_t s = 0 ; s < (n*n) ; s += 1 ) {
            q2[ s ] = (q[s]*q[s])   ;
        }
    }  ;
    if( (n*na) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t k = 0 ; k < n ; k += 1 ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                w[ (((long long)k*na)+a) ] = ( ( k == drop ) ? (0.0) : ((1.0/(mu[k]+alphas[a]))) )   ;
            }  ;
        }
    } else {
        for( std::int64_t k = 0 ; k < n ; k += 1 ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                w[ (((long long)k*na)+a) ] = ( ( k == drop ) ? (0.0) : ((1.0/(mu[k]+alphas[a]))) )   ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(gd, q2, w, 1.0, 0.0, 0, 0, n, na, n)  ;
    for( std::int64_t j = 0 ; !(j == t) ; j = (j+1) ) {
        if( (n*na) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t k = 0 ; k < n ; k += 1 ) {
                for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                    rw[ (((long long)k*na)+a) ] = (r[(((long long)k*t)+j)]*w[(((long long)k*na)+a)])   ;
                }  ;
            }
        } else {
            for( std::int64_t k = 0 ; k < n ; k += 1 ) {
                for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                    rw[ (((long long)k*na)+a) ] = (r[(((long long)k*t)+j)]*w[(((long long)k*na)+a)])   ;
                }  ;
            }
        }  ;
        scm2cpp::blas_gemm(c, q, rw, 1.0, 0.0, 0, 0, n, na, n)  ;
        for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
            mse[ (((long long)a*t)+j) ] = 0.0   ;
        }  ;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                double e = (c[(((long long)i*na)+a)]/gd[(((long long)i*na)+a)]);
                mse[ (((long long)a*t)+j) ] = (mse[(((long long)a*t)+j)]+((e*e)/double(n)))   ;
                if( store == 1 ) {
                    loo[ (((long long)(((i*t)+j))*na)+a) ] = (e*e)   ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
        }  ;
    }  ;
    return 0 ;
}


inline std::int64_t
ridge_gcv_scan( scm2cpp::cspan<double> z,  scm2cpp::cspan<double> lam,  scm2cpp::cspan<double> r,  scm2cpp::cspan<double> yc,  scm2cpp::cspan<double> alphas,  double  h0,  scm2cpp::span<double> mse,  scm2cpp::span<double> loo,  std::int64_t  store,  std::int64_t  n,  std::int64_t  m,  std::int64_t  t,  std::int64_t  na )
{   std::vector<double> z2((n*m),0.0);
    std::vector<double> w((m*na),0.0);
    std::vector<double> rw((m*na),0.0);
    std::vector<double> hd((n*na),0.0);
    std::vector<double> yh((n*na),0.0);
    if( (n*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t q = 0 ; q < (n*m) ; q += 1 ) {
            z2[ q ] = (z[q]*z[q])   ;
        }
    } else {
        for( std::int64_t q = 0 ; q < (n*m) ; q += 1 ) {
            z2[ q ] = (z[q]*z[q])   ;
        }
    }  ;
    if( (m*na) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t k = 0 ; k < m ; k += 1 ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                w[ (((long long)k*na)+a) ] = (1.0/(lam[k]+alphas[a]))   ;
            }  ;
        }
    } else {
        for( std::int64_t k = 0 ; k < m ; k += 1 ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                w[ (((long long)k*na)+a) ] = (1.0/(lam[k]+alphas[a]))   ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(hd, z2, w, 1.0, 0.0, 0, 0, n, na, m)  ;
    for( std::int64_t j = 0 ; !(j == t) ; j = (j+1) ) {
        if( (m*na) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t k = 0 ; k < m ; k += 1 ) {
                for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                    rw[ (((long long)k*na)+a) ] = (r[(((long long)k*t)+j)]*w[(((long long)k*na)+a)])   ;
                }  ;
            }
        } else {
            for( std::int64_t k = 0 ; k < m ; k += 1 ) {
                for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                    rw[ (((long long)k*na)+a) ] = (r[(((long long)k*t)+j)]*w[(((long long)k*na)+a)])   ;
                }  ;
            }
        }  ;
        scm2cpp::blas_gemm(yh, z, rw, 1.0, 0.0, 0, 0, n, na, m)  ;
        for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
            mse[ (((long long)a*t)+j) ] = 0.0   ;
        }  ;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            for( std::int64_t a = 0 ; !(a == na) ; a = (a+1) ) {
                double e = ((yc[(((long long)i*t)+j)]-yh[(((long long)i*na)+a)])/((1.0-h0)-hd[(((long long)i*na)+a)]));
                mse[ (((long long)a*t)+j) ] = (mse[(((long long)a*t)+j)]+((e*e)/double(n)))   ;
                if( store == 1 ) {
                    loo[ (((long long)(((i*t)+j))*na)+a) ] = (e*e)   ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_row_norms( scm2cpp::cspan<double> x,  scm2cpp::span<double> s,  std::int64_t  n,  std::int64_t  p )
{   if( (n*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(x[(((long long)i*p)+j)]*x[(((long long)i*p)+j)]))  ;
            }  ;
            s[ i ] = acc   ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(x[(((long long)i*p)+j)]*x[(((long long)i*p)+j)]))  ;
            }  ;
            s[ i ] = acc   ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_apply( scm2cpp::span<double> g,  scm2cpp::cspan<double> sa,  scm2cpp::cspan<double> sb,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  na,  std::int64_t  nb )
{   if( (na*nb) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < na ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == nb) ; j = (j+1) ) {
                double q = g[(((long long)i*nb)+j)];
                struct let4166 {
                    double & gamma;
                    let4166( double & gamma ):gamma(gamma)  {}
                    double operator()( double  d  )
                    {
                        return exp(((0.0-gamma)*( ( d < 0.0 ) ? (0.0) : (d) ))) ;
                    }
                }  ;

                struct let4198 {
                    double & q;
                    let4198( double & q ):q(q)  {}
                    double operator()( double  r  )
                    {
                        if( r > 0.0 ) {
                            return (q/r) ;
                        }
                        else {
                            return 0.0 ;
                        }
                    }
                }  ;
                g[ (((long long)i*nb)+j) ] = ( ( kind == 1 ) ? (let4166(gamma)(((sa[i]+sb[j])-(2.0*q)))) : (( ( kind == 2 ) ? (std::pow(((gamma*q)+coef0), (1.0*degree))) : (( ( kind == 3 ) ? ((1.0-(2.0/(exp((2.0*((gamma*q)+coef0)))+1.0)))) : (( ( kind == 4 ) ? (let4198(q)((sqrt(sa[i])*sqrt(sb[j])))) : (q) )) )) )) )   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < na ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == nb) ; j = (j+1) ) {
                double q = g[(((long long)i*nb)+j)];
                struct let4166 {
                    double & gamma;
                    let4166( double & gamma ):gamma(gamma)  {}
                    double operator()( double  d  )
                    {
                        return exp(((0.0-gamma)*( ( d < 0.0 ) ? (0.0) : (d) ))) ;
                    }
                }  ;

                struct let4198 {
                    double & q;
                    let4198( double & q ):q(q)  {}
                    double operator()( double  r  )
                    {
                        if( r > 0.0 ) {
                            return (q/r) ;
                        }
                        else {
                            return 0.0 ;
                        }
                    }
                }  ;
                g[ (((long long)i*nb)+j) ] = ( ( kind == 1 ) ? (let4166(gamma)(((sa[i]+sb[j])-(2.0*q)))) : (( ( kind == 2 ) ? (std::pow(((gamma*q)+coef0), (1.0*degree))) : (( ( kind == 3 ) ? ((1.0-(2.0/(exp((2.0*((gamma*q)+coef0)))+1.0)))) : (( ( kind == 4 ) ? (let4198(q)((sqrt(sa[i])*sqrt(sb[j])))) : (q) )) )) )) )   ;
                ;
            }  ;
        }
    }  ;
    return 0 ;
}


inline std::int64_t
kpca_kernel( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> k,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  na,  std::int64_t  nb,  std::int64_t  p )
{   std::vector<double> sa(na,0.0);
    std::vector<double> sb(nb,0.0);
    scm2cpp::blas_gemm(k, x, y, 1.0, 0.0, 0, 1, na, nb, p)  ;
    kpca_row_norms(x,sa,na,p)  ;
    kpca_row_norms(y,sb,nb,p)  ;
    kpca_apply(k,sa,sb,kind,gamma,degree,coef0,na,nb)  ;
    return 0 ;
}


inline std::int64_t
kpca_kernel_self( scm2cpp::cspan<double> x,  scm2cpp::span<double> k,  std::int64_t  kind,  double  gamma,  double  degree,  double  coef0,  std::int64_t  n,  std::int64_t  p )
{   std::vector<double> s(n,0.0);
    scm2cpp::blas_syrk(k, x, 1.0, 0.0, 0, n, p)  ;
    kpca_row_norms(x,s,n,p)  ;
    kpca_apply(k,s,s,kind,gamma,degree,coef0,n,n)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_centre( scm2cpp::span<double> k,  scm2cpp::span<double> m,  std::int64_t  n )
{   double all = 0.0;
    if( (n*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:all)
        for( std::int64_t j = 0 ; j < n ; j += 1 ) {
            double acc = 0.0;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                acc = (acc+k[(((long long)i*n)+j)])  ;
            }  ;
            m[ j ] = (acc/double(n))   ;
            all = (all+(acc/double(n)))  ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < n ; j += 1 ) {
            double acc = 0.0;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                acc = (acc+k[(((long long)i*n)+j)])  ;
            }  ;
            m[ j ] = (acc/double(n))   ;
            all = (all+(acc/double(n)))  ;
            ;
        }
    }  ;
    m[ n ] = (all/double(n))   ;
    if( (n*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                k[ (((long long)i*n)+j) ] = (((k[(((long long)i*n)+j)]-m[i])-m[j])+m[n])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                k[ (((long long)i*n)+j) ] = (((k[(((long long)i*n)+j)]-m[i])-m[j])+m[n])   ;
            }  ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_centre_new( scm2cpp::span<double> k,  scm2cpp::cspan<double> m,  std::int64_t  nb,  std::int64_t  n )
{   for( std::int64_t i = 0 ; !(i == nb) ; i = (i+1) ) {
        double acc = 0.0;
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
            for( std::int64_t j = 0 ; j < n ; j += 1 ) {
                acc = (acc+k[(((long long)i*n)+j)])  ;
            }
        } else {
            for( std::int64_t j = 0 ; j < n ; j += 1 ) {
                acc = (acc+k[(((long long)i*n)+j)])  ;
            }
        }  ;
        double r = (acc/double(n));
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < n ; j += 1 ) {
                k[ (((long long)i*n)+j) ] = (((k[(((long long)i*n)+j)]-r)-m[j])+m[n])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < n ; j += 1 ) {
                k[ (((long long)i*n)+j) ] = (((k[(((long long)i*n)+j)]-r)-m[j])+m[n])   ;
            }
        }  ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_flip( scm2cpp::span<double> vecs,  scm2cpp::cspan<double> vals,  std::int64_t  n,  std::int64_t  c )
{   for( std::int64_t r = 0 ; !(r == c) ; r = (r+1) ) {
        std::int64_t big = 0;
        double bv = -1.0;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double a = vecs[(((long long)i*c)+r)];
            double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
            if( aa > bv ) {
                bv = aa  ;
                big = i  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( vecs[(((long long)big*c)+r)] < 0.0 ) {
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                vecs[ (((long long)i*c)+r) ] = (0.0-vecs[(((long long)i*c)+r)])   ;
            }  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return 0 ;
}


inline std::int64_t
kpca_top_dense( scm2cpp::span<double> k,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  c )
{   std::vector<double> e(n,0.0);
    scm2cpp::lapack_syevr_top(k, vecs, vals, n, c)  ;
    kpca_flip(vecs,vals,n,c)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
kpca_orth( scm2cpp::span<double> y,  scm2cpp::span<double> g,  std::int64_t  n,  std::int64_t  b )
{   std::int64_t ok = 1;
    scm2cpp::blas_syrk(g, y, 1.0, 0.0, 1, b, n)  ;
    for( std::int64_t j = 0 ; !(j == b) ; j = (j+1) ) {
        double d = g[(((long long)j*b)+j)];
        double d0 = g[(((long long)j*b)+j)];
        for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
            d = (d-(g[(((long long)j*b)+l)]*g[(((long long)j*b)+l)]))  ;
        }  ;
        if( d > (1e-12*d0) ) {
            g[ (((long long)j*b)+j) ] = sqrt(d)   ;
        } else {
            ok = 0  ;
            g[ (((long long)j*b)+j) ] = 1.0   ;
        }  ;
        for( std::int64_t i = (j+1) ; !(i >= b) ; i = (i+1) ) {
            double s = g[(((long long)i*b)+j)];
            for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(g[(((long long)i*b)+l)]*g[(((long long)j*b)+l)]))  ;
            }  ;
            g[ (((long long)i*b)+j) ] = (s/g[(((long long)j*b)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        for( std::int64_t j = 0 ; !(j == b) ; j = (j+1) ) {
            double s = y[(((long long)i*b)+j)];
            for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(y[(((long long)i*b)+l)]*g[(((long long)j*b)+l)]))  ;
            }  ;
            y[ (((long long)i*b)+j) ] = (s/g[(((long long)j*b)+j)])   ;
            ;
        }  ;
    }  ;
    return ok ;
}


inline std::int64_t
kpca_top_subspace( scm2cpp::cspan<double> k,  scm2cpp::span<double> q,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  b,  std::int64_t  c,  double  tol,  std::int64_t  maxit )
{   std::vector<double> y((n*b),0.0);
    std::vector<double> u((n*b),0.0);
    std::vector<double> ku((n*b),0.0);
    std::vector<double> t((b*b),0.0);
    std::vector<double> wv((b*b),0.0);
    std::vector<double> ws((b*b),0.0);
    std::vector<double> g((b*b),0.0);
    std::vector<double> th(b,0.0);
    std::vector<double> e(b,0.0);
    std::vector<int> ord(b,0);
    std::int64_t status = 0;
    std::int64_t steps = 0;
    if( (kpca_orth(q,g,n,b)+kpca_orth(q,g,n,b)) == 2 ) {
        0  ;
    } else {
        status = -1  ;
    }  ;
    for( std::int64_t it = 0 ; status == 0 ; it = (it+1) ) {
        scm2cpp::blas_gemm(y, k, q, 1.0, 0.0, 0, 0, n, b, n)  ;
        scm2cpp::blas_gemm(t, q, y, 1.0, 0.0, 1, 0, b, b, n)  ;
        for( std::int64_t i = 0 ; !(i == b) ; i = (i+1) ) {
            for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
                double s = (0.5*(t[(((long long)i*b)+j)]+t[(((long long)j*b)+i)]));
                t[ (((long long)i*b)+j) ] = s   ;
                t[ (((long long)j*b)+i) ] = s   ;
                ;
            }  ;
        }  ;
        scm2cpp::lapack_syevd(t, wv, th, b)  ;
        eig_order(th,ord,b)  ;
        if( (b*b) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < b ; i += 1 ) {
                for( std::int64_t r = 0 ; !(r == b) ; r = (r+1) ) {
                    ws[ (((long long)i*b)+r) ] = wv[(((long long)i*b)+ord[r])]   ;
                }  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < b ; i += 1 ) {
                for( std::int64_t r = 0 ; !(r == b) ; r = (r+1) ) {
                    ws[ (((long long)i*b)+r) ] = wv[(((long long)i*b)+ord[r])]   ;
                }  ;
            }
        }  ;
        scm2cpp::blas_gemm(u, q, ws, 1.0, 0.0, 0, 0, n, b, b)  ;
        scm2cpp::blas_gemm(ku, y, ws, 1.0, 0.0, 0, 0, n, b, b)  ;
        double worst = 0.0;
        double top = th[ord[0]];
        for( std::int64_t r = 0 ; !(r == c) ; r = (r+1) ) {
            double acc = 0.0;
            double lam = th[ord[r]];
            if( n > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    double d = (ku[(((long long)i*b)+r)]-(lam*u[(((long long)i*b)+r)]));
                    acc = (acc+(d*d))  ;
                    ;
                }
            } else {
                for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                    double d = (ku[(((long long)i*b)+r)]-(lam*u[(((long long)i*b)+r)]));
                    acc = (acc+(d*d))  ;
                    ;
                }
            }  ;
            if( acc > worst ) {
                worst = acc  ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        steps = (it+1)  ;
        if( sqrt(worst) <= (tol*( ( top < 0.0 ) ? ((0.0-top)) : (top) )) ) {
            if( (c*n) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t r = 0 ; r < c ; r += 1 ) {
                    vals[ r ] = th[ord[r]]   ;
                    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                        vecs[ (((long long)i*c)+r) ] = u[(((long long)i*b)+r)]   ;
                    }  ;
                }
            } else {
                for( std::int64_t r = 0 ; r < c ; r += 1 ) {
                    vals[ r ] = th[ord[r]]   ;
                    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                        vecs[ (((long long)i*c)+r) ] = u[(((long long)i*b)+r)]   ;
                    }  ;
                }
            }  ;
            kpca_flip(vecs,vals,n,c)  ;
            status = 1  ;
        } else {
            if( (it+1) >= maxit ) {
                status = -1  ;
            } else {
                if( (n*b) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t s = 0 ; s < (n*b) ; s += 1 ) {
                        q[ s ] = ku[s]   ;
                    }
                } else {
                    for( std::int64_t s = 0 ; s < (n*b) ; s += 1 ) {
                        q[ s ] = ku[s]   ;
                    }
                }  ;
                if( (kpca_orth(q,g,n,b)+kpca_orth(q,g,n,b)) == 2 ) {
                    0  ;
                } else {
                    status = -1  ;
                }  ;
            }  ;
        }  ;
        ;
    }  ;
    if( status == 1 ) {
        return steps ;
    }
    else {
        return -1 ;
    }
}


inline std::int64_t
kpca_linear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xm,  scm2cpp::span<double> g,  scm2cpp::span<double> vecs,  scm2cpp::span<double> vals,  std::int64_t  n,  std::int64_t  p,  std::int64_t  c )
{   std::vector<double> e(p,0.0);
    std::vector<double> v((p*c),0.0);
    std::vector<double> s(c,0.0);
    scm2cpp::lapack_syevr_top(g, v, vals, p, c)  ;
    scm2cpp::blas_gemm(vecs, x, v, 1.0, 0.0, 0, 0, n, c, p)  ;
    if( (c*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < c ; r += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(xm[j]*v[(((long long)j*c)+r)]))  ;
            }  ;
            s[ r ] = acc   ;
            ;
        }
    } else {
        for( std::int64_t r = 0 ; r < c ; r += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                acc = (acc+(xm[j]*v[(((long long)j*c)+r)]))  ;
            }  ;
            s[ r ] = acc   ;
            ;
        }
    }  ;
    if( (n*c) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t r = 0 ; !(r == c) ; r = (r+1) ) {
                double lam = vals[r];
                vecs[ (((long long)i*c)+r) ] = ( ( lam > 0.0 ) ? (((vecs[(((long long)i*c)+r)]-s[r])/sqrt(lam))) : (0.0) )   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t r = 0 ; !(r == c) ; r = (r+1) ) {
                double lam = vals[r];
                vecs[ (((long long)i*c)+r) ] = ( ( lam > 0.0 ) ? (((vecs[(((long long)i*c)+r)]-s[r])/sqrt(lam))) : (0.0) )   ;
                ;
            }  ;
        }
    }  ;
    kpca_flip(vecs,vals,n,c)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lda_moments( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> g,  scm2cpp::span<double> means,  scm2cpp::span<double> counts,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   if( (k*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t q = 0 ; q < (k*p) ; q += 1 ) {
            means[ q ] = 0.0   ;
        }
    } else {
        for( std::int64_t q = 0 ; q < (k*p) ; q += 1 ) {
            means[ q ] = 0.0   ;
        }
    }  ;
    if( k > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            counts[ c ] = 0.0   ;
        }
    } else {
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            counts[ c ] = 0.0   ;
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        std::int64_t c = lab[i];
        counts[ c ] = (counts[c]+1.0)   ;
        if( p > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]+x[(((long long)i*p)+j)])   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]+x[(((long long)i*p)+j)])   ;
            }
        }  ;
        ;
    }  ;
    if( (k*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                if( counts[c] > 0.0 ) {
                    means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/counts[c])   ;
                } else {
                    0  ;
                }  ;
            }  ;
        }
    } else {
        for( std::int64_t c = 0 ; c < k ; c += 1 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                if( counts[c] > 0.0 ) {
                    means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/counts[c])   ;
                } else {
                    0  ;
                }  ;
            }  ;
        }
    }  ;
    scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lda_within( scm2cpp::span<double> g,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> counts,  double  n,  std::int64_t  p,  std::int64_t  k )
{   if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t a = 0 ; a < p ; a += 1 ) {
            for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                double acc = g[(((long long)a*p)+b)];
                for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                    acc = (acc-(counts[c]*(means[(((long long)c*p)+a)]*means[(((long long)c*p)+b)])))  ;
                }  ;
                g[ (((long long)a*p)+b) ] = (acc/(1.0*n))   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t a = 0 ; a < p ; a += 1 ) {
            for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                double acc = g[(((long long)a*p)+b)];
                for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                    acc = (acc-(counts[c]*(means[(((long long)c*p)+a)]*means[(((long long)c*p)+b)])))  ;
                }  ;
                g[ (((long long)a*p)+b) ] = (acc/(1.0*n))   ;
                ;
            }  ;
        }
    }  ;
    return 0 ;
}


inline std::int64_t
lda_svd_first( scm2cpp::cspan<double> sw,  scm2cpp::span<double> std,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  std::int64_t  p )
{   std::vector<double> mm((p*p),0.0);
    std::vector<double> vv((p*p),0.0);
    std::vector<double> ev(p,0.0);
    std::vector<double> e(p,0.0);
    std::vector<int> ord(p,0);
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double d = sw[(((long long)j*p)+j)];
            std[ j ] = ( ( d > 0.0 ) ? (sqrt(d)) : (1.0) )   ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            double d = sw[(((long long)j*p)+j)];
            std[ j ] = ( ( d > 0.0 ) ? (sqrt(d)) : (1.0) )   ;
            ;
        }
    }  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t a = 0 ; a < p ; a += 1 ) {
            for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                mm[ (((long long)a*p)+b) ] = (sw[(((long long)a*p)+b)]/(std[a]*std[b]))   ;
            }  ;
        }
    } else {
        for( std::int64_t a = 0 ; a < p ; a += 1 ) {
            for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                mm[ (((long long)a*p)+b) ] = (sw[(((long long)a*p)+b)]/(std[a]*std[b]))   ;
            }  ;
        }
    }  ;
    scm2cpp::lapack_syevd(mm, vv, ev, p)  ;
    eig_order(ev,ord,p)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            s[ r ] = ( ( ev[col] > 0.0 ) ? (sqrt(ev[col])) : (0.0) )   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                v[ (((long long)j*p)+r) ] = vv[(((long long)j*p)+col)]   ;
            }  ;
            ;
        }
    } else {
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            s[ r ] = ( ( ev[col] > 0.0 ) ? (sqrt(ev[col])) : (0.0) )   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                v[ (((long long)j*p)+r) ] = vv[(((long long)j*p)+col)]   ;
            }  ;
            ;
        }
    }  ;
    return 0 ;
}


inline std::int64_t
lda_eigen( scm2cpp::span<double> sb,  scm2cpp::span<double> sw,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  std::int64_t  p )
{   std::vector<double> vv((p*p),0.0);
    std::vector<double> w(p,0.0);
    std::vector<double> e(p,0.0);
    std::vector<int> ord(p,0);
    scm2cpp::lapack_sygvd(sb, sw, vv, w, p)  ;
    eig_order(w,ord,p)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            ev[ r ] = w[col]   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                v[ (((long long)j*p)+r) ] = vv[(((long long)j*p)+col)]   ;
            }  ;
            ;
        }
    } else {
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            std::int64_t col = ord[r];
            ev[ r ] = w[col]   ;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                v[ (((long long)j*p)+r) ] = vv[(((long long)j*p)+col)]   ;
            }  ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
tsvd_flip( scm2cpp::span<double> v,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
        std::int64_t big = 0;
        double bv = -1.0;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double a = v[(((long long)j*k)+r)];
            double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
            if( aa > bv ) {
                bv = aa  ;
                big = j  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( v[(((long long)big*k)+r)] < 0.0 ) {
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                v[ (((long long)j*k)+r) ] = (0.0-v[(((long long)j*k)+r)])   ;
            }  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                z[ (((long long)i*k)+r) ] = (0.0-z[(((long long)i*k)+r)])   ;
            }  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return 0 ;
}


inline std::int64_t
tsvd_tall( scm2cpp::cspan<double> x,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::vector<double> g((p*p),0.0);
    std::vector<double> e(p,0.0);
    scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    scm2cpp::lapack_syevr_top(g, v, s, p, k)  ;
    if( k > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    } else {
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    }  ;
    scm2cpp::blas_gemm(z, x, v, 1.0, 0.0, 0, 0, n, k, p)  ;
    tsvd_flip(v,z,n,p,k)  ;
    return 0 ;
}


inline std::int64_t
tsvd_wide( scm2cpp::cspan<double> x,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  scm2cpp::span<double> z,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::vector<double> g((n*n),0.0);
    std::vector<double> u((n*k),0.0);
    std::vector<double> e(n,0.0);
    scm2cpp::blas_syrk(g, x, 1.0, 0.0, 0, n, p)  ;
    scm2cpp::lapack_syevr_top(g, u, s, n, k)  ;
    if( k > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    } else {
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    }  ;
    scm2cpp::blas_gemm(v, x, u, 1.0, 0.0, 1, 0, p, k, n)  ;
    if( (p*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                double sr = s[r];
                v[ (((long long)j*k)+r) ] = ( ( sr > 0.0 ) ? ((v[(((long long)j*k)+r)]/sr)) : (0.0) )   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t j = 0 ; j < p ; j += 1 ) {
            for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                double sr = s[r];
                v[ (((long long)j*k)+r) ] = ( ( sr > 0.0 ) ? ((v[(((long long)j*k)+r)]/sr)) : (0.0) )   ;
                ;
            }  ;
        }
    }  ;
    if( (n*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                z[ (((long long)i*k)+r) ] = (u[(((long long)i*k)+r)]*s[r])   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                z[ (((long long)i*k)+r) ] = (u[(((long long)i*k)+r)]*s[r])   ;
            }  ;
        }
    }  ;
    tsvd_flip(v,z,n,p,k)  ;
    return 0 ;
}


inline std::int64_t
tsvd_gram( scm2cpp::span<double> g,  scm2cpp::span<double> v,  scm2cpp::span<double> s,  std::int64_t  m,  std::int64_t  k )
{   std::vector<double> e(m,0.0);
    scm2cpp::lapack_syevr_top(g, v, s, m, k)  ;
    if( k > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    } else {
        for( std::int64_t r = 0 ; r < k ; r += 1 ) {
            s[ r ] = ( ( s[r] > 0.0 ) ? (sqrt(s[r])) : (0.0) )   ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
svd_jacobi( scm2cpp::span<double> w,  scm2cpp::span<double> q,  std::int64_t  r,  std::int64_t  c )
{   if( (c*c) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < c ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == c) ; j = (j+1) ) {
                q[ (((long long)i*c)+j) ] = ( ( i == j ) ? (1.0) : (0.0) )   ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < c ; i += 1 ) {
            for( std::int64_t j = 0 ; !(j == c) ; j = (j+1) ) {
                q[ (((long long)i*c)+j) ] = ( ( i == j ) ? (1.0) : (0.0) )   ;
            }  ;
        }
    }  ;
    std::int64_t sweeps = 0;
    std::int64_t rotated = 1;
    for(  ; !((rotated == 0 || sweeps == 60)) ;  ) {
        rotated = 0  ;
        sweeps = (sweeps+1)  ;
        for( std::int64_t p = 0 ; !(p == c) ; p = (p+1) ) {
            for( std::int64_t qq = (p+1) ; !(qq >= c) ; qq = (qq+1) ) {
                double alpha = 0.0;
                double beta = 0.0;
                double gamma = 0.0;
                if( r > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:alpha) reduction(+:beta) reduction(+:gamma)
                    for( std::int64_t i = 0 ; i < r ; i += 1 ) {
                        double wp = w[(((long long)i*c)+p)];
                        double wq = w[(((long long)i*c)+qq)];
                        alpha = (alpha+(wp*wp))  ;
                        beta = (beta+(wq*wq))  ;
                        gamma = (gamma+(wp*wq))  ;
                        ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < r ; i += 1 ) {
                        double wp = w[(((long long)i*c)+p)];
                        double wq = w[(((long long)i*c)+qq)];
                        alpha = (alpha+(wp*wp))  ;
                        beta = (beta+(wq*wq))  ;
                        gamma = (gamma+(wp*wq))  ;
                        ;
                    }
                }  ;
                if( std::abs(gamma) > (1e-15*sqrt((alpha*beta))) ) {
                    double zeta = ((beta-alpha)/(2.0*gamma));
                    double t = (( ( zeta < 0.0 ) ? (-1.0) : (1.0) )/(std::abs(zeta)+sqrt((1.0+(zeta*zeta)))));
                    double cs = (1.0/sqrt((1.0+(t*t))));
                    double sn = (cs*t);
                    rotated = 1  ;
                    for( std::int64_t i = 0 ; !(i == r) ; i = (i+1) ) {
                        double wp = w[(((long long)i*c)+p)];
                        double wq = w[(((long long)i*c)+qq)];
                        w[ (((long long)i*c)+p) ] = ((cs*wp)-(sn*wq))   ;
                        w[ (((long long)i*c)+qq) ] = ((sn*wp)+(cs*wq))   ;
                        ;
                    }  ;
                    for( std::int64_t i = 0 ; !(i == c) ; i = (i+1) ) {
                        double vp = q[(((long long)i*c)+p)];
                        double vq = q[(((long long)i*c)+qq)];
                        q[ (((long long)i*c)+p) ] = ((cs*vp)-(sn*vq))   ;
                        q[ (((long long)i*c)+qq) ] = ((sn*vp)+(cs*vq))   ;
                        ;
                    }  ;
                    ;
                    ;
                    ;
                    ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
        }  ;
    }  ;
    return sweeps ;
}


inline std::int64_t
svd_collect( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::span<double> s,  scm2cpp::span<double> l,  scm2cpp::span<double> rr,  scm2cpp::span<int> ord,  std::int64_t  r,  std::int64_t  c )
{   if( (c*r) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            double nrm = 0.0;
            for( std::int64_t i = 0 ; !(i == r) ; i = (i+1) ) {
                nrm = (nrm+(w[(((long long)i*c)+j)]*w[(((long long)i*c)+j)]))  ;
            }  ;
            s[ j ] = sqrt(nrm)   ;
            ord[ j ] = j   ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            double nrm = 0.0;
            for( std::int64_t i = 0 ; !(i == r) ; i = (i+1) ) {
                nrm = (nrm+(w[(((long long)i*c)+j)]*w[(((long long)i*c)+j)]))  ;
            }  ;
            s[ j ] = sqrt(nrm)   ;
            ord[ j ] = j   ;
            ;
        }
    }  ;
    for( std::int64_t j = 0 ; !(j == c) ; j = (j+1) ) {
        std::int64_t best = j;
        for( std::int64_t t = (j+1) ; !(t >= c) ; t = (t+1) ) {
            if( s[ord[t]] > s[ord[best]] ) {
                best = t  ;
            } else {
                0  ;
            }  ;
        }  ;
        std::int64_t tmp = ord[j];
        ord[ j ] = ord[best]   ;
        ord[ best ] = tmp   ;
        ;
        ;
    }  ;
    std::vector<double> sv(c,0.0);
    if( (c*r) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            std::int64_t col = ord[j];
            double sg = s[col];
            sv[ j ] = sg   ;
            for( std::int64_t i = 0 ; !(i == r) ; i = (i+1) ) {
                l[ (((long long)i*c)+j) ] = ( ( sg > 0.0 ) ? ((w[(((long long)i*c)+col)]/sg)) : (0.0) )   ;
            }  ;
            for( std::int64_t i = 0 ; !(i == c) ; i = (i+1) ) {
                rr[ (((long long)j*c)+i) ] = q[(((long long)i*c)+col)]   ;
            }  ;
            ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            std::int64_t col = ord[j];
            double sg = s[col];
            sv[ j ] = sg   ;
            for( std::int64_t i = 0 ; !(i == r) ; i = (i+1) ) {
                l[ (((long long)i*c)+j) ] = ( ( sg > 0.0 ) ? ((w[(((long long)i*c)+col)]/sg)) : (0.0) )   ;
            }  ;
            for( std::int64_t i = 0 ; !(i == c) ; i = (i+1) ) {
                rr[ (((long long)j*c)+i) ] = q[(((long long)i*c)+col)]   ;
            }  ;
            ;
            ;
        }
    }  ;
    if( c > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            s[ j ] = sv[j]   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < c ; j += 1 ) {
            s[ j ] = sv[j]   ;
        }
    }  ;
    ;
    return 0 ;
}


inline std::int64_t
sym_svd( scm2cpp::span<double> a,  scm2cpp::span<double> u,  scm2cpp::span<double> s,  scm2cpp::span<double> vt,  std::int64_t  m,  std::int64_t  n )
{   if( m >= n ) {
        std::vector<double> q((n*n),0.0);
        std::vector<int> ord(n,0);
        std::int64_t sweeps = svd_jacobi(a,q,m,n);
        svd_collect(a,q,s,u,vt,ord,m,n)  ;
        return sweeps ;
    }
    else {
        std::vector<double> w((n*m),0.0);
        std::vector<double> q((m*m),0.0);
        std::vector<double> l((n*m),0.0);
        std::vector<int> ord(m,0);
        if( (m*n) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                    w[ (((long long)j*m)+i) ] = a[(((long long)i*n)+j)]   ;
                }  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                    w[ (((long long)j*m)+i) ] = a[(((long long)i*n)+j)]   ;
                }  ;
            }
        }  ;
        std::int64_t sweeps = svd_jacobi(w,q,n,m);
        svd_collect(w,q,s,l,u,ord,n,m)  ;
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            for( std::int64_t j = (i+1) ; !(j >= m) ; j = (j+1) ) {
                double tmp = u[(((long long)i*m)+j)];
                u[ (((long long)i*m)+j) ] = u[(((long long)j*m)+i)]   ;
                u[ (((long long)j*m)+i) ] = tmp   ;
                ;
            }  ;
        }  ;
        if( (m*n) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                    vt[ (((long long)i*n)+j) ] = l[(((long long)j*m)+i)]   ;
                }  ;
            }
        } else {
            for( std::int64_t i = 0 ; i < m ; i += 1 ) {
                for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                    vt[ (((long long)i*n)+j) ] = l[(((long long)j*m)+i)]   ;
                }  ;
            }
        }  ;
        return sweeps ;
    }
}


inline std::int64_t
pls_pinv( scm2cpp::cspan<double> a,  scm2cpp::span<double> pv,  std::int64_t  m )
{   std::vector<double> w((m*m),0.0);
    std::vector<double> v((m*m),0.0);
    std::vector<double> vs((m*m),0.0);
    std::vector<double> ev(m,0.0);
    std::vector<double> e(m,0.0);
    double top = 0.0;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t s = 0 ; s < (m*m) ; s += 1 ) {
            w[ s ] = a[s]   ;
        }
    } else {
        for( std::int64_t s = 0 ; s < (m*m) ; s += 1 ) {
            w[ s ] = a[s]   ;
        }
    }  ;
    scm2cpp::lapack_syevd(w, v, ev, m)  ;
    for( std::int64_t k = 0 ; !(k == m) ; k = (k+1) ) {
        if( ev[k] > top ) {
            top = ev[k]  ;
        } else {
            0  ;
        }  ;
    }  ;
    double cut = ((1000000.0*2.220446049250313e-16)*sqrt(top));
    double lo = ((1000.0*2.220446049250313e-16)*top);
    if( (m*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t k = 0 ; !(k == m) ; k = (k+1) ) {
                double lam = ev[k];
                vs[ (((long long)i*m)+k) ] = ( ( lam > lo ) ? (( ( sqrt(lam) > cut ) ? ((v[(((long long)i*m)+k)]/lam)) : (0.0) )) : (0.0) )   ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            for( std::int64_t k = 0 ; !(k == m) ; k = (k+1) ) {
                double lam = ev[k];
                vs[ (((long long)i*m)+k) ] = ( ( lam > lo ) ? (( ( sqrt(lam) > cut ) ? ((v[(((long long)i*m)+k)]/lam)) : (0.0) )) : (0.0) )   ;
                ;
            }  ;
        }
    }  ;
    scm2cpp::blas_gemm(pv, vs, v, 1.0, 0.0, 0, 1, m, m, m)  ;
    ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
pls_mv( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> x,  scm2cpp::span<double> y,  std::int64_t  m,  std::int64_t  n )
{   if( (m*n) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                acc = (acc+(a[(((long long)i*n)+j)]*x[j]))  ;
            }  ;
            y[ i ] = acc   ;
            ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            double acc = 0.0;
            for( std::int64_t j = 0 ; !(j == n) ; j = (j+1) ) {
                acc = (acc+(a[(((long long)i*n)+j)]*x[j]))  ;
            }  ;
            y[ i ] = acc   ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
pls_mtv( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> x,  scm2cpp::span<double> y,  std::int64_t  m,  std::int64_t  n )
{   if( (n*m) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < n ; j += 1 ) {
            double acc = 0.0;
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                acc = (acc+(a[(((long long)i*n)+j)]*x[i]))  ;
            }  ;
            y[ j ] = acc   ;
            ;
        }
    } else {
        for( std::int64_t j = 0 ; j < n ; j += 1 ) {
            double acc = 0.0;
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                acc = (acc+(a[(((long long)i*n)+j)]*x[i]))  ;
            }  ;
            y[ j ] = acc   ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
pls_dot( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  std::int64_t  m )
{   double acc = 0.0;
    if( m > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:acc)
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            acc = (acc+(x[i]*y[i]))  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < m ; i += 1 ) {
            acc = (acc+(x[i]*y[i]))  ;
        }
    }  ;
    return acc ;
}


inline std::int64_t
pls_fit( scm2cpp::span<double> cxx,  scm2cpp::span<double> cxy,  scm2cpp::span<double> cyy,  scm2cpp::span<double> xw,  scm2cpp::span<double> yw,  scm2cpp::span<double> xl,  scm2cpp::span<double> yl,  scm2cpp::span<int> niter,  std::int64_t  p,  std::int64_t  q,  std::int64_t  k,  std::int64_t  mode,  std::int64_t  canon,  std::int64_t  algo,  std::int64_t  maxit,  double  tol )
{   std::vector<double> c(q,0.0);
    std::vector<double> w(p,0.0);
    std::vector<double> wold(p,0.0);
    std::vector<double> yv(q,0.0);
    std::vector<double> a(p,0.0);
    std::vector<double> b(q,0.0);
    std::vector<double> g(p,0.0);
    std::vector<double> cy(q,0.0);
    std::vector<double> tmp(p,0.0);
    std::vector<double> px((p*p),0.0);
    std::vector<double> py((q*q),0.0);
    std::vector<double> cm((p*q),0.0);
    std::vector<double> uu((p*p),0.0);
    std::vector<double> ss(p,0.0);
    std::vector<double> vt((p*q),0.0);
    double eps = 2.220446049250313e-16;
    std::int64_t found = 0;
    std::int64_t stop = 0;
    for( std::int64_t comp = 0 ; !((comp == k || stop == 1)) ; comp = (comp+1) ) {
        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
            if( cyy[(((long long)j*q)+j)] < (100.0*(eps*eps)) ) {
                for( std::int64_t i = 0 ; !(i == q) ; i = (i+1) ) {
                    cyy[ (((long long)j*q)+i) ] = 0.0   ;
                    cyy[ (((long long)i*q)+j) ] = 0.0   ;
                }  ;
                for( std::int64_t i = 0 ; !(i == p) ; i = (i+1) ) {
                    cxy[ (((long long)i*q)+j) ] = 0.0   ;
                }  ;
            } else {
                0  ;
            }  ;
        }  ;
        std::int64_t first = -1;
        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
            if( (first < 0 && cyy[(((long long)j*q)+j)] > (eps*eps)) ) {
                first = j  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( first < 0 ) {
            stop = 1  ;
        } else {
            if( algo == 1 ) {
                std::int64_t r = ( ( p < q ) ? (p) : (q) );
                if( (p*q) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t s = 0 ; s < (p*q) ; s += 1 ) {
                        cm[ s ] = cxy[s]   ;
                    }
                } else {
                    for( std::int64_t s = 0 ; s < (p*q) ; s += 1 ) {
                        cm[ s ] = cxy[s]   ;
                    }
                }  ;
                scm2cpp::lapack_gesdd(cm, uu, ss, vt, p, q)  ;
                if( p > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        w[ i ] = uu[((long long)i*r)]   ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        w[ i ] = uu[((long long)i*r)]   ;
                    }
                }  ;
                if( q > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        yv[ j ] = vt[j]   ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        yv[ j ] = vt[j]   ;
                    }
                }  ;
                niter[ comp ] = 0   ;
                ;
            } else {
                if( mode == 1 ) {
                    pls_pinv(cxx,px,p)  ;
                    pls_pinv(cyy,py,q)  ;
                } else {
                    0  ;
                }  ;
                if( q > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        c[ j ] = ( ( j == first ) ? (1.0) : (0.0) )   ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        c[ j ] = ( ( j == first ) ? (1.0) : (0.0) )   ;
                    }
                }  ;
                if( p > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        wold[ i ] = 100.0   ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        wold[ i ] = 100.0   ;
                    }
                }  ;
                std::int64_t done = 0;
                for( std::int64_t it = 0 ; !((done == 1 || it == maxit)) ; it = (it+1) ) {
                    pls_mv(cxy,c,g,p,q)  ;
                    if( mode == 1 ) {
                        pls_mv(px,g,w,p,p)  ;
                    } else {
                        pls_mv(cyy,c,cy,q,q)  ;
                        double uu2 = pls_dot(c,cy,q);
                        if( p > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                                w[ i ] = (g[i]/uu2)   ;
                            }
                        } else {
                            for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                                w[ i ] = (g[i]/uu2)   ;
                            }
                        }  ;
                        ;
                    }  ;
                    double nw = (sqrt(pls_dot(w,w,p))+eps);
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            w[ i ] = (w[i]/nw)   ;
                        }
                    } else {
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            w[ i ] = (w[i]/nw)   ;
                        }
                    }  ;
                    ;
                    pls_mtv(cxy,w,b,p,q)  ;
                    if( mode == 1 ) {
                        pls_mv(py,b,yv,q,q)  ;
                    } else {
                        pls_mv(cxx,w,a,p,p)  ;
                        double s2 = pls_dot(w,a,p);
                        if( q > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                                yv[ j ] = (b[j]/s2)   ;
                            }
                        } else {
                            for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                                yv[ j ] = (b[j]/s2)   ;
                            }
                        }  ;
                        ;
                    }  ;
                    if( canon == 1 ) {
                        double ny = (sqrt(pls_dot(yv,yv,q))+eps);
                        if( q > 65536 ) {
                            #pragma omp parallel for num_threads(scm2cpp::omp_team())
                            for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                                yv[ j ] = (yv[j]/ny)   ;
                            }
                        } else {
                            for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                                yv[ j ] = (yv[j]/ny)   ;
                            }
                        }  ;
                        ;
                    } else {
                        0  ;
                    }  ;
                    double yy = (pls_dot(yv,yv,q)+eps);
                    if( q > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                            c[ j ] = (yv[j]/yy)   ;
                        }
                    } else {
                        for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                            c[ j ] = (yv[j]/yy)   ;
                        }
                    }  ;
                    ;
                    double d = 0.0;
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:d)
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            d = (d+((w[i]-wold[i])*(w[i]-wold[i])))  ;
                        }
                    } else {
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            d = (d+((w[i]-wold[i])*(w[i]-wold[i])))  ;
                        }
                    }  ;
                    if( (d < tol || q == 1) ) {
                        done = 1  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                    if( p > 65536 ) {
                        #pragma omp parallel for num_threads(scm2cpp::omp_team())
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            wold[ i ] = w[i]   ;
                        }
                    } else {
                        for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                            wold[ i ] = w[i]   ;
                        }
                    }  ;
                    niter[ comp ] = (it+1)   ;
                }  ;
                ;
            }  ;
            std::int64_t big = 0;
            double bv = -1.0;
            for( std::int64_t i = 0 ; !(i == p) ; i = (i+1) ) {
                double aa = ( ( w[i] < 0.0 ) ? ((0.0-w[i])) : (w[i]) );
                if( aa > bv ) {
                    bv = aa  ;
                    big = i  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
            if( w[big] < 0.0 ) {
                if( p > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        w[ i ] = (0.0-w[i])   ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        w[ i ] = (0.0-w[i])   ;
                    }
                }  ;
                if( q > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        yv[ j ] = (0.0-yv[j])   ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < q ; j += 1 ) {
                        yv[ j ] = (0.0-yv[j])   ;
                    }
                }  ;
            } else {
                0  ;
            }  ;
            ;
            pls_mv(cxx,w,a,p,p)  ;
            pls_mtv(cxy,w,b,p,q)  ;
            double s2 = pls_dot(w,a,p);
            double yss = ( ( canon == 1 ) ? (1.0) : (pls_dot(yv,yv,q)) );
            for( std::int64_t i = 0 ; !(i == p) ; i = (i+1) ) {
                xl[ (((long long)i*k)+comp) ] = (a[i]/s2)   ;
            }  ;
            if( canon == 1 ) {
                pls_mv(cyy,yv,cy,q,q)  ;
                pls_mv(cxy,yv,g,p,q)  ;
                double uu3 = (pls_dot(yv,cy,q)/(yss*yss));
                double h = (pls_dot(w,g,p)/yss);
                for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                    yl[ (((long long)j*k)+comp) ] = ((cy[j]/yss)/uu3)   ;
                }  ;
                if( p > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        tmp[ i ] = ((g[i]/yss)-((a[i]/s2)*h))   ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        tmp[ i ] = ((g[i]/yss)-((a[i]/s2)*h))   ;
                    }
                }  ;
                if( (p*q) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cxy[ (((long long)i*q)+j) ] = ((cxy[(((long long)i*q)+j)]-((a[i]*b[j])/s2))-(tmp[i]*yl[(((long long)j*k)+comp)]))   ;
                        }  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cxy[ (((long long)i*q)+j) ] = ((cxy[(((long long)i*q)+j)]-((a[i]*b[j])/s2))-(tmp[i]*yl[(((long long)j*k)+comp)]))   ;
                        }  ;
                    }
                }  ;
                if( (q*q) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < q ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cyy[ (((long long)i*q)+j) ] = (cyy[(((long long)i*q)+j)]-(((cy[i]/yss)*(cy[j]/yss))/uu3))   ;
                        }  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < q ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cyy[ (((long long)i*q)+j) ] = (cyy[(((long long)i*q)+j)]-(((cy[i]/yss)*(cy[j]/yss))/uu3))   ;
                        }  ;
                    }
                }  ;
                ;
            } else {
                for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                    yl[ (((long long)j*k)+comp) ] = (b[j]/s2)   ;
                }  ;
                if( (p*q) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cxy[ (((long long)i*q)+j) ] = (cxy[(((long long)i*q)+j)]-((a[i]*b[j])/s2))   ;
                        }  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cxy[ (((long long)i*q)+j) ] = (cxy[(((long long)i*q)+j)]-((a[i]*b[j])/s2))   ;
                        }  ;
                    }
                }  ;
                if( (q*q) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < q ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cyy[ (((long long)i*q)+j) ] = (cyy[(((long long)i*q)+j)]-((b[i]*b[j])/s2))   ;
                        }  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < q ; i += 1 ) {
                        for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                            cyy[ (((long long)i*q)+j) ] = (cyy[(((long long)i*q)+j)]-((b[i]*b[j])/s2))   ;
                        }  ;
                    }
                }  ;
            }  ;
            if( (p*p) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                        cxx[ (((long long)i*p)+j) ] = (cxx[(((long long)i*p)+j)]-((a[i]*a[j])/s2))   ;
                    }  ;
                }
            } else {
                for( std::int64_t i = 0 ; i < p ; i += 1 ) {
                    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                        cxx[ (((long long)i*p)+j) ] = (cxx[(((long long)i*p)+j)]-((a[i]*a[j])/s2))   ;
                    }  ;
                }
            }  ;
            ;
            for( std::int64_t i = 0 ; !(i == p) ; i = (i+1) ) {
                xw[ (((long long)i*k)+comp) ] = w[i]   ;
            }  ;
            for( std::int64_t j = 0 ; !(j == q) ; j = (j+1) ) {
                yw[ (((long long)j*k)+comp) ] = yv[j]   ;
            }  ;
            found = (found+1)  ;
        }  ;
        ;
    }  ;
    return found ;
}


inline std::int64_t
fa_fit( scm2cpp::cspan<double> c,  scm2cpp::cspan<double> var,  scm2cpp::span<double> psi,  scm2cpp::span<double> w,  scm2cpp::span<double> ll,  double  n,  std::int64_t  p,  std::int64_t  k,  std::int64_t  maxit,  double  tol )
{   std::vector<double> m((p*p),0.0);
    std::vector<double> v((p*k),0.0);
    std::vector<double> ev(k,0.0);
    std::vector<double> e(p,0.0);
    std::vector<double> sp(p,0.0);
    double llconst = ((1.8378770664093453*double(p))+double(k));
    std::int64_t it = 0;
    std::int64_t done = 0;
    double old = -1e+300;
    for( std::int64_t i = 0 ; !(i == maxit) ; i = (i+1) ) {
        if( done == 0 ) {
            double tr = 0.0;
            double sumlog = 0.0;
            double sums = 0.0;
            double slp = 0.0;
            if( p > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    sp[ j ] = (sqrt(psi[j])+1e-12)   ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    sp[ j ] = (sqrt(psi[j])+1e-12)   ;
                }
            }  ;
            if( (p*p) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t a = 0 ; a < p ; a += 1 ) {
                    for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                        m[ (((long long)a*p)+b) ] = (c[(((long long)a*p)+b)]/(sp[a]*sp[b]))   ;
                    }  ;
                }
            } else {
                for( std::int64_t a = 0 ; a < p ; a += 1 ) {
                    for( std::int64_t b = 0 ; !(b == p) ; b = (b+1) ) {
                        m[ (((long long)a*p)+b) ] = (c[(((long long)a*p)+b)]/(sp[a]*sp[b]))   ;
                    }  ;
                }
            }  ;
            if( p > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:tr)
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    tr = (tr+m[(((long long)j*p)+j)])  ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    tr = (tr+m[(((long long)j*p)+j)])  ;
                }
            }  ;
            scm2cpp::lapack_syevr_top(m, v, ev, p, k)  ;
            if( (k*p) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:sumlog) reduction(+:sums)
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    sumlog = (sumlog+log(ev[r]))  ;
                    sums = (sums+ev[r])  ;
                    double f = sqrt(scm2cpp::max2( (ev[r]-1.0), 0.0 ));
                    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                        w[ (((long long)r*p)+j) ] = ((f*v[(((long long)j*k)+r)])*sp[j])   ;
                    }  ;
                    ;
                }
            } else {
                for( std::int64_t r = 0 ; r < k ; r += 1 ) {
                    sumlog = (sumlog+log(ev[r]))  ;
                    sums = (sums+ev[r])  ;
                    double f = sqrt(scm2cpp::max2( (ev[r]-1.0), 0.0 ));
                    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                        w[ (((long long)r*p)+j) ] = ((f*v[(((long long)j*k)+r)])*sp[j])   ;
                    }  ;
                    ;
                }
            }  ;
            if( p > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:slp)
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    slp = (slp+log(psi[j]))  ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    slp = (slp+log(psi[j]))  ;
                }
            }  ;
            double l = ((-0.5*(1.0*n))*((llconst+sumlog)+((tr-sums)+slp)));
            ll[ i ] = l   ;
            it = (i+1)  ;
            if( (l-old) < tol ) {
                done = 1  ;
            } else {
                old = l  ;
                if( (p*k) > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                        double acc = 0.0;
                        for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                            acc = (acc+(w[(((long long)r*p)+j)]*w[(((long long)r*p)+j)]))  ;
                        }  ;
                        psi[ j ] = scm2cpp::max2( (var[j]-acc), 1e-12 )   ;
                        ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                        double acc = 0.0;
                        for( std::int64_t r = 0 ; !(r == k) ; r = (r+1) ) {
                            acc = (acc+(w[(((long long)r*p)+j)]*w[(((long long)r*p)+j)]))  ;
                        }  ;
                        psi[ j ] = scm2cpp::max2( (var[j]-acc), 1e-12 )   ;
                        ;
                    }
                }  ;
            }  ;
            ;
            ;
        } else {
            0  ;
        }  ;
    }  ;
    if( done == 1 ) {
        return it ;
    }
    else {
        return (maxit+1) ;
    }
}


inline std::int64_t
linreg_solve( scm2cpp::span<double> g,  scm2cpp::span<double> b,  scm2cpp::span<double> coef,  std::int64_t  p,  std::int64_t  t,  double  ratio,  double  tol )
{   std::vector<double> d(p,0.0);
    double dmax = 0.0;
    double dmin = 1e+300;
    std::int64_t zero = 0;
    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
        double gjj = g[(((long long)j*p)+j)];
        if( gjj > 0.0 ) {
            d[ j ] = sqrt(gjj)   ;
            if( gjj > dmax ) {
                dmax = gjj  ;
            } else {
                0  ;
            }  ;
            if( gjj < dmin ) {
                dmin = gjj  ;
            } else {
                0  ;
            }  ;
        } else {
            zero = 1  ;
        }  ;
        ;
    }  ;
    if( zero == 1 ) {
        return 0 ;
    }
    else {
        if( (p*p) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t a = 0 ; a < p ; a += 1 ) {
                for( std::int64_t c = 0 ; !(c == p) ; c = (c+1) ) {
                    g[ (((long long)a*p)+c) ] = (g[(((long long)a*p)+c)]/(d[a]*d[c]))   ;
                }  ;
            }
        } else {
            for( std::int64_t a = 0 ; a < p ; a += 1 ) {
                for( std::int64_t c = 0 ; !(c == p) ; c = (c+1) ) {
                    g[ (((long long)a*p)+c) ] = (g[(((long long)a*p)+c)]/(d[a]*d[c]))   ;
                }  ;
            }
        }  ;
        if( (p*t) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                for( std::int64_t q = 0 ; !(q == t) ; q = (q+1) ) {
                    b[ (((long long)j*t)+q) ] = (b[(((long long)j*t)+q)]/d[j])   ;
                }  ;
            }
        } else {
            for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                for( std::int64_t q = 0 ; !(q == t) ; q = (q+1) ) {
                    b[ (((long long)j*t)+q) ] = (b[(((long long)j*t)+q)]/d[j])   ;
                }  ;
            }
        }  ;
        double rc = scm2cpp::lapack_posv_rcond(g, b, p, t);
        if( (rc >= ratio && (dmax/dmin) <= (rc*(1.0/((1.0*tol)*tol)))) ) {
            if( (p*t) > 65536 ) {
                #pragma omp parallel for num_threads(scm2cpp::omp_team())
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    for( std::int64_t q = 0 ; !(q == t) ; q = (q+1) ) {
                        coef[ (((long long)j*t)+q) ] = (b[(((long long)j*t)+q)]/d[j])   ;
                    }  ;
                }
            } else {
                for( std::int64_t j = 0 ; j < p ; j += 1 ) {
                    for( std::int64_t q = 0 ; !(q == t) ; q = (q+1) ) {
                        coef[ (((long long)j*t)+q) ] = (b[(((long long)j*t)+q)]/d[j])   ;
                    }  ;
                }
            }  ;
            return 1 ;
        }
        else {
            return 0 ;
        }
    }
}


inline std::int64_t
linreg_singular( scm2cpp::span<double> g,  scm2cpp::span<double> s,  std::int64_t  p,  double  tol )
{   std::vector<double> v((p*p),0.0);
    std::vector<double> lam(p,0.0);
    std::vector<double> e(p,0.0);
    std::vector<int> ord(p,0);
    std::int64_t rank = 0;
    scm2cpp::lapack_syevd(g, v, lam, p)  ;
    eig_order(lam,ord,p)  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            double x = lam[ord[r]];
            s[ r ] = ( ( x > 0.0 ) ? (sqrt(x)) : (0.0) )   ;
            ;
        }
    } else {
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            double x = lam[ord[r]];
            s[ r ] = ( ( x > 0.0 ) ? (sqrt(x)) : (0.0) )   ;
            ;
        }
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:rank)
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            if( s[r] > (tol*s[0]) ) {
                rank = (rank+1)  ;
            } else {
                0  ;
            }  ;
        }
    } else {
        for( std::int64_t r = 0 ; r < p ; r += 1 ) {
            if( s[r] > (tol*s[0]) ) {
                rank = (rank+1)  ;
            } else {
                0  ;
            }  ;
        }
    }  ;
    return rank ;
}


SCM2CPP_FN inline std::int64_t
csr_gram( scm2cpp::cspan<std::int64_t> rp,  scm2cpp::cspan<int> ci,  scm2cpp::cspan<double> v,  scm2cpp::span<double> g,  std::int64_t  p,  std::int64_t  r0,  std::int64_t  r1 )
{   for( std::int64_t i = r0 ; !(i == r1) ; i = (i+1) ) {
        for( std::int64_t u = rp[i] ; !(u == rp[(i+1)]) ; u = (u+1) ) {
            std::int64_t a = ci[u];
            double x = v[u];
            for( std::int64_t w = rp[i] ; !(w == rp[(i+1)]) ; w = (w+1) ) {
                std::int64_t b = ci[w];
                if( b >= a ) {
                    g[ (((long long)a*p)+b) ] = (g[(((long long)a*p)+b)]+(x*v[w]))   ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
            ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
csr_mm( scm2cpp::cspan<std::int64_t> rp,  scm2cpp::cspan<int> ci,  scm2cpp::cspan<double> v,  scm2cpp::cspan<double> b,  scm2cpp::span<double> c,  std::int64_t  n,  std::int64_t  k )
{   if( (n*k) > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t s = 0 ; s < (n*k) ; s += 1 ) {
            c[ s ] = 0.0   ;
        }
    } else {
        for( std::int64_t s = 0 ; s < (n*k) ; s += 1 ) {
            c[ s ] = 0.0   ;
        }
    }  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t u = rp[i] ; !(u == rp[(i+1)]) ; u = (u+1) ) {
                std::int64_t j = ci[u];
                double x = v[u];
                for( std::int64_t q = 0 ; !(q == k) ; q = (q+1) ) {
                    c[ (((long long)i*k)+q) ] = (c[(((long long)i*k)+q)]+(x*b[(((long long)j*k)+q)]))   ;
                }  ;
                ;
            }  ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            for( std::int64_t u = rp[i] ; !(u == rp[(i+1)]) ; u = (u+1) ) {
                std::int64_t j = ci[u];
                double x = v[u];
                for( std::int64_t q = 0 ; !(q == k) ; q = (q+1) ) {
                    c[ (((long long)i*k)+q) ] = (c[(((long long)i*k)+q)]+(x*b[(((long long)j*k)+q)]))   ;
                }  ;
                ;
            }  ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lu_solve( scm2cpp::span<double> a,  scm2cpp::span<double> b,  std::int64_t  n )
{   std::int64_t bad = 0;
    for( std::int64_t k = 0 ; !((bad == 1 || k >= n)) ; k = (k+1) ) {
        std::int64_t piv = k;
        double big = gram_abs(a[(((long long)k*n)+k)]);
        for( std::int64_t i = (k+1) ; !(i >= n) ; i = (i+1) ) {
            if( gram_abs(a[(((long long)i*n)+k)]) > big ) {
                big = gram_abs(a[(((long long)i*n)+k)])  ;
                piv = i  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( !(big > 0.0) ) {
            bad = 1  ;
        } else {
            if( !(piv == k) ) {
                for( std::int64_t j = k ; !(j >= n) ; j = (j+1) ) {
                    double t = a[(((long long)k*n)+j)];
                    a[ (((long long)k*n)+j) ] = a[(((long long)piv*n)+j)]   ;
                    a[ (((long long)piv*n)+j) ] = t   ;
                    ;
                }  ;
                double t = b[k];
                b[ k ] = b[piv]   ;
                b[ piv ] = t   ;
                ;
            } else {
                0  ;
            }  ;
            for( std::int64_t i = (k+1) ; !(i >= n) ; i = (i+1) ) {
                double l = (a[(((long long)i*n)+k)]/a[(((long long)k*n)+k)]);
                for( std::int64_t j = (k+1) ; !(j >= n) ; j = (j+1) ) {
                    a[ (((long long)i*n)+j) ] = (a[(((long long)i*n)+j)]-(l*a[(((long long)k*n)+j)]))   ;
                }  ;
                b[ i ] = (b[i]-(l*b[k]))   ;
                ;
            }  ;
        }  ;
        ;
    }  ;
    if( bad == 0 ) {
        for( std::int64_t i = (n-1) ; !(i < 0) ; i = (i-1) ) {
            double s = b[i];
            for( std::int64_t j = (i+1) ; !(j >= n) ; j = (j+1) ) {
                s = (s-(a[(((long long)i*n)+j)]*b[j]))  ;
            }  ;
            b[ i ] = (s/a[(((long long)i*n)+i)])   ;
            ;
        }  ;
    } else {
        0  ;
    }  ;
    return bad ;
}


inline std::int64_t
quantile_fn( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> c,  scm2cpp::span<double> x,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  tol,  std::int64_t  maxit,  std::int64_t  n,  std::int64_t  m )
{   std::vector<double> s(n,0.0);
    std::vector<double> z(n,0.0);
    std::vector<double> w(n,0.0);
    std::vector<double> q(n,0.0);
    std::vector<double> r(n,0.0);
    std::vector<double> t(n,0.0);
    std::vector<double> dx(n,0.0);
    std::vector<double> dz(n,0.0);
    std::vector<double> dw(n,0.0);
    std::vector<double> aq((n*m),0.0);
    std::vector<double> g((m*m),0.0);
    std::vector<double> g2((m*m),0.0);
    std::vector<double> b(m,0.0);
    std::vector<double> y(m,0.0);
    std::vector<double> dy(m,0.0);
    std::vector<double> rhs(m,0.0);
    std::vector<double> rhs2(m,0.0);
    double beta = 0.9995;
    double ca = 0.0;
    double cnorm = 0.0;
    double gap = 0.0;
    double obj = 0.0;
    std::int64_t it = 0;
    std::int64_t status = 0;
    std::int64_t done = 0;
    scm2cpp::blas_gemv(b, a, x, 1.0, 0.0, 1, m, n)  ;
    if( n > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:ca) reduction(+:cnorm)
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ca = (ca+(c[i]*x[i]))  ;
            cnorm = (cnorm+gram_abs(c[i]))  ;
            s[ i ] = (1.0-x[i])   ;
        }
    } else {
        for( std::int64_t i = 0 ; i < n ; i += 1 ) {
            ca = (ca+(c[i]*x[i]))  ;
            cnorm = (cnorm+gram_abs(c[i]))  ;
            s[ i ] = (1.0-x[i])   ;
        }
    }  ;
    scm2cpp::blas_syrk(g, a, 1.0, 0.0, 1, m, n)  ;
    scm2cpp::blas_gemv(y, a, c, 1.0, 0.0, 1, m, n)  ;
    if( scm2cpp::lapack_posv(g, y, m, 1) == 0 ) {
        scm2cpp::blas_gemv(t, a, y, 1.0, 0.0, 0, n, m)  ;
        if( n > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double ri = (c[i]-t[i]);
                double rr = ( ( ri == 0.0 ) ? (0.001) : (ri) );
                z[ i ] = ( ( rr > 0.0 ) ? (rr) : (0.0) )   ;
                w[ i ] = (z[i]-rr)   ;
                ;
                ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double ri = (c[i]-t[i]);
                double rr = ( ( ri == 0.0 ) ? (0.001) : (ri) );
                z[ i ] = ( ( rr > 0.0 ) ? (rr) : (0.0) )   ;
                w[ i ] = (z[i]-rr)   ;
                ;
                ;
            }
        }  ;
    } else {
        if( m > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                y[ j ] = 0.0   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                y[ j ] = 0.0   ;
            }
        }  ;
        status = 2  ;
        done = 1  ;
    }  ;
    for(  ; !((done == 1 || it >= maxit)) ;  ) {
        it = (it+1)  ;
        if( (n*m) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double qi = (1.0/((z[i]/x[i])+(w[i]/s[i])));
                double sq = sqrt(qi);
                q[ i ] = qi   ;
                r[ i ] = (z[i]-w[i])   ;
                t[ i ] = (qi*r[i])   ;
                for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                    aq[ (((long long)i*m)+j) ] = (sq*a[(((long long)i*m)+j)])   ;
                }  ;
                ;
                ;
            }
        } else {
            for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                double qi = (1.0/((z[i]/x[i])+(w[i]/s[i])));
                double sq = sqrt(qi);
                q[ i ] = qi   ;
                r[ i ] = (z[i]-w[i])   ;
                t[ i ] = (qi*r[i])   ;
                for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                    aq[ (((long long)i*m)+j) ] = (sq*a[(((long long)i*m)+j)])   ;
                }  ;
                ;
                ;
            }
        }  ;
        scm2cpp::blas_syrk(g, aq, 1.0, 0.0, 1, m, n)  ;
        scm2cpp::blas_gemv(rhs, a, t, 1.0, 0.0, 1, m, n)  ;
        if( (m*m) > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t k = 0 ; k < (m*m) ; k += 1 ) {
                g2[ k ] = g[k]   ;
            }
        } else {
            for( std::int64_t k = 0 ; k < (m*m) ; k += 1 ) {
                g2[ k ] = g[k]   ;
            }
        }  ;
        if( m > 65536 ) {
            #pragma omp parallel for num_threads(scm2cpp::omp_team())
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                dy[ j ] = rhs[j]   ;
            }
        } else {
            for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                dy[ j ] = rhs[j]   ;
            }
        }  ;
        if( scm2cpp::lapack_posv(g, dy, m, 1) == 0 ) {
            double fp = 1e+20;
            double fd = 1e+20;
            scm2cpp::blas_gemv(t, a, dy, 1.0, 0.0, 0, n, m)  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double dxi = (q[i]*(t[i]-r[i]));
                double dzi = ((0.0-z[i])*(1.0+(dxi/x[i])));
                double dwi = ((0.0-w[i])*(1.0-(dxi/s[i])));
                dx[ i ] = dxi   ;
                dz[ i ] = dzi   ;
                dw[ i ] = dwi   ;
                if( dxi < 0.0 ) {
                    fp = scm2cpp::min2( fp, ((0.0-x[i])/dxi) )  ;
                } else {
                    0  ;
                }  ;
                if( dxi > 0.0 ) {
                    fp = scm2cpp::min2( fp, (s[i]/dxi) )  ;
                } else {
                    0  ;
                }  ;
                if( dzi < 0.0 ) {
                    fd = scm2cpp::min2( fd, ((0.0-z[i])/dzi) )  ;
                } else {
                    0  ;
                }  ;
                if( dwi < 0.0 ) {
                    fd = scm2cpp::min2( fd, ((0.0-w[i])/dwi) )  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
            }  ;
            fp = scm2cpp::min2( (beta*fp), 1.0 )  ;
            fd = scm2cpp::min2( (beta*fd), 1.0 )  ;
            if( scm2cpp::min2( fp, fd ) < 1.0 ) {
                double mu = 0.0;
                double gg = 0.0;
                if( n > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:mu) reduction(+:gg)
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        mu = (mu+((z[i]*x[i])+(w[i]*s[i])))  ;
                        gg = (gg+(((z[i]+(fd*dz[i]))*(x[i]+(fp*dx[i])))+((w[i]+(fd*dw[i]))*(s[i]-(fp*dx[i])))))  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        mu = (mu+((z[i]*x[i])+(w[i]*s[i])))  ;
                        gg = (gg+(((z[i]+(fd*dz[i]))*(x[i]+(fp*dx[i])))+((w[i]+(fd*dw[i]))*(s[i]-(fp*dx[i])))))  ;
                    }
                }  ;
                double ratio = (gg/mu);
                mu = ((mu*(ratio*(ratio*ratio)))/(2.0*double(n)))  ;
                ;
                if( n > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        double dxdz = (dx[i]*dz[i]);
                        double dsdw = ((0.0-dx[i])*dw[i]);
                        double xi = (mu*((1.0/x[i])-(1.0/s[i])));
                        t[ i ] = (q[i]*((dxdz-dsdw)-xi))   ;
                        ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        double dxdz = (dx[i]*dz[i]);
                        double dsdw = ((0.0-dx[i])*dw[i]);
                        double xi = (mu*((1.0/x[i])-(1.0/s[i])));
                        t[ i ] = (q[i]*((dxdz-dsdw)-xi))   ;
                        ;
                    }
                }  ;
                scm2cpp::blas_gemv(rhs2, a, t, 1.0, 0.0, 1, m, n)  ;
                if( m > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team())
                    for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                        dy[ j ] = (rhs[j]+rhs2[j])   ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                        dy[ j ] = (rhs[j]+rhs2[j])   ;
                    }
                }  ;
                if( scm2cpp::lapack_posv(g2, dy, m, 1) == 0 ) {
                    scm2cpp::blas_gemv(t, a, dy, 1.0, 0.0, 0, n, m)  ;
                    fp = 1e+20  ;
                    fd = 1e+20  ;
                    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                        double dxdz = (dx[i]*dz[i]);
                        double dsdw = ((0.0-dx[i])*dw[i]);
                        double xinv = (1.0/x[i]);
                        double sinv = (1.0/s[i]);
                        double dxi = (q[i]*((((t[i]+(mu*(xinv-sinv)))-r[i])-dxdz)+dsdw));
                        double dzi = ((((mu*xinv)-z[i])-(xinv*(z[i]*dxi)))-dxdz);
                        double dwi = ((((mu*sinv)-w[i])+(sinv*(w[i]*dxi)))-dsdw);
                        dx[ i ] = dxi   ;
                        dz[ i ] = dzi   ;
                        dw[ i ] = dwi   ;
                        if( dxi < 0.0 ) {
                            fp = scm2cpp::min2( fp, ((0.0-x[i])/dxi) )  ;
                        } else {
                            0  ;
                        }  ;
                        if( dxi > 0.0 ) {
                            fp = scm2cpp::min2( fp, (s[i]/dxi) )  ;
                        } else {
                            0  ;
                        }  ;
                        if( dzi < 0.0 ) {
                            fd = scm2cpp::min2( fd, ((0.0-z[i])/dzi) )  ;
                        } else {
                            0  ;
                        }  ;
                        if( dwi < 0.0 ) {
                            fd = scm2cpp::min2( fd, ((0.0-w[i])/dwi) )  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        ;
                        ;
                    }  ;
                    fp = scm2cpp::min2( (beta*fp), 1.0 )  ;
                    fd = scm2cpp::min2( (beta*fd), 1.0 )  ;
                } else {
                    status = 2  ;
                    done = 1  ;
                }  ;
                ;
            } else {
                0  ;
            }  ;
            if( status == 0 ) {
                double cx = 0.0;
                double sw = 0.0;
                double yb = 0.0;
                if( n > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:cx) reduction(+:sw)
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        x[ i ] = (x[i]+(fp*dx[i]))   ;
                        s[ i ] = (s[i]-(fp*dx[i]))   ;
                        z[ i ] = (z[i]+(fd*dz[i]))   ;
                        w[ i ] = (w[i]+(fd*dw[i]))   ;
                        cx = (cx+(c[i]*x[i]))  ;
                        sw = (sw+w[i])  ;
                    }
                } else {
                    for( std::int64_t i = 0 ; i < n ; i += 1 ) {
                        x[ i ] = (x[i]+(fp*dx[i]))   ;
                        s[ i ] = (s[i]-(fp*dx[i]))   ;
                        z[ i ] = (z[i]+(fd*dz[i]))   ;
                        w[ i ] = (w[i]+(fd*dw[i]))   ;
                        cx = (cx+(c[i]*x[i]))  ;
                        sw = (sw+w[i])  ;
                    }
                }  ;
                if( m > 65536 ) {
                    #pragma omp parallel for num_threads(scm2cpp::omp_team()) reduction(+:yb)
                    for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                        y[ j ] = (y[j]+(fd*dy[j]))   ;
                        yb = (yb+(y[j]*b[j]))  ;
                    }
                } else {
                    for( std::int64_t j = 0 ; j < m ; j += 1 ) {
                        y[ j ] = (y[j]+(fd*dy[j]))   ;
                        yb = (yb+(y[j]*b[j]))  ;
                    }
                }  ;
                gap = ((cx-yb)+sw)  ;
                obj = gram_abs(double(((ca-yb)+sw)))  ;
                if( gap <= scm2cpp::max2( (tol*obj), (1e-14*cnorm) ) ) {
                    done = 1  ;
                } else {
                    0  ;
                }  ;
                ;
            } else {
                0  ;
            }  ;
            ;
        } else {
            status = 2  ;
            done = 1  ;
        }  ;
    }  ;
    if( (status == 0 && done == 0) ) {
        status = 1  ;
    } else {
        0  ;
    }  ;
    if( m > 65536 ) {
        #pragma omp parallel for num_threads(scm2cpp::omp_team())
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            coef[ j ] = (0.0-y[j])   ;
        }
    } else {
        for( std::int64_t j = 0 ; j < m ; j += 1 ) {
            coef[ j ] = (0.0-y[j])   ;
        }
    }  ;
    out[ 0 ] = gap   ;
    out[ 1 ] = obj   ;
    out[ 2 ] = double(status)   ;
    return it ;
}
#endif // GRAMOPS_HPP
