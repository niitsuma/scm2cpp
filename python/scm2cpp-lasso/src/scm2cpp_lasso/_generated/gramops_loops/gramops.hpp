
#ifndef GRAMOPS_HPP
#define GRAMOPS_HPP
#define SCM2CPP_MINIMAL
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
omp( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  int  kmax,  int  n,  int  p );
SCM2CPP_FN double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  int  multi,  int  fitint,  int  n,  int  p,  int  k );
int
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  int  maxiter,  double  tol,  int  multi,  int  fitint,  int  n,  int  p,  int  k );
SCM2CPP_FN double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  int  fitint,  int  n,  int  p );
int
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p );
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
lbfgs( int  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,3> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  int  m,  int  maxiter,  double  pgtol,  double  ftol,  int  maxls,  int  ib,  double  lbv,  int  nv,  int  n,  int  p,  int  k );
SCM2CPP_FN double
lbfgs_fg( int  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,3> & aux,  scm2cpp::span<double> work,  int  n,  int  p,  int  k );



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
    struct let24288 {
        let24288() {}
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
    double radius = (sqrt((2.0*let24288()(out[0])))/alpha);
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
                    for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                        qw[ r ] = (qw[r]-(wj*qm[((j*m)+r)]))   ;
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
    for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        ynorm2 = (ynorm2+(q[j]*q[j]))  ;
        excl[ j ] = 0   ;
    }  ;
    for( int k2493 = 0 ; !(k2493 == m) ; k2493 = (k2493+1) ) {
        qw[ k2493 ] = ([&]() -> double { int i2496 = 0; double r2497 = 0.0; while (!(i2496 == m)) {
        int i2496_next24316 = (i2496+1);
            double r2497_next24317 = (r2497+(qm[((k2493*m)+i2496)]*w[i2496]));
            i2496 = i2496_next24316;
            r2497 = r2497_next24317;
        } return r2497; })()   ;
    }  ;
    double gtol = (tol*ynorm2);
    enet_gap(w,q,qw,xta,out,alpha,ynorm2,m)  ;
    if( (out[0] >= 0.0 && out[0] <= gtol) ) {
        done = 1  ;
    } else {
        for( int j = 0 ; !(j == m) ; j = (j+1) ) {
            if( qm[((j*m)+j)] == 0.0 ) {
                w[ j ] = 0.0   ;
                excl[ j ] = 1   ;
            } else {
                0  ;
            }  ;
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
                    for( int r = 0 ; !(r == m) ; r = (r+1) ) {
                        qw[ r ] = (qw[r]+((wn-wj)*qm[((j*m)+r)]))   ;
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
    for( int i = 0 ; !(i == p) ; i = (i+1) ) {
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            cov[ ((i*p)+j) ] = ( ( i == j ) ? (emp[((i*p)+j)]) : ((0.95*emp[((i*p)+j)])) )   ;
        }  ;
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
                for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                    for( int t = 0 ; !(t == m) ; t = (t+1) ) {
                        sub[ ((s*m)+t) ] = cov[(((s+1)*p)+(t+1))]   ;
                    }  ;
                }  ;
            }  ;
            double pii = prec[((idx*p)+idx)];
            for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                int o = ( ( s < idx ) ? (s) : ((s+1)) );
                row[ s ] = emp[((idx*p)+o)]   ;
                b[ s ] = (0.0-(prec[((o*p)+idx)]/(pii+(1000.0*2.220446049250313e-16))))   ;
                ;
            }  ;
            ;
            enet_gram(b,sub,row,qw,xta,active,excl,out,alpha,innermax,enettol,m)  ;
            double acc = 0.0;
            for( int s = 0 ; !(s == m) ; s = (s+1) ) {
                int o = ( ( s < idx ) ? (s) : ((s+1)) );
                acc = (acc+(cov[((o*p)+idx)]*b[s]))  ;
                ;
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
            for( int k2500 = 0 ; !(k2500 == m) ; k2500 = (k2500+1) ) {
                bnew[ k2500 ] = ([&]() -> double { int i2503 = 0; double r2504 = 0.0; while (!(i2503 == m)) {
                int i2503_next24318 = (i2503+1);
                    double r2504_next24319 = (r2504+(sub[((k2500*m)+i2503)]*b[i2503]));
                    i2503 = i2503_next24318;
                    r2504 = r2504_next24319;
                } return r2504; })()   ;
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
        for( int i = 0 ; !(i == p) ; i = (i+1) ) {
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
omp( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  int  kmax,  int  n,  int  p )
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
            int i2510_next24320 = (i2510+1);
                double r2511_next24321 = (r2511+(x[((i2510*p)+k2507)]*x[((i2510*p)+k2508)]));
                i2510 = i2510_next24320;
                r2511 = r2511_next24321;
            } return r2511; })()   ;
            g[ ((k2508*p)+k2507) ] = g[((k2507*p)+k2508)]   ;
        }  ;
    }  ;
    for( int i2515 = 0 ; !(i2515 == p) ; i2515 = (i2515+1) ) {
        xy[ i2515 ] = 0.0   ;
    }  ;
    for( int k2513 = 0 ; !(k2513 == n) ; k2513 = (k2513+1) ) {
        for( int i2516 = 0 ; !(i2516 == p) ; i2516 = (i2516+1) ) {
            xy[ i2516 ] = (xy[i2516]+(x[((k2513*p)+i2516)]*y[k2513]))   ;
        }  ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        index[ j ] = j   ;
        alpha[ j ] = xy[j]   ;
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
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double acc = 0.0;
                    for( int s = 0 ; !(s == na) ; s = (s+1) ) {
                        acc = (acc+(g[((j*p)+s)]*gamma[s]))  ;
                    }  ;
                    beta[ j ] = acc   ;
                    alpha[ j ] = (xy[j]-acc)   ;
                    ;
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
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        coef[ j ] = 0.0   ;
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
    for( int k2518 = 0 ; !(k2518 == n) ; k2518 = (k2518+1) ) {
        for( int k2519 = 0 ; !(k2519 == k) ; k2519 = (k2519+1) ) {
            z[ ((k2518*k)+k2519) ] = ([&]() -> double { int i2521 = 0; double r2522 = 0.0; while (!(i2521 == p)) {
            int i2521_next24322 = (i2521+1);
                double r2522_next24323 = (r2522+(x[((k2518*p)+i2521)]*coef[((k2519*p)+i2521)]));
                i2521 = i2521_next24322;
                r2522 = r2522_next24323;
            } return r2522; })()   ;
        }  ;
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        for( int c = 0 ; !(c == k) ; c = (c+1) ) {
            z[ ((i*k)+c) ] = (z[((i*k)+c)]+coef[((k*p)+c)])   ;
        }  ;
    }  ;
    if( multi == 0 ) {
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
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
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                double ec = exp((z[((i*k)+c)]-zmax));
                z[ ((i*k)+c) ] = ec   ;
                se = (se+ec)  ;
                ;
            }  ;
            loss = (loss+(zmax+log(se)))  ;
            for( int c = 0 ; !(c == k) ; c = (c+1) ) {
                z[ ((i*k)+c) ] = (z[((i*k)+c)]/se)   ;
            }  ;
            int iy = ((i*k)+int(yc));
            z[ iy ] = (z[iy]-1.0)   ;
            ;
            ;
        }  ;
    }  ;
    for( int i2526 = 0 ; !(i2526 == k) ; i2526 = (i2526+1) ) {
        for( int i2527 = 0 ; !(i2527 == p) ; i2527 = (i2527+1) ) {
            g[ ((i2526*p)+i2527) ] = 0.0   ;
        }  ;
    }  ;
    for( int k2524 = 0 ; !(k2524 == n) ; k2524 = (k2524+1) ) {
        for( int k2525 = 0 ; !(k2525 == k) ; k2525 = (k2525+1) ) {
            for( int k2528 = 0 ; !(k2528 == p) ; k2528 = (k2528+1) ) {
                g[ ((k2525*p)+k2528) ] = (g[((k2525*p)+k2528)]+(x[((k2524*p)+k2528)]*z[((k2524*k)+k2525)]))   ;
            }  ;
        }  ;
    }  ;
    for( int t = 0 ; !(t == (k*p)) ; t = (t+1) ) {
        double wt = coef[t];
        pen = (pen+(wt*wt))  ;
        g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
        ;
    }  ;
    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
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
    }  ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}


