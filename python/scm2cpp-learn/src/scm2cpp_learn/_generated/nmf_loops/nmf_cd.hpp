
#ifndef NMF_CD_HPP
#define NMF_CD_HPP
#define SCM2CPP_MINIMAL
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
        std::vector<double> b01517(k,0.0);
        std::vector<double> g1516((k*k),0.0);
        std::vector<double> c1515((n*k),0.0);
        for( int y2059 = 0 ; !(y2059 == k) ; y2059 = (y2059+1) ) {
            for( int y2060 = 0 ; !(y2060 == k) ; y2060 = (y2060+1) ) {
                g1516[ ((y2059*k)+y2060) ] = ([&]() -> double { int k2061 = 0; double sum2071 = 0.0; while (!(k2061 == p)) {
                int k2061_next1527 = (k2061+1);
                    double sum2071_next1528 = (sum2071+(ht[((k2061*k)+y2060)]*ht[((k2061*k)+y2059)]));
                    k2061 = k2061_next1527;
                    sum2071 = sum2071_next1528;
                } return sum2071; })()   ;
            }  ;
        }  ;
        for( int y2062 = 0 ; !(y2062 == n) ; y2062 = (y2062+1) ) {
            for( int y2063 = 0 ; !(y2063 == k) ; y2063 = (y2063+1) ) {
                c1515[ ((y2062*k)+y2063) ] = ([&]() -> double { int k2064 = 0; double sum2073 = 0.0; while (!(k2064 == p)) {
                int k2064_next1529 = (k2064+1);
                    double sum2073_next1530 = (sum2073+(x[((y2062*p)+k2064)]*ht[((k2064*k)+y2063)]));
                    k2064 = k2064_next1529;
                    sum2073 = sum2073_next1530;
                } return sum2073; })()   ;
            }  ;
        }  ;
        for( int y2065 = 0 ; !(y2065 == n) ; y2065 = (y2065+1) ) {
            for( int y2066 = 0 ; !(y2066 == k) ; y2066 = (y2066+1) ) {
                c1515[ ((y2065*k)+y2066) ] = (c1515[((y2065*k)+y2066)]-([&]() -> double { int k2067 = 0; double sum2075 = 0.0; while (!(k2067 == k)) {
                int k2067_next1531 = (k2067+1);
                    double sum2075_next1532 = (sum2075+(w[((y2065*k)+k2067)]*g1516[((k2067*k)+y2066)]));
                    k2067 = k2067_next1531;
                    sum2075 = sum2075_next1532;
                } return sum2075; })())   ;
            }  ;
        }  ;
        for( int t = 0 ; !(t == k) ; t = (t+1) ) {
            double hess = ([&]() -> double { int i2068 = 0; double r2069 = 0.0; while (!(i2068 == p)) {
            int i2068_next1533 = (i2068+1);
                double r2069_next1534 = (r2069+(ht[((i2068*k)+t)]*ht[((i2068*k)+t)]));
                i2068 = i2068_next1533;
                r2069 = r2069_next1534;
            } return r2069; })();
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
        return violation ;
    }
    else {
        std::vector<double> r((n*p),0.0);
        for( int i2052 = 0 ; !(i2052 == (n*p)) ; i2052 = (i2052+1) ) {
            r[ i2052 ] = x[i2052]   ;
        }  ;
        for( int k2053 = 0 ; !(k2053 == n) ; k2053 = (k2053+1) ) {
            for( int k2054 = 0 ; !(k2054 == p) ; k2054 = (k2054+1) ) {
                r[ ((k2053*p)+k2054) ] = (r[((k2053*p)+k2054)]-([&]() -> double { int i2056 = 0; double r2057 = 0.0; while (!(i2056 == k)) {
                int i2056_next1535 = (i2056+1);
                    double r2057_next1536 = (r2057+(w[((k2053*k)+i2056)]*ht[((k2054*k)+i2056)]));
                    i2056 = i2056_next1535;
                    r2057 = r2057_next1536;
                } return r2057; })())   ;
            }  ;
        }  ;
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
