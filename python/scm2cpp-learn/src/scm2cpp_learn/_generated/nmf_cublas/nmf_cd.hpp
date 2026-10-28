
#ifndef NMF_CD_HPP
#define NMF_CD_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-cublas.hpp"
#include	<vector>
#include	"scm2cpp.hpp"

double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  int  n,  int  p,  int  k );
SCM2CPP_FN int
nmf( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xt,  scm2cpp::span<double> w,  scm2cpp::span<double> ht,  int  iters,  double  tol,  int  n,  int  p,  int  k );



inline double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  int  n,  int  p,  int  k )
{   scm2cpp::device_matrix d1529 = scm2cpp::dmat_upload(ht, (p*k), 1);
    if( k < p ) {
        double violation = 0.0;
        std::vector<double> b01517(k,0.0);
        std::vector<double> g1516((k*k),0.0);
        std::vector<double> c1515((n*k),0.0);
        scm2cpp::device_matrix d1527 = scm2cpp::dmat_upload(ht, (p*k), 1);
        scm2cpp::device_matrix d1528 = scm2cpp::dmat_upload(x, (n*p), 1);
        scm2cpp::blas_syrk(g1516, d1527, 1.0, 0.0, 1, k, p)  ;
        scm2cpp::blas_gemm(c1515, d1528, d1527, 1.0, 0.0, 0, 0, n, k, p)  ;
        scm2cpp::blas_gemm(c1515, scm2cpp::dmat_upload(w, (n*k), 1), scm2cpp::dmat_upload(g1516, (k*k), 1), -1.0, 1.0, 0, 0, n, k, k)  ;
        for( int t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { int i2053 = 0; double r2054 = 0.0; while (!(i2053 == p)) {
            int i2053_next1533 = (i2053+1);
                double r2054_next1534 = (r2054+(ht[((i2053*k)+t)]*ht[((i2053*k)+t)]));
                i2053 = i2053_next1533;
                r2054 = r2054_next1534;
            } return r2054; })();
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[((i*k)+t)];
                grad = (grad-c1515[((i*k)+t)])  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ ((i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( int k1519 = 0 ; !(k1519 == k) ; k1519 = (k1519+1) ) {
                            c1515[ ((i*k)+k1519) ] = (c1515[((i*k)+k1519)]-(g1516[((t*k)+k1519)]*(wc-old)))   ;
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
        ;
        return violation ;
    }
    else {
        std::vector<double> r((n*p),0.0);
        for( int i2052 = 0 ; !(i2052 == (n*p)) ; i2052 = (i2052+1) ) {
            r[ i2052 ] = x[i2052]   ;
        }  ;
        scm2cpp::blas_gemm(r, scm2cpp::dmat_upload(w, (n*k), 1), d1529, -1.0, 1.0, 0, 1, n, p, k)  ;
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