inline int
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  int  maxiter,  double  tol,  int  multi,  int  fitint,  int  n,  int  p,  int  k )
{   std::array<double,3> aux = scm2cpp::filled_array<double,3>(0.0);
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
    for( int k2531 = 0 ; !(k2531 == n) ; k2531 = (k2531+1) ) {
        z[ k2531 ] = ([&]() -> double { int i2534 = 0; double r2535 = 0.0; while (!(i2534 == p)) {
        int i2534_next24324 = (i2534+1);
            double r2535_next24325 = (r2535+(x[((k2531*p)+i2534)]*coef[i2534]));
            i2534 = i2534_next24324;
            r2535 = r2535_next24325;
        } return r2535; })()   ;
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
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
    }  ;
    for( int i2539 = 0 ; !(i2539 == p) ; i2539 = (i2539+1) ) {
        g[ i2539 ] = 0.0   ;
    }  ;
    for( int k2537 = 0 ; !(k2537 == n) ; k2537 = (k2537+1) ) {
        for( int i2540 = 0 ; !(i2540 == p) ; i2540 = (i2540+1) ) {
            g[ i2540 ] = (g[i2540]+(x[((k2537*p)+i2540)]*z[k2537]))   ;
        }  ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double wj = coef[j];
        ww = (ww+(wj*wj))  ;
        g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
        ;
    }  ;
    g[ p ] = ( ( fitint == 1 ) ? (csum) : (0.0) )   ;
    double sqloss = (sq/sigma);
    double eps2 = (epsilon*epsilon);
    g[ (p+1) ] = ((double(n)-(double(nout)*eps2))-(sqloss/sigma))   ;
    return ((((double(n)*sigma)+sqloss)+((2.0*(epsilon*outsum))-(sigma*(double(nout)*eps2))))+(alpha*ww)) ;
}


