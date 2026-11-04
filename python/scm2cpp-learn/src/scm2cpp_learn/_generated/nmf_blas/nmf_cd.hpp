
#ifndef NMF_CD_HPP
#define NMF_CD_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-blas.hpp"
#include	<vector>
#include	"scm2cpp.hpp"

double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN std::int64_t
nmf( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xt,  scm2cpp::span<double> w,  scm2cpp::span<double> ht,  std::int64_t  iters,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );



inline double
nmf_half( scm2cpp::cspan<double> x,  scm2cpp::span<double> w,  scm2cpp::cspan<double> ht,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   if( k < p ) {
        double violation = 0.0;
        std::vector<double> b0471(k,0.0);
        std::vector<double> g470((k*k),0.0);
        std::vector<double> c469((n*k),0.0);
        scm2cpp::blas_syrk(g470, ht, 1.0, 0.0, 1, k, p)  ;
        scm2cpp::blas_gemm(c469, x, ht, 1.0, 0.0, 0, 0, n, k, p)  ;
        scm2cpp::blas_gemm(c469, w, g470, -1.0, 1.0, 0, 0, n, k, k)  ;
        for( std::int64_t t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { std::int64_t i2063 = 0; double r2064 = 0.0; while (!(i2063 == p)) {
            std::int64_t i2063_next483 = (i2063+1);
                double r2064_next484 = (r2064+(ht[(((long long)i2063*k)+t)]*ht[(((long long)i2063*k)+t)]));
                i2063 = i2063_next483;
                r2064 = r2064_next484;
            } return r2064; })();
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[(((long long)i*k)+t)];
                grad = (grad-c469[(((long long)i*k)+t)])  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ (((long long)i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( std::int64_t k473 = 0 ; !(k473 == k) ; k473 = (k473+1) ) {
                            c469[ (((long long)i*k)+k473) ] = (c469[(((long long)i*k)+k473)]-(g470[(((long long)t*k)+k473)]*(wc-old)))   ;
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
        for( std::int64_t i2062 = 0 ; !(i2062 == (n*p)) ; i2062 = (i2062+1) ) {
            r[ i2062 ] = x[i2062]   ;
        }  ;
        scm2cpp::blas_gemm(r, w, ht, -1.0, 1.0, 0, 1, n, p, k)  ;
        double violation = 0.0;
        for( std::int64_t t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = 0.0;
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                hess = (hess+(ht[(((long long)j*k)+t)]*ht[(((long long)j*k)+t)]))  ;
            }  ;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[(((long long)i*k)+t)];
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    grad = (grad-(r[(((long long)i*p)+j)]*ht[(((long long)j*k)+t)]))  ;
                }  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ (((long long)i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                            r[ (((long long)i*p)+j) ] = (r[(((long long)i*p)+j)]-(ht[(((long long)j*k)+t)]*(wc-old)))   ;
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


SCM2CPP_FN inline std::int64_t
nmf( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> xt,  scm2cpp::span<double> w,  scm2cpp::span<double> ht,  std::int64_t  iters,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   double vinit = 0.0;
    std::int64_t stop = 0;
    std::int64_t it = 0;
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
