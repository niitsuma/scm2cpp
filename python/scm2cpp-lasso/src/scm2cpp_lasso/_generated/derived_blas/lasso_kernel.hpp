
#ifndef LASSO_KERNEL_HPP
#define LASSO_KERNEL_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-blas.hpp"
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
        std::vector<double> b08314(p,0.0);
        std::vector<double> g8313((p*p),0.0);
        std::vector<double> c8312(p,0.0);
        scm2cpp::blas_gram(g8313, x, p, n)  ;
        scm2cpp::blas_gemv(c8312, x, resid, p, n)  ;
        for( int k8315 = 0 ; !(k8315 == p) ; k8315 = (k8315+1) ) {
            b08314[ k8315 ] = beta[k8315]   ;
        }  ;
        for( int l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            int stop = 0;
            for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                double maxmove = 0.0;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = c8312[j];
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
                        for( int k8316 = 0 ; !(k8316 == p) ; k8316 = (k8316+1) ) {
                            c8312[ k8316 ] = (c8312[k8316]-(g8313[((j*p)+k8316)]*(bnew-old)))   ;
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
        std::vector<double> d8320(p,0.0);
        for( int i2491 = 0 ; !(i2491 == p) ; i2491 = (i2491+1) ) {
            d8320[ i2491 ] = (beta[i2491]-b08314[i2491])   ;
        }  ;
        scm2cpp::blas_gemv_t_add(resid, x, d8320, -1.0, p, n)  ;
        ;
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
