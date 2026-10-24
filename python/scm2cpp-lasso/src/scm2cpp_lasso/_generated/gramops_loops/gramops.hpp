
#ifndef GRAMOPS_HPP
#define GRAMOPS_HPP
#define SCM2CPP_MINIMAL
#include	<cmath>
#include	<array>
#include	<math.h>
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN int
spd_inverse( scm2cpp::cspan<double> a,  scm2cpp::span<double> inv,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  int  p );
SCM2CPP_FN int
enet_gap( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::cspan<double> qw,  scm2cpp::span<double> xta,  std::array<double,2> & out,  double  alpha,  double  ynorm2,  int  m );
SCM2CPP_FN int
enet_safe_rule( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::span<double> qw,  scm2cpp::cspan<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  const std::array<double,2> & out,  double  alpha,  int  m );
SCM2CPP_FN int
enet_gram( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::cspan<double> q,  scm2cpp::span<double> qw,  scm2cpp::span<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  std::array<double,2> & out,  double  alpha,  int  maxiter,  double  tol,  int  m );
int
graphical_lasso( scm2cpp::cspan<double> emp,  scm2cpp::span<double> cov,  scm2cpp::span<double> prec,  double  alpha,  int  maxiter,  double  tol,  double  enettol,  int  p );
int
omp( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  int  rec,  int  kmax,  int  n,  int  p );
SCM2CPP_FN double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  int  multi,  int  fitint,  int  n,  int  p,  int  k );
int
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  int  maxiter,  double  tol,  int  multi,  int  fitint,  int  n,  int  p,  int  k );
SCM2CPP_FN double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  int  fitint,  int  n,  int  p );
int
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p );
SCM2CPP_FN double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  int  family,  double  power,  double  l2,  int  fitint,  int  n,  int  p );
int
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  int  family,  double  power,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p );
SCM2CPP_FN double
lb_abs( double  a );
SCM2CPP_FN double
lb_max( double  a,  double  b );
SCM2CPP_FN double
lb_min( double  a,  double  b );
SCM2CPP_FN int
lb_dcstep( std::array<double,8> & cs,  double  fp,  double  dp,  double  stpmin,  double  stpmax );
SCM2CPP_FN int
lb_search_start( std::array<double,16> & ls,  double  f,  double  g,  double  stp,  double  stpmin,  double  stpmax,  double  ftol );
SCM2CPP_FN int
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax );
SCM2CPP_FN double
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  int  nv );
SCM2CPP_FN double
lb_dot_row( scm2cpp::cspan<double> mem,  int  slot,  scm2cpp::cspan<double> v,  int  nv );
SCM2CPP_FN double
lb_dot_rows( scm2cpp::cspan<double> a,  int  ra,  scm2cpp::cspan<double> b,  int  rb,  int  nv );
SCM2CPP_FN double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  int  ib,  double  lbv,  int  nv );
SCM2CPP_FN int
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  int  col,  int  head,  int  m,  int  nv );
SCM2CPP_FN double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  int  col,  int  head,  int  m,  int  nv );
SCM2CPP_FN int
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  int  col,  int  head,  int  m,  int  ib,  double  lbv,  int  nv );
int
lbfgs( int  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  int  m,  int  maxiter,  double  pgtol,  double  ftol,  int  maxls,  int  ib,  double  lbv,  int  nv,  int  n,  int  p,  int  k );
SCM2CPP_FN double
lbfgs_fg( int  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  int  n,  int  p,  int  k );
SCM2CPP_FN int
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  int  norm,  int  n,  int  p,  int  kc );
SCM2CPP_FN double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  int  n,  int  p,  int  kc );
SCM2CPP_FN double
gmm_abs( double  a );
int
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  int  maxiter,  double  tol,  double  reg,  int  n,  int  p,  int  kc );
SCM2CPP_FN double
eig_hypot( double  a,  double  b );
SCM2CPP_FN int
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m );
SCM2CPP_FN double
eig_abs( double  a );
SCM2CPP_FN int
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  int  m );
SCM2CPP_FN double
ica_tanh( double  x );
SCM2CPP_FN int
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> t,  int  m );
int
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  int  maxiter,  double  tol,  int  n,  int  p,  int  nc );
int
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  int  n,  int  p );
SCM2CPP_FN int
ard_pinvh( scm2cpp::span<double> a,  scm2cpp::span<double> s,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  k );
SCM2CPP_FN int
ard_sigma_coef( scm2cpp::cspan<double> xy,  scm2cpp::cspan<int> idx,  scm2cpp::cspan<double> lam,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::cspan<double> gk,  double  alpha,  int  k );
int
ard( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> lam,  scm2cpp::span<double> out,  int  maxiter,  double  tol,  double  alpha1,  double  alpha2,  double  lambda1,  double  lambda2,  double  thresh,  int  hoist,  int  n,  int  p );
int
f_regression( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> r,  scm2cpp::span<double> f,  int  center,  int  n,  int  p,  int  q );
int
f_classif( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> f,  int  n,  int  p,  int  k );
SCM2CPP_FN double
min_pos( scm2cpp::cspan<double> v,  int  m );
SCM2CPP_FN double
round_even( double  y );
SCM2CPP_FN int
cholesky_delete( scm2cpp::span<double> l,  int  go,  int  n,  int  k );
SCM2CPP_FN int
swap_rc( scm2cpp::span<double> g,  int  a,  int  b,  int  p );
int
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  int  rec,  double  nsamples,  double  alphamin,  int  method,  int  maxiter,  double  eps,  int  p );
SCM2CPP_FN int
rfe_chol( scm2cpp::cspan<double> g,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> l,  double  alpha,  int  k,  int  p );
SCM2CPP_FN int
rfe_solve( scm2cpp::cspan<double> c,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::cspan<double> l,  int  k,  int  p );
int
rfe( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<int> support,  scm2cpp::span<int> ranking,  double  alpha,  int  nsel,  int  step,  int  n,  int  p );
SCM2CPP_FN int
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  int  n,  int  p );
SCM2CPP_FN int
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  int  n,  int  p,  int  q );



