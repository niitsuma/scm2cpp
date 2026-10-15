
#ifndef GRAMOPS_HPP
#define GRAMOPS_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-blas.hpp"
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
    scm2cpp::blas_gemv(qw, qm, w, 1.0, 0.0, 0, m, m)  ;
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
            scm2cpp::blas_gemv(bnew, sub, b, 1.0, 0.0, 0, m, m)  ;
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
    scm2cpp::blas_syrk(g, x, 1.0, 0.0, 1, p, n)  ;
    scm2cpp::blas_gemv(xy, x, y, 1.0, 0.0, 1, p, n)  ;
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
#endif // GRAMOPS_HPP
