
#ifndef NMF_CD_HPP
#define NMF_CD_HPP
#define SCM2CPP_MINIMAL
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
        for( std::int64_t y2069 = 0 ; !(y2069 == k) ; y2069 = (y2069+1) ) {
            for( std::int64_t y2070 = 0 ; !(y2070 == k) ; y2070 = (y2070+1) ) {
                g470[ (((long long)y2069*k)+y2070) ] = ([&]() -> double { std::int64_t k2071 = 0; double sum2081 = 0.0; while (!(k2071 == p)) {
                std::int64_t k2071_next481 = (k2071+1);
                    double sum2081_next482 = (sum2081+(ht[(((long long)k2071*k)+y2070)]*ht[(((long long)k2071*k)+y2069)]));
                    k2071 = k2071_next481;
                    sum2081 = sum2081_next482;
                } return sum2081; })()   ;
            }  ;
        }  ;
        for( std::int64_t y2072 = 0 ; !(y2072 == n) ; y2072 = (y2072+1) ) {
            for( std::int64_t y2073 = 0 ; !(y2073 == k) ; y2073 = (y2073+1) ) {
                c469[ (((long long)y2072*k)+y2073) ] = ([&]() -> double { std::int64_t k2074 = 0; double sum2083 = 0.0; while (!(k2074 == p)) {
                std::int64_t k2074_next483 = (k2074+1);
                    double sum2083_next484 = (sum2083+(x[(((long long)y2072*p)+k2074)]*ht[(((long long)k2074*k)+y2073)]));
                    k2074 = k2074_next483;
                    sum2083 = sum2083_next484;
                } return sum2083; })()   ;
            }  ;
        }  ;
        for( std::int64_t y2075 = 0 ; !(y2075 == n) ; y2075 = (y2075+1) ) {
            for( std::int64_t y2076 = 0 ; !(y2076 == k) ; y2076 = (y2076+1) ) {
                c469[ (((long long)y2075*k)+y2076) ] = (c469[(((long long)y2075*k)+y2076)]-([&]() -> double { std::int64_t k2077 = 0; double sum2085 = 0.0; while (!(k2077 == k)) {
                std::int64_t k2077_next485 = (k2077+1);
                    double sum2085_next486 = (sum2085+(w[(((long long)y2075*k)+k2077)]*g470[(((long long)k2077*k)+y2076)]));
                    k2077 = k2077_next485;
                    sum2085 = sum2085_next486;
                } return sum2085; })())   ;
            }  ;
        }  ;
        for( std::int64_t t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { std::int64_t i2078 = 0; double r2079 = 0.0; while (!(i2078 == p)) {
            std::int64_t i2078_next487 = (i2078+1);
                double r2079_next488 = (r2079+(ht[(((long long)i2078*k)+t)]*ht[(((long long)i2078*k)+t)]));
                i2078 = i2078_next487;
                r2079 = r2079_next488;
            } return r2079; })();
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
        for( std::int64_t k2063 = 0 ; !(k2063 == n) ; k2063 = (k2063+1) ) {
            for( std::int64_t k2064 = 0 ; !(k2064 == p) ; k2064 = (k2064+1) ) {
                r[ (((long long)k2063*p)+k2064) ] = (r[(((long long)k2063*p)+k2064)]-([&]() -> double { std::int64_t i2066 = 0; double r2067 = 0.0; while (!(i2066 == k)) {
                std::int64_t i2066_next489 = (i2066+1);
                    double r2067_next490 = (r2067+(w[(((long long)k2063*k)+i2066)]*ht[(((long long)k2064*k)+i2066)]));
                    i2066 = i2066_next489;
                    r2067 = r2067_next490;
                } return r2067; })())   ;
            }  ;
        }  ;
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
