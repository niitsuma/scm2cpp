
#ifndef ACCEL_HPP
#define ACCEL_HPP
#define SCM2CPP_MINIMAL
#include	<cmath>
#include	"scm2cpp-cublas.hpp"
#include	<math.h>
#include	<vector>
#include	"scm2cpp.hpp"

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
SCM2CPP_FN double
eig_hypot( double  a,  double  b );
SCM2CPP_FN int
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m );
SCM2CPP_FN double
eig_abs( double  a );
SCM2CPP_FN int
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  int  m );
int
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m,  int  k );
SCM2CPP_FN int
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m );
int
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  int  n,  int  p );
SCM2CPP_FN int
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  int  n,  int  p );
SCM2CPP_FN int
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  int  n,  int  p,  int  q );



inline int
f_regression( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> r,  scm2cpp::span<double> f,  int  center,  int  n,  int  p,  int  q )
{   std::vector<double> mx(p,0.0);
    std::vector<double> sx(p,0.0);
    std::vector<double> yc((n*q),0.0);
    std::vector<double> yn(q,0.0);
    double dof = double((n-( ( center == 1 ) ? (2) : (1) )));
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            double v = x[((i*p)+j)];
            mx[ j ] = (mx[j]+v)   ;
            sx[ j ] = (sx[j]+(v*v))   ;
            ;
        }  ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        mx[ j ] = (mx[j]/double(n))   ;
    }  ;
    for( int t = 0 ; !(t == q) ; t = (t+1) ) {
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
    }  ;
    scm2cpp::device_matrix d6085 = scm2cpp::dmat_upload(x, (n*p), 1);
    scm2cpp::device_matrix d6086 = scm2cpp::dmat_upload(yc, (n*q), 1);
    scm2cpp::blas_gemm(r, d6085, d6086, 1.0, 0.0, 1, 0, p, q, n)  ;
    ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double xn = sqrt(( ( center == 1 ) ? ((sx[j]-(double(n)*(mx[j]*mx[j])))) : (sx[j]) ));
        for( int t = 0 ; !(t == q) ; t = (t+1) ) {
            double rr = ((r[((j*q)+t)]/xn)/yn[t]);
            r[ ((j*q)+t) ] = rr   ;
            f[ ((j*q)+t) ] = (((rr*rr)/(1.0-(rr*rr)))*dof)   ;
            ;
        }  ;
        ;
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
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            double v = x[((i*p)+j)];
            ss[ j ] = (ss[j]+(v*v))   ;
            ;
        }  ;
    }  ;
    scm2cpp::device_matrix d6087 = scm2cpp::dmat_upload(oh, (n*k), 1);
    scm2cpp::device_matrix d6088 = scm2cpp::dmat_upload(x, (n*p), 1);
    scm2cpp::blas_gemm(cs, d6087, d6088, 1.0, 0.0, 1, 0, k, p, n)  ;
    ;
    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            tot[ j ] = (tot[j]+cs[((c*p)+j)])   ;
        }  ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
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
    for( int t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
        g0[ t ] = g[t]   ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        cov0[ j ] = cov[j]   ;
        cbuf[ j ] = cov[j]   ;
        index[ j ] = j   ;
        coef[ j ] = 0.0   ;
        if( rec == 1 ) {
            path[ j ] = 0.0   ;
        } else {
            0  ;
        }  ;
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
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        coef[ j ] = (prev[j]+(ss*(coef[j]-prev[j])))   ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
                alpha = alphamin  ;
                if( rec == 1 ) {
                    alphas[ niter ] = alphamin   ;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        path[ ((niter*p)+j) ] = coef[j]   ;
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
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                sm = (sm+(ls[i]*sign[i]))  ;
                            }  ;
                            aa = (1.0/sqrt(sm))  ;
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                ls[ i ] = (aa*ls[i])   ;
                            }  ;
                            ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            double acc = 0.0;
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                acc = (acc+(g[((i*p)+(na+t))]*ls[i]))  ;
                            }  ;
                            dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                            ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                        }  ;
                        double gfirst = min_pos(ratio,clen2);
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                        }  ;
                        double gsecond = min_pos(ratio,clen2);
                        double gam = ( ( ( ( gfirst < gsecond ) ? (gfirst) : (gsecond) ) < (cabs/aa) ) ? (( ( gfirst < gsecond ) ? (gfirst) : (gsecond) )) : ((cabs/aa)) );
                        int nidx = 0;
                        drop = 0  ;
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
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
                        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                            prev[ j ] = coef[j]   ;
                            coef[ j ] = 0.0   ;
                        }  ;
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            int a = active[i];
                            coef[ a ] = (prev[a]+(gam*ls[i]))   ;
                            ;
                        }  ;
                        if( rec == 1 ) {
                            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                                path[ ((niter*p)+j) ] = coef[j]   ;
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
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
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            mx[ j ] = (mx[j]+x[((i*p)+j)])   ;
        }  ;
    }  ;
    ym = (ym/double(n))  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        mx[ j ] = (mx[j]/double(n))   ;
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        yc[ i ] = (y[i]-ym)   ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            xc[ ((i*p)+j) ] = (x[((i*p)+j)]-mx[j])   ;
        }  ;
    }  ;
    scm2cpp::device_matrix d6089 = scm2cpp::dmat_upload(xc, (n*p), 1);
    scm2cpp::blas_syrk(g, d6089, 1.0, 0.0, 1, p, n)  ;
    ;
    scm2cpp::device_matrix d6090 = scm2cpp::dmat_upload(xc, (n*p), 1);
    scm2cpp::blas_gemv(c, d6090, yc, 1.0, 0.0, 1, p, n)  ;
    ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        support[ j ] = 1   ;
        ranking[ j ] = 1   ;
        idx[ j ] = j   ;
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
        for( int t = 0 ; !(t == k) ; t = (t+1) ) {
            gone[ t ] = 0   ;
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
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            if( support[j] == 0 ) {
                ranking[ j ] = (ranking[j]+1)   ;
            } else {
                0  ;
            }  ;
        }  ;
        k = (k-thr)  ;
        rounds = (rounds+1)  ;
        ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        coef[ j ] = 0.0   ;
    }  ;
    rfe_solve(c,idx,w,l,k,p)  ;
    for( int i = 0 ; !(i == k) ; i = (i+1) ) {
        coef[ idx[i] ] = w[i]   ;
    }  ;
    return rounds ;
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
            for( int k = 0 ; !(k > l) ; k = (k+1) ) {
                double ak = a[((i*m)+k)];
                scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                ;
            }  ;
            if( scale == 0.0 ) {
                e[ i ] = a[((i*m)+l)]   ;
            } else {
                for( int k = 0 ; !(k > l) ; k = (k+1) ) {
                    a[ ((i*m)+k) ] = (a[((i*m)+k)]/scale)   ;
                    h = (h+(a[((i*m)+k)]*a[((i*m)+k)]))  ;
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
                    for( int k = 0 ; !(k > j) ; k = (k+1) ) {
                        gg = (gg+(a[((j*m)+k)]*a[((i*m)+k)]))  ;
                    }  ;
                    for( int k = (j+1) ; !(k > l) ; k = (k+1) ) {
                        gg = (gg+(a[((k*m)+j)]*a[((i*m)+k)]))  ;
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
                for( int k = 0 ; !(k == i) ; k = (k+1) ) {
                    g3 = (g3+(a[((i*m)+k)]*a[((k*m)+j)]))  ;
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
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        for( int j = 0 ; !(j == m) ; j = (j+1) ) {
            v[ ((j*m)+i) ] = a[((i*m)+j)]   ;
        }  ;
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
{   for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        ord[ j ] = j   ;
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


inline int
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m,  int  k )
{   std::vector<double> vf((m*m),0.0);
    std::vector<double> evf(m,0.0);
    std::vector<int> ord(m,0);
    sym_eigen(a,vf,evf,e,m)  ;
    eig_order(evf,ord,m)  ;
    for( int c = 0 ; !(c == k) ; c = (c+1) ) {
        int col = ord[c];
        ev[ c ] = evf[col]   ;
        for( int j = 0 ; !(j == m) ; j = (j+1) ) {
            v[ ((j*k)+c) ] = vf[((j*m)+col)]   ;
        }  ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m )
{   for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        double d = b[((j*m)+j)];
        for( int l = 0 ; !(l == j) ; l = (l+1) ) {
            d = (d-(b[((j*m)+l)]*b[((j*m)+l)]))  ;
        }  ;
        b[ ((j*m)+j) ] = sqrt(d)   ;
        for( int i = (j+1) ; !(i >= m) ; i = (i+1) ) {
            double s = b[((i*m)+j)];
            for( int l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(b[((i*m)+l)]*b[((j*m)+l)]))  ;
            }  ;
            b[ ((i*m)+j) ] = (s/b[((j*m)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( int c = 0 ; !(c == m) ; c = (c+1) ) {
        for( int i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[((i*m)+c)];
            for( int l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[((i*m)+l)]*a[((l*m)+c)]))  ;
            }  ;
            a[ ((i*m)+c) ] = (s/b[((i*m)+i)])   ;
            ;
        }  ;
    }  ;
    for( int r = 0 ; !(r == m) ; r = (r+1) ) {
        for( int i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[((r*m)+i)];
            for( int l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[((i*m)+l)]*a[((r*m)+l)]))  ;
            }  ;
            a[ ((r*m)+i) ] = (s/b[((i*m)+i)])   ;
            ;
        }  ;
    }  ;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        for( int j = 0 ; !(j == i) ; j = (j+1) ) {
            double s = (0.5*(a[((i*m)+j)]+a[((j*m)+i)]));
            a[ ((i*m)+j) ] = s   ;
            a[ ((j*m)+i) ] = s   ;
            ;
        }  ;
    }  ;
    sym_eigen(a,v,ev,e,m)  ;
    for( int c = 0 ; !(c == m) ; c = (c+1) ) {
        for( int ii = 0 ; !(ii == m) ; ii = (ii+1) ) {
            int i = ((m-1)-ii);
            double s = v[((i*m)+c)];
            for( int l = (i+1) ; !(l >= m) ; l = (l+1) ) {
                s = (s-(b[((l*m)+i)]*v[((l*m)+c)]))  ;
            }  ;
            v[ ((i*m)+c) ] = (s/b[((i*m)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    return 0 ;
}


inline int
pca( scm2cpp::cspan<double> x,  scm2cpp::span<double> comps,  scm2cpp::span<double> ev,  scm2cpp::span<double> sv,  scm2cpp::span<double> mean,  int  n,  int  p )
{   std::vector<double> c((p*p),0.0);
    std::vector<double> v((p*p),0.0);
    std::vector<double> e(p,0.0);
    std::vector<double> sc(p,0.0);
    std::vector<int> ord(p,0);
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        mean[ j ] = 0.0   ;
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            mean[ j ] = (mean[j]+x[((i*p)+j)])   ;
        }  ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        mean[ j ] = (mean[j]/double(n))   ;
    }  ;
    scm2cpp::device_matrix d6091 = scm2cpp::dmat_upload(x, (n*p), 1);
    scm2cpp::blas_syrk(c, d6091, 1.0, 0.0, 1, p, n)  ;
    ;
    for( int i = 0 ; !(i == p) ; i = (i+1) ) {
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            c[ ((i*p)+j) ] = ((c[((i*p)+j)]-(double(n)*(mean[i]*mean[j])))/double((n-1)))   ;
        }  ;
    }  ;
    sym_eigen(c,v,e,sc,p)  ;
    eig_order(e,ord,p)  ;
    for( int r = 0 ; !(r == p) ; r = (r+1) ) {
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
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
gram_xx( scm2cpp::cspan<double> x,  scm2cpp::span<double> g,  int  n,  int  p )
{   scm2cpp::device_matrix d6092 = scm2cpp::dmat_upload(x, (n*p), 1);
    scm2cpp::blas_syrk(g, d6092, 1.0, 0.0, 1, p, n)  ;
    ;
    return 0 ;
}


SCM2CPP_FN inline int
gram_xy( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> c,  int  n,  int  p,  int  q )
{   scm2cpp::device_matrix d6093 = scm2cpp::dmat_upload(x, (n*p), 1);
    scm2cpp::device_matrix d6094 = scm2cpp::dmat_upload(y, (n*q), 1);
    scm2cpp::blas_gemm(c, d6093, d6094, 1.0, 0.0, 1, 0, p, q, n)  ;
    ;
    return 0 ;
}
#endif // ACCEL_HPP
