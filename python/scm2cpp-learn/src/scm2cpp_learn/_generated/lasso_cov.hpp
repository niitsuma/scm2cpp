
#ifndef LASSO_COV_HPP
#define LASSO_COV_HPP
#define SCM2CPP_MINIMAL
#include	<math.h>
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN double
soft_threshold( double  z,  double  g );
SCM2CPP_FN std::int64_t
cov_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> beta,  double  lam,  std::int64_t  iters,  double  nobs,  std::int64_t  p );
SCM2CPP_FN std::int64_t
enet_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> beta,  double  lam1,  double  lam2,  std::int64_t  iters,  double  nobs,  std::int64_t  p );
SCM2CPP_FN std::int64_t
mt_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> w,  double  lam1,  double  lam2,  std::int64_t  iters,  double  nobs,  std::int64_t  p,  std::int64_t  ntask );



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


SCM2CPP_FN inline std::int64_t
cov_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> beta,  double  lam,  std::int64_t  iters,  double  nobs,  std::int64_t  p )
{   std::int64_t stop = 0;
    for( std::int64_t sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
        std::int64_t moved = 0;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double gjj = g[(((long long)j*p)+j)];
            double old = beta[j];
            double bnew = ( ( gjj > 0.0 ) ? ((soft_threshold(double((c[j]+(old*gjj))),double((lam*(1.0*nobs))))/gjj)) : (0.0) );
            beta[ j ] = bnew   ;
            double d = (bnew-old);
            if( d == 0.0 ) {
                0  ;
            } else {
                moved = 1  ;
                for( std::int64_t k = 0 ; !(k == p) ; k = (k+1) ) {
                    c[ k ] = (c[k]-(d*g[(((long long)j*p)+k)]))   ;
                }  ;
            }  ;
            ;
            ;
            ;
        }  ;
        if( moved == 0 ) {
            stop = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
enet_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> beta,  double  lam1,  double  lam2,  std::int64_t  iters,  double  nobs,  std::int64_t  p )
{   std::int64_t stop = 0;
    for( std::int64_t sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
        std::int64_t moved = 0;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double gjj = g[(((long long)j*p)+j)];
            double old = beta[j];
            double bnew = ( ( gjj > 0.0 ) ? ((soft_threshold(double((c[j]+(old*gjj))),double((lam1*(1.0*nobs))))/(gjj+(lam2*(1.0*nobs))))) : (0.0) );
            beta[ j ] = bnew   ;
            double d = (bnew-old);
            if( d == 0.0 ) {
                0  ;
            } else {
                moved = 1  ;
                for( std::int64_t k = 0 ; !(k == p) ; k = (k+1) ) {
                    c[ k ] = (c[k]-(d*g[(((long long)j*p)+k)]))   ;
                }  ;
            }  ;
            ;
            ;
            ;
        }  ;
        if( moved == 0 ) {
            stop = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
mt_descend( scm2cpp::cspan<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> w,  double  lam1,  double  lam2,  std::int64_t  iters,  double  nobs,  std::int64_t  p,  std::int64_t  ntask )
{   std::int64_t stop = 0;
    for( std::int64_t sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
        std::int64_t moved = 0;
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double gjj = g[(((long long)j*p)+j)];
            double nrm2 = 0.0;
            for( std::int64_t t = 0 ; !(t == ntask) ; t = (t+1) ) {
                double z = (c[(((long long)j*ntask)+t)]+(gjj*w[(((long long)j*ntask)+t)]));
                nrm2 = (nrm2+(z*z))  ;
                ;
            }  ;
            double nrm = sqrt(nrm2);
            double thr = (lam1*(1.0*nobs));
            double scale = ( ( (gjj > 0.0 && nrm > thr) ) ? (((nrm-thr)/(nrm*(gjj+(lam2*(1.0*nobs)))))) : (0.0) );
            for( std::int64_t t = 0 ; !(t == ntask) ; t = (t+1) ) {
                double old = w[(((long long)j*ntask)+t)];
                double wnew = (scale*(c[(((long long)j*ntask)+t)]+(gjj*old)));
                w[ (((long long)j*ntask)+t) ] = wnew   ;
                double d = (wnew-old);
                if( d == 0.0 ) {
                    0  ;
                } else {
                    moved = 1  ;
                    for( std::int64_t k = 0 ; !(k == p) ; k = (k+1) ) {
                        c[ (((long long)k*ntask)+t) ] = (c[(((long long)k*ntask)+t)]-(d*g[(((long long)j*p)+k)]))   ;
                    }  ;
                }  ;
                ;
                ;
                ;
            }  ;
            ;
            ;
            ;
        }  ;
        if( moved == 0 ) {
            stop = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    ;
    return 0 ;
}
#endif // LASSO_COV_HPP