SCM2CPP_FN inline int
spd_inverse( scm2cpp::cspan<double> a,  scm2cpp::span<double> inv,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  int  p )
{   for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double s = a[((j*p)+j)];
        for( int k = 0 ; !(k == j) ; k = (k+1) ) {
            s = (s-(l[((j*p)+k)]*l[((j*p)+k)]))  ;
        }  ;
        l[ ((j*p)+j) ] = sqrt(s)   ;
        for( int i = (j+1) ; !(i >= p) ; i = (i+1) ) {
            double t = a[((i*p)+j)];
            for( int k = 0 ; !(k == j) ; k = (k+1) ) {
                t = (t-(l[((i*p)+k)]*l[((j*p)+k)]))  ;
            }  ;
            l[ ((i*p)+j) ] = (t/l[((j*p)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( int c = 0 ; !(c == p) ; c = (c+1) ) {
        for( int i = 0 ; !(i == p) ; i = (i+1) ) {
            double t = ( ( i == c ) ? (1.0) : (0.0) );
            for( int k = 0 ; !(k == i) ; k = (k+1) ) {
                t = (t-(l[((i*p)+k)]*z[k]))  ;
            }  ;
            z[ i ] = (t/l[((i*p)+i)])   ;
            ;
        }  ;
        for( int ii = 0 ; !(ii == p) ; ii = (ii+1) ) {
            int i = ((p-1)-ii);
            double t = z[i];
            for( int k = (i+1) ; !(k >= p) ; k = (k+1) ) {
                t = (t-(l[((k*p)+i)]*inv[((k*p)+c)]))  ;
            }  ;
            inv[ ((i*p)+c) ] = (t/l[((i*p)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
enet_gap( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> q,  scm2cpp::cspan<double> qw,  scm2cpp::span<double> xta,  std::array<double,2> & out,  double  alpha,  double  ynorm2,  int  m )
{   double qdotw = 0.0;
    double wqw = 0.0;
    double l1 = 0.0;
    double dn = 0.0;
    for( int j = 0 ; !(j == m) ; j = (j+1) ) {
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


SCM2CPP_FN inline int
enet_safe_rule( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::span<double> qw,  scm2cpp::cspan<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  const std::array<double,2> & out,  double  alpha,  int  m )
{
    struct let5217 {
        let5217() {}
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
    double radius = (sqrt((2.0*let5217()(out[0])))/alpha);
    double dn = out[1];
    int nact = 0;
    for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        if( excl[j] == 0 ) {
            double xjt = (xta[j]/( ( alpha > dn ) ? (alpha) : (dn) ));
            double dj = ((1.0-( ( xjt < 0.0 ) ? ((0.0-xjt)) : (xjt) ))/sqrt(qm[((j*m)+j)]));
            if( dj <= radius ) {
                active[ nact ] = j   ;
                nact = (nact+1)  ;
            } else {
                if( !(w[j] == 0.0) ) {
                    double wj = w[j];
                    if( m > 65536 ) {
                        #pragma omp parallel for
                        for( int r = 0 ; r < m ; r = (r+1) ) {
                            qw[ r ] = (qw[r]-(wj*qm[((j*m)+r)]))   ;
                        }
                    } else {
                        for( int r = 0 ; r < m ; r = (r+1) ) {
                            qw[ r ] = (qw[r]-(wj*qm[((j*m)+r)]))   ;
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


SCM2CPP_FN inline int
enet_gram( scm2cpp::span<double> w,  scm2cpp::cspan<double> qm,  scm2cpp::cspan<double> q,  scm2cpp::span<double> qw,  scm2cpp::span<double> xta,  scm2cpp::span<int> active,  scm2cpp::span<int> excl,  std::array<double,2> & out,  double  alpha,  int  maxiter,  double  tol,  int  m )
{   double ynorm2 = 0.0;
    double dwtol = tol;
    int nact = 0;
    int done = 0;
    int iter = 0;
    if( m > 65536 ) {
        #pragma omp parallel for reduction(+:ynorm2)
        for( int j = 0 ; j < m ; j = (j+1) ) {
            ynorm2 = (ynorm2+(q[j]*q[j]))  ;
            excl[ j ] = 0   ;
        }
    } else {
        for( int j = 0 ; j < m ; j = (j+1) ) {
            ynorm2 = (ynorm2+(q[j]*q[j]))  ;
            excl[ j ] = 0   ;
        }
    }  ;
    if( m > 65536 ) {
        #pragma omp parallel for
        for( int k2493 = 0 ; k2493 < m ; k2493 = (k2493+1) ) {
            qw[ k2493 ] = ([&]() -> double { int i2496 = 0; double r2497 = 0.0; while (!(i2496 == m)) {
            int i2496_next5245 = (i2496+1);
                double r2497_next5246 = (r2497+(qm[((k2493*m)+i2496)]*w[i2496]));
                i2496 = i2496_next5245;
                r2497 = r2497_next5246;
            } return r2497;
                                           })()   ;
        }
    } else {
        for( int k2493 = 0 ; k2493 < m ; k2493 = (k2493+1) ) {
            qw[ k2493 ] = ([&]() -> double { int i2496 = 0; double r2497 = 0.0; while (!(i2496 == m)) {
            int i2496_next5245 = (i2496+1);
                double r2497_next5246 = (r2497+(qm[((k2493*m)+i2496)]*w[i2496]));
                i2496 = i2496_next5245;
                r2497 = r2497_next5246;
            } return r2497; })()   ;
        }
    }  ;
    double gtol = (tol*ynorm2);
    enet_gap(w,q,qw,xta,out,alpha,ynorm2,m)  ;
    if( (out[0] >= 0.0 && out[0] <= gtol) ) {
        done = 1  ;
    } else {
        if( m > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < m ; j = (j+1) ) {
                if( qm[((j*m)+j)] == 0.0 ) {
                    w[ j ] = 0.0   ;
                    excl[ j ] = 1   ;
                } else {
                    0  ;
                }  ;
            }
        } else {
            for( int j = 0 ; j < m ; j = (j+1) ) {
                if( qm[((j*m)+j)] == 0.0 ) {
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
        for( int f = 0 ; !(f == nact) ; f = (f+1) ) {
            int j = active[f];
            double qjj = qm[((j*m)+j)];
            if( !(qjj == 0.0) ) {
                double wj = w[j];
                double tmp = ((q[j]-qw[j])+(wj*qjj));
                double mag = (( ( tmp < 0.0 ) ? ((0.0-tmp)) : (tmp) )-alpha);
                double wn = ( ( mag > 0.0 ) ? ((( ( tmp < 0.0 ) ? ((0.0-mag)) : (mag) )/qjj)) : (0.0) );
                w[ j ] = wn   ;
                if( !(wn == wj) ) {
                    if( m > 65536 ) {
                        #pragma omp parallel for
                        for( int r = 0 ; r < m ; r = (r+1) ) {
                            qw[ r ] = (qw[r]+((wn-wj)*qm[((j*m)+r)]))   ;
                        }
                    } else {
                        for( int r = 0 ; r < m ; r = (r+1) ) {
                            qw[ r ] = (qw[r]+((wn-wj)*qm[((j*m)+r)]))   ;
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


inline int
graphical_lasso( scm2cpp::cspan<double> emp,  scm2cpp::span<double> cov,  scm2cpp::span<double> prec,  double  alpha,  int  maxiter,  double  tol,  double  enettol,  int  p )
{   int m = (p-1);
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
    int done = 0;
    int it = 0;
    int innermax = ( ( maxiter > 20 ) ? (maxiter) : (20) );
    if( (p*p) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < p ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                cov[ ((i*p)+j) ] = ( ( i == j ) ? (emp[((i*p)+j)]) : ((0.95*emp[((i*p)+j)])) )   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < p ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                cov[ ((i*p)+j) ] = ( ( i == j ) ? (emp[((i*p)+j)]) : ((0.95*emp[((i*p)+j)])) )   ;
            }  ;
        }
    }  ;
    spd_inverse(cov,prec,l,z,p)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        for( int idx = 0 ; !(idx == p) ; idx = (idx+1) ) {
            if( idx > 0 ) {
                int di = (idx-1);
                for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                    int o = ( ( s < idx ) ? (s) : ((s+1)) );
                    sub[ ((di*m)+s) ] = cov[((di*p)+o)]   ;
                    sub[ ((s*m)+di) ] = cov[((o*p)+di)]   ;
                    ;
                }  ;
                ;
            } else {
                if( (m*m) > 65536 ) {
                    #pragma omp parallel for
                    for( int s = 0 ; s < m ; s = (s+1) ) {
                        for( int t = 0 ; !(t == m) ; t = (t+1) ) {
                            sub[ ((s*m)+t) ] = cov[(((s+1)*p)+(t+1))]   ;
                        }  ;
                    }
                } else {
                    for( int s = 0 ; s < m ; s = (s+1) ) {
                        for( int t = 0 ; !(t == m) ; t = (t+1) ) {
                            sub[ ((s*m)+t) ] = cov[(((s+1)*p)+(t+1))]   ;
                        }  ;
                    }
                }  ;
            }  ;
            double pii = prec[((idx*p)+idx)];
            if( m > 65536 ) {
                #pragma omp parallel for
                for( int s = 0 ; s < m ; s = (s+1) ) {
                    int o = ( ( s < idx ) ? (s) : ((s+1)) );
                    row[ s ] = emp[((idx*p)+o)]   ;
                    b[ s ] = (0.0-(prec[((o*p)+idx)]/(pii+(1000.0*2.220446049250313e-16))))   ;
                    ;
                }
            } else {
                for( int s = 0 ; s < m ; s = (s+1) ) {
                    int o = ( ( s < idx ) ? (s) : ((s+1)) );
                    row[ s ] = emp[((idx*p)+o)]   ;
                    b[ s ] = (0.0-(prec[((o*p)+idx)]/(pii+(1000.0*2.220446049250313e-16))))   ;
                    ;
                }
            }  ;
            ;
            enet_gram(b,sub,row,qw,xta,active,excl,out,alpha,innermax,enettol,m)  ;
            double acc = 0.0;
            if( m > 65536 ) {
                #pragma omp parallel for reduction(+:acc)
                for( int s = 0 ; s < m ; s = (s+1) ) {
                    int o = ( ( s < idx ) ? (s) : ((s+1)) );
                    acc = (acc+(cov[((o*p)+idx)]*b[s]))  ;
                    ;
                }
            } else {
                for( int s = 0 ; s < m ; s = (s+1) ) {
                    int o = ( ( s < idx ) ? (s) : ((s+1)) );
                    acc = (acc+(cov[((o*p)+idx)]*b[s]))  ;
                    ;
                }
            }  ;
            double pnew = (1.0/(cov[((idx*p)+idx)]-acc));
            prec[ ((idx*p)+idx) ] = pnew   ;
            for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                int o = ( ( s < idx ) ? (s) : ((s+1)) );
                prec[ ((o*p)+idx) ] = (0.0-(pnew*b[s]))   ;
                prec[ ((idx*p)+o) ] = (0.0-(pnew*b[s]))   ;
                ;
            }  ;
            ;
            ;
            if( m > 65536 ) {
                #pragma omp parallel for
                for( int k2500 = 0 ; k2500 < m ; k2500 = (k2500+1) ) {
                    bnew[ k2500 ] = ([&]() -> double { int i2503 = 0; double r2504 = 0.0; while (!(i2503 == m)) {
                    int i2503_next5247 = (i2503+1);
                        double r2504_next5248 = (r2504+(sub[((k2500*m)+i2503)]*b[i2503]));
                        i2503 = i2503_next5247;
                        r2504 = r2504_next5248;
                    } return r2504;
                                                     })()   ;
                }
            } else {
                for( int k2500 = 0 ; k2500 < m ; k2500 = (k2500+1) ) {
                    bnew[ k2500 ] = ([&]() -> double { int i2503 = 0; double r2504 = 0.0; while (!(i2503 == m)) {
                    int i2503_next5247 = (i2503+1);
                        double r2504_next5248 = (r2504+(sub[((k2500*m)+i2503)]*b[i2503]));
                        i2503 = i2503_next5247;
                        r2504 = r2504_next5248;
                    } return r2504; })()   ;
                }
            }  ;
            for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                int o = ( ( s < idx ) ? (s) : ((s+1)) );
                cov[ ((idx*p)+o) ] = bnew[s]   ;
                cov[ ((o*p)+idx) ] = bnew[s]   ;
                ;
            }  ;
        }  ;
        double tr = 0.0;
        double offl1 = 0.0;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for reduction(+:tr) reduction(+:offl1)
            for( int i = 0 ; i < p ; i = (i+1) ) {
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double t = prec[((i*p)+j)];
                    tr = (tr+(emp[((i*p)+j)]*t))  ;
                    if( !(i == j) ) {
                        offl1 = (offl1+( ( t < 0.0 ) ? ((0.0-t)) : (t) ))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
            }
        } else {
            for( int i = 0 ; i < p ; i = (i+1) ) {
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double t = prec[((i*p)+j)];
                    tr = (tr+(emp[((i*p)+j)]*t))  ;
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


inline int
omp( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  int  rec,  int  kmax,  int  n,  int  p )
{   std::vector<double> g((p*p),0.0);
    std::vector<double> xy(p,0.0);
    std::vector<double> alpha(p,0.0);
    std::vector<double> beta(p,0.0);
    std::vector<int> index(p,0);
    std::vector<double> l((kmax*kmax),0.0);
    std::vector<double> gamma(kmax,0.0);
    std::vector<double> z(kmax,0.0);
    double eps = 2.220446049250313e-16;
    int na = 0;
    int done = 0;
    for( int k2507 = 0 ; !(k2507 == p) ; k2507 = (k2507+1) ) {
        for( int k2508 = k2507 ; !(k2508 == p) ; k2508 = (k2508+1) ) {
            g[ ((k2507*p)+k2508) ] = ([&]() -> double { int i2510 = 0; double r2511 = 0.0; while (!(i2510 == n)) {
            int i2510_next5249 = (i2510+1);
                double r2511_next5250 = (r2511+(x[((i2510*p)+k2507)]*x[((i2510*p)+k2508)]));
                i2510 = i2510_next5249;
                r2511 = r2511_next5250;
            } return r2511; })()   ;
            g[ ((k2508*p)+k2507) ] = g[((k2507*p)+k2508)]   ;
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int i2515 = 0 ; i2515 < p ; i2515 = (i2515+1) ) {
            xy[ i2515 ] = 0.0   ;
        }
    } else {
        for( int i2515 = 0 ; i2515 < p ; i2515 = (i2515+1) ) {
            xy[ i2515 ] = 0.0   ;
        }
    }  ;
    for( int k2513 = 0 ; !(k2513 == n) ; k2513 = (k2513+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int i2516 = 0 ; i2516 < p ; i2516 = (i2516+1) ) {
                xy[ i2516 ] = (xy[i2516]+(x[((k2513*p)+i2516)]*y[k2513]))   ;
            }
        } else {
            for( int i2516 = 0 ; i2516 < p ; i2516 = (i2516+1) ) {
                xy[ i2516 ] = (xy[i2516]+(x[((k2513*p)+i2516)]*y[k2513]))   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            index[ j ] = j   ;
            alpha[ j ] = xy[j]   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            index[ j ] = j   ;
            alpha[ j ] = xy[j]   ;
        }
    }  ;
    for(  ; !(done == 1) ;  ) {
        int lam = 0;
        double best = -1.0;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
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
                for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                    double t = g[((lam*p)+i)];
                    for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                        t = (t-(l[((i*kmax)+s)]*l[((na*kmax)+s)]))  ;
                    }  ;
                    double li = (t/l[((i*kmax)+i)]);
                    l[ ((na*kmax)+i) ] = li   ;
                    v = (v+(li*li))  ;
                    ;
                    ;
                }  ;
                double lkk = (g[((lam*p)+lam)]-v);
                if( lkk <= eps ) {
                    done = 1  ;
                } else {
                    l[ ((na*kmax)+na) ] = sqrt(lkk)   ;
                }  ;
                ;
                ;
            } else {
                l[ 0 ] = sqrt(g[((lam*p)+lam)])   ;
            }  ;
            if( done == 0 ) {
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double grow = g[((na*p)+j)];
                    g[ ((na*p)+j) ] = g[((lam*p)+j)]   ;
                    g[ ((lam*p)+j) ] = grow   ;
                    ;
                }  ;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double gcol = g[((j*p)+na)];
                    g[ ((j*p)+na) ] = g[((j*p)+lam)]   ;
                    g[ ((j*p)+lam) ] = gcol   ;
                    ;
                }  ;
                int itmp = index[na];
                index[ na ] = index[lam]   ;
                index[ lam ] = itmp   ;
                ;
                double xtmp = xy[na];
                xy[ na ] = xy[lam]   ;
                xy[ lam ] = xtmp   ;
                ;
                na = (na+1)  ;
                for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                    double t = xy[i];
                    for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                        t = (t-(l[((i*kmax)+s)]*z[s]))  ;
                    }  ;
                    z[ i ] = (t/l[((i*kmax)+i)])   ;
                    ;
                }  ;
                for( int ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                    int i = ((na-1)-ii);
                    double t = z[i];
                    for( int s = (i+1) ; !(s >= na) ; s = (s+1) ) {
                        t = (t-(l[((s*kmax)+i)]*gamma[s]))  ;
                    }  ;
                    gamma[ i ] = (t/l[((i*kmax)+i)])   ;
                    ;
                    ;
                }  ;
                if( rec == 1 ) {
                    if( p > 65536 ) {
                        #pragma omp parallel for
                        for( int j = 0 ; j < p ; j = (j+1) ) {
                            path[ (((na-1)*p)+j) ] = 0.0   ;
                        }
                    } else {
                        for( int j = 0 ; j < p ; j = (j+1) ) {
                            path[ (((na-1)*p)+j) ] = 0.0   ;
                        }
                    }  ;
                    for( int s = 0 ; !(s == na) ; s = (s+1) ) {
                        path[ (((na-1)*p)+index[s]) ] = gamma[s]   ;
                    }  ;
                } else {
                    0  ;
                }  ;
                if( (p*na) > 65536 ) {
                    #pragma omp parallel for
                    for( int j = 0 ; j < p ; j = (j+1) ) {
                        double acc = 0.0;
                        for( int s = 0 ; !(s == na) ; s = (s+1) ) {
                            acc = (acc+(g[((j*p)+s)]*gamma[s]))  ;
                        }  ;
                        beta[ j ] = acc   ;
                        alpha[ j ] = (xy[j]-acc)   ;
                        ;
                    }
                } else {
                    for( int j = 0 ; j < p ; j = (j+1) ) {
                        double acc = 0.0;
                        for( int s = 0 ; !(s == na) ; s = (s+1) ) {
                            acc = (acc+(g[((j*p)+s)]*gamma[s]))  ;
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
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    for( int s = 0 ; !(s == na) ; s = (s+1) ) {
        coef[ index[s] ] = gamma[s]   ;
    }  ;
    return na ;
}


SCM2CPP_FN inline double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  int  multi,  int  fitint,  int  n,  int  p,  int  k )
{   double loss = 0.0;
    double pen = 0.0;
    if( (n*k) > 65536 ) {
        #pragma omp parallel for
        for( int k2518 = 0 ; k2518 < n ; k2518 = (k2518+1) ) {
            for( int k2519 = 0 ; !(k2519 == k) ; k2519 = (k2519+1) ) {
                z[ ((k2518*k)+k2519) ] = ([&]() -> double { int i2521 = 0; double r2522 = 0.0; while (!(i2521 == p)) {
                int i2521_next5251 = (i2521+1);
                    double r2522_next5252 = (r2522+(x[((k2518*p)+i2521)]*coef[((k2519*p)+i2521)]));
                    i2521 = i2521_next5251;
                    r2522 = r2522_next5252;
                } return r2522;
                                                          })()   ;
            }  ;
        }
    } else {
        for( int k2518 = 0 ; k2518 < n ; k2518 = (k2518+1) ) {
            for( int k2519 = 0 ; !(k2519 == k) ; k2519 = (k2519+1) ) {
                z[ ((k2518*k)+k2519) ] = ([&]() -> double { int i2521 = 0; double r2522 = 0.0; while (!(i2521 == p)) {
                int i2521_next5251 = (i2521+1);
                    double r2522_next5252 = (r2522+(x[((k2518*p)+i2521)]*coef[((k2519*p)+i2521)]));
                    i2521 = i2521_next5251;
                    r2522 = r2522_next5252;
                } return r2522; })()   ;
            }  ;
        }
    }  ;
    if( (n*k) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < n ; i = (i+1) ) {
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                z[ ((i*k)+c) ] = (z[((i*k)+c)]+coef[((k*p)+c)])   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                z[ ((i*k)+c) ] = (z[((i*k)+c)]+coef[((k*p)+c)])   ;
            }  ;
        }
    }  ;
    if( multi == 0 ) {
        if( n > 65536 ) {
            #pragma omp parallel for reduction(+:loss)
            for( int i = 0 ; i < n ; i = (i+1) ) {
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
            for( int i = 0 ; i < n ; i = (i+1) ) {
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
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            double zmax = z[(i*k)];
            double se = 0.0;
            double yc = y[i];
            for( int c = 1 ; !(c == k) ; c = (c+1) ) {
                if( z[((i*k)+c)] > zmax ) {
                    zmax = z[((i*k)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            loss = (loss-z[((i*k)+int(yc))])  ;
            if( k > 65536 ) {
                #pragma omp parallel for reduction(+:se)
                for( int c = 0 ; c < k ; c = (c+1) ) {
                    double ec = exp((z[((i*k)+c)]-zmax));
                    z[ ((i*k)+c) ] = ec   ;
                    se = (se+ec)  ;
                    ;
                }
            } else {
                for( int c = 0 ; c < k ; c = (c+1) ) {
                    double ec = exp((z[((i*k)+c)]-zmax));
                    z[ ((i*k)+c) ] = ec   ;
                    se = (se+ec)  ;
                    ;
                }
            }  ;
            loss = (loss+(zmax+log(se)))  ;
            if( k > 65536 ) {
                #pragma omp parallel for
                for( int c = 0 ; c < k ; c = (c+1) ) {
                    z[ ((i*k)+c) ] = (z[((i*k)+c)]/se)   ;
                }
            } else {
                for( int c = 0 ; c < k ; c = (c+1) ) {
                    z[ ((i*k)+c) ] = (z[((i*k)+c)]/se)   ;
                }
            }  ;
            int iy = ((i*k)+int(yc));
            z[ iy ] = (z[iy]-1.0)   ;
            ;
            ;
        }  ;
    }  ;
    if( (k*p) > 65536 ) {
        #pragma omp parallel for
        for( int i2526 = 0 ; i2526 < k ; i2526 = (i2526+1) ) {
            for( int i2527 = 0 ; !(i2527 == p) ; i2527 = (i2527+1) ) {
                g[ ((i2526*p)+i2527) ] = 0.0   ;
            }  ;
        }
    } else {
        for( int i2526 = 0 ; i2526 < k ; i2526 = (i2526+1) ) {
            for( int i2527 = 0 ; !(i2527 == p) ; i2527 = (i2527+1) ) {
                g[ ((i2526*p)+i2527) ] = 0.0   ;
            }  ;
        }
    }  ;
    for( int k2524 = 0 ; !(k2524 == n) ; k2524 = (k2524+1) ) {
        if( (k*p) > 65536 ) {
            #pragma omp parallel for
            for( int k2525 = 0 ; k2525 < k ; k2525 = (k2525+1) ) {
                for( int k2528 = 0 ; !(k2528 == p) ; k2528 = (k2528+1) ) {
                    g[ ((k2525*p)+k2528) ] = (g[((k2525*p)+k2528)]+(x[((k2524*p)+k2528)]*z[((k2524*k)+k2525)]))   ;
                }  ;
            }
        } else {
            for( int k2525 = 0 ; k2525 < k ; k2525 = (k2525+1) ) {
                for( int k2528 = 0 ; !(k2528 == p) ; k2528 = (k2528+1) ) {
                    g[ ((k2525*p)+k2528) ] = (g[((k2525*p)+k2528)]+(x[((k2524*p)+k2528)]*z[((k2524*k)+k2525)]))   ;
                }  ;
            }
        }  ;
    }  ;
    if( (k*p) > 65536 ) {
        #pragma omp parallel for reduction(+:pen)
        for( int t = 0 ; t < (k*p) ; t = (t+1) ) {
            double wt = coef[t];
            pen = (pen+(wt*wt))  ;
            g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
            ;
        }
    } else {
        for( int t = 0 ; t < (k*p) ; t = (t+1) ) {
            double wt = coef[t];
            pen = (pen+(wt*wt))  ;
            g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
            ;
        }
    }  ;
    if( k > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < k ; c = (c+1) ) {
            double acc = 0.0;
            if( fitint == 1 ) {
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    acc = (acc+z[((i*k)+c)])  ;
                }  ;
            } else {
                0  ;
            }  ;
            g[ ((k*p)+c) ] = (acc/double(n))   ;
            ;
        }
    } else {
        for( int c = 0 ; c < k ; c = (c+1) ) {
            double acc = 0.0;
            if( fitint == 1 ) {
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    acc = (acc+z[((i*k)+c)])  ;
                }  ;
            } else {
                0  ;
            }  ;
            g[ ((k*p)+c) ] = (acc/double(n))   ;
            ;
        }
    }  ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}


inline int
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  int  maxiter,  double  tol,  int  multi,  int  fitint,  int  n,  int  p,  int  k )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work((n*k),0.0);
    aux[ 0 ] = (1.0/(c*double(n)))   ;
    aux[ 1 ] = ( ( multi == 1 ) ? (1.0) : (0.0) )   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    return lbfgs(0,coef,x,y,aux,work,out,10,maxiter,tol,(64.0*2.220446049250313e-16),50,-1,0.0,(k*(p+1)),n,p,k) ;
}


SCM2CPP_FN inline double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  int  fitint,  int  n,  int  p )
{   double b = coef[p];
    double sigma = coef[(p+1)];
    int nout = 0;
    double outsum = 0.0;
    double sq = 0.0;
    double csum = 0.0;
    double ww = 0.0;
    if( n > 65536 ) {
        #pragma omp parallel for
        for( int k2531 = 0 ; k2531 < n ; k2531 = (k2531+1) ) {
            z[ k2531 ] = ([&]() -> double { int i2534 = 0; double r2535 = 0.0; while (!(i2534 == p)) {
            int i2534_next5253 = (i2534+1);
                double r2535_next5254 = (r2535+(x[((k2531*p)+i2534)]*coef[i2534]));
                i2534 = i2534_next5253;
                r2535 = r2535_next5254;
            } return r2535;
                                          })()   ;
        }
    } else {
        for( int k2531 = 0 ; k2531 < n ; k2531 = (k2531+1) ) {
            z[ k2531 ] = ([&]() -> double { int i2534 = 0; double r2535 = 0.0; while (!(i2534 == p)) {
            int i2534_next5253 = (i2534+1);
                double r2535_next5254 = (r2535+(x[((k2531*p)+i2534)]*coef[i2534]));
                i2534 = i2534_next5253;
                r2535 = r2535_next5254;
            } return r2535; })()   ;
        }
    }  ;
    if( n > 65536 ) {
        #pragma omp parallel for reduction(+:nout) reduction(+:outsum) reduction(+:sq) reduction(+:csum)
        for( int i = 0 ; i < n ; i = (i+1) ) {
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
        for( int i = 0 ; i < n ; i = (i+1) ) {
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
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int i2539 = 0 ; i2539 < p ; i2539 = (i2539+1) ) {
            g[ i2539 ] = 0.0   ;
        }
    } else {
        for( int i2539 = 0 ; i2539 < p ; i2539 = (i2539+1) ) {
            g[ i2539 ] = 0.0   ;
        }
    }  ;
    for( int k2537 = 0 ; !(k2537 == n) ; k2537 = (k2537+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int i2540 = 0 ; i2540 < p ; i2540 = (i2540+1) ) {
                g[ i2540 ] = (g[i2540]+(x[((k2537*p)+i2540)]*z[k2537]))   ;
            }
        } else {
            for( int i2540 = 0 ; i2540 < p ; i2540 = (i2540+1) ) {
                g[ i2540 ] = (g[i2540]+(x[((k2537*p)+i2540)]*z[k2537]))   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for reduction(+:ww)
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double wj = coef[j];
            ww = (ww+(wj*wj))  ;
            g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
            ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
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


inline int
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work(n,0.0);
    aux[ 0 ] = epsilon   ;
    aux[ 1 ] = alpha   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    return lbfgs(1,coef,x,y,aux,work,out,10,maxiter,tol,(10000000.0*2.220446049250313e-16),20,(p+1),(10.0*2.220446049250313e-16),(p+2),n,p,1) ;
}


SCM2CPP_FN inline double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  int  family,  double  power,  double  l2,  int  fitint,  int  n,  int  p )
{   double loss = 0.0;
    double pen = 0.0;
    double b = coef[p];
    if( n > 65536 ) {
        #pragma omp parallel for
        for( int k2543 = 0 ; k2543 < n ; k2543 = (k2543+1) ) {
            z[ k2543 ] = ([&]() -> double { int i2546 = 0; double r2547 = 0.0; while (!(i2546 == p)) {
            int i2546_next5255 = (i2546+1);
                double r2547_next5256 = (r2547+(x[((k2543*p)+i2546)]*coef[i2546]));
                i2546 = i2546_next5255;
                r2547 = r2547_next5256;
            } return r2547;
                                          })()   ;
        }
    } else {
        for( int k2543 = 0 ; k2543 < n ; k2543 = (k2543+1) ) {
            z[ k2543 ] = ([&]() -> double { int i2546 = 0; double r2547 = 0.0; while (!(i2546 == p)) {
            int i2546_next5255 = (i2546+1);
                double r2547_next5256 = (r2547+(x[((k2543*p)+i2546)]*coef[i2546]));
                i2546 = i2546_next5255;
                r2547 = r2547_next5256;
            } return r2547; })()   ;
        }
    }  ;
    if( n > 65536 ) {
        #pragma omp parallel for reduction(+:loss)
        for( int i = 0 ; i < n ; i = (i+1) ) {
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
        for( int i = 0 ; i < n ; i = (i+1) ) {
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
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int i2551 = 0 ; i2551 < p ; i2551 = (i2551+1) ) {
            g[ i2551 ] = 0.0   ;
        }
    } else {
        for( int i2551 = 0 ; i2551 < p ; i2551 = (i2551+1) ) {
            g[ i2551 ] = 0.0   ;
        }
    }  ;
    for( int k2549 = 0 ; !(k2549 == n) ; k2549 = (k2549+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int i2552 = 0 ; i2552 < p ; i2552 = (i2552+1) ) {
                g[ i2552 ] = (g[i2552]+(x[((k2549*p)+i2552)]*z[k2549]))   ;
            }
        } else {
            for( int i2552 = 0 ; i2552 < p ; i2552 = (i2552+1) ) {
                g[ i2552 ] = (g[i2552]+(x[((k2549*p)+i2552)]*z[k2549]))   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for reduction(+:pen)
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double wj = coef[j];
            pen = (pen+(wj*wj))  ;
            g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
            ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double wj = coef[j];
            pen = (pen+(wj*wj))  ;
            g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
            ;
        }
    }  ;
    double acc = 0.0;
    if( fitint == 1 ) {
        if( n > 65536 ) {
            #pragma omp parallel for reduction(+:acc)
            for( int i = 0 ; i < n ; i = (i+1) ) {
                acc = (acc+z[i])  ;
            }
        } else {
            for( int i = 0 ; i < n ; i = (i+1) ) {
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


inline int
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  int  family,  double  power,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    std::vector<double> work(n,0.0);
    double ym = 0.0;
    aux[ 0 ] = alpha   ;
    aux[ 1 ] = double(family)   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    aux[ 3 ] = power   ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    if( n > 65536 ) {
        #pragma omp parallel for reduction(+:ym)
        for( int i = 0 ; i < n ; i = (i+1) ) {
            ym = (ym+y[i])  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
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


SCM2CPP_FN inline int
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


SCM2CPP_FN inline int
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


SCM2CPP_FN inline int
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax )
{   double stp = ls[15];
    double finit = ls[8];
    double ginit = ls[9];
    double gtest = ls[10];
    int task = 0;
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
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  int  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for reduction(+:acc)
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(a[j]*b[j]))  ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(a[j]*b[j]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_row( scm2cpp::cspan<double> mem,  int  slot,  scm2cpp::cspan<double> v,  int  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for reduction(+:acc)
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(mem[((slot*nv)+j)]*v[j]))  ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(mem[((slot*nv)+j)]*v[j]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_rows( scm2cpp::cspan<double> a,  int  ra,  scm2cpp::cspan<double> b,  int  rb,  int  nv )
{   double acc = 0.0;
    if( nv > 65536 ) {
        #pragma omp parallel for reduction(+:acc)
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(a[((ra*nv)+j)]*b[((rb*nv)+j)]))  ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            acc = (acc+(a[((ra*nv)+j)]*b[((rb*nv)+j)]))  ;
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  int  ib,  double  lbv,  int  nv )
{   double acc = 0.0;
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
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


SCM2CPP_FN inline int
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  int  col,  int  head,  int  m,  int  nv )
{   for( int ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        int slot = ((head+((col-1)-ii)) % m);
        double a = (rho[slot]*lb_dot_row(smem,slot,q,nv));
        al[ slot ] = a   ;
        if( nv > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                q[ j ] = (q[j]-(a*ymem[((slot*nv)+j)]))   ;
            }
        } else {
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                q[ j ] = (q[j]-(a*ymem[((slot*nv)+j)]))   ;
            }
        }  ;
        ;
        ;
    }  ;
    if( nv > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            q[ j ] = (q[j]/theta)   ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            q[ j ] = (q[j]/theta)   ;
        }
    }  ;
    for( int ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        int slot2 = ((head+ii) % m);
        double bb = (rho[slot2]*lb_dot_row(ymem,slot2,q,nv));
        if( nv > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                q[ j ] = (q[j]+((al[slot2]-bb)*smem[((slot2*nv)+j)]))   ;
            }
        } else {
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                q[ j ] = (q[j]+((al[slot2]-bb)*smem[((slot2*nv)+j)]))   ;
            }
        }  ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  int  col,  int  head,  int  m,  int  nv )
{   for( int ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        int si = ((head+ii) % m);
        if( nv > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                bm[ ((ii*nv)+j) ] = (theta*smem[((si*nv)+j)])   ;
            }
        } else {
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                bm[ ((ii*nv)+j) ] = (theta*smem[((si*nv)+j)])   ;
            }
        }  ;
        for( int jj = 0 ; !(jj == ii) ; jj = (jj+1) ) {
            int sj = ((head+jj) % m);
            double cb = (lb_dot_rows(bm,jj,smem,si,nv)/sb[jj]);
            double cy = (rho[sj]*lb_dot_rows(ymem,sj,smem,si,nv));
            for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                bm[ ((ii*nv)+j) ] = ((bm[((ii*nv)+j)]-(cb*bm[((jj*nv)+j)]))+(cy*ymem[((sj*nv)+j)]))   ;
            }  ;
            ;
            ;
        }  ;
        sb[ ii ] = lb_dot_rows(bm,ii,smem,si,nv)   ;
        ;
    }  ;
    double acc = (theta*lb_dot(v,v,nv));
    for( int ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        int si2 = ((head+ii) % m);
        double bv = lb_dot_row(bm,ii,v,nv);
        double yv = lb_dot_row(ymem,si2,v,nv);
        acc = ((acc-((bv*bv)/sb[ii]))+(rho[si2]*(yv*yv)))  ;
        ;
        ;
    }  ;
    return acc ;
}


SCM2CPP_FN inline int
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  int  col,  int  head,  int  m,  int  ib,  double  lbv,  int  nv )
{   if( nv > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            q[ j ] = g[j]   ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            q[ j ] = g[j]   ;
        }
    }  ;
    lb_hv(q,smem,ymem,rho,al,theta,col,head,m,nv)  ;
    if( nv > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            d[ j ] = (0.0-q[j])   ;
        }
    } else {
        for( int j = 0 ; j < nv ; j = (j+1) ) {
            d[ j ] = (0.0-q[j])   ;
        }
    }  ;
    if( ib >= 0 ) {
        double gs = g[ib];
        double tl = (w[ib]-lbv);
        int fixed = 0;
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
                #pragma omp parallel for
                for( int j = 0 ; j < nv ; j = (j+1) ) {
                    e[ j ] = 0.0   ;
                }
            } else {
                for( int j = 0 ; j < nv ; j = (j+1) ) {
                    e[ j ] = 0.0   ;
                }
            }  ;
            e[ ib ] = 1.0   ;
            lb_hv(e,smem,ymem,rho,al,theta,col,head,m,nv)  ;
            double lam = ((delta+q[ib])/e[ib]);
            if( nv > 65536 ) {
                #pragma omp parallel for
                for( int j = 0 ; j < nv ; j = (j+1) ) {
                    d[ j ] = (d[j]+(lam*e[j]))   ;
                }
            } else {
                for( int j = 0 ; j < nv ; j = (j+1) ) {
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
                        #pragma omp parallel for
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
                            double xcpj = ((0.0-dtm)*g[j]);
                            d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
                            ;
                        }
                    } else {
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
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


inline int
lbfgs( int  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  int  m,  int  maxiter,  double  pgtol,  double  ftol,  int  maxls,  int  ib,  double  lbv,  int  nv,  int  n,  int  p,  int  k )
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
    int iter = 0;
    int col = 0;
    int head = 0;
    double theta = 1.0;
    int nfg = 0;
    int done = 0;
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
            #pragma omp parallel for
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                t[ j ] = w[j]   ;
                gold[ j ] = g[j]   ;
            }
        } else {
            for( int j = 0 ; j < nv ; j = (j+1) ) {
                t[ j ] = w[j]   ;
                gold[ j ] = g[j]   ;
            }
        }  ;
        double fold = f;
        double dnorm = sqrt(lb_dot(d,d,nv));
        double gdold = lb_dot(g,d,nv);
        double stpmx = 10000000000.0;
        double gd = 0.0;
        int task = 0;
        int ifun = 0;
        int fail = 0;
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
                        #pragma omp parallel for
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
                            w[ j ] = (t[j]+(stp*d[j]))   ;
                        }
                    } else {
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
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
                #pragma omp parallel for
                for( int j = 0 ; j < nv ; j = (j+1) ) {
                    w[ j ] = t[j]   ;
                    g[ j ] = gold[j]   ;
                }
            } else {
                for( int j = 0 ; j < nv ; j = (j+1) ) {
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
                    int slot3 = ( ( col < m ) ? (((head+col) % m)) : (head) );
                    double rr = 0.0;
                    if( nv > 65536 ) {
                        #pragma omp parallel for reduction(+:rr)
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
                            double yj = (g[j]-gold[j]);
                            smem[ ((slot3*nv)+j) ] = (stp2*d[j])   ;
                            ymem[ ((slot3*nv)+j) ] = yj   ;
                            rr = (rr+(yj*yj))  ;
                            ;
                        }
                    } else {
                        for( int j = 0 ; j < nv ; j = (j+1) ) {
                            double yj = (g[j]-gold[j]);
                            smem[ ((slot3*nv)+j) ] = (stp2*d[j])   ;
                            ymem[ ((slot3*nv)+j) ] = yj   ;
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
lbfgs_fg( int  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  int  n,  int  p,  int  k )
{
    if( kind == 0 ) {
        return logistic_fg(w,g,x,y,work,aux[0],( ( aux[1] == 1.0 ) ? (1) : (0) ),( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p,k) ;
    }
    else {
        if( kind == 1 ) {
            return huber_fg(w,g,x,y,work,aux[0],aux[1],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
        else {
            return glm_fg(w,g,x,y,work,int(aux[1]),aux[3],aux[0],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
    }
}


SCM2CPP_FN inline int
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  int  norm,  int  n,  int  p,  int  kc )
{   double tot = 0.0;
    if( kc > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = 0.0   ;
        }
    } else {
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = 0.0   ;
        }
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( kc > 65536 ) {
            #pragma omp parallel for
            for( int c = 0 ; c < kc ; c = (c+1) ) {
                weights[ c ] = (weights[c]+resp[((i*kc)+c)])   ;
            }
        } else {
            for( int c = 0 ; c < kc ; c = (c+1) ) {
                weights[ c ] = (weights[c]+resp[((i*kc)+c)])   ;
            }
        }  ;
    }  ;
    if( kc > 65536 ) {
        #pragma omp parallel for reduction(+:tot)
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
            tot = (tot+weights[c])  ;
        }
    } else {
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
            tot = (tot+weights[c])  ;
        }
    }  ;
    if( (kc*p) > 65536 ) {
        #pragma omp parallel for
        for( int i2572 = 0 ; i2572 < kc ; i2572 = (i2572+1) ) {
            for( int i2573 = 0 ; !(i2573 == p) ; i2573 = (i2573+1) ) {
                means[ ((i2572*p)+i2573) ] = 0.0   ;
            }  ;
        }
    } else {
        for( int i2572 = 0 ; i2572 < kc ; i2572 = (i2572+1) ) {
            for( int i2573 = 0 ; !(i2573 == p) ; i2573 = (i2573+1) ) {
                means[ ((i2572*p)+i2573) ] = 0.0   ;
            }  ;
        }
    }  ;
    for( int k2570 = 0 ; !(k2570 == n) ; k2570 = (k2570+1) ) {
        if( (kc*p) > 65536 ) {
            #pragma omp parallel for
            for( int k2571 = 0 ; k2571 < kc ; k2571 = (k2571+1) ) {
                for( int k2574 = 0 ; !(k2574 == p) ; k2574 = (k2574+1) ) {
                    means[ ((k2571*p)+k2574) ] = (means[((k2571*p)+k2574)]+(x[((k2570*p)+k2574)]*resp[((k2570*kc)+k2571)]))   ;
                }  ;
            }
        } else {
            for( int k2571 = 0 ; k2571 < kc ; k2571 = (k2571+1) ) {
                for( int k2574 = 0 ; !(k2574 == p) ; k2574 = (k2574+1) ) {
                    means[ ((k2571*p)+k2574) ] = (means[((k2571*p)+k2574)]+(x[((k2570*p)+k2574)]*resp[((k2570*kc)+k2571)]))   ;
                }  ;
            }
        }  ;
    }  ;
    for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
        double nk = weights[c];
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                means[ ((c*p)+j) ] = (means[((c*p)+j)]/nk)   ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                means[ ((c*p)+j) ] = (means[((c*p)+j)]/nk)   ;
            }
        }  ;
        if( (n*p) > 65536 ) {
            #pragma omp parallel for
            for( int i = 0 ; i < n ; i = (i+1) ) {
                double r = resp[((i*kc)+c)];
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double dv = (x[((i*p)+j)]-means[((c*p)+j)]);
                    u[ ((i*p)+j) ] = dv   ;
                    dw[ ((i*p)+j) ] = (r*dv)   ;
                    ;
                }  ;
                ;
            }
        } else {
            for( int i = 0 ; i < n ; i = (i+1) ) {
                double r = resp[((i*kc)+c)];
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double dv = (x[((i*p)+j)]-means[((c*p)+j)]);
                    u[ ((i*p)+j) ] = dv   ;
                    dw[ ((i*p)+j) ] = (r*dv)   ;
                    ;
                }  ;
                ;
            }
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for
            for( int i2577 = 0 ; i2577 < p ; i2577 = (i2577+1) ) {
                for( int i2578 = 0 ; !(i2578 == p) ; i2578 = (i2578+1) ) {
                    cov[ ((i2577*p)+i2578) ] = 0.0   ;
                }  ;
            }
        } else {
            for( int i2577 = 0 ; i2577 < p ; i2577 = (i2577+1) ) {
                for( int i2578 = 0 ; !(i2578 == p) ; i2578 = (i2578+1) ) {
                    cov[ ((i2577*p)+i2578) ] = 0.0   ;
                }  ;
            }
        }  ;
        for( int k2575 = 0 ; !(k2575 == n) ; k2575 = (k2575+1) ) {
            if( (p*p) > 65536 ) {
                #pragma omp parallel for
                for( int k2576 = 0 ; k2576 < p ; k2576 = (k2576+1) ) {
                    for( int k2579 = 0 ; !(k2579 == p) ; k2579 = (k2579+1) ) {
                        cov[ ((k2576*p)+k2579) ] = (cov[((k2576*p)+k2579)]+(u[((k2575*p)+k2579)]*dw[((k2575*p)+k2576)]))   ;
                    }  ;
                }
            } else {
                for( int k2576 = 0 ; k2576 < p ; k2576 = (k2576+1) ) {
                    for( int k2579 = 0 ; !(k2579 == p) ; k2579 = (k2579+1) ) {
                        cov[ ((k2576*p)+k2579) ] = (cov[((k2576*p)+k2579)]+(u[((k2575*p)+k2579)]*dw[((k2575*p)+k2576)]))   ;
                    }  ;
                }
            }  ;
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                cov[ t ] = (cov[t]/nk)   ;
            }
        } else {
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                cov[ t ] = (cov[t]/nk)   ;
            }
        }  ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            cov[ ((j*p)+j) ] = (cov[((j*p)+j)]+reg)   ;
        }  ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            double s = cov[((j*p)+j)];
            for( int m = 0 ; !(m == j) ; m = (m+1) ) {
                s = (s-(l[((j*p)+m)]*l[((j*p)+m)]))  ;
            }  ;
            l[ ((j*p)+j) ] = sqrt(s)   ;
            for( int i = (j+1) ; !(i >= p) ; i = (i+1) ) {
                double t2 = cov[((i*p)+j)];
                for( int m = 0 ; !(m == j) ; m = (m+1) ) {
                    t2 = (t2-(l[((i*p)+m)]*l[((j*p)+m)]))  ;
                }  ;
                l[ ((i*p)+j) ] = (t2/l[((j*p)+j)])   ;
                ;
            }  ;
            ;
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                prec[ ((c*(p*p))+t) ] = 0.0   ;
            }
        } else {
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                prec[ ((c*(p*p))+t) ] = 0.0   ;
            }
        }  ;
        for( int e = 0 ; !(e == p) ; e = (e+1) ) {
            for( int i = e ; !(i == p) ; i = (i+1) ) {
                double t3 = ( ( i == e ) ? (1.0) : (0.0) );
                for( int m = e ; !(m == i) ; m = (m+1) ) {
                    t3 = (t3-(l[((i*p)+m)]*prec[((c*(p*p))+((e*p)+m))]))  ;
                }  ;
                prec[ ((c*(p*p))+((e*p)+i)) ] = (t3/l[((i*p)+i)])   ;
                ;
            }  ;
        }  ;
        ;
    }  ;
    if( kc > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
        }
    } else {
        for( int c = 0 ; c < kc ; c = (c+1) ) {
            weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  int  n,  int  p,  int  kc )
{   for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
        double logdet = 0.0;
        double lw = log(weights[c]);
        if( (p*p) > 65536 ) {
            #pragma omp parallel for
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                u[ t ] = prec[((c*(p*p))+t)]   ;
            }
        } else {
            for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
                u[ t ] = prec[((c*(p*p))+t)]   ;
            }
        }  ;
        if( (p*p) > 65536 ) {
            #pragma omp parallel for reduction(+:logdet)
            for( int j = 0 ; j < p ; j = (j+1) ) {
                logdet = (logdet+log(u[((j*p)+j)]))  ;
                double acc = 0.0;
                for( int m = 0 ; !(m == p) ; m = (m+1) ) {
                    acc = (acc+(means[((c*p)+m)]*u[((m*p)+j)]))  ;
                }  ;
                mu[ j ] = acc   ;
                ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                logdet = (logdet+log(u[((j*p)+j)]))  ;
                double acc = 0.0;
                for( int m = 0 ; !(m == p) ; m = (m+1) ) {
                    acc = (acc+(means[((c*p)+m)]*u[((m*p)+j)]))  ;
                }  ;
                mu[ j ] = acc   ;
                ;
            }
        }  ;
        if( (n*p) > 65536 ) {
            #pragma omp parallel for
            for( int k2581 = 0 ; k2581 < n ; k2581 = (k2581+1) ) {
                for( int k2582 = 0 ; !(k2582 == p) ; k2582 = (k2582+1) ) {
                    y[ ((k2581*p)+k2582) ] = ([&]() -> double { int i2583 = 0; double sum2584 = 0.0; while (!(i2583 == p)) {
                    int i2583_next5559 = (i2583+1);
                        double sum2584_next5560 = (sum2584+(x[((k2581*p)+i2583)]*u[((i2583*p)+k2582)]));
                        i2583 = i2583_next5559;
                        sum2584 = sum2584_next5560;
                    } return sum2584;
                                                              })()   ;
                }  ;
            }
        } else {
            for( int k2581 = 0 ; k2581 < n ; k2581 = (k2581+1) ) {
                for( int k2582 = 0 ; !(k2582 == p) ; k2582 = (k2582+1) ) {
                    y[ ((k2581*p)+k2582) ] = ([&]() -> double { int i2583 = 0; double sum2584 = 0.0; while (!(i2583 == p)) {
                    int i2583_next5559 = (i2583+1);
                        double sum2584_next5560 = (sum2584+(x[((k2581*p)+i2583)]*u[((i2583*p)+k2582)]));
                        i2583 = i2583_next5559;
                        sum2584 = sum2584_next5560;
                    } return sum2584; })()   ;
                }  ;
            }
        }  ;
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            double sq = 0.0;
            if( p > 65536 ) {
                #pragma omp parallel for reduction(+:sq)
                for( int j = 0 ; j < p ; j = (j+1) ) {
                    double v = (y[((i*p)+j)]-mu[j]);
                    sq = (sq+(v*v))  ;
                    ;
                }
            } else {
                for( int j = 0 ; j < p ; j = (j+1) ) {
                    double v = (y[((i*p)+j)]-mu[j]);
                    sq = (sq+(v*v))  ;
                    ;
                }
            }  ;
            wlp[ ((i*kc)+c) ] = (((-0.5*((double(p)*1.8378770664093453)+sq))+logdet)+lw)   ;
            ;
        }  ;
        ;
    }  ;
    double lb = 0.0;
    if( (n*(kc-1)) > 65536 ) {
        #pragma omp parallel for reduction(+:lb)
        for( int i = 0 ; i < n ; i = (i+1) ) {
            double amax = wlp[(i*kc)];
            double se = 0.0;
            for( int c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( wlp[((i*kc)+c)] > amax ) {
                    amax = wlp[((i*kc)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
                se = (se+exp((wlp[((i*kc)+c)]-amax)))  ;
            }  ;
            double lse = (log(se)+amax);
            lb = (lb+lse)  ;
            for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
                resp[ ((i*kc)+c) ] = exp((wlp[((i*kc)+c)]-lse))   ;
            }  ;
            ;
            ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            double amax = wlp[(i*kc)];
            double se = 0.0;
            for( int c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( wlp[((i*kc)+c)] > amax ) {
                    amax = wlp[((i*kc)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
                se = (se+exp((wlp[((i*kc)+c)]-amax)))  ;
            }  ;
            double lse = (log(se)+amax);
            lb = (lb+lse)  ;
            for( int c = 0 ; !(c == kc) ; c = (c+1) ) {
                resp[ ((i*kc)+c) ] = exp((wlp[((i*kc)+c)]-lse))   ;
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


inline int
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  int  maxiter,  double  tol,  double  reg,  int  n,  int  p,  int  kc )
{   std::vector<double> dw((n*p),0.0);
    std::vector<double> y((n*p),0.0);
    std::vector<double> wlp((n*kc),0.0);
    std::vector<double> cov((p*p),0.0);
    std::vector<double> l((p*p),0.0);
    std::vector<double> u((p*p),0.0);
    std::vector<double> mu(p,0.0);
    double lb = -1e+300;
    int it = 0;
    int conv = 0;
    int done = 0;
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
        #pragma omp parallel for
        for( int i = 0 ; i < n ; i = (i+1) ) {
            int best = 0;
            double bv = resp[(i*kc)];
            for( int c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( resp[((i*kc)+c)] > bv ) {
                    bv = resp[((i*kc)+c)]  ;
                    best = c  ;
                } else {
                    0  ;
                }  ;
            }  ;
            labels[ i ] = double(best)   ;
            ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            int best = 0;
            double bv = resp[(i*kc)];
            for( int c = 1 ; !(c == kc) ; c = (c+1) ) {
                if( resp[((i*kc)+c)] > bv ) {
                    bv = resp[((i*kc)+c)]  ;
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


SCM2CPP_FN inline int
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m )
{   for( int ii = 0 ; !(ii == (m-1)) ; ii = (ii+1) ) {
        int i = ((m-1)-ii);
        int l = (i-1);
        double h = 0.0;
        double scale = 0.0;
        if( l > 0 ) {
            if( (l+1) > 65536 ) {
                #pragma omp parallel for reduction(+:scale)
                for( int k = 0 ; k <= l ; k = (k+1) ) {
                    double ak = a[((i*m)+k)];
                    scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                    ;
                }
            } else {
                for( int k = 0 ; k <= l ; k = (k+1) ) {
                    double ak = a[((i*m)+k)];
                    scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                    ;
                }
            }  ;
            if( scale == 0.0 ) {
                e[ i ] = a[((i*m)+l)]   ;
            } else {
                if( (l+1) > 65536 ) {
                    #pragma omp parallel for reduction(+:h)
                    for( int k = 0 ; k <= l ; k = (k+1) ) {
                        a[ ((i*m)+k) ] = (a[((i*m)+k)]/scale)   ;
                        h = (h+(a[((i*m)+k)]*a[((i*m)+k)]))  ;
                    }
                } else {
                    for( int k = 0 ; k <= l ; k = (k+1) ) {
                        a[ ((i*m)+k) ] = (a[((i*m)+k)]/scale)   ;
                        h = (h+(a[((i*m)+k)]*a[((i*m)+k)]))  ;
                    }
                }  ;
                double f = a[((i*m)+l)];
                double g = ( ( f >= 0.0 ) ? ((0.0-sqrt(h))) : (sqrt(h)) );
                e[ i ] = (scale*g)   ;
                h = (h-(f*g))  ;
                a[ ((i*m)+l) ] = (f-g)   ;
                double ff = 0.0;
                for( int j = 0 ; !(j > l) ; j = (j+1) ) {
                    a[ ((j*m)+i) ] = (a[((i*m)+j)]/h)   ;
                    double gg = 0.0;
                    if( (j+1) > 65536 ) {
                        #pragma omp parallel for reduction(+:gg)
                        for( int k = 0 ; k <= j ; k = (k+1) ) {
                            gg = (gg+(a[((j*m)+k)]*a[((i*m)+k)]))  ;
                        }
                    } else {
                        for( int k = 0 ; k <= j ; k = (k+1) ) {
                            gg = (gg+(a[((j*m)+k)]*a[((i*m)+k)]))  ;
                        }
                    }  ;
                    if( ((l+1)-(j+1)) > 65536 ) {
                        #pragma omp parallel for reduction(+:gg)
                        for( int k = (j+1) ; k <= l ; k = (k+1) ) {
                            gg = (gg+(a[((k*m)+j)]*a[((i*m)+k)]))  ;
                        }
                    } else {
                        for( int k = (j+1) ; k <= l ; k = (k+1) ) {
                            gg = (gg+(a[((k*m)+j)]*a[((i*m)+k)]))  ;
                        }
                    }  ;
                    e[ j ] = (gg/h)   ;
                    ff = (ff+(e[j]*a[((i*m)+j)]))  ;
                    ;
                }  ;
                double hh = (ff/(h+h));
                for( int j = 0 ; !(j > l) ; j = (j+1) ) {
                    double f2 = a[((i*m)+j)];
                    double g2 = (e[j]-(hh*f2));
                    e[ j ] = g2   ;
                    for( int k = 0 ; !(k > j) ; k = (k+1) ) {
                        a[ ((j*m)+k) ] = (a[((j*m)+k)]-((f2*e[k])+(g2*a[((i*m)+k)])))   ;
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
            e[ i ] = a[((i*m)+l)]   ;
        }  ;
        ev[ i ] = h   ;
        ;
        ;
    }  ;
    ev[ 0 ] = 0.0   ;
    e[ 0 ] = 0.0   ;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        if( !(ev[i] == 0.0) ) {
            for( int j = 0 ; !(j == i) ; j = (j+1) ) {
                double g3 = 0.0;
                if( i > 65536 ) {
                    #pragma omp parallel for reduction(+:g3)
                    for( int k = 0 ; k < i ; k = (k+1) ) {
                        g3 = (g3+(a[((i*m)+k)]*a[((k*m)+j)]))  ;
                    }
                } else {
                    for( int k = 0 ; k < i ; k = (k+1) ) {
                        g3 = (g3+(a[((i*m)+k)]*a[((k*m)+j)]))  ;
                    }
                }  ;
                for( int k = 0 ; !(k == i) ; k = (k+1) ) {
                    a[ ((k*m)+j) ] = (a[((k*m)+j)]-(g3*a[((k*m)+i)]))   ;
                }  ;
                ;
            }  ;
        } else {
            0  ;
        }  ;
        ev[ i ] = a[((i*m)+i)]   ;
        a[ ((i*m)+i) ] = 1.0   ;
        for( int j = 0 ; !(j == i) ; j = (j+1) ) {
            a[ ((j*m)+i) ] = 0.0   ;
            a[ ((i*m)+j) ] = 0.0   ;
        }  ;
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ ((j*m)+i) ] = a[((i*m)+j)]   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                v[ ((j*m)+i) ] = a[((i*m)+j)]   ;
            }  ;
        }
    }  ;
    for( int i = 1 ; !(i == m) ; i = (i+1) ) {
        e[ (i-1) ] = e[i]   ;
    }  ;
    e[ (m-1) ] = 0.0   ;
    for( int l = 0 ; !(l == m) ; l = (l+1) ) {
        int fin = 0;
        int iter = 0;
        for(  ; !((fin == 1 || iter > 60)) ;  ) {
            int mm = l;
            int found = 0;
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
                int under = 0;
                int i = (mm-1);
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
                        for( int k = 0 ; !(k == m) ; k = (k+1) ) {
                            double zf = v[(((i+1)*m)+k)];
                            double zi = v[((i*m)+k)];
                            v[ (((i+1)*m)+k) ] = ((s*zi)+(c*zf))   ;
                            v[ ((i*m)+k) ] = ((c*zi)-(s*zf))   ;
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
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        for( int j = (i+1) ; !(j >= m) ; j = (j+1) ) {
            double tmp = v[((i*m)+j)];
            v[ ((i*m)+j) ] = v[((j*m)+i)]   ;
            v[ ((j*m)+i) ] = tmp   ;
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


SCM2CPP_FN inline int
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  int  m )
{   if( m > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < m ; j = (j+1) ) {
            ord[ j ] = j   ;
        }
    } else {
        for( int j = 0 ; j < m ; j = (j+1) ) {
            ord[ j ] = j   ;
        }
    }  ;
    for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        int best = j;
        for( int r = (j+1) ; !(r >= m) ; r = (r+1) ) {
            if( ev[ord[r]] > ev[ord[best]] ) {
                best = r  ;
            } else {
                0  ;
            }  ;
        }  ;
        int tmp = ord[j];
        ord[ j ] = ord[best]   ;
        ord[ best ] = tmp   ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline double
ica_tanh( double  x )
{
    return (1.0-(2.0/(exp((2.0*x))+1.0))) ;
}


SCM2CPP_FN inline int
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> t,  int  m )
{   if( (m*m) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(w[((i*m)+r)]*w[((j*m)+r)]))  ;
                }  ;
                a[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(w[((i*m)+r)]*w[((j*m)+r)]))  ;
                }  ;
                a[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    sym_eigen(a,v,ev,e,m)  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                    acc = (acc+((v[((i*m)+r)]/sqrt(sr))*v[((j*m)+r)]))  ;
                    ;
                }  ;
                t[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                    acc = (acc+((v[((i*m)+r)]/sqrt(sr))*v[((j*m)+r)]))  ;
                    ;
                }  ;
                t[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(t[((i*m)+r)]*w[((r*m)+j)]))  ;
                }  ;
                a[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < m ; i = (i+1) ) {
            for( int j = 0 ; !(j == m) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                    acc = (acc+(t[((i*m)+r)]*w[((r*m)+j)]))  ;
                }  ;
                a[ ((i*m)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    if( (m*m) > 65536 ) {
        #pragma omp parallel for
        for( int t2 = 0 ; t2 < (m*m) ; t2 = (t2+1) ) {
            w[ t2 ] = a[t2]   ;
        }
    } else {
        for( int t2 = 0 ; t2 < (m*m) ; t2 = (t2+1) ) {
            w[ t2 ] = a[t2]   ;
        }
    }  ;
    return 0 ;
}


inline int
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  int  maxiter,  double  tol,  int  n,  int  p,  int  nc )
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
    int it = 0;
    int done = 0;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = 0.0   ;
        }
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mean[ j ] = (mean[j]+x[((i*p)+j)])   ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mean[ j ] = (mean[j]+x[((i*p)+j)])   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    }  ;
    if( (n*p) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < n ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ ((i*p)+j) ] = (x[((i*p)+j)]-mean[j])   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ ((i*p)+j) ] = (x[((i*p)+j)]-mean[j])   ;
            }  ;
        }
    }  ;
    for( int k2595 = 0 ; !(k2595 == p) ; k2595 = (k2595+1) ) {
        for( int k2596 = k2595 ; !(k2596 == p) ; k2596 = (k2596+1) ) {
            g[ ((k2595*p)+k2596) ] = ([&]() -> double { int i2598 = 0; double r2599 = 0.0; while (!(i2598 == n)) {
            int i2598_next5573 = (i2598+1);
                double r2599_next5574 = (r2599+(xc[((i2598*p)+k2595)]*xc[((i2598*p)+k2596)]));
                i2598 = i2598_next5573;
                r2599 = r2599_next5574;
            } return r2599; })()   ;
            g[ ((k2596*p)+k2595) ] = g[((k2595*p)+k2596)]   ;
        }  ;
    }  ;
    sym_eigen(g,u,ev,pe,p)  ;
    eig_order(ev,ord,p)  ;
    if( (nc*p) > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            int col = ord[c];
            double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
            double d = sqrt(ev[col]);
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                white[ ((c*p)+j) ] = ((sg*u[((j*p)+col)])/d)   ;
            }  ;
            ;
            ;
        }
    } else {
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            int col = ord[c];
            double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
            double d = sqrt(ev[col]);
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                white[ ((c*p)+j) ] = ((sg*u[((j*p)+col)])/d)   ;
            }  ;
            ;
            ;
        }
    }  ;
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for
        for( int k2601 = 0 ; k2601 < nc ; k2601 = (k2601+1) ) {
            for( int k2602 = 0 ; !(k2602 == n) ; k2602 = (k2602+1) ) {
                x1[ ((k2601*n)+k2602) ] = ([&]() -> double { int i2604 = 0; double r2605 = 0.0; while (!(i2604 == p)) {
                int i2604_next5575 = (i2604+1);
                    double r2605_next5576 = (r2605+(white[((k2601*p)+i2604)]*xc[((k2602*p)+i2604)]));
                    i2604 = i2604_next5575;
                    r2605 = r2605_next5576;
                } return r2605;
                                                           })()   ;
            }  ;
        }
    } else {
        for( int k2601 = 0 ; k2601 < nc ; k2601 = (k2601+1) ) {
            for( int k2602 = 0 ; !(k2602 == n) ; k2602 = (k2602+1) ) {
                x1[ ((k2601*n)+k2602) ] = ([&]() -> double { int i2604 = 0; double r2605 = 0.0; while (!(i2604 == p)) {
                int i2604_next5575 = (i2604+1);
                    double r2605_next5576 = (r2605+(white[((k2601*p)+i2604)]*xc[((k2602*p)+i2604)]));
                    i2604 = i2604_next5575;
                    r2605 = r2605_next5576;
                } return r2605; })()   ;
            }  ;
        }
    }  ;
    double sn = sqrt(double(n));
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for
        for( int t = 0 ; t < (nc*n) ; t = (t+1) ) {
            x1[ t ] = (x1[t]*sn)   ;
        }
    } else {
        for( int t = 0 ; t < (nc*n) ; t = (t+1) ) {
            x1[ t ] = (x1[t]*sn)   ;
        }
    }  ;
    ;
    if( (nc*nc) > 65536 ) {
        #pragma omp parallel for
        for( int t = 0 ; t < (nc*nc) ; t = (t+1) ) {
            unmix[ t ] = winit[t]   ;
        }
    } else {
        for( int t = 0 ; t < (nc*nc) ; t = (t+1) ) {
            unmix[ t ] = winit[t]   ;
        }
    }  ;
    ica_sym(unmix,sa,sv,se,se2,st,nc)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        if( (nc*n) > 65536 ) {
            #pragma omp parallel for
            for( int k2613 = 0 ; k2613 < nc ; k2613 = (k2613+1) ) {
                for( int k2614 = 0 ; !(k2614 == n) ; k2614 = (k2614+1) ) {
                    gw[ ((k2613*n)+k2614) ] = ([&]() -> double { int i2615 = 0; double sum2616 = 0.0; while (!(i2615 == nc)) {
                    int i2615_next5577 = (i2615+1);
                        double sum2616_next5578 = (sum2616+(unmix[((k2613*nc)+i2615)]*x1[((i2615*n)+k2614)]));
                        i2615 = i2615_next5577;
                        sum2616 = sum2616_next5578;
                    } return sum2616;
                                                               })()   ;
                }  ;
            }
        } else {
            for( int k2613 = 0 ; k2613 < nc ; k2613 = (k2613+1) ) {
                for( int k2614 = 0 ; !(k2614 == n) ; k2614 = (k2614+1) ) {
                    gw[ ((k2613*n)+k2614) ] = ([&]() -> double { int i2615 = 0; double sum2616 = 0.0; while (!(i2615 == nc)) {
                    int i2615_next5577 = (i2615+1);
                        double sum2616_next5578 = (sum2616+(unmix[((k2613*nc)+i2615)]*x1[((i2615*n)+k2614)]));
                        i2615 = i2615_next5577;
                        sum2616 = sum2616_next5578;
                    } return sum2616; })()   ;
                }  ;
            }
        }  ;
        if( (nc*n) > 65536 ) {
            #pragma omp parallel for
            for( int c = 0 ; c < nc ; c = (c+1) ) {
                double acc = 0.0;
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    double th = ica_tanh(gw[((c*n)+i)]);
                    gw[ ((c*n)+i) ] = th   ;
                    acc = (acc+(1.0-(th*th)))  ;
                    ;
                }  ;
                gx[ c ] = (acc/double(n))   ;
                ;
            }
        } else {
            for( int c = 0 ; c < nc ; c = (c+1) ) {
                double acc = 0.0;
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    double th = ica_tanh(gw[((c*n)+i)]);
                    gw[ ((c*n)+i) ] = th   ;
                    acc = (acc+(1.0-(th*th)))  ;
                    ;
                }  ;
                gx[ c ] = (acc/double(n))   ;
                ;
            }
        }  ;
        if( (nc*nc) > 65536 ) {
            #pragma omp parallel for
            for( int k2618 = 0 ; k2618 < nc ; k2618 = (k2618+1) ) {
                for( int k2619 = 0 ; !(k2619 == nc) ; k2619 = (k2619+1) ) {
                    w1[ ((k2618*nc)+k2619) ] = ([&]() -> double { int i2621 = 0; double r2622 = 0.0; while (!(i2621 == n)) {
                    int i2621_next5583 = (i2621+1);
                        double r2622_next5584 = (r2622+(gw[((k2618*n)+i2621)]*x1[((k2619*n)+i2621)]));
                        i2621 = i2621_next5583;
                        r2622 = r2622_next5584;
                    } return r2622;
                                                                })()   ;
                }  ;
            }
        } else {
            for( int k2618 = 0 ; k2618 < nc ; k2618 = (k2618+1) ) {
                for( int k2619 = 0 ; !(k2619 == nc) ; k2619 = (k2619+1) ) {
                    w1[ ((k2618*nc)+k2619) ] = ([&]() -> double { int i2621 = 0; double r2622 = 0.0; while (!(i2621 == n)) {
                    int i2621_next5583 = (i2621+1);
                        double r2622_next5584 = (r2622+(gw[((k2618*n)+i2621)]*x1[((k2619*n)+i2621)]));
                        i2621 = i2621_next5583;
                        r2622 = r2622_next5584;
                    } return r2622; })()   ;
                }  ;
            }
        }  ;
        if( (nc*nc) > 65536 ) {
            #pragma omp parallel for
            for( int c = 0 ; c < nc ; c = (c+1) ) {
                for( int j = 0 ; !(j == nc) ; j = (j+1) ) {
                    w1[ ((c*nc)+j) ] = ((w1[((c*nc)+j)]/double(n))-(gx[c]*unmix[((c*nc)+j)]))   ;
                }  ;
            }
        } else {
            for( int c = 0 ; c < nc ; c = (c+1) ) {
                for( int j = 0 ; !(j == nc) ; j = (j+1) ) {
                    w1[ ((c*nc)+j) ] = ((w1[((c*nc)+j)]/double(n))-(gx[c]*unmix[((c*nc)+j)]))   ;
                }  ;
            }
        }  ;
        ica_sym(w1,sa,sv,se,se2,st,nc)  ;
        double lim = 0.0;
        for( int c = 0 ; !(c == nc) ; c = (c+1) ) {
            double acc = 0.0;
            if( nc > 65536 ) {
                #pragma omp parallel for reduction(+:acc)
                for( int j = 0 ; j < nc ; j = (j+1) ) {
                    acc = (acc+(w1[((c*nc)+j)]*unmix[((c*nc)+j)]))  ;
                }
            } else {
                for( int j = 0 ; j < nc ; j = (j+1) ) {
                    acc = (acc+(w1[((c*nc)+j)]*unmix[((c*nc)+j)]))  ;
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
            #pragma omp parallel for
            for( int t = 0 ; t < (nc*nc) ; t = (t+1) ) {
                unmix[ t ] = w1[t]   ;
            }
        } else {
            for( int t = 0 ; t < (nc*nc) ; t = (t+1) ) {
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
        #pragma omp parallel for
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[((c*nc)+r)]*white[((r*p)+j)]))  ;
                }  ;
                comps[ ((c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[((c*nc)+r)]*white[((r*p)+j)]))  ;
                }  ;
                comps[ ((c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for
        for( int k2607 = 0 ; k2607 < nc ; k2607 = (k2607+1) ) {
            for( int k2608 = 0 ; !(k2608 == n) ; k2608 = (k2608+1) ) {
                gw[ ((k2607*n)+k2608) ] = ([&]() -> double { int i2610 = 0; double r2611 = 0.0; while (!(i2610 == p)) {
                int i2610_next5585 = (i2610+1);
                    double r2611_next5586 = (r2611+(comps[((k2607*p)+i2610)]*xc[((k2608*p)+i2610)]));
                    i2610 = i2610_next5585;
                    r2611 = r2611_next5586;
                } return r2611;
                                                           })()   ;
            }  ;
        }
    } else {
        for( int k2607 = 0 ; k2607 < nc ; k2607 = (k2607+1) ) {
            for( int k2608 = 0 ; !(k2608 == n) ; k2608 = (k2608+1) ) {
                gw[ ((k2607*n)+k2608) ] = ([&]() -> double { int i2610 = 0; double r2611 = 0.0; while (!(i2610 == p)) {
                int i2610_next5585 = (i2610+1);
                    double r2611_next5586 = (r2611+(comps[((k2607*p)+i2610)]*xc[((k2608*p)+i2610)]));
                    i2610 = i2610_next5585;
                    r2611 = r2611_next5586;
                } return r2611; })()   ;
            }  ;
        }
    }  ;
    if( (nc*n) > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            double m1 = 0.0;
            double v1 = 0.0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                m1 = (m1+gw[((c*n)+i)])  ;
            }  ;
            m1 = (m1/double(n))  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double dd = (gw[((c*n)+i)]-m1);
                v1 = (v1+(dd*dd))  ;
                ;
            }  ;
            double sd = sqrt((v1/double(n)));
            for( int j = 0 ; !(j == nc) ; j = (j+1) ) {
                unmix[ ((c*nc)+j) ] = (unmix[((c*nc)+j)]/sd)   ;
            }  ;
            ;
            ;
        }
    } else {
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            double m1 = 0.0;
            double v1 = 0.0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                m1 = (m1+gw[((c*n)+i)])  ;
            }  ;
            m1 = (m1/double(n))  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double dd = (gw[((c*n)+i)]-m1);
                v1 = (v1+(dd*dd))  ;
                ;
            }  ;
            double sd = sqrt((v1/double(n)));
            for( int j = 0 ; !(j == nc) ; j = (j+1) ) {
                unmix[ ((c*nc)+j) ] = (unmix[((c*nc)+j)]/sd)   ;
            }  ;
            ;
            ;
        }
    }  ;
    if( (nc*p) > 65536 ) {
        #pragma omp parallel for
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[((c*nc)+r)]*white[((r*p)+j)]))  ;
                }  ;
                comps[ ((c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int c = 0 ; c < nc ; c = (c+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == nc) ; r = (r+1) ) {
                    acc = (acc+(unmix[((c*nc)+r)]*white[((r*p)+j)]))  ;
                }  ;
                comps[ ((c*p)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    return it ;
}


inline int
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  int  n,  int  p )
{   std::vector<double> c((p*p),0.0);
    std::vector<double> v((p*p),0.0);
    std::vector<double> e(p,0.0);
    std::vector<double> sc(p,0.0);
    std::vector<int> ord(p,0);
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = 0.0   ;
        }
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mean[ j ] = (mean[j]+x[((i*p)+j)])   ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mean[ j ] = (mean[j]+x[((i*p)+j)])   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mean[ j ] = (mean[j]/double(n))   ;
        }
    }  ;
    for( int k2625 = 0 ; !(k2625 == p) ; k2625 = (k2625+1) ) {
        for( int k2626 = k2625 ; !(k2626 == p) ; k2626 = (k2626+1) ) {
            c[ ((k2625*p)+k2626) ] = ([&]() -> double { int i2628 = 0; double r2629 = 0.0; while (!(i2628 == n)) {
            int i2628_next5587 = (i2628+1);
                double r2629_next5588 = (r2629+(x[((i2628*p)+k2625)]*x[((i2628*p)+k2626)]));
                i2628 = i2628_next5587;
                r2629 = r2629_next5588;
            } return r2629; })()   ;
            c[ ((k2626*p)+k2625) ] = c[((k2625*p)+k2626)]   ;
        }  ;
    }  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < p ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                c[ ((i*p)+j) ] = ((c[((i*p)+j)]-(double(n)*(mean[i]*mean[j])))/double((n-1)))   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < p ; i = (i+1) ) {
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                c[ ((i*p)+j) ] = ((c[((i*p)+j)]-(double(n)*(mean[i]*mean[j])))/double((n-1)))   ;
            }  ;
        }
    }  ;
    sym_eigen(c,v,e,sc,p)  ;
    eig_order(e,ord,p)  ;
    if( (p*p) > 65536 ) {
        #pragma omp parallel for
        for( int r = 0 ; r < p ; r = (r+1) ) {
            int col = ord[r];
            double lam = ( ( e[col] < 0.0 ) ? (0.0) : (e[col]) );
            int big = 0;
            double bv = -1.0;
            ev[ r ] = lam   ;
            sv[ r ] = sqrt((lam*double((n-1))))   ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double a = v[((j*p)+col)];
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
            double sg = ( ( v[((big*p)+col)] < 0.0 ) ? (-1.0) : (1.0) );
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                comps[ ((r*p)+j) ] = (sg*v[((j*p)+col)])   ;
            }  ;
            ;
            ;
            ;
        }
    } else {
        for( int r = 0 ; r < p ; r = (r+1) ) {
            int col = ord[r];
            double lam = ( ( e[col] < 0.0 ) ? (0.0) : (e[col]) );
            int big = 0;
            double bv = -1.0;
            ev[ r ] = lam   ;
            sv[ r ] = sqrt((lam*double((n-1))))   ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                double a = v[((j*p)+col)];
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
            double sg = ( ( v[((big*p)+col)] < 0.0 ) ? (-1.0) : (1.0) );
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                comps[ ((r*p)+j) ] = (sg*v[((j*p)+col)])   ;
            }  ;
            ;
            ;
            ;
        }
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
ard_pinvh( scm2cpp::span<double> a,  scm2cpp::span<double> s,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  k )
{   sym_eigen(a,v,ev,e,k)  ;
    double mx = 0.0;
    for( int r = 0 ; !(r == k) ; r = (r+1) ) {
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
        #pragma omp parallel for
        for( int i = 0 ; i < k ; i = (i+1) ) {
            for( int j = 0 ; !(j == k) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == k) ; r = (r+1) ) {
                    double er = ev[r];
                    if( ( ( er < 0.0 ) ? ((0.0-er)) : (er) ) > cut ) {
                        acc = (acc+((v[((i*k)+r)]*v[((j*k)+r)])/er))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
                s[ ((i*k)+j) ] = acc   ;
                ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < k ; i = (i+1) ) {
            for( int j = 0 ; !(j == k) ; j = (j+1) ) {
                double acc = 0.0;
                for( int r = 0 ; !(r == k) ; r = (r+1) ) {
                    double er = ev[r];
                    if( ( ( er < 0.0 ) ? ((0.0-er)) : (er) ) > cut ) {
                        acc = (acc+((v[((i*k)+r)]*v[((j*k)+r)])/er))  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                }  ;
                s[ ((i*k)+j) ] = acc   ;
                ;
            }  ;
        }
    }  ;
    ;
    ;
    return 0 ;
}


SCM2CPP_FN inline int
ard_sigma_coef( scm2cpp::cspan<double> xy,  scm2cpp::cspan<int> idx,  scm2cpp::cspan<double> lam,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::cspan<double> gk,  double  alpha,  int  k )
{   if( (k*k) > 65536 ) {
        #pragma omp parallel for
        for( int r = 0 ; r < k ; r = (r+1) ) {
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                a[ ((r*k)+c) ] = (( ( r == c ) ? (lam[idx[r]]) : (0.0) )+(alpha*gk[((r*k)+c)]))   ;
            }  ;
        }
    } else {
        for( int r = 0 ; r < k ; r = (r+1) ) {
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                a[ ((r*k)+c) ] = (( ( r == c ) ? (lam[idx[r]]) : (0.0) )+(alpha*gk[((r*k)+c)]))   ;
            }  ;
        }
    }  ;
    ard_pinvh(a,sigma,v,ev,e,k)  ;
    for( int r = 0 ; !(r == k) ; r = (r+1) ) {
        double acc = 0.0;
        if( k > 65536 ) {
            #pragma omp parallel for reduction(+:acc)
            for( int c = 0 ; c < k ; c = (c+1) ) {
                acc = (acc+(sigma[((r*k)+c)]*xy[idx[c]]))  ;
            }
        } else {
            for( int c = 0 ; c < k ; c = (c+1) ) {
                acc = (acc+(sigma[((r*k)+c)]*xy[idx[c]]))  ;
            }
        }  ;
        coef[ idx[r] ] = (alpha*acc)   ;
        ;
    }  ;
    return 0 ;
}


