
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
        std::vector<double> b03094(k,0.0);
        std::vector<double> g3093((k*k),0.0);
        std::vector<double> c3092((n*k),0.0);
        for( std::int64_t y2070 = 0 ; !(y2070 == k) ; y2070 = (y2070+1) ) {
            for( std::int64_t y2071 = 0 ; !(y2071 == k) ; y2071 = (y2071+1) ) {
                g3093[ (((long long)y2070*k)+y2071) ] = ([&]() -> double { std::int64_t k2072 = 0; double sum2082 = 0.0; while (!(k2072 == p)) {
                std::int64_t k2072_next3104 = (k2072+1);
                    double sum2082_next3105 = (sum2082+(ht[(((long long)k2072*k)+y2071)]*ht[(((long long)k2072*k)+y2070)]));
                    k2072 = k2072_next3104;
                    sum2082 = sum2082_next3105;
                } return sum2082; })()   ;
            }  ;
        }  ;
        for( std::int64_t y2073 = 0 ; !(y2073 == n) ; y2073 = (y2073+1) ) {
            for( std::int64_t y2074 = 0 ; !(y2074 == k) ; y2074 = (y2074+1) ) {
                c3092[ (((long long)y2073*k)+y2074) ] = ([&]() -> double { std::int64_t k2075 = 0; double sum2084 = 0.0; while (!(k2075 == p)) {
                std::int64_t k2075_next3106 = (k2075+1);
                    double sum2084_next3107 = (sum2084+(x[(((long long)y2073*p)+k2075)]*ht[(((long long)k2075*k)+y2074)]));
                    k2075 = k2075_next3106;
                    sum2084 = sum2084_next3107;
                } return sum2084; })()   ;
            }  ;
        }  ;
        for( std::int64_t y2076 = 0 ; !(y2076 == n) ; y2076 = (y2076+1) ) {
            for( std::int64_t y2077 = 0 ; !(y2077 == k) ; y2077 = (y2077+1) ) {
                c3092[ (((long long)y2076*k)+y2077) ] = (c3092[(((long long)y2076*k)+y2077)]-([&]() -> double { std::int64_t k2078 = 0; double sum2086 = 0.0; while (!(k2078 == k)) {
                std::int64_t k2078_next3108 = (k2078+1);
                    double sum2086_next3109 = (sum2086+(w[(((long long)y2076*k)+k2078)]*g3093[(((long long)k2078*k)+y2077)]));
                    k2078 = k2078_next3108;
                    sum2086 = sum2086_next3109;
                } return sum2086; })())   ;
            }  ;
        }  ;
        for( std::int64_t t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { std::int64_t i2079 = 0; double r2080 = 0.0; while (!(i2079 == p)) {
            std::int64_t i2079_next3110 = (i2079+1);
                double r2080_next3111 = (r2080+(ht[(((long long)i2079*k)+t)]*ht[(((long long)i2079*k)+t)]));
                i2079 = i2079_next3110;
                r2080 = r2080_next3111;
            } return r2080; })();
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double grad = 0.0;
                double old = w[(((long long)i*k)+t)];
                grad = (grad-c3092[(((long long)i*k)+t)])  ;
                double pg = ( ( old == 0.0 ) ? (( ( grad < 0.0 ) ? (grad) : (0.0) )) : (grad) );
                violation = (violation+( ( pg < 0.0 ) ? ((0.0-pg)) : (pg) ))  ;
                ;
                if( !(hess == 0.0) ) {
                    double wnew = (old-(grad/hess));
                    double wc = ( ( wnew < 0.0 ) ? (0.0) : (wnew) );
                    w[ (((long long)i*k)+t) ] = wc   ;
                    if( !(wc == old) ) {
                        for( std::int64_t k3096 = 0 ; !(k3096 == k) ; k3096 = (k3096+1) ) {
                            c3092[ (((long long)i*k)+k3096) ] = (c3092[(((long long)i*k)+k3096)]-(g3093[(((long long)t*k)+k3096)]*(wc-old)))   ;
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
        for( std::int64_t i2063 = 0 ; !(i2063 == (n*p)) ; i2063 = (i2063+1) ) {
            r[ i2063 ] = x[i2063]   ;
        }  ;
        for( std::int64_t k2064 = 0 ; !(k2064 == n) ; k2064 = (k2064+1) ) {
            for( std::int64_t k2065 = 0 ; !(k2065 == p) ; k2065 = (k2065+1) ) {
                r[ (((long long)k2064*p)+k2065) ] = (r[(((long long)k2064*p)+k2065)]-([&]() -> double { std::int64_t i2067 = 0; double r2068 = 0.0; while (!(i2067 == k)) {
                std::int64_t i2067_next3112 = (i2067+1);
                    double r2068_next3113 = (r2068+(w[(((long long)k2064*k)+i2067)]*ht[(((long long)k2065*k)+i2067)]));
                    i2067 = i2067_next3112;
                    r2068 = r2068_next3113;
                } return r2068; })())   ;
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
