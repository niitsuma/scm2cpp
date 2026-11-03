
#ifndef LASSO_DESIGN_HPP
#define LASSO_DESIGN_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-blas.hpp"
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN double
soft_threshold( double  z,  double  g );
std::int64_t
lasso_design( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> resid,  scm2cpp::span<double> xnorm,  scm2cpp::span<double> beta,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  std::int64_t  iters,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nlam );



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


inline std::int64_t
lasso_design( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> resid,  scm2cpp::span<double> xnorm,  scm2cpp::span<double> beta,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  std::int64_t  iters,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nlam )
{   std::int64_t swept = 0;
    if( p < n ) {
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            resid[ i ] = y[i]   ;
        }  ;
        0  ;
        std::vector<double> b0471(p,0.0);
        std::vector<double> g470((p*p),0.0);
        std::vector<double> c469(p,0.0);
        scm2cpp::blas_syrk(g470, x, 1.0, 0.0, 1, p, n)  ;
        scm2cpp::blas_gemv(c469, x, resid, 1.0, 0.0, 1, p, n)  ;
        for( std::int64_t l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            std::int64_t stop = 0;
            for( std::int64_t sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                swept = (swept+1)  ;
                double maxmove = 0.0;
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = c469[j];
                    double old = beta[j];
                    rho = (rho+(old*g470[(((long long)j*p)+j)]))  ;
                    double bnew = (soft_threshold(rho,double((lam*(1.0*n))))/g470[(((long long)j*p)+j)]);
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
                        b0471[ j ] = (b0471[j]+(bnew-old))   ;
                        for( std::int64_t k473 = 0 ; !(k473 == p) ; k473 = (k473+1) ) {
                            c469[ k473 ] = (c469[k473]-(g470[(((long long)j*p)+k473)]*(bnew-old)))   ;
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
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                betas[ (((long long)l*p)+j) ] = beta[j]   ;
            }  ;
            ;
        }  ;
        scm2cpp::blas_gemv(resid, x, b0471, -1.0, 1.0, 0, n, p)  ;
        0  ;
        ;
    } else {
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            resid[ i ] = y[i]   ;
        }  ;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                acc = (acc+(x[(((long long)i*p)+j)]*x[(((long long)i*p)+j)]))  ;
            }  ;
            xnorm[ j ] = acc   ;
            ;
        }  ;
        for( std::int64_t l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            std::int64_t stop = 0;
            for( std::int64_t sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                swept = (swept+1)  ;
                double maxmove = 0.0;
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = 0.0;
                    double old = beta[j];
                    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                        rho = (rho+(x[(((long long)i*p)+j)]*resid[i]))  ;
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
                        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                            resid[ i ] = (resid[i]-(x[(((long long)i*p)+j)]*(bnew-old)))   ;
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
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                betas[ (((long long)l*p)+j) ] = beta[j]   ;
            }  ;
            ;
        }  ;
    }  ;
    return swept ;
}
#endif // LASSO_DESIGN_HPP