inline int
ard( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> sigma,  scm2cpp::span<double> lam,  scm2cpp::span<double> out,  int  maxiter,  double  tol,  double  alpha1,  double  alpha2,  double  lambda1,  double  lambda2,  double  thresh,  int  hoist,  int  n,  int  p )
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
    int k = p;
    int it = 0;
    int done = 0;
    if( hoist == 1 ) {
        for( int k2638 = 0 ; !(k2638 == p) ; k2638 = (k2638+1) ) {
            for( int k2639 = k2638 ; !(k2639 == p) ; k2639 = (k2639+1) ) {
                g[ ((k2638*p)+k2639) ] = ([&]() -> double { int i2641 = 0; double r2642 = 0.0; while (!(i2641 == n)) {
                int i2641_next5589 = (i2641+1);
                    double r2642_next5590 = (r2642+(x[((i2641*p)+k2638)]*x[((i2641*p)+k2639)]));
                    i2641 = i2641_next5589;
                    r2642 = r2642_next5590;
                } return r2642; })()   ;
                g[ ((k2639*p)+k2638) ] = g[((k2638*p)+k2639)]   ;
            }  ;
        }  ;
    } else {
        0  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int i2636 = 0 ; i2636 < p ; i2636 = (i2636+1) ) {
            xy[ i2636 ] = 0.0   ;
        }
    } else {
        for( int i2636 = 0 ; i2636 < p ; i2636 = (i2636+1) ) {
            xy[ i2636 ] = 0.0   ;
        }
    }  ;
    for( int k2634 = 0 ; !(k2634 == n) ; k2634 = (k2634+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int i2637 = 0 ; i2637 < p ; i2637 = (i2637+1) ) {
                xy[ i2637 ] = (xy[i2637]+(x[((k2634*p)+i2637)]*y[k2634]))   ;
            }
        } else {
            for( int i2637 = 0 ; i2637 < p ; i2637 = (i2637+1) ) {
                xy[ i2637 ] = (xy[i2637]+(x[((k2634*p)+i2637)]*y[k2634]))   ;
            }
        }  ;
    }  ;
    double ym = 0.0;
    double vy = 0.0;
    if( n > 65536 ) {
        #pragma omp parallel for reduction(+:ym)
        for( int i = 0 ; i < n ; i = (i+1) ) {
            ym = (ym+y[i])  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            ym = (ym+y[i])  ;
        }
    }  ;
    ym = (ym/double(n))  ;
    if( n > 65536 ) {
        #pragma omp parallel for reduction(+:vy)
        for( int i = 0 ; i < n ; i = (i+1) ) {
            vy = (vy+((y[i]-ym)*(y[i]-ym)))  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            vy = (vy+((y[i]-ym)*(y[i]-ym)))  ;
        }
    }  ;
    alpha = (1.0/((vy/double(n))+2.220446049250313e-16))  ;
    ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            lam[ j ] = 1.0   ;
            coef[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            lam[ j ] = 1.0   ;
            coef[ j ] = 0.0   ;
        }
    }  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        k = 0  ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            if( keep[j] == 1 ) {
                idx[ k ] = j   ;
                k = (k+1)  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( hoist == 1 ) {
            if( (k*k) > 65536 ) {
                #pragma omp parallel for
                for( int r = 0 ; r < k ; r = (r+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ ((r*k)+c) ] = g[((idx[r]*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( int r = 0 ; r < k ; r = (r+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ ((r*k)+c) ] = g[((idx[r]*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
        } else {
            if( (n*k) > 65536 ) {
                #pragma omp parallel for
                for( int i = 0 ; i < n ; i = (i+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ ((i*k)+c) ] = x[((i*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( int i = 0 ; i < n ; i = (i+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ ((i*k)+c) ] = x[((i*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
            for( int k2644 = 0 ; !(k2644 == k) ; k2644 = (k2644+1) ) {
                for( int k2645 = k2644 ; !(k2645 == k) ; k2645 = (k2645+1) ) {
                    gk[ ((k2644*k)+k2645) ] = ([&]() -> double { int i2647 = 0; double r2648 = 0.0; while (!(i2647 == n)) {
                    int i2647_next5591 = (i2647+1);
                        double r2648_next5592 = (r2648+(xk[((i2647*k)+k2644)]*xk[((i2647*k)+k2645)]));
                        i2647 = i2647_next5591;
                        r2648 = r2648_next5592;
                    } return r2648; })()   ;
                    gk[ ((k2645*k)+k2644) ] = gk[((k2644*k)+k2645)]   ;
                }  ;
            }  ;
        }  ;
        ard_sigma_coef(xy,idx,lam,coef,sigma,a,v,ev,e,gk,alpha,k)  ;
        if( n > 65536 ) {
            #pragma omp parallel for
            for( int k2650 = 0 ; k2650 < n ; k2650 = (k2650+1) ) {
                r[ k2650 ] = ([&]() -> double { int i2653 = 0; double r2654 = 0.0; while (!(i2653 == p)) {
                int i2653_next5593 = (i2653+1);
                    double r2654_next5594 = (r2654+(x[((k2650*p)+i2653)]*coef[i2653]));
                    i2653 = i2653_next5593;
                    r2654 = r2654_next5594;
                } return r2654;
                                              })()   ;
            }
        } else {
            for( int k2650 = 0 ; k2650 < n ; k2650 = (k2650+1) ) {
                r[ k2650 ] = ([&]() -> double { int i2653 = 0; double r2654 = 0.0; while (!(i2653 == p)) {
                int i2653_next5593 = (i2653+1);
                    double r2654_next5594 = (r2654+(x[((k2650*p)+i2653)]*coef[i2653]));
                    i2653 = i2653_next5593;
                    r2654 = r2654_next5594;
                } return r2654; })()   ;
            }
        }  ;
        double sse = 0.0;
        double gsum = 0.0;
        if( n > 65536 ) {
            #pragma omp parallel for reduction(+:sse)
            for( int i = 0 ; i < n ; i = (i+1) ) {
                double d = (y[i]-r[i]);
                sse = (sse+(d*d))  ;
                ;
            }
        } else {
            for( int i = 0 ; i < n ; i = (i+1) ) {
                double d = (y[i]-r[i]);
                sse = (sse+(d*d))  ;
                ;
            }
        }  ;
        for( int c = 0 ; !(c == k) ; c = (c+1) ) {
            int j = idx[c];
            double gm = (1.0-(lam[j]*sigma[((c*k)+c)]));
            gsum = (gsum+gm)  ;
            lam[ j ] = ((gm+(2.0*lambda1))/((coef[j]*coef[j])+(2.0*lambda2)))   ;
            ;
            ;
        }  ;
        alpha = (((double(n)-gsum)+(2.0*alpha1))/(sse+(2.0*alpha2)))  ;
        ;
        int nk = 0;
        double moved = 0.0;
        if( p > 65536 ) {
            #pragma omp parallel for reduction(+:nk) reduction(+:moved)
            for( int j = 0 ; j < p ; j = (j+1) ) {
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
            for( int j = 0 ; j < p ; j = (j+1) ) {
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
                #pragma omp parallel for
                for( int j = 0 ; j < p ; j = (j+1) ) {
                    old[ j ] = coef[j]   ;
                }
            } else {
                for( int j = 0 ; j < p ; j = (j+1) ) {
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
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
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
                #pragma omp parallel for
                for( int r = 0 ; r < k ; r = (r+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ ((r*k)+c) ] = g[((idx[r]*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( int r = 0 ; r < k ; r = (r+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        gk[ ((r*k)+c) ] = g[((idx[r]*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
        } else {
            if( (n*k) > 65536 ) {
                #pragma omp parallel for
                for( int i = 0 ; i < n ; i = (i+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ ((i*k)+c) ] = x[((i*p)+idx[c])]   ;
                    }  ;
                }
            } else {
                for( int i = 0 ; i < n ; i = (i+1) ) {
                    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                        xk[ ((i*k)+c) ] = x[((i*p)+idx[c])]   ;
                    }  ;
                }
            }  ;
            for( int k2656 = 0 ; !(k2656 == k) ; k2656 = (k2656+1) ) {
                for( int k2657 = k2656 ; !(k2657 == k) ; k2657 = (k2657+1) ) {
                    gk[ ((k2656*k)+k2657) ] = ([&]() -> double { int i2659 = 0; double r2660 = 0.0; while (!(i2659 == n)) {
                    int i2659_next5595 = (i2659+1);
                        double r2660_next5596 = (r2660+(xk[((i2659*k)+k2656)]*xk[((i2659*k)+k2657)]));
                        i2659 = i2659_next5595;
                        r2660 = r2660_next5596;
                    } return r2660; })()   ;
                    gk[ ((k2657*k)+k2656) ] = gk[((k2656*k)+k2657)]   ;
                }  ;
            }  ;
        }  ;
        ard_sigma_coef(xy,idx,lam,coef,sigma,a,v,ev,e,gk,alpha,k)  ;
    } else {
        0  ;
    }  ;
    out[ 0 ] = alpha   ;
    out[ 1 ] = double(k)   ;
    return it ;
}


inline int
f_regression( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> r,  scm2cpp::span<double> f,  int  center,  int  n,  int  p,  int  q )
{   std::vector<double> mx(p,0.0);
    std::vector<double> sx(p,0.0);
    std::vector<double> yc((n*q),0.0);
    std::vector<double> yn(q,0.0);
    double dof = double((n-( ( center == 1 ) ? (2) : (1) )));
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                double v = x[((i*p)+j)];
                mx[ j ] = (mx[j]+v)   ;
                sx[ j ] = (sx[j]+(v*v))   ;
                ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                double v = x[((i*p)+j)];
                mx[ j ] = (mx[j]+v)   ;
                sx[ j ] = (sx[j]+(v*v))   ;
                ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    }  ;
    if( (q*n) > 65536 ) {
        #pragma omp parallel for
        for( int t = 0 ; t < q ; t = (t+1) ) {
            double m = 0.0;
            double s = 0.0;
            if( center == 1 ) {
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    m = (m+y[((i*q)+t)])  ;
                }  ;
                m = (m/double(n))  ;
            } else {
                0  ;
            }  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double v = (y[((i*q)+t)]-m);
                yc[ ((i*q)+t) ] = v   ;
                s = (s+(v*v))  ;
                ;
            }  ;
            yn[ t ] = sqrt(s)   ;
            ;
        }
    } else {
        for( int t = 0 ; t < q ; t = (t+1) ) {
            double m = 0.0;
            double s = 0.0;
            if( center == 1 ) {
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    m = (m+y[((i*q)+t)])  ;
                }  ;
                m = (m/double(n))  ;
            } else {
                0  ;
            }  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double v = (y[((i*q)+t)]-m);
                yc[ ((i*q)+t) ] = v   ;
                s = (s+(v*v))  ;
                ;
            }  ;
            yn[ t ] = sqrt(s)   ;
            ;
        }
    }  ;
    if( (p*q) > 65536 ) {
        #pragma omp parallel for
        for( int i2665 = 0 ; i2665 < p ; i2665 = (i2665+1) ) {
            for( int i2666 = 0 ; !(i2666 == q) ; i2666 = (i2666+1) ) {
                r[ ((i2665*q)+i2666) ] = 0.0   ;
            }  ;
        }
    } else {
        for( int i2665 = 0 ; i2665 < p ; i2665 = (i2665+1) ) {
            for( int i2666 = 0 ; !(i2666 == q) ; i2666 = (i2666+1) ) {
                r[ ((i2665*q)+i2666) ] = 0.0   ;
            }  ;
        }
    }  ;
    for( int k2663 = 0 ; !(k2663 == n) ; k2663 = (k2663+1) ) {
        if( (p*q) > 65536 ) {
            #pragma omp parallel for
            for( int k2664 = 0 ; k2664 < p ; k2664 = (k2664+1) ) {
                for( int k2667 = 0 ; !(k2667 == q) ; k2667 = (k2667+1) ) {
                    r[ ((k2664*q)+k2667) ] = (r[((k2664*q)+k2667)]+(yc[((k2663*q)+k2667)]*x[((k2663*p)+k2664)]))   ;
                }  ;
            }
        } else {
            for( int k2664 = 0 ; k2664 < p ; k2664 = (k2664+1) ) {
                for( int k2667 = 0 ; !(k2667 == q) ; k2667 = (k2667+1) ) {
                    r[ ((k2664*q)+k2667) ] = (r[((k2664*q)+k2667)]+(yc[((k2663*q)+k2667)]*x[((k2663*p)+k2664)]))   ;
                }  ;
            }
        }  ;
    }  ;
    if( (p*q) > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double xn = sqrt(( ( center == 1 ) ? ((sx[j]-(double(n)*(mx[j]*mx[j])))) : (sx[j]) ));
            for( int t = 0 ; !(t == q) ; t = (t+1) ) {
                double rr = ((r[((j*q)+t)]/xn)/yn[t]);
                r[ ((j*q)+t) ] = rr   ;
                f[ ((j*q)+t) ] = (((rr*rr)/(1.0-(rr*rr)))*dof)   ;
                ;
            }  ;
            ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double xn = sqrt(( ( center == 1 ) ? ((sx[j]-(double(n)*(mx[j]*mx[j])))) : (sx[j]) ));
            for( int t = 0 ; !(t == q) ; t = (t+1) ) {
                double rr = ((r[((j*q)+t)]/xn)/yn[t]);
                r[ ((j*q)+t) ] = rr   ;
                f[ ((j*q)+t) ] = (((rr*rr)/(1.0-(rr*rr)))*dof)   ;
                ;
            }  ;
            ;
        }
    }  ;
    return 0 ;
}


inline int
f_classif( scm2cpp::cspan<double> x,  scm2cpp::cspan<int> lab,  scm2cpp::span<double> f,  int  n,  int  p,  int  k )
{   std::vector<double> oh((n*k),0.0);
    std::vector<double> cs((k*p),0.0);
    std::vector<double> cnt(k,0.0);
    std::vector<double> ss(p,0.0);
    std::vector<double> tot(p,0.0);
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        int c = lab[i];
        oh[ ((i*k)+c) ] = 1.0   ;
        cnt[ c ] = (cnt[c]+1.0)   ;
        ;
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                double v = x[((i*p)+j)];
                ss[ j ] = (ss[j]+(v*v))   ;
                ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                double v = x[((i*p)+j)];
                ss[ j ] = (ss[j]+(v*v))   ;
                ;
            }
        }  ;
    }  ;
    if( (k*p) > 65536 ) {
        #pragma omp parallel for
        for( int i2671 = 0 ; i2671 < k ; i2671 = (i2671+1) ) {
            for( int i2672 = 0 ; !(i2672 == p) ; i2672 = (i2672+1) ) {
                cs[ ((i2671*p)+i2672) ] = 0.0   ;
            }  ;
        }
    } else {
        for( int i2671 = 0 ; i2671 < k ; i2671 = (i2671+1) ) {
            for( int i2672 = 0 ; !(i2672 == p) ; i2672 = (i2672+1) ) {
                cs[ ((i2671*p)+i2672) ] = 0.0   ;
            }  ;
        }
    }  ;
    for( int k2669 = 0 ; !(k2669 == n) ; k2669 = (k2669+1) ) {
        if( (k*p) > 65536 ) {
            #pragma omp parallel for
            for( int k2670 = 0 ; k2670 < k ; k2670 = (k2670+1) ) {
                for( int k2673 = 0 ; !(k2673 == p) ; k2673 = (k2673+1) ) {
                    cs[ ((k2670*p)+k2673) ] = (cs[((k2670*p)+k2673)]+(x[((k2669*p)+k2673)]*oh[((k2669*k)+k2670)]))   ;
                }  ;
            }
        } else {
            for( int k2670 = 0 ; k2670 < k ; k2670 = (k2670+1) ) {
                for( int k2673 = 0 ; !(k2673 == p) ; k2673 = (k2673+1) ) {
                    cs[ ((k2670*p)+k2673) ] = (cs[((k2670*p)+k2673)]+(x[((k2669*p)+k2673)]*oh[((k2669*k)+k2670)]))   ;
                }  ;
            }
        }  ;
    }  ;
    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                tot[ j ] = (tot[j]+cs[((c*p)+j)])   ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                tot[ j ] = (tot[j]+cs[((c*p)+j)])   ;
            }
        }  ;
    }  ;
    if( (p*k) > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double sq = ((tot[j]*tot[j])/double(n));
            double ssbn = 0.0;
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                ssbn = (ssbn+((cs[((c*p)+j)]*cs[((c*p)+j)])/cnt[c]))  ;
            }  ;
            ssbn = (ssbn-sq)  ;
            double sswn = ((ss[j]-sq)-ssbn);
            f[ j ] = ((ssbn/double((k-1)))/(sswn/double((n-k))))   ;
            ;
            ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            double sq = ((tot[j]*tot[j])/double(n));
            double ssbn = 0.0;
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                ssbn = (ssbn+((cs[((c*p)+j)]*cs[((c*p)+j)])/cnt[c]))  ;
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
min_pos( scm2cpp::cspan<double> v,  int  m )
{   double r = 1.7976931348623157e+308;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
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


SCM2CPP_FN inline int
cholesky_delete( scm2cpp::span<double> l,  int  go,  int  n,  int  k )
{   for( int i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        for( int j = 0 ; !(j == (i+2)) ; j = (j+1) ) {
            l[ ((i*k)+j) ] = l[(((i+1)*k)+j)]   ;
        }  ;
    }  ;
    for( int i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        double a = l[((i*k)+i)];
        double b = l[((i*k)+(i+1))];
        double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
        double ab = ( ( b < 0.0 ) ? ((0.0-b)) : (b) );
        double roe = ( ( aa > ab ) ? (a) : (b) );
        double scale = (aa+ab);
        double r = ( ( scale == 0.0 ) ? (0.0) : ((( ( roe < 0.0 ) ? (-1.0) : (1.0) )*(scale*sqrt((((a/scale)*(a/scale))+((b/scale)*(b/scale))))))) );
        double c = ( ( scale == 0.0 ) ? (1.0) : ((a/r)) );
        double s = ( ( scale == 0.0 ) ? (0.0) : ((b/r)) );
        double cc = ( ( r < 0.0 ) ? ((0.0-c)) : (c) );
        double ss = ( ( r < 0.0 ) ? ((0.0-s)) : (s) );
        l[ ((i*k)+i) ] = ( ( r < 0.0 ) ? ((0.0-r)) : (r) )   ;
        l[ ((i*k)+(i+1)) ] = 0.0   ;
        for( int t = (i+1) ; !(t >= n) ; t = (t+1) ) {
            double x = l[((t*k)+i)];
            double y = l[((t*k)+(i+1))];
            l[ ((t*k)+i) ] = ((cc*x)+(ss*y))   ;
            l[ ((t*k)+(i+1)) ] = ((cc*y)-(ss*x))   ;
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


SCM2CPP_FN inline int
swap_rc( scm2cpp::span<double> g,  int  a,  int  b,  int  p )
{   for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double rv = g[((a*p)+j)];
        g[ ((a*p)+j) ] = g[((b*p)+j)]   ;
        g[ ((b*p)+j) ] = rv   ;
        ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double cv = g[((j*p)+a)];
        g[ ((j*p)+a) ] = g[((j*p)+b)]   ;
        g[ ((j*p)+b) ] = cv   ;
        ;
    }  ;
    return 0 ;
}


inline int
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  int  rec,  double  nsamples,  double  alphamin,  int  method,  int  maxiter,  double  eps,  int  p )
{   std::vector<double> g0((p*p),0.0);
    std::vector<double> cov0(p,0.0);
    std::vector<double> cbuf(p,0.0);
    std::vector<int> index(p,0);
    std::vector<int> active(p,0);
    std::vector<double> sign(p,0.0);
    int kmax = ( ( maxiter < p ) ? (maxiter) : (p) );
    std::vector<double> prev(p,0.0);
    std::vector<double> dir(p,0.0);
    std::vector<double> ls(p,0.0);
    std::vector<double> zz(p,0.0);
    std::vector<double> ratio(p,0.0);
    std::vector<int> idx(p,0);
    std::vector<int> dropv(p,0);
    int cs = 0;
    int na = 0;
    int niter = 0;
    int drop = 0;
    int done = 0;
    double alpha = 0.0;
    double prevalpha = 0.0;
    double tiny32 = 1.1754943508222875e-38;
    double eqtol = 1.1920928955078125e-7;
    std::vector<double> l((kmax*kmax),0.0);
    if( (p*p) > 65536 ) {
        #pragma omp parallel for
        for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
            g0[ t ] = g[t]   ;
        }
    } else {
        for( int t = 0 ; t < (p*p) ; t = (t+1) ) {
            g0[ t ] = g[t]   ;
        }
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
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
        for( int j = 0 ; j < p ; j = (j+1) ) {
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
        int clen = (p-cs);
        int cidx = 0;
        double cval = 0.0;
        double cabs = 0.0;
        for( int t = 0 ; !(t == clen) ; t = (t+1) ) {
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
                        #pragma omp parallel for
                        for( int j = 0 ; j < p ; j = (j+1) ) {
                            coef[ j ] = (prev[j]+(ss*(coef[j]-prev[j])))   ;
                        }
                    } else {
                        for( int j = 0 ; j < p ; j = (j+1) ) {
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
                        #pragma omp parallel for
                        for( int j = 0 ; j < p ; j = (j+1) ) {
                            path[ ((niter*p)+j) ] = coef[j]   ;
                        }
                    } else {
                        for( int j = 0 ; j < p ; j = (j+1) ) {
                            path[ ((niter*p)+j) ] = coef[j]   ;
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
                int degenerate = 0;
                if( drop == 0 ) {
                    int m = na;
                    int nn = (cidx+na);
                    sign[ na ] = ( ( cval > 0.0 ) ? (1.0) : (( ( cval < 0.0 ) ? (-1.0) : (0.0) )) )   ;
                    double tc = cbuf[(cs+cidx)];
                    cbuf[ (cs+cidx) ] = cbuf[cs]   ;
                    cbuf[ cs ] = tc   ;
                    ;
                    int ti = index[nn];
                    index[ nn ] = index[m]   ;
                    index[ m ] = ti   ;
                    ;
                    cs = (cs+1)  ;
                    swap_rc(g,m,nn,p)  ;
                    double c = g[((na*p)+na)];
                    double v = 0.0;
                    for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                        double t = g[((na*p)+i)];
                        for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                            t = (t-(l[((i*kmax)+s)]*l[((na*kmax)+s)]))  ;
                        }  ;
                        double li = (t/l[((i*kmax)+i)]);
                        l[ ((na*kmax)+i) ] = li   ;
                        v = (v+(li*li))  ;
                        ;
                        ;
                    }  ;
                    double dd = sqrt(( ( (c-v) < 0.0 ) ? ((v-c)) : ((c-v)) ));
                    double dg = ( ( dd > (1.0*eps) ) ? (dd) : ((1.0*eps)) );
                    l[ ((na*kmax)+na) ] = dg   ;
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
                        int clen2 = (p-cs);
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            double t = sign[i];
                            for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                                t = (t-(l[((i*kmax)+s)]*zz[s]))  ;
                            }  ;
                            zz[ i ] = (t/l[((i*kmax)+i)])   ;
                            ;
                        }  ;
                        for( int ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                            int i = ((na-1)-ii);
                            double t = zz[i];
                            for( int s = (i+1) ; !(s >= na) ; s = (s+1) ) {
                                t = (t-(l[((s*kmax)+i)]*ls[s]))  ;
                            }  ;
                            ls[ i ] = (t/l[((i*kmax)+i)])   ;
                            ;
                            ;
                        }  ;
                        if( (na == 1 && ls[0] == 0.0) ) {
                            ls[ 0 ] = 1.0   ;
                            aa = 1.0  ;
                        } else {
                            double sm = 0.0;
                            if( na > 65536 ) {
                                #pragma omp parallel for reduction(+:sm)
                                for( int i = 0 ; i < na ; i = (i+1) ) {
                                    sm = (sm+(ls[i]*sign[i]))  ;
                                }
                            } else {
                                for( int i = 0 ; i < na ; i = (i+1) ) {
                                    sm = (sm+(ls[i]*sign[i]))  ;
                                }
                            }  ;
                            aa = (1.0/sqrt(sm))  ;
                            if( na > 65536 ) {
                                #pragma omp parallel for
                                for( int i = 0 ; i < na ; i = (i+1) ) {
                                    ls[ i ] = (aa*ls[i])   ;
                                }
                            } else {
                                for( int i = 0 ; i < na ; i = (i+1) ) {
                                    ls[ i ] = (aa*ls[i])   ;
                                }
                            }  ;
                            ;
                        }  ;
                        if( (clen2*na) > 65536 ) {
                            #pragma omp parallel for
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                double acc = 0.0;
                                for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                    acc = (acc+(g[((i*p)+(na+t))]*ls[i]))  ;
                                }  ;
                                dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                                ;
                            }
                        } else {
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                double acc = 0.0;
                                for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                    acc = (acc+(g[((i*p)+(na+t))]*ls[i]))  ;
                                }  ;
                                dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                                ;
                            }
                        }  ;
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                            }
                        } else {
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                            }
                        }  ;
                        double gfirst = min_pos(ratio,clen2);
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                            }
                        } else {
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                            }
                        }  ;
                        double gsecond = min_pos(ratio,clen2);
                        double gam = ( ( ( ( gfirst < gsecond ) ? (gfirst) : (gsecond) ) < (cabs/aa) ) ? (( ( gfirst < gsecond ) ? (gfirst) : (gsecond) )) : ((cabs/aa)) );
                        int nidx = 0;
                        drop = 0  ;
                        if( na > 65536 ) {
                            #pragma omp parallel for
                            for( int i = 0 ; i < na ; i = (i+1) ) {
                                zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
                            }
                        } else {
                            for( int i = 0 ; i < na ; i = (i+1) ) {
                                zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
                            }
                        }  ;
                        double zpos = min_pos(zz,na);
                        if( zpos < gam ) {
                            for( int ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                                int i = ((na-1)-ii);
                                if( zz[i] == zpos ) {
                                    idx[ nidx ] = i   ;
                                    nidx = (nidx+1)  ;
                                } else {
                                    0  ;
                                }  ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int i = idx[r];
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
                            #pragma omp parallel for
                            for( int j = 0 ; j < p ; j = (j+1) ) {
                                prev[ j ] = coef[j]   ;
                                coef[ j ] = 0.0   ;
                            }
                        } else {
                            for( int j = 0 ; j < p ; j = (j+1) ) {
                                prev[ j ] = coef[j]   ;
                                coef[ j ] = 0.0   ;
                            }
                        }  ;
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            int a = active[i];
                            coef[ a ] = (prev[a]+(gam*ls[i]))   ;
                            ;
                        }  ;
                        if( rec == 1 ) {
                            if( p > 65536 ) {
                                #pragma omp parallel for
                                for( int j = 0 ; j < p ; j = (j+1) ) {
                                    path[ ((niter*p)+j) ] = coef[j]   ;
                                }
                            } else {
                                for( int j = 0 ; j < p ; j = (j+1) ) {
                                    path[ ((niter*p)+j) ] = coef[j]   ;
                                }
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        if( clen2 > 65536 ) {
                            #pragma omp parallel for
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
                            }
                        } else {
                            for( int t = 0 ; t < clen2 ; t = (t+1) ) {
                                cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
                            }
                        }  ;
                        if( (drop == 1 && method == 1) ) {
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                cholesky_delete(l,idx[r],na,kmax)  ;
                            }  ;
                            na = (na-1)  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                int dropped = active[ii];
                                for( int i = ii ; !(i >= na) ; i = (i+1) ) {
                                    active[ i ] = active[(i+1)]   ;
                                }  ;
                                dropv[ r ] = dropped   ;
                                ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                for( int i = ii ; !(i >= na) ; i = (i+1) ) {
                                    int ti = index[i];
                                    index[ i ] = index[(i+1)]   ;
                                    index[ (i+1) ] = ti   ;
                                    ;
                                    swap_rc(g,i,int((i+1)),p)  ;
                                }  ;
                                ;
                            }  ;
                            for( int rr = 0 ; !(rr == nidx) ; rr = (rr+1) ) {
                                int r = ((nidx-1)-rr);
                                int d = dropv[r];
                                double t = cov0[d];
                                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                                    t = (t-(g0[((d*p)+j)]*coef[j]))  ;
                                }  ;
                                cs = (cs-1)  ;
                                cbuf[ cs ] = t   ;
                                ;
                                ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                for( int i = ii ; !(i >= (p-1)) ; i = (i+1) ) {
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


SCM2CPP_FN inline int
rfe_chol( scm2cpp::cspan<double> g,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> l,  double  alpha,  int  k,  int  p )
{   for( int j = 0 ; !(j == k) ; j = (j+1) ) {
        double s = (g[((idx[j]*p)+idx[j])]+alpha);
        for( int m = 0 ; !(m == j) ; m = (m+1) ) {
            s = (s-(l[((j*p)+m)]*l[((j*p)+m)]))  ;
        }  ;
        l[ ((j*p)+j) ] = sqrt(s)   ;
        for( int i = (j+1) ; !(i >= k) ; i = (i+1) ) {
            double t = g[((idx[i]*p)+idx[j])];
            for( int m = 0 ; !(m == j) ; m = (m+1) ) {
                t = (t-(l[((i*p)+m)]*l[((j*p)+m)]))  ;
            }  ;
            l[ ((i*p)+j) ] = (t/l[((j*p)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
rfe_solve( scm2cpp::cspan<double> c,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::cspan<double> l,  int  k,  int  p )
{   for( int i = 0 ; !(i == k) ; i = (i+1) ) {
        double t = c[idx[i]];
        for( int m = 0 ; !(m == i) ; m = (m+1) ) {
            t = (t-(l[((i*p)+m)]*w[m]))  ;
        }  ;
        w[ i ] = (t/l[((i*p)+i)])   ;
        ;
    }  ;
    for( int ii = 0 ; !(ii == k) ; ii = (ii+1) ) {
        int i = ((k-1)-ii);
        double t = w[i];
        for( int m = (i+1) ; !(m >= k) ; m = (m+1) ) {
            t = (t-(l[((m*p)+i)]*w[m]))  ;
        }  ;
        w[ i ] = (t/l[((i*p)+i)])   ;
        ;
        ;
    }  ;
    return 0 ;
}


inline int
rfe( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<int> support,  scm2cpp::span<int> ranking,  double  alpha,  int  nsel,  int  step,  int  n,  int  p )
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
    int rounds = 0;
    int k = p;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        ym = (ym+y[i])  ;
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mx[ j ] = (mx[j]+x[((i*p)+j)])   ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
                mx[ j ] = (mx[j]+x[((i*p)+j)])   ;
            }
        }  ;
    }  ;
    ym = (ym/double(n))  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            mx[ j ] = (mx[j]/double(n))   ;
        }
    }  ;
    if( (n*p) > 65536 ) {
        #pragma omp parallel for
        for( int i = 0 ; i < n ; i = (i+1) ) {
            yc[ i ] = (y[i]-ym)   ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ ((i*p)+j) ] = (x[((i*p)+j)]-mx[j])   ;
            }  ;
        }
    } else {
        for( int i = 0 ; i < n ; i = (i+1) ) {
            yc[ i ] = (y[i]-ym)   ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                xc[ ((i*p)+j) ] = (x[((i*p)+j)]-mx[j])   ;
            }  ;
        }
    }  ;
    for( int k2682 = 0 ; !(k2682 == p) ; k2682 = (k2682+1) ) {
        for( int k2683 = k2682 ; !(k2683 == p) ; k2683 = (k2683+1) ) {
            g[ ((k2682*p)+k2683) ] = ([&]() -> double { int i2685 = 0; double r2686 = 0.0; while (!(i2685 == n)) {
            int i2685_next5601 = (i2685+1);
                double r2686_next5602 = (r2686+(xc[((i2685*p)+k2682)]*xc[((i2685*p)+k2683)]));
                i2685 = i2685_next5601;
                r2686 = r2686_next5602;
            } return r2686; })()   ;
            g[ ((k2683*p)+k2682) ] = g[((k2682*p)+k2683)]   ;
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int i2690 = 0 ; i2690 < p ; i2690 = (i2690+1) ) {
            c[ i2690 ] = 0.0   ;
        }
    } else {
        for( int i2690 = 0 ; i2690 < p ; i2690 = (i2690+1) ) {
            c[ i2690 ] = 0.0   ;
        }
    }  ;
    for( int k2688 = 0 ; !(k2688 == n) ; k2688 = (k2688+1) ) {
        if( p > 65536 ) {
            #pragma omp parallel for
            for( int i2691 = 0 ; i2691 < p ; i2691 = (i2691+1) ) {
                c[ i2691 ] = (c[i2691]+(xc[((k2688*p)+i2691)]*yc[k2688]))   ;
            }
        } else {
            for( int i2691 = 0 ; i2691 < p ; i2691 = (i2691+1) ) {
                c[ i2691 ] = (c[i2691]+(xc[((k2688*p)+i2691)]*yc[k2688]))   ;
            }
        }  ;
    }  ;
    if( p > 65536 ) {
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            support[ j ] = 1   ;
            ranking[ j ] = 1   ;
            idx[ j ] = j   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            support[ j ] = 1   ;
            ranking[ j ] = 1   ;
            idx[ j ] = j   ;
        }
    }  ;
    rfe_chol(g,idx,l,alpha,p,p)  ;
    for(  ; !(k <= nsel) ;  ) {
        rfe_solve(c,idx,w,l,k,p)  ;
        for( int i = 0 ; !(i == k) ; i = (i+1) ) {
            double key = (w[i]*w[i]);
            int jj = (i-1);
            for(  ; !((jj < 0 || (w[ord[jj]]*w[ord[jj]]) <= key)) ;  ) {
                ord[ (jj+1) ] = ord[jj]   ;
                jj = (jj-1)  ;
            }  ;
            ord[ (jj+1) ] = i   ;
            ;
        }  ;
        int thr = ( ( step < (k-nsel) ) ? (step) : ((k-nsel)) );
        for( int r = 0 ; !(r == thr) ; r = (r+1) ) {
            support[ idx[ord[r]] ] = 0   ;
        }  ;
        if( k > 65536 ) {
            #pragma omp parallel for
            for( int t = 0 ; t < k ; t = (t+1) ) {
                gone[ t ] = 0   ;
            }
        } else {
            for( int t = 0 ; t < k ; t = (t+1) ) {
                gone[ t ] = 0   ;
            }
        }  ;
        for( int r = 0 ; !(r == thr) ; r = (r+1) ) {
            gone[ ord[r] ] = 1   ;
        }  ;
        int cur = k;
        for( int tt = 0 ; !(tt == k) ; tt = (tt+1) ) {
            int pos = ((k-1)-tt);
            if( gone[pos] == 1 ) {
                cholesky_delete(l,pos,cur,p)  ;
                for( int u = pos ; !(u >= (cur-1)) ; u = (u+1) ) {
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
            #pragma omp parallel for
            for( int j = 0 ; j < p ; j = (j+1) ) {
                if( support[j] == 0 ) {
                    ranking[ j ] = (ranking[j]+1)   ;
                } else {
                    0  ;
                }  ;
            }
        } else {
            for( int j = 0 ; j < p ; j = (j+1) ) {
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
        #pragma omp parallel for
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    } else {
        for( int j = 0 ; j < p ; j = (j+1) ) {
            coef[ j ] = 0.0   ;
        }
    }  ;
    rfe_solve(c,idx,w,l,k,p)  ;
    for( int i = 0 ; !(i == k) ; i = (i+1) ) {
        coef[ idx[i] ] = w[i]   ;
    }  ;
    return rounds ;
}


SCM2CPP_FN inline int
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  int  n,  int  p )
{   for( int k2693 = 0 ; !(k2693 == p) ; k2693 = (k2693+1) ) {
        for( int k2694 = k2693 ; !(k2694 == p) ; k2694 = (k2694+1) ) {
            g[ ((k2693*p)+k2694) ] = ([&]() -> double { int i2696 = 0; double r2697 = 0.0; while (!(i2696 == n)) {
            int i2696_next5603 = (i2696+1);
                double r2697_next5604 = (r2697+(x[((i2696*p)+k2693)]*x[((i2696*p)+k2694)]));
                i2696 = i2696_next5603;
                r2697 = r2697_next5604;
            } return r2697; })()   ;
            g[ ((k2694*p)+k2693) ] = g[((k2693*p)+k2694)]   ;
        }  ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  int  n,  int  p,  int  q )
{   if( (p*q) > 65536 ) {
        #pragma omp parallel for
        for( int i2702 = 0 ; i2702 < p ; i2702 = (i2702+1) ) {
            for( int i2703 = 0 ; !(i2703 == q) ; i2703 = (i2703+1) ) {
                c[ ((i2702*q)+i2703) ] = 0.0   ;
            }  ;
        }
    } else {
        for( int i2702 = 0 ; i2702 < p ; i2702 = (i2702+1) ) {
            for( int i2703 = 0 ; !(i2703 == q) ; i2703 = (i2703+1) ) {
                c[ ((i2702*q)+i2703) ] = 0.0   ;
            }  ;
        }
    }  ;
    for( int k2700 = 0 ; !(k2700 == n) ; k2700 = (k2700+1) ) {
        if( (p*q) > 65536 ) {
            #pragma omp parallel for
            for( int k2701 = 0 ; k2701 < p ; k2701 = (k2701+1) ) {
                for( int k2704 = 0 ; !(k2704 == q) ; k2704 = (k2704+1) ) {
                    c[ ((k2701*q)+k2704) ] = (c[((k2701*q)+k2704)]+(y[((k2700*q)+k2704)]*x[((k2700*p)+k2701)]))   ;
                }  ;
            }
        } else {
            for( int k2701 = 0 ; k2701 < p ; k2701 = (k2701+1) ) {
                for( int k2704 = 0 ; !(k2704 == q) ; k2704 = (k2704+1) ) {
                    c[ ((k2701*q)+k2704) ] = (c[((k2701*q)+k2704)]+(y[((k2700*q)+k2704)]*x[((k2700*p)+k2701)]))   ;
                }  ;
            }
        }  ;
    }  ;
    return 0 ;
}
#endif // GRAMOPS_HPP
