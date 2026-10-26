
#ifndef NMF_CD_HPP
#define NMF_CD_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-blas.hpp"
#include	<vector>
#include	"scm2cpp.hpp"

double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  int  n,  int  p,  int  k );
SCM2CPP_FN int
nmf( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xt,  scm2cpp::span<double> w,  scm2cpp::span<double> ht,  int  iters,  double  tol,  int  n,  int  p,  int  k );



inline double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  int  n,  int  p,  int  k )
{   if( k < p ) {
        double violation = 0.0;
        std::vector<double> b06087(k,0.0);
        std::vector<double> g6086((k*k),0.0);
        std::vector<double> c6085((n*k),0.0);
        scm2cpp::blas_syrk(g6086, ht, 1.0, 0.0, 1, k, p)  ;
        scm2cpp::blas_gemm(c6085, x, ht, 1.0, 0.0, 0, 0, n, k, p)  ;
        scm2cpp::blas_gemm(c6085, w, g6086, -1.0, 1.0, 0, 0, n, k, k)  ;
        for( int t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { int i2053 = 0; double r2054 = 0.0; while (!(i2053 == p)) {
            int i2053_next6099 = (i2053+1);
                double r2054_next6100 = (r2054+(ht[((i2053*k)+t)]*ht[((i2053*k)+t)]));
                i2053 = i2053_next6099;
                r2054 = r2054_next6100;
            } return r2054; })();
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[((i*k)+t)];
                grad = (grad-c6085[((i*k)+t)])  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ ((i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( int k6089 = 0 ; !(k6089 == k) ; k6089 = (k6089+1) ) {
                            c6085[ ((i*k)+k6089) ] = (c6085[((i*k)+k6089)]-(g6086[((t*k)+k6089)]*(wc-old)))   ;
                        }  ;
                    } else {
                        false  ;
                    }  ;
                    ;
                    ;
                } else {
                    false  ;
                }  ;
                ;
            }  ;
            ;
        }  ;
        0  ;
        ;
        return violation ;
    }
    else {
        std::vector<double> r((n*p),0.0);
        for( int i2052 = 0 ; !(i2052 == (n*p)) ; i2052 = (i2052+1) ) {
            r[ i2052 ] = x[i2052]   ;
        }  ;
        scm2cpp::blas_gemm(r, w, ht, -1.0, 1.0, 0, 1, n, p, k)  ;
        double violation = 0.0;
        for( int t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = 0.0;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                hess = (hess+(ht[((j*k)+t)]*ht[((j*k)+t)]))  ;
            }  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[((i*k)+t)];
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    grad = (grad-(r[((i*p)+j)]*ht[((j*k)+t)]))  ;
                }  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ ((i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                            r[ ((i*p)+j) ] = (r[((i*p)+j)]-(ht[((j*k)+t)]*(wc-old)))   ;
                        }  ;
                    } else {
                        false  ;
                    }  ;
                    ;
                    ;
                } else {
                    false  ;
                }  ;
                ;
            }  ;
            ;
        }  ;
        return violation ;
    }
}


SCM2CPP_FN inline int
nmf( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xt,  scm2cpp::span<double> w,  scm2cpp::span<double> ht,  int  iters,  double  tol,  int  n,  int  p,  int  k )
{   double vinit = 0.0;
    int stop = 0;
    int it = 0;
    for(  ; !((stop == 1 || it >= iters)) ;  ) {
        it = (it+1)  ;
        double v = (nmf_half(x,w,ht,n,p,k)+nmf_half(xt,ht,w,p,n,k));
        if( it == 1 ) {
            vinit = v  ;
        } else {
            0  ;
        }  ;
        if( (vinit == 0.0 || (v/vinit) <= tol) ) {
            stop = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return it ;
}
#endif // NMF_CD_HPP