inline int
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  int  maxiter,  double  tol,  int  fitint,  int  n,  int  p )
{   std::array<double,3> aux = scm2cpp::filled_array<double,3>(0.0);
    std::vector<double> work(n,0.0);
    aux[ 0 ] = epsilon   ;
    aux[ 1 ] = alpha   ;
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    return lbfgs(1,coef,x,y,aux,work,out,10,maxiter,tol,(10000000.0*2.220446049250313e-16),20,(p+1),(10.0*2.220446049250313e-16),(p+2),n,p,1) ;
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
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        acc = (acc+(a[j]*b[j]))  ;
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_row( scm2cpp::cspan<double> mem,  int  slot,  scm2cpp::cspan<double> v,  int  nv )
{   double acc = 0.0;
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        acc = (acc+(mem[((slot*nv)+j)]*v[j]))  ;
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_dot_rows( scm2cpp::cspan<double> a,  int  ra,  scm2cpp::cspan<double> b,  int  rb,  int  nv )
{   double acc = 0.0;
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        acc = (acc+(a[((ra*nv)+j)]*b[((rb*nv)+j)]))  ;
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
        for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
            q[ j ] = (q[j]-(a*ymem[((slot*nv)+j)]))   ;
        }  ;
        ;
        ;
    }  ;
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        q[ j ] = (q[j]/theta)   ;
    }  ;
    for( int ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        int slot2 = ((head+ii) % m);
        double bb = (rho[slot2]*lb_dot_row(ymem,slot2,q,nv));
        for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
            q[ j ] = (q[j]+((al[slot2]-bb)*smem[((slot2*nv)+j)]))   ;
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
        for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
            bm[ ((ii*nv)+j) ] = (theta*smem[((si*nv)+j)])   ;
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
{   for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        q[ j ] = g[j]   ;
    }  ;
    lb_hv(q,smem,ymem,rho,al,theta,col,head,m,nv)  ;
    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
        d[ j ] = (0.0-q[j])   ;
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
            for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                e[ j ] = 0.0   ;
            }  ;
            e[ ib ] = 1.0   ;
            lb_hv(e,smem,ymem,rho,al,theta,col,head,m,nv)  ;
            double lam = ((delta+q[ib])/e[ib]);
            for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                d[ j ] = (d[j]+(lam*e[j]))   ;
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
                    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                        double xcpj = ((0.0-dtm)*g[j]);
                        d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
                        ;
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
lbfgs( int  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,3> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  int  m,  int  maxiter,  double  pgtol,  double  ftol,  int  maxls,  int  ib,  double  lbv,  int  nv,  int  n,  int  p,  int  k )
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
        for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
            t[ j ] = w[j]   ;
            gold[ j ] = g[j]   ;
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
                    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                        w[ j ] = (t[j]+(stp*d[j]))   ;
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
            for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                w[ j ] = t[j]   ;
                g[ j ] = gold[j]   ;
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
                    for( int j = 0 ; !(j == nv) ; j = (j+1) ) {
                        double yj = (g[j]-gold[j]);
                        smem[ ((slot3*nv)+j) ] = (stp2*d[j])   ;
                        ymem[ ((slot3*nv)+j) ] = yj   ;
                        rr = (rr+(yj*yj))  ;
                        ;
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
lbfgs_fg( int  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,3> & aux,  scm2cpp::span<double> work,  int  n,  int  p,  int  k )
{
    if( kind == 0 ) {
        return logistic_fg(w,g,x,y,work,aux[0],( ( aux[1] == 1.0 ) ? (1) : (0) ),( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p,k) ;
    }
    else {
        return huber_fg(w,g,x,y,work,aux[0],aux[1],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
    }
}
#endif // GRAMOPS_HPP
