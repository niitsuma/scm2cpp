
#ifndef LASSO_KERNEL_HPP
#define LASSO_KERNEL_HPP
#define SCM2CPP_MINIMAL
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN double
soft_threshold( double  z,  double  g );
int
lasso( scm2cpp::cspan<double> x,  scm2cpp::span<double> beta,  scm2cpp::span<double> resid,  scm2cpp::cspan<double> xnorm,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  int  iters,  double  tol,  int  n,  int  p,  int  nlam );



SCM2CPP_FN inline double
soft_threshold( double  z,  double  g )
{
    if(z > g) {
        return (z-g) ;
    }
    else if(z < (0.0-g)) {
        return (z+g) ;
    }
    else {
        return 0.0 ;
    }
}


inline int
lasso( scm2cpp::cspan<double> x,  scm2cpp::span<double> beta,  scm2cpp::span<double> resid,  scm2cpp::cspan<double> xnorm,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  int  iters,  double  tol,  int  n,  int  p,  int  nlam )
{   if( p < n ) {
        std::vector<double> b07363(p,0.0);
        std::vector<double> g7362((p*p),0.0);
        std::vector<double> c7361(p,0.0);
        for( int k2491 = 0 ; !(k2491 == p) ; k2491 = (k2491+1) ) {
            for( int k2492 = k2491 ; !(k2492 == p) ; k2492 = (k2492+1) ) {
                g7362[ ((k2491*p)+k2492) ] = ([&]() -> double { int i2494 = 0; double r2495 = 0.0; while (!(i2494 == n)) {
                int i2494_next7369 = (i2494+1);
                    double r2495_next7370 = (r2495+(x[((k2491*n)+i2494)]*x[((k2492*n)+i2494)]));
                    i2494 = i2494_next7369;
                    r2495 = r2495_next7370;
                } return r2495; })()   ;
                g7362[ ((k2492*p)+k2491) ] = g7362[((k2491*p)+k2492)]   ;
            }  ;
        }  ;
        for( int k2497 = 0 ; !(k2497 == p) ; k2497 = (k2497+1) ) {
            c7361[ k2497 ] = ([&]() -> double { int i2500 = 0; double r2501 = 0.0; while (!(i2500 == n)) {
            int i2500_next7371 = (i2500+1);
                double r2501_next7372 = (r2501+(x[((k2497*n)+i2500)]*resid[i2500]));
                i2500 = i2500_next7371;
                r2501 = r2501_next7372;
            } return r2501; })()   ;
        }  ;
        for( int k7364 = 0 ; !(k7364 == p) ; k7364 = (k7364+1) ) {
            b07363[ k7364 ] = beta[k7364]   ;
        }  ;
        for( int l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            int stop = 0;
            for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                double maxmove = 0.0;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = c7361[j];
                    double old = beta[j];
                    rho = (rho+(old*xnorm[j]))  ;
                    double bnew = (soft_threshold(rho,double((lam*(1.0*n))))/xnorm[j]);
                    beta[ j ] = bnew   ;
                    if( !(bnew == old) ) {
                        if( (bnew-old) > maxmove ) {
                            maxmove = (bnew-old)  ;
                        } else {
                            0  ;
                        }  ;
                        if( (old-bnew) > maxmove ) {
                            maxmove = (old-bnew)  ;
                        } else {
                            0  ;
                        }  ;
                        for( int k7365 = 0 ; !(k7365 == p) ; k7365 = (k7365+1) ) {
                            c7361[ k7365 ] = (c7361[k7365]-(g7362[((j*p)+k7365)]*(bnew-old)))   ;
                        }  ;
                    } else {
                        false  ;
                    }  ;
                    ;
                    ;
                }  ;
                if( maxmove <= tol ) {
                    stop = 1  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
            ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                betas[ ((l*p)+j) ] = beta[j]   ;
            }  ;
            ;
        }  ;
        for( int k2503 = 0 ; !(k2503 == p) ; k2503 = (k2503+1) ) {
            for( int i2506 = 0 ; !(i2506 == n) ; i2506 = (i2506+1) ) {
                resid[ i2506 ] = (resid[i2506]-(x[((k2503*n)+i2506)]*(beta[k2503]-b07363[k2503])))   ;
            }  ;
        }  ;
        0  ;
        ;
    } else {
        for( int l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            int stop = 0;
            for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                double maxmove = 0.0;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = 0.0;
                    double old = beta[j];
                    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                        rho = (rho+(x[((j*n)+i)]*resid[i]))  ;
                    }  ;
                    rho = (rho+(old*xnorm[j]))  ;
                    double bnew = (soft_threshold(rho,double((lam*(1.0*n))))/xnorm[j]);
                    beta[ j ] = bnew   ;
                    if( !(bnew == old) ) {
                        if( (bnew-old) > maxmove ) {
                            maxmove = (bnew-old)  ;
                        } else {
                            0  ;
                        }  ;
                        if( (old-bnew) > maxmove ) {
                            maxmove = (old-bnew)  ;
                        } else {
                            0  ;
                        }  ;
                        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                            resid[ i ] = (resid[i]-(x[((j*n)+i)]*(bnew-old)))   ;
                        }  ;
                    } else {
                        false  ;
                    }  ;
                    ;
                    ;
                }  ;
                if( maxmove <= tol ) {
                    stop = 1  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
            ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                betas[ ((l*p)+j) ] = beta[j]   ;
            }  ;
            ;
        }  ;
    }  ;
    return 0 ;
}
#endif // LASSO_KERNEL_HPP
