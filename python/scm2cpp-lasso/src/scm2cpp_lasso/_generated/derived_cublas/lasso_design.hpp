
#ifndef LASSO_DESIGN_HPP
#define LASSO_DESIGN_HPP
#define SCM2CPP_MINIMAL
#include	"scm2cpp-cublas.hpp"
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN double
soft_threshold( double  z,  double  g );
int
lasso_design( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> resid,  scm2cpp::span<double> xnorm,  scm2cpp::span<double> beta,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  int  iters,  double  tol,  int  n,  int  p,  int  nlam );



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
lasso_design( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> resid,  scm2cpp::span<double> xnorm,  scm2cpp::span<double> beta,  scm2cpp::cspan<double> lams,  scm2cpp::span<double> betas,  int  iters,  double  tol,  int  n,  int  p,  int  nlam )
{   if( p < n ) {
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            resid[ i ] = y[i]   ;
        }  ;
        0  ;
        std::vector<double> b024258(p,0.0);
        std::vector<double> g24257((p*p),0.0);
        std::vector<double> c24256(p,0.0);
        scm2cpp::device_matrix d24266 = scm2cpp::dmat_upload(x, (n*p), 1);
        scm2cpp::blas_syrk(g24257, d24266, 1.0, 0.0, 1, p, n)  ;
        scm2cpp::blas_gemv(c24256, d24266, resid, 1.0, 0.0, 1, p, n)  ;
        for( int l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            int stop = 0;
            for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                double maxmove = 0.0;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = c24256[j];
                    double old = beta[j];
                    rho = (rho+(old*g24257[((j*p)+j)]))  ;
                    double bnew = (soft_threshold(rho,double((lam*(1.0*n))))/g24257[((j*p)+j)]);
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
                        b024258[ j ] = (b024258[j]+(bnew-old))   ;
                        for( int k24260 = 0 ; !(k24260 == p) ; k24260 = (k24260+1) ) {
                            c24256[ k24260 ] = (c24256[k24260]-(g24257[((j*p)+k24260)]*(bnew-old)))   ;
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
        scm2cpp::blas_gemv(resid, d24266, b024258, -1.0, 1.0, 0, n, p)  ;
        0  ;
        ;
        ;
    } else {
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            resid[ i ] = y[i]   ;
        }  ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            double acc = 0.0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                acc = (acc+(x[((i*p)+j)]*x[((i*p)+j)]))  ;
            }  ;
            xnorm[ j ] = acc   ;
            ;
        }  ;
        for( int l = 0 ; !(l == nlam) ; l = (l+1) ) {
            double lam = lams[l];
            int stop = 0;
            for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
                double maxmove = 0.0;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    double rho = 0.0;
                    double old = beta[j];
                    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                        rho = (rho+(x[((i*p)+j)]*resid[i]))  ;
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
                            resid[ i ] = (resid[i]-(x[((i*p)+j)]*(bnew-old)))   ;
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
#endif // LASSO_DESIGN_HPP
