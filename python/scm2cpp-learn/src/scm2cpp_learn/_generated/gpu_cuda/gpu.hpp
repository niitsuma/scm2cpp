
#ifndef GPU_HPP
#define GPU_HPP
#define SCM2CPP_MINIMAL
#include	<array>
#include	"scm2cpp-cuda.hpp"
#include	<vector>
#include	<math.h>
#include	"scm2cpp.hpp"

SCM2CPP_FN double
eig_hypot( double  a,  double  b );
std::int64_t
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m );
SCM2CPP_FN double
eig_abs( double  a );
std::int64_t
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  std::int64_t  m );
std::int64_t
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m,  std::int64_t  k );
std::int64_t
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m );
SCM2CPP_FN double
ica_tanh( double  x );
std::int64_t
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> t,  std::int64_t  m );
std::int64_t
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  std::int64_t  maxiter,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nc );
std::int64_t
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  std::int64_t  norm,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
SCM2CPP_FN double
gmm_abs( double  a );
std::int64_t
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  reg,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc );
double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
std::int64_t
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  std::int64_t  maxiter,  double  tol,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
std::int64_t
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  std::int64_t  family,  double  power,  double  l2,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
std::int64_t
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  std::int64_t  family,  double  power,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p );
SCM2CPP_FN double
lb_abs( double  a );
SCM2CPP_FN double
lb_max( double  a,  double  b );
SCM2CPP_FN double
lb_min( double  a,  double  b );
SCM2CPP_FN std::int64_t
lb_dcstep( std::array<double,8> & cs,  double  fp,  double  dp,  double  stpmin,  double  stpmax );
SCM2CPP_FN std::int64_t
lb_search_start( std::array<double,16> & ls,  double  f,  double  g,  double  stp,  double  stpmin,  double  stpmax,  double  ftol );
SCM2CPP_FN std::int64_t
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax );
double
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  std::int64_t  nv );
double
lb_dot_row( scm2cpp::cspan<double> mem,  std::int64_t  slot,  scm2cpp::cspan<double> v,  std::int64_t  nv );
double
lb_dot_rows( scm2cpp::cspan<double> a,  std::int64_t  ra,  scm2cpp::cspan<double> b,  std::int64_t  rb,  std::int64_t  nv );
SCM2CPP_FN double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  std::int64_t  ib,  double  lbv,  std::int64_t  nv );
std::int64_t
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv );
double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv );
std::int64_t
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  ib,  double  lbv,  std::int64_t  nv );
std::int64_t
lbfgs( std::int64_t  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  std::int64_t  m,  std::int64_t  maxiter,  double  pgtol,  double  ftol,  std::int64_t  maxls,  std::int64_t  ib,  double  lbv,  std::int64_t  nv,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );
SCM2CPP_FN double
lbfgs_fg( std::int64_t  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k );



SCM2CPP_FN inline double
eig_hypot( double  a,  double  b )
{
    double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
    double bb = ( ( b < 0.0 ) ? ((0.0-b)) : (b) );
    if( aa > bb ) {
        return (aa*sqrt((1.0+((bb/aa)*(bb/aa))))) ;
    }
    else {
        if( bb == 0.0 ) {
            return 0.0 ;
        }
        else {
            return (bb*sqrt((1.0+((aa/bb)*(aa/bb))))) ;
        }
    }
}
static __global__ void scm2cpp_k1(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* a, std::int64_t i, std::int64_t m, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t k = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double g3 = 0.0;
    {   g3 = (g3+(a[(((long long)i*m)+k)]*a[(((long long)k*m)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, g3);
}
static __global__ void scm2cpp_k2(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* v, const double* a, std::int64_t m, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
            v[ (((long long)j*m)+i) ] = a[(((long long)i*m)+j)]   ;
        }  ;
    }
}


inline std::int64_t
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m )
{   scm2cpp::cu::need_host(a);
    scm2cpp::cu::need_host(e);
    scm2cpp::cu::need_host(ev);
    for( std::int64_t ii = 0 ; !(ii == (m-1)) ; ii = (ii+1) ) {
        std::int64_t i = ((m-1)-ii);
        std::int64_t l = (i-1);
        double h = 0.0;
        double scale = 0.0;
        if( l > 0 ) {
            for( std::int64_t k = 0 ; !(k > l) ; k = (k+1) ) {
                double ak = a[(((long long)i*m)+k)];
                scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                ;
            }  ;
            if( scale == 0.0 ) {
                e[ i ] = a[(((long long)i*m)+l)]   ;
            } else {
                for( std::int64_t k = 0 ; !(k > l) ; k = (k+1) ) {
                    a[ (((long long)i*m)+k) ] = (a[(((long long)i*m)+k)]/scale)   ;
                    h = (h+(a[(((long long)i*m)+k)]*a[(((long long)i*m)+k)]))  ;
                }  ;
                double f = a[(((long long)i*m)+l)];
                double g = ( ( f >= 0.0 ) ? ((0.0-sqrt(h))) : (sqrt(h)) );
                e[ i ] = (scale*g)   ;
                h = (h-(f*g))  ;
                a[ (((long long)i*m)+l) ] = (f-g)   ;
                double ff = 0.0;
                for( std::int64_t j = 0 ; !(j > l) ; j = (j+1) ) {
                    a[ (((long long)j*m)+i) ] = (a[(((long long)i*m)+j)]/h)   ;
                    double gg = 0.0;
                    for( std::int64_t k = 0 ; !(k > j) ; k = (k+1) ) {
                        gg = (gg+(a[(((long long)j*m)+k)]*a[(((long long)i*m)+k)]))  ;
                    }  ;
                    for( std::int64_t k = (j+1) ; !(k > l) ; k = (k+1) ) {
                        gg = (gg+(a[(((long long)k*m)+j)]*a[(((long long)i*m)+k)]))  ;
                    }  ;
                    e[ j ] = (gg/h)   ;
                    ff = (ff+(e[j]*a[(((long long)i*m)+j)]))  ;
                    ;
                }  ;
                double hh = (ff/(h+h));
                for( std::int64_t j = 0 ; !(j > l) ; j = (j+1) ) {
                    double f2 = a[(((long long)i*m)+j)];
                    double g2 = (e[j]-(hh*f2));
                    e[ j ] = g2   ;
                    for( std::int64_t k = 0 ; !(k > j) ; k = (k+1) ) {
                        a[ (((long long)j*m)+k) ] = (a[(((long long)j*m)+k)]-((f2*e[k])+(g2*a[(((long long)i*m)+k)])))   ;
                    }  ;
                    ;
                    ;
                }  ;
                ;
                ;
                ;
                ;
            }  ;
        } else {
            e[ i ] = a[(((long long)i*m)+l)]   ;
        }  ;
        ev[ i ] = h   ;
        ;
        ;
    }  ;
    scm2cpp::cu::wrote_host(e);
    scm2cpp::cu::wrote_host(a);
    scm2cpp::cu::wrote_host(ev);
    scm2cpp::cu::need_host(ev);
    ev[ 0 ] = 0.0   ;
    scm2cpp::cu::wrote_host(ev);
    scm2cpp::cu::need_host(e);
    e[ 0 ] = 0.0   ;
    scm2cpp::cu::wrote_host(e);
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        scm2cpp::cu::need_host(ev);
        if( !(ev[i] == 0.0) ) {
            for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
                double g3 = 0.0;
                {
                    long scm2cpp_cnt = (long)(i) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k1<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(a), i, m, j, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k1");
                        g3 = g3 + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                    } else {
                        scm2cpp::cu::need_host(a);
                        for( std::int64_t k = 0 ; !(k == i) ; k = (k+1) ) {
                            g3 = (g3+(a[(((long long)i*m)+k)]*a[(((long long)k*m)+j)]))  ;
                        }
                    }
                }  ;
                scm2cpp::cu::need_host(a);
                for( std::int64_t k = 0 ; !(k == i) ; k = (k+1) ) {
                    a[ (((long long)k*m)+j) ] = (a[(((long long)k*m)+j)]-(g3*a[(((long long)k*m)+i)]))   ;
                }  ;
                scm2cpp::cu::wrote_host(a);
                ;
            }  ;
        } else {
            0  ;
        }  ;
        scm2cpp::cu::need_host(ev);
        scm2cpp::cu::need_host(a);
        ev[ i ] = a[(((long long)i*m)+i)]   ;
        scm2cpp::cu::wrote_host(ev);
        scm2cpp::cu::need_host(a);
        a[ (((long long)i*m)+i) ] = 1.0   ;
        scm2cpp::cu::wrote_host(a);
        scm2cpp::cu::need_host(a);
        for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
            a[ (((long long)j*m)+i) ] = 0.0   ;
            a[ (((long long)i*m)+j) ] = 0.0   ;
        }  ;
        scm2cpp::cu::wrote_host(a);
    }  ;
    {   long scm2cpp_cnt = (long)(m) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k2<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(v), scm2cpp::cu::dev(a), m, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k2");
            scm2cpp::cu::wrote_dev(v);
        } else {
            scm2cpp::cu::need_host(v);
            scm2cpp::cu::need_host(a);
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                    v[ (((long long)j*m)+i) ] = a[(((long long)i*m)+j)]   ;
                }  ;
            }
            scm2cpp::cu::wrote_host(v);
        }
    }  ;
    scm2cpp::cu::need_host(e);
    for( std::int64_t i = 1 ; !(i == m) ; i = (i+1) ) {
        e[ (i-1) ] = e[i]   ;
    }  ;
    scm2cpp::cu::wrote_host(e);
    scm2cpp::cu::need_host(e);
    e[ (m-1) ] = 0.0   ;
    scm2cpp::cu::wrote_host(e);
    scm2cpp::cu::need_host(ev);
    scm2cpp::cu::need_host(e);
    scm2cpp::cu::need_host(v);
    for( std::int64_t l = 0 ; !(l == m) ; l = (l+1) ) {
        std::int64_t fin = 0;
        std::int64_t iter = 0;
        for(  ; !((fin == 1 || iter > 60)) ;  ) {
            std::int64_t mm = l;
            std::int64_t found = 0;
            for(  ; !((found == 1 || mm >= (m-1))) ;  ) {
                double dd = (eig_abs(ev[mm])+eig_abs(ev[(mm+1)]));
                if( (eig_abs(e[mm])+dd) == dd ) {
                    found = 1  ;
                } else {
                    mm = (mm+1)  ;
                }  ;
                ;
            }  ;
            if( mm == l ) {
                fin = 1  ;
            } else {
                iter = (iter+1)  ;
                double g = ((ev[(l+1)]-ev[l])/(2.0*e[l]));
                double r = eig_hypot(g,1.0);
                double g4 = ((ev[mm]-ev[l])+(e[l]/(g+( ( g >= 0.0 ) ? (eig_abs(r)) : ((0.0-eig_abs(r))) ))));
                double s = 1.0;
                double c = 1.0;
                double pp = 0.0;
                double gq = g4;
                std::int64_t under = 0;
                std::int64_t i = (mm-1);
                for(  ; !((under == 1 || i < l)) ;  ) {
                    double f = (s*e[i]);
                    double b = (c*e[i]);
                    double r2 = eig_hypot(f,gq);
                    e[ (i+1) ] = r2   ;
                    if( r2 == 0.0 ) {
                        ev[ (i+1) ] = (ev[(i+1)]-pp)   ;
                        e[ mm ] = 0.0   ;
                        under = 1  ;
                    } else {
                        s = (f/r2)  ;
                        c = (gq/r2)  ;
                        double g5 = (ev[(i+1)]-pp);
                        double r3 = (((ev[i]-g5)*s)+(2.0*(c*b)));
                        pp = (s*r3)  ;
                        ev[ (i+1) ] = (g5+pp)   ;
                        gq = ((c*r3)-b)  ;
                        ;
                        ;
                        for( std::int64_t k = 0 ; !(k == m) ; k = (k+1) ) {
                            double zf = v[(((long long)((i+1))*m)+k)];
                            double zi = v[(((long long)i*m)+k)];
                            v[ (((long long)((i+1))*m)+k) ] = ((s*zi)+(c*zf))   ;
                            v[ (((long long)i*m)+k) ] = ((c*zi)-(s*zf))   ;
                            ;
                        }  ;
                        i = (i-1)  ;
                    }  ;
                    ;
                    ;
                }  ;
                if( under == 0 ) {
                    ev[ l ] = (ev[l]-pp)   ;
                    e[ l ] = gq   ;
                    e[ mm ] = 0.0   ;
                } else {
                    0  ;
                }  ;
                ;
                ;
                ;
                ;
            }  ;
            ;
        }  ;
        ;
    }  ;
    scm2cpp::cu::wrote_host(e);
    scm2cpp::cu::wrote_host(ev);
    scm2cpp::cu::wrote_host(v);
    scm2cpp::cu::need_host(v);
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        for( std::int64_t j = (i+1) ; !(j >= m) ; j = (j+1) ) {
            double tmp = v[(((long long)i*m)+j)];
            v[ (((long long)i*m)+j) ] = v[(((long long)j*m)+i)]   ;
            v[ (((long long)j*m)+i) ] = tmp   ;
            ;
        }  ;
    }  ;
    scm2cpp::cu::wrote_host(v);
    return 0 ;
}


SCM2CPP_FN inline double
eig_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}
static __global__ void scm2cpp_k3(long scm2cpp_cnt, std::int64_t scm2cpp_lo, int* ord, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   ord[ j ] = j   ;
    }
}


inline std::int64_t
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  std::int64_t  m )
{  {   long scm2cpp_cnt = (long)(m) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k3<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ord), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k3");
            scm2cpp::cu::wrote_dev(ord);
        } else {
            scm2cpp::cu::need_host(ord);
            for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                ord[ j ] = j   ;
            }
            scm2cpp::cu::wrote_host(ord);
        }
    }  ;
    scm2cpp::cu::need_host(ev);
    scm2cpp::cu::need_host(ord);
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        std::int64_t best = j;
        for( std::int64_t r = (j+1) ; !(r >= m) ; r = (r+1) ) {
            if( ev[ord[r]] > ev[ord[best]] ) {
                best = r  ;
            } else {
                0  ;
            }  ;
        }  ;
        std::int64_t tmp = ord[j];
        ord[ j ] = ord[best]   ;
        ord[ best ] = tmp   ;
        ;
        ;
    }  ;
    scm2cpp::cu::wrote_host(ord);
    return 0 ;
}
static __global__ void scm2cpp_k4(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const int* ord, double* ev, const double* evf, double* v, const double* vf, std::int64_t m, std::int64_t k, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   std::int64_t col = ord[c];
        ev[ c ] = evf[col]   ;
        for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
            v[ (((long long)j*k)+c) ] = vf[(((long long)j*m)+col)]   ;
        }  ;
        ;
    }
}


inline std::int64_t
sym_eigen_top( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m,  std::int64_t  k )
{   std::vector<double> vf((m*m),0.0);
    scm2cpp::cu::fresh(vf);
    std::vector<double> evf(m,0.0);
    scm2cpp::cu::fresh(evf);
    std::vector<int> ord(m,0);
    scm2cpp::cu::fresh(ord);
    sym_eigen(a,vf,evf,e,m)  ;
    eig_order(evf,ord,m)  ;
    {   long scm2cpp_cnt = (long)(k) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k4<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ord), scm2cpp::cu::dev(ev), scm2cpp::cu::dev(evf), scm2cpp::cu::dev(v), scm2cpp::cu::dev(vf), m, k, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k4");
            scm2cpp::cu::wrote_dev(ev);
            scm2cpp::cu::wrote_dev(v);
        } else {
            scm2cpp::cu::need_host(ord);
            scm2cpp::cu::need_host(ev);
            scm2cpp::cu::need_host(evf);
            scm2cpp::cu::need_host(v);
            scm2cpp::cu::need_host(vf);
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                std::int64_t col = ord[c];
                ev[ c ] = evf[col]   ;
                for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                    v[ (((long long)j*k)+c) ] = vf[(((long long)j*m)+col)]   ;
                }  ;
                ;
            }
            scm2cpp::cu::wrote_host(ev);
            scm2cpp::cu::wrote_host(v);
        }
    }  ;
    return 0 ;
}


inline std::int64_t
sym_eigen_gen( scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  std::int64_t  m )
{   scm2cpp::cu::need_host(b);
    for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
        double d = b[(((long long)j*m)+j)];
        for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
            d = (d-(b[(((long long)j*m)+l)]*b[(((long long)j*m)+l)]))  ;
        }  ;
        b[ (((long long)j*m)+j) ] = sqrt(d)   ;
        for( std::int64_t i = (j+1) ; !(i >= m) ; i = (i+1) ) {
            double s = b[(((long long)i*m)+j)];
            for( std::int64_t l = 0 ; !(l == j) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*b[(((long long)j*m)+l)]))  ;
            }  ;
            b[ (((long long)i*m)+j) ] = (s/b[(((long long)j*m)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    scm2cpp::cu::wrote_host(b);
    scm2cpp::cu::need_host(a);
    scm2cpp::cu::need_host(b);
    for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[(((long long)i*m)+c)];
            for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*a[(((long long)l*m)+c)]))  ;
            }  ;
            a[ (((long long)i*m)+c) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
        }  ;
    }  ;
    scm2cpp::cu::wrote_host(a);
    scm2cpp::cu::need_host(a);
    scm2cpp::cu::need_host(b);
    for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
        for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
            double s = a[(((long long)r*m)+i)];
            for( std::int64_t l = 0 ; !(l == i) ; l = (l+1) ) {
                s = (s-(b[(((long long)i*m)+l)]*a[(((long long)r*m)+l)]))  ;
            }  ;
            a[ (((long long)r*m)+i) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
        }  ;
    }  ;
    scm2cpp::cu::wrote_host(a);
    scm2cpp::cu::need_host(a);
    for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
        for( std::int64_t j = 0 ; !(j == i) ; j = (j+1) ) {
            double s = (0.5*(a[(((long long)i*m)+j)]+a[(((long long)j*m)+i)]));
            a[ (((long long)i*m)+j) ] = s   ;
            a[ (((long long)j*m)+i) ] = s   ;
            ;
        }  ;
    }  ;
    scm2cpp::cu::wrote_host(a);
    sym_eigen(a,v,ev,e,m)  ;
    scm2cpp::cu::need_host(v);
    scm2cpp::cu::need_host(b);
    for( std::int64_t c = 0 ; !(c == m) ; c = (c+1) ) {
        for( std::int64_t ii = 0 ; !(ii == m) ; ii = (ii+1) ) {
            std::int64_t i = ((m-1)-ii);
            double s = v[(((long long)i*m)+c)];
            for( std::int64_t l = (i+1) ; !(l >= m) ; l = (l+1) ) {
                s = (s-(b[(((long long)l*m)+i)]*v[(((long long)l*m)+c)]))  ;
            }  ;
            v[ (((long long)i*m)+c) ] = (s/b[(((long long)i*m)+i)])   ;
            ;
            ;
        }  ;
    }  ;
    scm2cpp::cu::wrote_host(v);
    return 0 ;
}


SCM2CPP_FN inline double
ica_tanh( double  x )
{
    return (1.0-(2.0/(exp((2.0*x))+1.0))) ;
}
static __global__ void scm2cpp_k5(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* w, double* a, std::int64_t m, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
            }  ;
            a[ (((long long)i*m)+j) ] = acc   ;
            ;
        }  ;
    }
}
static __global__ void scm2cpp_k6(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* w, double* a, std::int64_t m, std::int64_t i, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
            acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
        }  ;
        a[ (((long long)i*m)+j) ] = acc   ;
        ;
    }
}
static __global__ void scm2cpp_k7(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* w, std::int64_t i, std::int64_t m, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t r = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k8(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* ev, const double* v, double* t, std::int64_t m, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
                ;
            }  ;
            t[ (((long long)i*m)+j) ] = acc   ;
            ;
        }  ;
    }
}
static __global__ void scm2cpp_k9(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* ev, const double* v, double* t, std::int64_t m, std::int64_t i, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
            double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
            acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
            ;
        }  ;
        t[ (((long long)i*m)+j) ] = acc   ;
        ;
    }
}
static __global__ void scm2cpp_k10(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* ev, const double* v, std::int64_t i, std::int64_t m, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t r = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
        acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k11(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* t, const double* w, double* a, std::int64_t m, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
            }  ;
            a[ (((long long)i*m)+j) ] = acc   ;
            ;
        }  ;
    }
}
static __global__ void scm2cpp_k12(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* t, const double* w, double* a, std::int64_t m, std::int64_t i, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
            acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
        }  ;
        a[ (((long long)i*m)+j) ] = acc   ;
        ;
    }
}
static __global__ void scm2cpp_k13(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* t, const double* w, std::int64_t i, std::int64_t m, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t r = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k14(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* w, const double* a, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t2 = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   w[ t2 ] = a[t2]   ;
    }
}


inline std::int64_t
ica_sym( scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> t,  std::int64_t  m )
{  {   long scm2cpp_cnt = (long)(m) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k5<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), scm2cpp::cu::dev(a), m, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k5");
            scm2cpp::cu::wrote_dev(a);
        } else {
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                {
                    long scm2cpp_cnt = (long)(m) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k6<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), scm2cpp::cu::dev(a), m, i, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k6");
                        scm2cpp::cu::wrote_dev(a);
                    } else {
                        for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                            double acc = 0.0;
                            {
                                long scm2cpp_cnt = (long)(m) - (long)(0);
                                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                                    scm2cpp_k7<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), i, m, j, scm2cpp_red);
                                    scm2cpp::cu::launched("scm2cpp_k7");
                                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                                } else {
                                    scm2cpp::cu::need_host(w);
                                    for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                                        acc = (acc+(w[(((long long)i*m)+r)]*w[(((long long)j*m)+r)]))  ;
                                    }
                                }
                            }  ;
                            scm2cpp::cu::need_host(a);
                            a[ (((long long)i*m)+j) ] = acc   ;
                            scm2cpp::cu::wrote_host(a);
                            ;
                        }
                    }
                }  ;
            }
        }
    }  ;
    sym_eigen(a,v,ev,e,m)  ;
    {   long scm2cpp_cnt = (long)(m) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k8<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ev), scm2cpp::cu::dev(v), scm2cpp::cu::dev(t), m, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k8");
            scm2cpp::cu::wrote_dev(t);
        } else {
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                {
                    long scm2cpp_cnt = (long)(m) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k9<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ev), scm2cpp::cu::dev(v), scm2cpp::cu::dev(t), m, i, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k9");
                        scm2cpp::cu::wrote_dev(t);
                    } else {
                        for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                            double acc = 0.0;
                            {
                                long scm2cpp_cnt = (long)(m) - (long)(0);
                                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                                    scm2cpp_k10<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ev), scm2cpp::cu::dev(v), i, m, j, scm2cpp_red);
                                    scm2cpp::cu::launched("scm2cpp_k10");
                                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                                } else {
                                    scm2cpp::cu::need_host(ev);
                                    scm2cpp::cu::need_host(v);
                                    for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                                        double sr = ( ( ev[r] < 2.2250738585072014e-308 ) ? (2.2250738585072014e-308) : (ev[r]) );
                                        acc = (acc+((v[(((long long)i*m)+r)]/sqrt(sr))*v[(((long long)j*m)+r)]))  ;
                                        ;
                                    }
                                }
                            }  ;
                            scm2cpp::cu::need_host(t);
                            t[ (((long long)i*m)+j) ] = acc   ;
                            scm2cpp::cu::wrote_host(t);
                            ;
                        }
                    }
                }  ;
            }
        }
    }  ;
    {   long scm2cpp_cnt = (long)(m) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k11<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(t), scm2cpp::cu::dev(w), scm2cpp::cu::dev(a), m, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k11");
            scm2cpp::cu::wrote_dev(a);
        } else {
            for( std::int64_t i = 0 ; !(i == m) ; i = (i+1) ) {
                {
                    long scm2cpp_cnt = (long)(m) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k12<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(t), scm2cpp::cu::dev(w), scm2cpp::cu::dev(a), m, i, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k12");
                        scm2cpp::cu::wrote_dev(a);
                    } else {
                        for( std::int64_t j = 0 ; !(j == m) ; j = (j+1) ) {
                            double acc = 0.0;
                            {
                                long scm2cpp_cnt = (long)(m) - (long)(0);
                                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                                    scm2cpp_k13<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(t), scm2cpp::cu::dev(w), i, m, j, scm2cpp_red);
                                    scm2cpp::cu::launched("scm2cpp_k13");
                                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                                } else {
                                    scm2cpp::cu::need_host(t);
                                    scm2cpp::cu::need_host(w);
                                    for( std::int64_t r = 0 ; !(r == m) ; r = (r+1) ) {
                                        acc = (acc+(t[(((long long)i*m)+r)]*w[(((long long)r*m)+j)]))  ;
                                    }
                                }
                            }  ;
                            scm2cpp::cu::need_host(a);
                            a[ (((long long)i*m)+j) ] = acc   ;
                            scm2cpp::cu::wrote_host(a);
                            ;
                        }
                    }
                }  ;
            }
        }
    }  ;
    {   long scm2cpp_cnt = (long)((m*m)) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k14<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), scm2cpp::cu::dev(a), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k14");
            scm2cpp::cu::wrote_dev(w);
        } else {
            scm2cpp::cu::need_host(w);
            scm2cpp::cu::need_host(a);
            for( std::int64_t t2 = 0 ; !(t2 == (m*m)) ; t2 = (t2+1) ) {
                w[ t2 ] = a[t2]   ;
            }
            scm2cpp::cu::wrote_host(w);
        }
    }  ;
    return 0 ;
}
static __global__ void scm2cpp_k15(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* mean, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   mean[ j ] = 0.0   ;
    }
}
static __global__ void scm2cpp_k16(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* mean, const double* x, std::int64_t i, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
    }
}
static __global__ void scm2cpp_k17(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* mean, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   mean[ j ] = (mean[j]/double(n))   ;
    }
}
static __global__ void scm2cpp_k18(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* xc, const double* x, const double* mean, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mean[j])   ;
        }  ;
    }
}
static __global__ void scm2cpp_k19(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* xc, const double* x, const double* mean, std::int64_t i, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mean[j])   ;
    }
}
static __global__ void scm2cpp_k20(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const int* ord, const double* u, const double* ev, double* white, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   std::int64_t col = ord[c];
        double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
        double d = sqrt(ev[col]);
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            white[ (((long long)c*p)+j) ] = ((sg*u[(((long long)j*p)+col)])/d)   ;
        }  ;
        ;
        ;
    }
}
static __global__ void scm2cpp_k21(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* white, const double* u, std::int64_t c, std::int64_t p, double sg, std::int64_t col, double d, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   white[ (((long long)c*p)+j) ] = ((sg*u[(((long long)j*p)+col)])/d)   ;
    }
}
static __global__ void scm2cpp_k22(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* x1, double sn, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   x1[ t ] = (x1[t]*sn)   ;
    }
}
static __global__ void scm2cpp_k23(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* unmix, const double* winit, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   unmix[ t ] = winit[t]   ;
    }
}
static __global__ void scm2cpp_k24(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* gw, double* gx, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double th = ica_tanh(gw[(((long long)c*n)+i)]);
            gw[ (((long long)c*n)+i) ] = th   ;
            acc = (acc+(1.0-(th*th)))  ;
            ;
        }  ;
        gx[ c ] = (acc/double(n))   ;
        ;
    }
}
static __global__ void scm2cpp_k25(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* gw, std::int64_t c, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   double th = ica_tanh(gw[(((long long)c*n)+i)]);
        gw[ (((long long)c*n)+i) ] = th   ;
        acc = (acc+(1.0-(th*th)))  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k26(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* w1, const double* gx, const double* unmix, std::int64_t nc, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
            w1[ (((long long)c*nc)+j) ] = ((w1[(((long long)c*nc)+j)]/double(n))-(gx[c]*unmix[(((long long)c*nc)+j)]))   ;
        }  ;
    }
}
static __global__ void scm2cpp_k27(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* w1, const double* gx, const double* unmix, std::int64_t c, std::int64_t nc, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   w1[ (((long long)c*nc)+j) ] = ((w1[(((long long)c*nc)+j)]/double(n))-(gx[c]*unmix[(((long long)c*nc)+j)]))   ;
    }
}
static __global__ void scm2cpp_k28(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* w1, const double* unmix, std::int64_t c, std::int64_t nc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(w1[(((long long)c*nc)+j)]*unmix[(((long long)c*nc)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k29(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* unmix, const double* w1, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   unmix[ t ] = w1[t]   ;
    }
}
static __global__ void scm2cpp_k30(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, double* comps, std::int64_t p, std::int64_t nc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
            }  ;
            comps[ (((long long)c*p)+j) ] = acc   ;
            ;
        }  ;
    }
}
static __global__ void scm2cpp_k31(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, double* comps, std::int64_t nc, std::int64_t c, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
            acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
        }  ;
        comps[ (((long long)c*p)+j) ] = acc   ;
        ;
    }
}
static __global__ void scm2cpp_k32(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, std::int64_t c, std::int64_t nc, std::int64_t p, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t r = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k33(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* gw, double* unmix, std::int64_t n, std::int64_t nc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double m1 = 0.0;
        double v1 = 0.0;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            m1 = (m1+gw[(((long long)c*n)+i)])  ;
        }  ;
        m1 = (m1/double(n))  ;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double dd = (gw[(((long long)c*n)+i)]-m1);
            v1 = (v1+(dd*dd))  ;
            ;
        }  ;
        double sd = sqrt((v1/double(n)));
        for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
            unmix[ (((long long)c*nc)+j) ] = (unmix[(((long long)c*nc)+j)]/sd)   ;
        }  ;
        ;
        ;
    }
}
static __global__ void scm2cpp_k34(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* gw, std::int64_t c, std::int64_t n, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double m1 = 0.0;
    {   m1 = (m1+gw[(((long long)c*n)+i)])  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, m1);
}
static __global__ void scm2cpp_k35(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* gw, std::int64_t c, std::int64_t n, double m1, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double v1 = 0.0;
    {   double dd = (gw[(((long long)c*n)+i)]-m1);
        v1 = (v1+(dd*dd))  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, v1);
}
static __global__ void scm2cpp_k36(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* unmix, std::int64_t c, std::int64_t nc, double sd, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   unmix[ (((long long)c*nc)+j) ] = (unmix[(((long long)c*nc)+j)]/sd)   ;
    }
}
static __global__ void scm2cpp_k37(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, double* comps, std::int64_t p, std::int64_t nc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double acc = 0.0;
            for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
            }  ;
            comps[ (((long long)c*p)+j) ] = acc   ;
            ;
        }  ;
    }
}
static __global__ void scm2cpp_k38(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, double* comps, std::int64_t nc, std::int64_t c, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
            acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
        }  ;
        comps[ (((long long)c*p)+j) ] = acc   ;
        ;
    }
}
static __global__ void scm2cpp_k39(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* unmix, const double* white, std::int64_t c, std::int64_t nc, std::int64_t p, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t r = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline std::int64_t
fastica( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> winit,  scm2cpp::span<double> comps,  scm2cpp::span<double> white,  scm2cpp::span<double> unmix,  scm2cpp::span<double> mean,  std::int64_t  maxiter,  double  tol,  std::int64_t  n,  std::int64_t  p,  std::int64_t  nc )
{   std::vector<double> xc((n*p),0.0);
    scm2cpp::cu::fresh(xc);
    std::vector<double> g((p*p),0.0);
    scm2cpp::cu::fresh(g);
    std::vector<double> u((p*p),0.0);
    scm2cpp::cu::fresh(u);
    std::vector<double> ev(p,0.0);
    scm2cpp::cu::fresh(ev);
    std::vector<int> ord(p,0);
    scm2cpp::cu::fresh(ord);
    std::vector<double> x1((nc*n),0.0);
    scm2cpp::cu::fresh(x1);
    std::vector<double> gw((nc*n),0.0);
    scm2cpp::cu::fresh(gw);
    std::vector<double> w1((nc*nc),0.0);
    scm2cpp::cu::fresh(w1);
    std::vector<double> gx(nc,0.0);
    scm2cpp::cu::fresh(gx);
    std::vector<double> sa((nc*nc),0.0);
    scm2cpp::cu::fresh(sa);
    std::vector<double> sv((nc*nc),0.0);
    scm2cpp::cu::fresh(sv);
    std::vector<double> se(nc,0.0);
    scm2cpp::cu::fresh(se);
    std::vector<double> se2(nc,0.0);
    scm2cpp::cu::fresh(se2);
    std::vector<double> pe(p,0.0);
    scm2cpp::cu::fresh(pe);
    std::vector<double> st((nc*nc),0.0);
    scm2cpp::cu::fresh(st);
    std::int64_t it = 0;
    std::int64_t done = 0;
    {   long scm2cpp_cnt = (long)(p) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k15<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(mean), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k15");
            scm2cpp::cu::wrote_dev(mean);
        } else {
            scm2cpp::cu::need_host(mean);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                mean[ j ] = 0.0   ;
            }
            scm2cpp::cu::wrote_host(mean);
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        {
            long scm2cpp_cnt = (long)(p) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k16<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(mean), scm2cpp::cu::dev(x), i, p, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k16");
                scm2cpp::cu::wrote_dev(mean);
            } else {
                scm2cpp::cu::need_host(mean);
                scm2cpp::cu::need_host(x);
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    mean[ j ] = (mean[j]+x[(((long long)i*p)+j)])   ;
                }
                scm2cpp::cu::wrote_host(mean);
            }
        }  ;
    }  ;
    {   long scm2cpp_cnt = (long)(p) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k17<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(mean), n, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k17");
            scm2cpp::cu::wrote_dev(mean);
        } else {
            scm2cpp::cu::need_host(mean);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                mean[ j ] = (mean[j]/double(n))   ;
            }
            scm2cpp::cu::wrote_host(mean);
        }
    }  ;
    {   long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k18<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(xc), scm2cpp::cu::dev(x), scm2cpp::cu::dev(mean), p, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k18");
            scm2cpp::cu::wrote_dev(xc);
        } else {
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                {
                    long scm2cpp_cnt = (long)(p) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k19<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(xc), scm2cpp::cu::dev(x), scm2cpp::cu::dev(mean), i, p, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k19");
                        scm2cpp::cu::wrote_dev(xc);
                    } else {
                        scm2cpp::cu::need_host(xc);
                        scm2cpp::cu::need_host(x);
                        scm2cpp::cu::need_host(mean);
                        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                            xc[ (((long long)i*p)+j) ] = (x[(((long long)i*p)+j)]-mean[j])   ;
                        }
                        scm2cpp::cu::wrote_host(xc);
                    }
                }  ;
            }
        }
    }  ;
    scm2cpp::cu::blas_syrk(g, xc, 1.0, 0.0, 1, p, n)  ;
    sym_eigen(g,u,ev,pe,p)  ;
    eig_order(ev,ord,p)  ;
    {   long scm2cpp_cnt = (long)(nc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k20<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(ord), scm2cpp::cu::dev(u), scm2cpp::cu::dev(ev), scm2cpp::cu::dev(white), p, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k20");
            scm2cpp::cu::wrote_dev(white);
        } else {
            for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                scm2cpp::cu::need_host(ord);
                std::int64_t col = ord[c];
                scm2cpp::cu::need_host(u);
                scm2cpp::cu::need_host(ev);
                double sg = ( ( u[col] < 0.0 ) ? (-1.0) : (( ( u[col] > 0.0 ) ? (1.0) : (0.0) )) );
                double d = sqrt(ev[col]);
                {
                    long scm2cpp_cnt = (long)(p) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k21<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(white), scm2cpp::cu::dev(u), c, p, sg, col, d, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k21");
                        scm2cpp::cu::wrote_dev(white);
                    } else {
                        scm2cpp::cu::need_host(white);
                        scm2cpp::cu::need_host(u);
                        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                            white[ (((long long)c*p)+j) ] = ((sg*u[(((long long)j*p)+col)])/d)   ;
                        }
                        scm2cpp::cu::wrote_host(white);
                    }
                }  ;
                ;
                ;
            }
        }
    }  ;
    scm2cpp::cu::blas_gemm(x1, white, xc, 1.0, 0.0, 0, 1, nc, n, p)  ;
    double sn = sqrt(double(n));
    {
        long scm2cpp_cnt = (long)((nc*n)) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k22<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(x1), sn, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k22");
            scm2cpp::cu::wrote_dev(x1);
        } else {
            scm2cpp::cu::need_host(x1);
            for( std::int64_t t = 0 ; !(t == (nc*n)) ; t = (t+1) ) {
                x1[ t ] = (x1[t]*sn)   ;
            }
            scm2cpp::cu::wrote_host(x1);
        }
    }  ;
    ;
    {   long scm2cpp_cnt = (long)((nc*nc)) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k23<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(winit), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k23");
            scm2cpp::cu::wrote_dev(unmix);
        } else {
            scm2cpp::cu::need_host(unmix);
            scm2cpp::cu::need_host(winit);
            for( std::int64_t t = 0 ; !(t == (nc*nc)) ; t = (t+1) ) {
                unmix[ t ] = winit[t]   ;
            }
            scm2cpp::cu::wrote_host(unmix);
        }
    }  ;
    ica_sym(unmix,sa,sv,se,se2,st,nc)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        scm2cpp::cu::blas_gemm(gw, unmix, x1, 1.0, 0.0, 0, 0, nc, n, nc)  ;
        {   long scm2cpp_cnt = (long)(nc) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k24<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(gw), scm2cpp::cu::dev(gx), n, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k24");
                scm2cpp::cu::wrote_dev(gw);
                scm2cpp::cu::wrote_dev(gx);
            } else {
                for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                    double acc = 0.0;
                    {
                        long scm2cpp_cnt = (long)(n) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k25<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(gw), c, n, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k25");
                            scm2cpp::cu::wrote_dev(gw);
                            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                        } else {
                            scm2cpp::cu::need_host(gw);
                            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                                double th = ica_tanh(gw[(((long long)c*n)+i)]);
                                gw[ (((long long)c*n)+i) ] = th   ;
                                acc = (acc+(1.0-(th*th)))  ;
                                ;
                            }
                            scm2cpp::cu::wrote_host(gw);
                        }
                    }  ;
                    scm2cpp::cu::need_host(gx);
                    gx[ c ] = (acc/double(n))   ;
                    scm2cpp::cu::wrote_host(gx);
                    ;
                }
            }
        }  ;
        scm2cpp::cu::blas_gemm(w1, gw, x1, 1.0, 0.0, 0, 1, nc, nc, n)  ;
        {   long scm2cpp_cnt = (long)(nc) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k26<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w1), scm2cpp::cu::dev(gx), scm2cpp::cu::dev(unmix), nc, n, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k26");
                scm2cpp::cu::wrote_dev(w1);
            } else {
                for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                    {
                        long scm2cpp_cnt = (long)(nc) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k27<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w1), scm2cpp::cu::dev(gx), scm2cpp::cu::dev(unmix), c, nc, n, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k27");
                            scm2cpp::cu::wrote_dev(w1);
                        } else {
                            scm2cpp::cu::need_host(w1);
                            scm2cpp::cu::need_host(gx);
                            scm2cpp::cu::need_host(unmix);
                            for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                                w1[ (((long long)c*nc)+j) ] = ((w1[(((long long)c*nc)+j)]/double(n))-(gx[c]*unmix[(((long long)c*nc)+j)]))   ;
                            }
                            scm2cpp::cu::wrote_host(w1);
                        }
                    }  ;
                }
            }
        }  ;
        ica_sym(w1,sa,sv,se,se2,st,nc)  ;
        double lim = 0.0;
        for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
            double acc = 0.0;
            {
                long scm2cpp_cnt = (long)(nc) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k28<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w1), scm2cpp::cu::dev(unmix), c, nc, scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k28");
                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                } else {
                    scm2cpp::cu::need_host(w1);
                    scm2cpp::cu::need_host(unmix);
                    for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                        acc = (acc+(w1[(((long long)c*nc)+j)]*unmix[(((long long)c*nc)+j)]))  ;
                    }
                }
            }  ;
            double dv = (( ( acc < 0.0 ) ? ((0.0-acc)) : (acc) )-1.0);
            double av = ( ( dv < 0.0 ) ? ((0.0-dv)) : (dv) );
            if( av > lim ) {
                lim = av  ;
            } else {
                0  ;
            }  ;
            ;
            ;
            ;
        }  ;
        {   long scm2cpp_cnt = (long)((nc*nc)) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k29<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(w1), scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k29");
                scm2cpp::cu::wrote_dev(unmix);
            } else {
                scm2cpp::cu::need_host(unmix);
                scm2cpp::cu::need_host(w1);
                for( std::int64_t t = 0 ; !(t == (nc*nc)) ; t = (t+1) ) {
                    unmix[ t ] = w1[t]   ;
                }
                scm2cpp::cu::wrote_host(unmix);
            }
        }  ;
        it = (it+1)  ;
        if( lim < tol ) {
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    {   long scm2cpp_cnt = (long)(nc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k30<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), scm2cpp::cu::dev(comps), p, nc, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k30");
            scm2cpp::cu::wrote_dev(comps);
        } else {
            for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                {
                    long scm2cpp_cnt = (long)(p) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k31<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), scm2cpp::cu::dev(comps), nc, c, p, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k31");
                        scm2cpp::cu::wrote_dev(comps);
                    } else {
                        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                            double acc = 0.0;
                            {
                                long scm2cpp_cnt = (long)(nc) - (long)(0);
                                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                                    scm2cpp_k32<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), c, nc, p, j, scm2cpp_red);
                                    scm2cpp::cu::launched("scm2cpp_k32");
                                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                                } else {
                                    scm2cpp::cu::need_host(unmix);
                                    scm2cpp::cu::need_host(white);
                                    for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                                        acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                                    }
                                }
                            }  ;
                            scm2cpp::cu::need_host(comps);
                            comps[ (((long long)c*p)+j) ] = acc   ;
                            scm2cpp::cu::wrote_host(comps);
                            ;
                        }
                    }
                }  ;
            }
        }
    }  ;
    scm2cpp::cu::blas_gemm(gw, comps, xc, 1.0, 0.0, 0, 1, nc, n, p)  ;
    {   long scm2cpp_cnt = (long)(nc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k33<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(gw), scm2cpp::cu::dev(unmix), n, nc, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k33");
            scm2cpp::cu::wrote_dev(unmix);
        } else {
            for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                double m1 = 0.0;
                double v1 = 0.0;
                {
                    long scm2cpp_cnt = (long)(n) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k34<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(gw), c, n, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k34");
                        m1 = m1 + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                    } else {
                        scm2cpp::cu::need_host(gw);
                        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                            m1 = (m1+gw[(((long long)c*n)+i)])  ;
                        }
                    }
                }  ;
                m1 = (m1/double(n))  ;
                {   long scm2cpp_cnt = (long)(n) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k35<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(gw), c, n, m1, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k35");
                        v1 = v1 + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                    } else {
                        scm2cpp::cu::need_host(gw);
                        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                            double dd = (gw[(((long long)c*n)+i)]-m1);
                            v1 = (v1+(dd*dd))  ;
                            ;
                        }
                    }
                }  ;
                double sd = sqrt((v1/double(n)));
                {
                    long scm2cpp_cnt = (long)(nc) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k36<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), c, nc, sd, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k36");
                        scm2cpp::cu::wrote_dev(unmix);
                    } else {
                        scm2cpp::cu::need_host(unmix);
                        for( std::int64_t j = 0 ; !(j == nc) ; j = (j+1) ) {
                            unmix[ (((long long)c*nc)+j) ] = (unmix[(((long long)c*nc)+j)]/sd)   ;
                        }
                        scm2cpp::cu::wrote_host(unmix);
                    }
                }  ;
                ;
                ;
            }
        }
    }  ;
    {   long scm2cpp_cnt = (long)(nc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k37<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), scm2cpp::cu::dev(comps), p, nc, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k37");
            scm2cpp::cu::wrote_dev(comps);
        } else {
            for( std::int64_t c = 0 ; !(c == nc) ; c = (c+1) ) {
                {
                    long scm2cpp_cnt = (long)(p) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k38<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), scm2cpp::cu::dev(comps), nc, c, p, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k38");
                        scm2cpp::cu::wrote_dev(comps);
                    } else {
                        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                            double acc = 0.0;
                            {
                                long scm2cpp_cnt = (long)(nc) - (long)(0);
                                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                                    scm2cpp_k39<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(unmix), scm2cpp::cu::dev(white), c, nc, p, j, scm2cpp_red);
                                    scm2cpp::cu::launched("scm2cpp_k39");
                                    acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                                } else {
                                    scm2cpp::cu::need_host(unmix);
                                    scm2cpp::cu::need_host(white);
                                    for( std::int64_t r = 0 ; !(r == nc) ; r = (r+1) ) {
                                        acc = (acc+(unmix[(((long long)c*nc)+r)]*white[(((long long)r*p)+j)]))  ;
                                    }
                                }
                            }  ;
                            scm2cpp::cu::need_host(comps);
                            comps[ (((long long)c*p)+j) ] = acc   ;
                            scm2cpp::cu::wrote_host(comps);
                            ;
                        }
                    }
                }  ;
            }
        }
    }  ;
    return it ;
}
static __global__ void scm2cpp_k40(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* weights, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   weights[ c ] = 0.0   ;
    }
}
static __global__ void scm2cpp_k41(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* weights, const double* resp, std::int64_t i, std::int64_t kc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   weights[ c ] = (weights[c]+resp[(((long long)i*kc)+c)])   ;
    }
}
static __global__ void scm2cpp_k42(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* weights, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double tot = 0.0;
    {   weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
        tot = (tot+weights[c])  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, tot);
}
static __global__ void scm2cpp_k43(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* means, std::int64_t c, std::int64_t p, double nk, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/nk)   ;
    }
}
static __global__ void scm2cpp_k44(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* resp, const double* x, const double* means, double* u, double* dw, std::int64_t kc, std::int64_t c, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double r = resp[(((long long)i*kc)+c)];
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double dv = (x[(((long long)i*p)+j)]-means[(((long long)c*p)+j)]);
            u[ (((long long)i*p)+j) ] = dv   ;
            dw[ (((long long)i*p)+j) ] = (r*dv)   ;
            ;
        }  ;
        ;
    }
}
static __global__ void scm2cpp_k45(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* x, const double* means, double* u, double* dw, std::int64_t i, std::int64_t p, std::int64_t c, double r, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double dv = (x[(((long long)i*p)+j)]-means[(((long long)c*p)+j)]);
        u[ (((long long)i*p)+j) ] = dv   ;
        dw[ (((long long)i*p)+j) ] = (r*dv)   ;
        ;
    }
}
static __global__ void scm2cpp_k46(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* cov, double nk, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   cov[ t ] = (cov[t]/nk)   ;
    }
}
static __global__ void scm2cpp_k47(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* prec, std::int64_t c, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   prec[ (((long long)c*(p*p))+t) ] = 0.0   ;
    }
}
static __global__ void scm2cpp_k48(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* weights, std::int64_t norm, std::int64_t n, double tot, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
    }
}


inline std::int64_t
gmm_mstep( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> dw,  scm2cpp::span<double> cov,  scm2cpp::span<double> l,  scm2cpp::span<double> u,  double  reg,  std::int64_t  norm,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   double tot = 0.0;
    {   long scm2cpp_cnt = (long)(kc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k40<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(weights), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k40");
            scm2cpp::cu::wrote_dev(weights);
        } else {
            scm2cpp::cu::need_host(weights);
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                weights[ c ] = 0.0   ;
            }
            scm2cpp::cu::wrote_host(weights);
        }
    }  ;
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        {
            long scm2cpp_cnt = (long)(kc) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k41<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(weights), scm2cpp::cu::dev(resp), i, kc, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k41");
                scm2cpp::cu::wrote_dev(weights);
            } else {
                scm2cpp::cu::need_host(weights);
                scm2cpp::cu::need_host(resp);
                for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                    weights[ c ] = (weights[c]+resp[(((long long)i*kc)+c)])   ;
                }
                scm2cpp::cu::wrote_host(weights);
            }
        }  ;
    }  ;
    {   long scm2cpp_cnt = (long)(kc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k42<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(weights), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k42");
            scm2cpp::cu::wrote_dev(weights);
            tot = tot + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(weights);
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                weights[ c ] = (weights[c]+(10.0*2.220446049250313e-16))   ;
                tot = (tot+weights[c])  ;
            }
            scm2cpp::cu::wrote_host(weights);
        }
    }  ;
    scm2cpp::cu::blas_gemm(means, resp, x, 1.0, 0.0, 1, 0, kc, p, n)  ;
    for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
        scm2cpp::cu::need_host(weights);
        double nk = weights[c];
        {
            long scm2cpp_cnt = (long)(p) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k43<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(means), c, p, nk, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k43");
                scm2cpp::cu::wrote_dev(means);
            } else {
                scm2cpp::cu::need_host(means);
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    means[ (((long long)c*p)+j) ] = (means[(((long long)c*p)+j)]/nk)   ;
                }
                scm2cpp::cu::wrote_host(means);
            }
        }  ;
        {   long scm2cpp_cnt = (long)(n) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k44<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(resp), scm2cpp::cu::dev(x), scm2cpp::cu::dev(means), scm2cpp::cu::dev(u), scm2cpp::cu::dev(dw), kc, c, p, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k44");
                scm2cpp::cu::wrote_dev(u);
                scm2cpp::cu::wrote_dev(dw);
            } else {
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    scm2cpp::cu::need_host(resp);
                    double r = resp[(((long long)i*kc)+c)];
                    {
                        long scm2cpp_cnt = (long)(p) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k45<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(x), scm2cpp::cu::dev(means), scm2cpp::cu::dev(u), scm2cpp::cu::dev(dw), i, p, c, r, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k45");
                            scm2cpp::cu::wrote_dev(u);
                            scm2cpp::cu::wrote_dev(dw);
                        } else {
                            scm2cpp::cu::need_host(x);
                            scm2cpp::cu::need_host(means);
                            scm2cpp::cu::need_host(u);
                            scm2cpp::cu::need_host(dw);
                            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                                double dv = (x[(((long long)i*p)+j)]-means[(((long long)c*p)+j)]);
                                u[ (((long long)i*p)+j) ] = dv   ;
                                dw[ (((long long)i*p)+j) ] = (r*dv)   ;
                                ;
                            }
                            scm2cpp::cu::wrote_host(u);
                            scm2cpp::cu::wrote_host(dw);
                        }
                    }  ;
                    ;
                }
            }
        }  ;
        scm2cpp::cu::blas_gemm(cov, dw, u, 1.0, 0.0, 1, 0, p, p, n)  ;
        {   long scm2cpp_cnt = (long)((p*p)) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k46<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(cov), nk, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k46");
                scm2cpp::cu::wrote_dev(cov);
            } else {
                scm2cpp::cu::need_host(cov);
                for( std::int64_t t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
                    cov[ t ] = (cov[t]/nk)   ;
                }
                scm2cpp::cu::wrote_host(cov);
            }
        }  ;
        scm2cpp::cu::need_host(cov);
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            cov[ (((long long)j*p)+j) ] = (cov[(((long long)j*p)+j)]+reg)   ;
        }  ;
        scm2cpp::cu::wrote_host(cov);
        scm2cpp::cu::need_host(cov);
        scm2cpp::cu::need_host(l);
        for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
            double s = cov[(((long long)j*p)+j)];
            for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
                s = (s-(l[(((long long)j*p)+m)]*l[(((long long)j*p)+m)]))  ;
            }  ;
            l[ (((long long)j*p)+j) ] = sqrt(s)   ;
            for( std::int64_t i = (j+1) ; !(i >= p) ; i = (i+1) ) {
                double t2 = cov[(((long long)i*p)+j)];
                for( std::int64_t m = 0 ; !(m == j) ; m = (m+1) ) {
                    t2 = (t2-(l[(((long long)i*p)+m)]*l[(((long long)j*p)+m)]))  ;
                }  ;
                l[ (((long long)i*p)+j) ] = (t2/l[(((long long)j*p)+j)])   ;
                ;
            }  ;
            ;
        }  ;
        scm2cpp::cu::wrote_host(l);
        {   long scm2cpp_cnt = (long)((p*p)) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k47<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(prec), c, p, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k47");
                scm2cpp::cu::wrote_dev(prec);
            } else {
                scm2cpp::cu::need_host(prec);
                for( std::int64_t t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
                    prec[ (((long long)c*(p*p))+t) ] = 0.0   ;
                }
                scm2cpp::cu::wrote_host(prec);
            }
        }  ;
        scm2cpp::cu::need_host(l);
        scm2cpp::cu::need_host(prec);
        for( std::int64_t e = 0 ; !(e == p) ; e = (e+1) ) {
            for( std::int64_t i = e ; !(i == p) ; i = (i+1) ) {
                double t3 = ( ( i == e ) ? (1.0) : (0.0) );
                for( std::int64_t m = e ; !(m == i) ; m = (m+1) ) {
                    t3 = (t3-(l[(((long long)i*p)+m)]*prec[(((long long)c*(p*p))+(((long long)e*p)+m))]))  ;
                }  ;
                prec[ (((long long)c*(p*p))+(((long long)e*p)+i)) ] = (t3/l[(((long long)i*p)+i)])   ;
                ;
            }  ;
        }  ;
        scm2cpp::cu::wrote_host(prec);
        ;
    }  ;
    {   long scm2cpp_cnt = (long)(kc) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k48<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(weights), norm, n, tot, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k48");
            scm2cpp::cu::wrote_dev(weights);
        } else {
            scm2cpp::cu::need_host(weights);
            for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                weights[ c ] = (weights[c]/( ( norm == 1 ) ? (double(n)) : (tot) ))   ;
            }
            scm2cpp::cu::wrote_host(weights);
        }
    }  ;
    return 0 ;
}
static __global__ void scm2cpp_k49(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* u, const double* prec, std::int64_t c, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   u[ t ] = prec[(((long long)c*(p*p))+t)]   ;
    }
}
static __global__ void scm2cpp_k50(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* u, const double* means, double* mu, std::int64_t p, std::int64_t c, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double logdet = 0.0;
    {   logdet = (logdet+log(u[(((long long)j*p)+j)]))  ;
        double acc = 0.0;
        for( std::int64_t m = 0 ; !(m == p) ; m = (m+1) ) {
            acc = (acc+(means[(((long long)c*p)+m)]*u[(((long long)m*p)+j)]))  ;
        }  ;
        mu[ j ] = acc   ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, logdet);
}
static __global__ void scm2cpp_k51(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* means, const double* u, std::int64_t c, std::int64_t p, std::int64_t j, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t m = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(means[(((long long)c*p)+m)]*u[(((long long)m*p)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}
static __global__ void scm2cpp_k52(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* y, const double* mu, std::int64_t i, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double sq = 0.0;
    {   double v = (y[(((long long)i*p)+j)]-mu[j]);
        sq = (sq+(v*v))  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, sq);
}
static __global__ void scm2cpp_k53(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* wlp, double* resp, std::int64_t kc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double lb = 0.0;
    {   double amax = wlp[((long long)i*kc)];
        double se = 0.0;
        for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
            if( wlp[(((long long)i*kc)+c)] > amax ) {
                amax = wlp[(((long long)i*kc)+c)]  ;
            } else {
                0  ;
            }  ;
        }  ;
        for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
            se = (se+exp((wlp[(((long long)i*kc)+c)]-amax)))  ;
        }  ;
        double lse = (log(se)+amax);
        lb = (lb+lse)  ;
        for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
            resp[ (((long long)i*kc)+c) ] = exp((wlp[(((long long)i*kc)+c)]-lse))   ;
        }  ;
        ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, lb);
}
static __global__ void scm2cpp_k54(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* wlp, std::int64_t i, std::int64_t kc, double amax, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double se = 0.0;
    {   se = (se+exp((wlp[(((long long)i*kc)+c)]-amax)))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, se);
}
static __global__ void scm2cpp_k55(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* resp, const double* wlp, std::int64_t i, std::int64_t kc, double lse, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   resp[ (((long long)i*kc)+c) ] = exp((wlp[(((long long)i*kc)+c)]-lse))   ;
    }
}


inline double
gmm_estep( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::cspan<double> weights,  scm2cpp::cspan<double> means,  scm2cpp::cspan<double> prec,  scm2cpp::span<double> wlp,  scm2cpp::span<double> y,  scm2cpp::span<double> u,  scm2cpp::span<double> mu,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
        scm2cpp::cu::need_host(weights);
        double logdet = 0.0;
        double lw = log(weights[c]);
        {
            long scm2cpp_cnt = (long)((p*p)) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k49<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(u), scm2cpp::cu::dev(prec), c, p, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k49");
                scm2cpp::cu::wrote_dev(u);
            } else {
                scm2cpp::cu::need_host(u);
                scm2cpp::cu::need_host(prec);
                for( std::int64_t t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
                    u[ t ] = prec[(((long long)c*(p*p))+t)]   ;
                }
                scm2cpp::cu::wrote_host(u);
            }
        }  ;
        {   long scm2cpp_cnt = (long)(p) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k50<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(u), scm2cpp::cu::dev(means), scm2cpp::cu::dev(mu), p, c, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k50");
                scm2cpp::cu::wrote_dev(mu);
                logdet = logdet + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
            } else {
                for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                    scm2cpp::cu::need_host(u);
                    logdet = (logdet+log(u[(((long long)j*p)+j)]))  ;
                    double acc = 0.0;
                    {
                        long scm2cpp_cnt = (long)(p) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k51<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(means), scm2cpp::cu::dev(u), c, p, j, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k51");
                            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                        } else {
                            scm2cpp::cu::need_host(means);
                            scm2cpp::cu::need_host(u);
                            for( std::int64_t m = 0 ; !(m == p) ; m = (m+1) ) {
                                acc = (acc+(means[(((long long)c*p)+m)]*u[(((long long)m*p)+j)]))  ;
                            }
                        }
                    }  ;
                    scm2cpp::cu::need_host(mu);
                    mu[ j ] = acc   ;
                    scm2cpp::cu::wrote_host(mu);
                    ;
                }
            }
        }  ;
        scm2cpp::cu::blas_gemm(y, x, u, 1.0, 0.0, 0, 0, n, p, p)  ;
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            double sq = 0.0;
            {
                long scm2cpp_cnt = (long)(p) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k52<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(y), scm2cpp::cu::dev(mu), i, p, scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k52");
                    sq = sq + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                } else {
                    scm2cpp::cu::need_host(y);
                    scm2cpp::cu::need_host(mu);
                    for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                        double v = (y[(((long long)i*p)+j)]-mu[j]);
                        sq = (sq+(v*v))  ;
                        ;
                    }
                }
            }  ;
            scm2cpp::cu::need_host(wlp);
            wlp[ (((long long)i*kc)+c) ] = (((-0.5*((double(p)*1.8378770664093453)+sq))+logdet)+lw)   ;
            scm2cpp::cu::wrote_host(wlp);
            ;
        }  ;
        ;
    }  ;
    double lb = 0.0;
    {
        long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k53<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(wlp), scm2cpp::cu::dev(resp), kc, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k53");
            scm2cpp::cu::wrote_dev(resp);
            lb = lb + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                scm2cpp::cu::need_host(wlp);
                double amax = wlp[((long long)i*kc)];
                double se = 0.0;
                scm2cpp::cu::need_host(wlp);
                for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                    if( wlp[(((long long)i*kc)+c)] > amax ) {
                        amax = wlp[(((long long)i*kc)+c)]  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                {   long scm2cpp_cnt = (long)(kc) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k54<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(wlp), i, kc, amax, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k54");
                        se = se + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                    } else {
                        scm2cpp::cu::need_host(wlp);
                        for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                            se = (se+exp((wlp[(((long long)i*kc)+c)]-amax)))  ;
                        }
                    }
                }  ;
                double lse = (log(se)+amax);
                lb = (lb+lse)  ;
                {   long scm2cpp_cnt = (long)(kc) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k55<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(resp), scm2cpp::cu::dev(wlp), i, kc, lse, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k55");
                        scm2cpp::cu::wrote_dev(resp);
                    } else {
                        scm2cpp::cu::need_host(resp);
                        scm2cpp::cu::need_host(wlp);
                        for( std::int64_t c = 0 ; !(c == kc) ; c = (c+1) ) {
                            resp[ (((long long)i*kc)+c) ] = exp((wlp[(((long long)i*kc)+c)]-lse))   ;
                        }
                        scm2cpp::cu::wrote_host(resp);
                    }
                }  ;
                ;
                ;
            }
        }
    }  ;
    return (lb/double(n)) ;
}


SCM2CPP_FN inline double
gmm_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}
static __global__ void scm2cpp_k56(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* resp, double* labels, std::int64_t kc, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   std::int64_t best = 0;
        double bv = resp[((long long)i*kc)];
        for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
            if( resp[(((long long)i*kc)+c)] > bv ) {
                bv = resp[(((long long)i*kc)+c)]  ;
                best = c  ;
            } else {
                0  ;
            }  ;
        }  ;
        labels[ i ] = double(best)   ;
        ;
    }
}


inline std::int64_t
gmm( scm2cpp::cspan<double> x,  scm2cpp::span<double> resp,  scm2cpp::span<double> weights,  scm2cpp::span<double> means,  scm2cpp::span<double> prec,  scm2cpp::span<double> labels,  scm2cpp::span<double> out,  std::int64_t  maxiter,  double  tol,  double  reg,  std::int64_t  n,  std::int64_t  p,  std::int64_t  kc )
{   std::vector<double> dw((n*p),0.0);
    scm2cpp::cu::fresh(dw);
    std::vector<double> y((n*p),0.0);
    scm2cpp::cu::fresh(y);
    std::vector<double> wlp((n*kc),0.0);
    scm2cpp::cu::fresh(wlp);
    std::vector<double> cov((p*p),0.0);
    scm2cpp::cu::fresh(cov);
    std::vector<double> l((p*p),0.0);
    scm2cpp::cu::fresh(l);
    std::vector<double> u((p*p),0.0);
    scm2cpp::cu::fresh(u);
    std::vector<double> mu(p,0.0);
    scm2cpp::cu::fresh(mu);
    double lb = -1e+300;
    std::int64_t it = 0;
    std::int64_t conv = 0;
    std::int64_t done = 0;
    gmm_mstep(x,resp,weights,means,prec,dw,cov,l,y,reg,1,n,p,kc)  ;
    for(  ; !((done == 1 || it >= maxiter)) ;  ) {
        double prev = lb;
        lb = gmm_estep(x,resp,weights,means,prec,wlp,y,u,mu,n,p,kc)  ;
        gmm_mstep(x,resp,weights,means,prec,dw,cov,l,y,reg,0,n,p,kc)  ;
        it = (it+1)  ;
        if( (it > 1 && gmm_abs(double((lb-prev))) < tol) ) {
            conv = 1  ;
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    gmm_estep(x,resp,weights,means,prec,wlp,y,u,mu,n,p,kc)  ;
    {   long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k56<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(resp), scm2cpp::cu::dev(labels), kc, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k56");
            scm2cpp::cu::wrote_dev(labels);
        } else {
            scm2cpp::cu::need_host(resp);
            scm2cpp::cu::need_host(labels);
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                std::int64_t best = 0;
                double bv = resp[((long long)i*kc)];
                for( std::int64_t c = 1 ; !(c == kc) ; c = (c+1) ) {
                    if( resp[(((long long)i*kc)+c)] > bv ) {
                        bv = resp[(((long long)i*kc)+c)]  ;
                        best = c  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                labels[ i ] = double(best)   ;
                ;
            }
            scm2cpp::cu::wrote_host(labels);
        }
    }  ;
    scm2cpp::cu::need_host(out);
    out[ 0 ] = lb   ;
    scm2cpp::cu::wrote_host(out);
    scm2cpp::cu::need_host(out);
    out[ 1 ] = double(conv)   ;
    scm2cpp::cu::wrote_host(out);
    return it ;
}
static __global__ void scm2cpp_k57(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, const double* coef, std::int64_t k, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
{   for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
            z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]+coef[(((long long)k*p)+c)])   ;
        }  ;
    }
}
static __global__ void scm2cpp_k58(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, const double* coef, std::int64_t i, std::int64_t k, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]+coef[(((long long)k*p)+c)])   ;
    }
}
static __global__ void scm2cpp_k59(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, const double* y, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double loss = 0.0;
    {   double zi = z[i];
        double yi = y[i];
        if( zi <= -2.0 ) {
            double e1 = exp(zi);
            if( zi <= -37.0 ) {
                loss = (loss+(e1-(yi*zi)))  ;
                z[ i ] = (e1-yi)   ;
            } else {
                loss = (loss+(log((1.0+e1))-(yi*zi)))  ;
                z[ i ] = ((((1.0-yi)*e1)-yi)/(1.0+e1))   ;
            }  ;
            ;
        } else {
            double e2 = exp((0.0-zi));
            loss = (loss+(( ( zi <= 18.0 ) ? (log((1.0+e2))) : (e2) )+((1.0-yi)*zi)))  ;
            z[ i ] = (((1.0-yi)-(yi*e2))/(1.0+e2))   ;
            ;
        }  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, loss);
}
static __global__ void scm2cpp_k60(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, std::int64_t i, std::int64_t k, double zmax, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double se = 0.0;
    {   double ec = exp((z[(((long long)i*k)+c)]-zmax));
        z[ (((long long)i*k)+c) ] = ec   ;
        se = (se+ec)  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, se);
}
static __global__ void scm2cpp_k61(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, std::int64_t i, std::int64_t k, double se, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]/se)   ;
    }
}
static __global__ void scm2cpp_k62(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* coef, double* g, std::int64_t n, double l2, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t t = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double pen = 0.0;
    {   double wt = coef[t];
        pen = (pen+(wt*wt))  ;
        g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, pen);
}
static __global__ void scm2cpp_k63(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* z, double* g, std::int64_t fitint, std::int64_t n, std::int64_t k, std::int64_t p, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t c = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double acc = 0.0;
        if( fitint == 1 ) {
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                acc = (acc+z[(((long long)i*k)+c)])  ;
            }  ;
        } else {
            0  ;
        }  ;
        g[ (((long long)k*p)+c) ] = (acc/double(n))   ;
        ;
    }
}
static __global__ void scm2cpp_k64(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* z, std::int64_t k, std::int64_t c, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+z[(((long long)i*k)+c)])  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline double
logistic_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  l2,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   double loss = 0.0;
    double pen = 0.0;
    scm2cpp::cu::blas_gemm(z, x, coef, 1.0, 0.0, 0, 1, n, k, p)  ;
    {   long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k57<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp::cu::dev(coef), k, p, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k57");
            scm2cpp::cu::wrote_dev(z);
        } else {
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                {
                    long scm2cpp_cnt = (long)(k) - (long)(0);
                    if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                        double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                        scm2cpp_k58<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp::cu::dev(coef), i, k, p, scm2cpp_red);
                        scm2cpp::cu::launched("scm2cpp_k58");
                        scm2cpp::cu::wrote_dev(z);
                    } else {
                        scm2cpp::cu::need_host(z);
                        scm2cpp::cu::need_host(coef);
                        for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                            z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]+coef[(((long long)k*p)+c)])   ;
                        }
                        scm2cpp::cu::wrote_host(z);
                    }
                }  ;
            }
        }
    }  ;
    if( multi == 0 ) {
        {
            long scm2cpp_cnt = (long)(n) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k59<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp::cu::dev(y), scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k59");
                scm2cpp::cu::wrote_dev(z);
                loss = loss + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
            } else {
                scm2cpp::cu::need_host(z);
                scm2cpp::cu::need_host(y);
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    double zi = z[i];
                    double yi = y[i];
                    if( zi <= -2.0 ) {
                        double e1 = exp(zi);
                        if( zi <= -37.0 ) {
                            loss = (loss+(e1-(yi*zi)))  ;
                            z[ i ] = (e1-yi)   ;
                        } else {
                            loss = (loss+(log((1.0+e1))-(yi*zi)))  ;
                            z[ i ] = ((((1.0-yi)*e1)-yi)/(1.0+e1))   ;
                        }  ;
                        ;
                    } else {
                        double e2 = exp((0.0-zi));
                        loss = (loss+(( ( zi <= 18.0 ) ? (log((1.0+e2))) : (e2) )+((1.0-yi)*zi)))  ;
                        z[ i ] = (((1.0-yi)-(yi*e2))/(1.0+e2))   ;
                        ;
                    }  ;
                    ;
                }
                scm2cpp::cu::wrote_host(z);
            }
        }  ;
    } else {
        for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
            scm2cpp::cu::need_host(z);
            scm2cpp::cu::need_host(y);
            double zmax = z[((long long)i*k)];
            double se = 0.0;
            double yc = y[i];
            scm2cpp::cu::need_host(z);
            for( std::int64_t c = 1 ; !(c == k) ; c = (c+1) ) {
                if( z[(((long long)i*k)+c)] > zmax ) {
                    zmax = z[(((long long)i*k)+c)]  ;
                } else {
                    0  ;
                }  ;
            }  ;
            scm2cpp::cu::need_host(z);
            loss = (loss-z[(((long long)i*k)+std::int64_t(yc))])  ;
            {   long scm2cpp_cnt = (long)(k) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k60<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), i, k, zmax, scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k60");
                    scm2cpp::cu::wrote_dev(z);
                    se = se + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                } else {
                    scm2cpp::cu::need_host(z);
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        double ec = exp((z[(((long long)i*k)+c)]-zmax));
                        z[ (((long long)i*k)+c) ] = ec   ;
                        se = (se+ec)  ;
                        ;
                    }
                    scm2cpp::cu::wrote_host(z);
                }
            }  ;
            loss = (loss+(zmax+log(se)))  ;
            {   long scm2cpp_cnt = (long)(k) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k61<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), i, k, se, scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k61");
                    scm2cpp::cu::wrote_dev(z);
                } else {
                    scm2cpp::cu::need_host(z);
                    for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                        z[ (((long long)i*k)+c) ] = (z[(((long long)i*k)+c)]/se)   ;
                    }
                    scm2cpp::cu::wrote_host(z);
                }
            }  ;
            scm2cpp::cu::need_host(z);
            std::int64_t iy = ((i*k)+std::int64_t(yc));
            z[ iy ] = (z[iy]-1.0)   ;
            ;
            scm2cpp::cu::wrote_host(z);
            ;
        }  ;
    }  ;
    scm2cpp::cu::blas_gemm(g, z, x, 1.0, 0.0, 1, 0, k, p, n)  ;
    {   long scm2cpp_cnt = (long)((k*p)) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k62<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(coef), scm2cpp::cu::dev(g), n, l2, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k62");
            scm2cpp::cu::wrote_dev(g);
            pen = pen + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(coef);
            scm2cpp::cu::need_host(g);
            for( std::int64_t t = 0 ; !(t == (k*p)) ; t = (t+1) ) {
                double wt = coef[t];
                pen = (pen+(wt*wt))  ;
                g[ t ] = ((g[t]/double(n))+(l2*wt))   ;
                ;
            }
            scm2cpp::cu::wrote_host(g);
        }
    }  ;
    {   long scm2cpp_cnt = (long)(k) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k63<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp::cu::dev(g), fitint, n, k, p, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k63");
            scm2cpp::cu::wrote_dev(g);
        } else {
            for( std::int64_t c = 0 ; !(c == k) ; c = (c+1) ) {
                double acc = 0.0;
                if( fitint == 1 ) {
                    {
                        long scm2cpp_cnt = (long)(n) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k64<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), k, c, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k64");
                            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                        } else {
                            scm2cpp::cu::need_host(z);
                            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                                acc = (acc+z[(((long long)i*k)+c)])  ;
                            }
                        }
                    }  ;
                } else {
                    0  ;
                }  ;
                scm2cpp::cu::need_host(g);
                g[ (((long long)k*p)+c) ] = (acc/double(n))   ;
                scm2cpp::cu::wrote_host(g);
                ;
            }
        }
    }  ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}


inline std::int64_t
logistic_lbfgs( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  c,  std::int64_t  maxiter,  double  tol,  std::int64_t  multi,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    scm2cpp::cu::fresh(aux);
    std::vector<double> work((n*k),0.0);
    scm2cpp::cu::fresh(work);
    scm2cpp::cu::need_host(aux);
    aux[ 0 ] = (1.0/(c*double(n)))   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 1 ] = ( ( multi == 1 ) ? (1.0) : (0.0) )   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    scm2cpp::cu::wrote_host(aux);
    return lbfgs(0,coef,x,y,aux,work,out,10,maxiter,tol,(64.0*2.220446049250313e-16),50,-1,0.0,(k*(p+1)),n,p,k) ;
}
static __global__ void scm2cpp_k65(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* coef, double* g, double alpha, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double ww = 0.0;
    {   double wj = coef[j];
        ww = (ww+(wj*wj))  ;
        g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, ww);
}


inline double
huber_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  double  epsilon,  double  alpha,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   scm2cpp::cu::need_host(coef);
    double b = coef[p];
    double sigma = coef[(p+1)];
    std::int64_t nout = 0;
    double outsum = 0.0;
    double sq = 0.0;
    double csum = 0.0;
    double ww = 0.0;
    scm2cpp::cu::blas_gemv(z, x, coef, 1.0, 0.0, 0, n, p)  ;
    scm2cpp::cu::need_host(y);
    scm2cpp::cu::need_host(z);
    for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
        double r = ((y[i]-z[i])-b);
        double a = lb_abs(r);
        if( a > (epsilon*sigma) ) {
            nout = (nout+1)  ;
            outsum = (outsum+a)  ;
            z[ i ] = (-2.0*(epsilon*( ( r < 0.0 ) ? (-1.0) : (1.0) )))   ;
        } else {
            sq = (sq+(r*r))  ;
            z[ i ] = ((-2.0*r)/sigma)   ;
        }  ;
        csum = (csum+z[i])  ;
        ;
        ;
    }  ;
    scm2cpp::cu::wrote_host(z);
    scm2cpp::cu::blas_gemv(g, x, z, 1.0, 0.0, 1, p, n)  ;
    {   long scm2cpp_cnt = (long)(p) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k65<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(coef), scm2cpp::cu::dev(g), alpha, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k65");
            scm2cpp::cu::wrote_dev(g);
            ww = ww + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(coef);
            scm2cpp::cu::need_host(g);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double wj = coef[j];
                ww = (ww+(wj*wj))  ;
                g[ j ] = (g[j]+(2.0*(alpha*wj)))   ;
                ;
            }
            scm2cpp::cu::wrote_host(g);
        }
    }  ;
    scm2cpp::cu::need_host(g);
    g[ p ] = ( ( fitint == 1 ) ? (csum) : (0.0) )   ;
    scm2cpp::cu::wrote_host(g);
    scm2cpp::cu::need_host(g);
    double sqloss = (sq/sigma);
    double eps2 = (epsilon*epsilon);
    g[ (p+1) ] = ((double(n)-(double(nout)*eps2))-(sqloss/sigma))   ;
    return ((((double(n)*sigma)+sqloss)+((2.0*(epsilon*outsum))-(sigma*(double(nout)*eps2))))+(alpha*ww)) ;
}


inline std::int64_t
huber( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  double  epsilon,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    scm2cpp::cu::fresh(aux);
    std::vector<double> work(n,0.0);
    scm2cpp::cu::fresh(work);
    scm2cpp::cu::need_host(aux);
    aux[ 0 ] = epsilon   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 1 ] = alpha   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    scm2cpp::cu::wrote_host(aux);
    return lbfgs(1,coef,x,y,aux,work,out,10,maxiter,tol,(10000000.0*2.220446049250313e-16),20,(p+1),(10.0*2.220446049250313e-16),(p+2),n,p,1) ;
}
static __global__ void scm2cpp_k66(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* z, const double* y, double b, std::int64_t family, double power, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double loss = 0.0;
    {   double zi = (z[i]+b);
        double yi = y[i];
        if( (family == 0 || (family == 2 && power == 1.0)) ) {
            double e = exp(zi);
            loss = (loss+(e-(yi*zi)))  ;
            z[ i ] = (e-yi)   ;
            ;
        } else {
            if( (family == 1 || (family == 2 && power == 2.0)) ) {
                double e2 = exp((0.0-zi));
                loss = (loss+(zi+(yi*e2)))  ;
                z[ i ] = (1.0-(yi*e2))   ;
                ;
            } else {
                if( family == 3 ) {
                    double r = (zi-yi);
                    loss = (loss+(0.5*(r*r)))  ;
                    z[ i ] = r   ;
                    ;
                } else {
                    if( power == 0.0 ) {
                        double e3 = exp(zi);
                        loss = (loss+(0.5*((e3-yi)*(e3-yi))))  ;
                        z[ i ] = (e3*(e3-yi))   ;
                        ;
                    } else {
                        double e1 = exp(((1.0-power)*zi));
                        double e4 = exp(((2.0-power)*zi));
                        loss = (loss+((e4/(2.0-power))-((yi*e1)/(1.0-power))))  ;
                        z[ i ] = (e4-(yi*e1))   ;
                        ;
                    }  ;
                }  ;
            }  ;
        }  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, loss);
}
static __global__ void scm2cpp_k67(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* coef, double* g, std::int64_t n, double l2, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double pen = 0.0;
    {   double wj = coef[j];
        pen = (pen+(wj*wj))  ;
        g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, pen);
}
static __global__ void scm2cpp_k68(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* z, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+z[i])  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline double
glm_fg( scm2cpp::cspan<double> coef,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> z,  std::int64_t  family,  double  power,  double  l2,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   scm2cpp::cu::need_host(coef);
    double loss = 0.0;
    double pen = 0.0;
    double b = coef[p];
    scm2cpp::cu::blas_gemv(z, x, coef, 1.0, 0.0, 0, n, p)  ;
    {   long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k66<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp::cu::dev(y), b, family, power, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k66");
            scm2cpp::cu::wrote_dev(z);
            loss = loss + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(z);
            scm2cpp::cu::need_host(y);
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                double zi = (z[i]+b);
                double yi = y[i];
                if( (family == 0 || (family == 2 && power == 1.0)) ) {
                    double e = exp(zi);
                    loss = (loss+(e-(yi*zi)))  ;
                    z[ i ] = (e-yi)   ;
                    ;
                } else {
                    if( (family == 1 || (family == 2 && power == 2.0)) ) {
                        double e2 = exp((0.0-zi));
                        loss = (loss+(zi+(yi*e2)))  ;
                        z[ i ] = (1.0-(yi*e2))   ;
                        ;
                    } else {
                        if( family == 3 ) {
                            double r = (zi-yi);
                            loss = (loss+(0.5*(r*r)))  ;
                            z[ i ] = r   ;
                            ;
                        } else {
                            if( power == 0.0 ) {
                                double e3 = exp(zi);
                                loss = (loss+(0.5*((e3-yi)*(e3-yi))))  ;
                                z[ i ] = (e3*(e3-yi))   ;
                                ;
                            } else {
                                double e1 = exp(((1.0-power)*zi));
                                double e4 = exp(((2.0-power)*zi));
                                loss = (loss+((e4/(2.0-power))-((yi*e1)/(1.0-power))))  ;
                                z[ i ] = (e4-(yi*e1))   ;
                                ;
                            }  ;
                        }  ;
                    }  ;
                }  ;
                ;
            }
            scm2cpp::cu::wrote_host(z);
        }
    }  ;
    scm2cpp::cu::blas_gemv(g, x, z, 1.0, 0.0, 1, p, n)  ;
    {   long scm2cpp_cnt = (long)(p) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k67<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(coef), scm2cpp::cu::dev(g), n, l2, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k67");
            scm2cpp::cu::wrote_dev(g);
            pen = pen + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(coef);
            scm2cpp::cu::need_host(g);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                double wj = coef[j];
                pen = (pen+(wj*wj))  ;
                g[ j ] = ((g[j]/double(n))+(l2*wj))   ;
                ;
            }
            scm2cpp::cu::wrote_host(g);
        }
    }  ;
    double acc = 0.0;
    if( fitint == 1 ) {
        {
            long scm2cpp_cnt = (long)(n) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k68<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(z), scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k68");
                acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
            } else {
                scm2cpp::cu::need_host(z);
                for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                    acc = (acc+z[i])  ;
                }
            }
        }  ;
    } else {
        0  ;
    }  ;
    scm2cpp::cu::need_host(g);
    g[ p ] = (acc/double(n))   ;
    scm2cpp::cu::wrote_host(g);
    ;
    return ((loss/double(n))+(0.5*(l2*pen))) ;
}
static __global__ void scm2cpp_k69(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* coef, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   coef[ j ] = 0.0   ;
    }
}
static __global__ void scm2cpp_k70(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* y, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t i = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double ym = 0.0;
    {   ym = (ym+y[i])  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, ym);
}


inline std::int64_t
glm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> coef,  scm2cpp::span<double> out,  std::int64_t  family,  double  power,  double  alpha,  std::int64_t  maxiter,  double  tol,  std::int64_t  fitint,  std::int64_t  n,  std::int64_t  p )
{   std::array<double,4> aux = scm2cpp::filled_array<double,4>(0.0);
    scm2cpp::cu::fresh(aux);
    std::vector<double> work(n,0.0);
    scm2cpp::cu::fresh(work);
    double ym = 0.0;
    scm2cpp::cu::need_host(aux);
    aux[ 0 ] = alpha   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 1 ] = double(family)   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 2 ] = ( ( fitint == 1 ) ? (1.0) : (0.0) )   ;
    scm2cpp::cu::wrote_host(aux);
    scm2cpp::cu::need_host(aux);
    aux[ 3 ] = power   ;
    scm2cpp::cu::wrote_host(aux);
    {   long scm2cpp_cnt = (long)(p) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k69<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(coef), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k69");
            scm2cpp::cu::wrote_dev(coef);
        } else {
            scm2cpp::cu::need_host(coef);
            for( std::int64_t j = 0 ; !(j == p) ; j = (j+1) ) {
                coef[ j ] = 0.0   ;
            }
            scm2cpp::cu::wrote_host(coef);
        }
    }  ;
    {   long scm2cpp_cnt = (long)(n) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k70<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(y), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k70");
            ym = ym + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(y);
            for( std::int64_t i = 0 ; !(i == n) ; i = (i+1) ) {
                ym = (ym+y[i])  ;
            }
        }
    }  ;
    ym = (ym/double(n))  ;
    scm2cpp::cu::need_host(coef);
    coef[ p ] = ( ( fitint == 1 ) ? (( ( family == 3 ) ? (ym) : (log(ym)) )) : (0.0) )   ;
    scm2cpp::cu::wrote_host(coef);
    return lbfgs(2,coef,x,y,aux,work,out,10,maxiter,tol,(64.0*2.220446049250313e-16),50,-1,0.0,(p+1),n,p,1) ;
}


SCM2CPP_FN inline double
lb_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}


SCM2CPP_FN inline double
lb_max( double  a,  double  b )
{
    if( a > b ) {
        return a ;
    }
    else {
        return b ;
    }
}


SCM2CPP_FN inline double
lb_min( double  a,  double  b )
{
    if( a < b ) {
        return a ;
    }
    else {
        return b ;
    }
}


SCM2CPP_FN inline std::int64_t
lb_dcstep( std::array<double,8> & cs,  double  fp,  double  dp,  double  stpmin,  double  stpmax )
{   double stx = cs[0];
    double fx = cs[1];
    double dx = cs[2];
    double sty = cs[3];
    double fy = cs[4];
    double dy = cs[5];
    double stp = cs[6];
    double brackt = cs[7];
    double stpf = 0.0;
    double sgnd = (dp*(dx/lb_abs(dx)));
    if( fp > fx ) {
        double th1 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
        double s1 = lb_max(lb_abs(th1),lb_max(lb_abs(dx),lb_abs(dp)));
        double ga1 = (s1*sqrt((((th1/s1)*(th1/s1))-((dx/s1)*(dp/s1)))));
        double gm1 = ( ( stp < stx ) ? ((0.0-ga1)) : (ga1) );
        double r1 = (((gm1-dx)+th1)/(((gm1-dx)+gm1)+dp));
        double stpc1 = (stx+(r1*(stp-stx)));
        double stpq1 = (stx+(((dx/(((fx-fp)/(stp-stx))+dx))/2.0)*(stp-stx)));
        if( lb_abs(double((stpc1-stx))) < lb_abs(double((stpq1-stx))) ) {
            stpf = stpc1  ;
        } else {
            stpf = (stpc1+((stpq1-stpc1)/2.0))  ;
        }  ;
        brackt = 1.0  ;
        ;
        ;
        ;
        ;
        ;
        ;
        0  ;
    } else {
        if( sgnd < 0.0 ) {
            double th2 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
            double s2 = lb_max(lb_abs(th2),lb_max(lb_abs(dx),lb_abs(dp)));
            double ga2 = (s2*sqrt((((th2/s2)*(th2/s2))-((dx/s2)*(dp/s2)))));
            double gm2 = ( ( stp > stx ) ? ((0.0-ga2)) : (ga2) );
            double r2 = (((gm2-dp)+th2)/(((gm2-dp)+gm2)+dx));
            double stpc2 = (stp+(r2*(stx-stp)));
            double stpq2 = (stp+((dp/(dp-dx))*(stx-stp)));
            if( lb_abs(double((stpc2-stp))) > lb_abs(double((stpq2-stp))) ) {
                stpf = stpc2  ;
            } else {
                stpf = stpq2  ;
            }  ;
            brackt = 1.0  ;
            ;
            ;
            ;
            ;
            ;
            ;
            0  ;
        } else {
            if( lb_abs(dp) < lb_abs(dx) ) {
                double th3 = ((((3.0*(fx-fp))/(stp-stx))+dx)+dp);
                double s3 = lb_max(lb_abs(th3),lb_max(lb_abs(dx),lb_abs(dp)));
                double ga3 = (s3*sqrt(lb_max(0.0,double((((th3/s3)*(th3/s3))-((dx/s3)*(dp/s3)))))));
                double gm3 = ( ( stp > stx ) ? ((0.0-ga3)) : (ga3) );
                double r3 = (((gm3-dp)+th3)/((gm3+(dx-dp))+gm3));
                double stpc3 = ( ( (r3 < 0.0 && !(gm3 == 0.0)) ) ? ((stp+(r3*(stx-stp)))) : (( ( stp > stx ) ? (stpmax) : (stpmin) )) );
                double stpq3 = (stp+((dp/(dp-dx))*(stx-stp)));
                if( brackt == 1.0 ) {
                    if( lb_abs(double((stpc3-stp))) < lb_abs(double((stpq3-stp))) ) {
                        stpf = stpc3  ;
                    } else {
                        stpf = stpq3  ;
                    }  ;
                    if( stp > stx ) {
                        stpf = lb_min(double((stp+(0.66*(sty-stp)))),stpf)  ;
                    } else {
                        stpf = lb_max(double((stp+(0.66*(sty-stp)))),stpf)  ;
                    }  ;
                } else {
                    if( lb_abs(double((stpc3-stp))) > lb_abs(double((stpq3-stp))) ) {
                        stpf = stpc3  ;
                    } else {
                        stpf = stpq3  ;
                    }  ;
                    stpf = lb_min(stpmax,stpf)  ;
                    stpf = lb_max(stpmin,stpf)  ;
                }  ;
                ;
                ;
                ;
                ;
                ;
                ;
                0  ;
            } else {
                if( brackt == 1.0 ) {
                    double th4 = ((((3.0*(fp-fy))/(sty-stp))+dy)+dp);
                    double s4 = lb_max(lb_abs(th4),lb_max(lb_abs(dy),lb_abs(dp)));
                    double ga4 = (s4*sqrt((((th4/s4)*(th4/s4))-((dy/s4)*(dp/s4)))));
                    double gm4 = ( ( stp > sty ) ? ((0.0-ga4)) : (ga4) );
                    double r4 = (((gm4-dp)+th4)/(((gm4-dp)+gm4)+dy));
                    stpf = (stp+(r4*(sty-stp)))  ;
                    ;
                    ;
                    ;
                    ;
                    ;
                    0  ;
                } else {
                    if( stp > stx ) {
                        stpf = stpmax  ;
                    } else {
                        stpf = stpmin  ;
                    }  ;
                }  ;
            }  ;
        }  ;
    }  ;
    if( fp > fx ) {
        cs[ 3 ] = stp   ;
        cs[ 4 ] = fp   ;
        cs[ 5 ] = dp   ;
    } else {
        if( sgnd < 0.0 ) {
            cs[ 3 ] = stx   ;
            cs[ 4 ] = fx   ;
            cs[ 5 ] = dx   ;
        } else {
            0  ;
        }  ;
        cs[ 0 ] = stp   ;
        cs[ 1 ] = fp   ;
        cs[ 2 ] = dp   ;
    }  ;
    cs[ 6 ] = stpf   ;
    cs[ 7 ] = brackt   ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lb_search_start( std::array<double,16> & ls,  double  f,  double  g,  double  stp,  double  stpmin,  double  stpmax,  double  ftol )
{   ls[ 0 ] = 0.0   ;
    ls[ 1 ] = f   ;
    ls[ 2 ] = g   ;
    ls[ 3 ] = 0.0   ;
    ls[ 4 ] = f   ;
    ls[ 5 ] = g   ;
    ls[ 6 ] = 0.0   ;
    ls[ 7 ] = 1.0   ;
    ls[ 8 ] = f   ;
    ls[ 9 ] = g   ;
    ls[ 10 ] = (ftol*g)   ;
    ls[ 11 ] = (stpmax-stpmin)   ;
    ls[ 12 ] = ((stpmax-stpmin)/0.5)   ;
    ls[ 13 ] = 0.0   ;
    ls[ 14 ] = (stp+(4.0*stp))   ;
    ls[ 15 ] = stp   ;
    return 0 ;
}


SCM2CPP_FN inline std::int64_t
lb_search_step( std::array<double,16> & ls,  std::array<double,8> & cs,  double  f,  double  g,  double  ftol,  double  gtol,  double  xtol,  double  stpmin,  double  stpmax )
{   double stp = ls[15];
    double finit = ls[8];
    double ginit = ls[9];
    double gtest = ls[10];
    std::int64_t task = 0;
    double ftest = (finit+(stp*gtest));
    if( (ls[7] == 1.0 && (f <= ftest && g >= 0.0)) ) {
        ls[ 7 ] = 2.0   ;
    } else {
        0  ;
    }  ;
    if( (ls[6] == 1.0 && (stp <= ls[13] || stp >= ls[14])) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (ls[6] == 1.0 && (ls[14]-ls[13]) <= (xtol*ls[14])) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (stp == stpmax && (f <= ftest && g <= gtest)) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (stp == stpmin && (f > ftest || g >= gtest)) ) {
        task = 2  ;
    } else {
        0  ;
    }  ;
    if( (f <= ftest && lb_abs(g) <= (gtol*(0.0-ginit))) ) {
        task = 1  ;
    } else {
        0  ;
    }  ;
    if( task == 0 ) {
        cs[ 0 ] = ls[0]   ;
        cs[ 3 ] = ls[3]   ;
        cs[ 6 ] = stp   ;
        cs[ 7 ] = ls[6]   ;
        if( (ls[7] == 1.0 && (f <= ls[1] && f > ftest)) ) {
            cs[ 1 ] = (ls[1]-(ls[0]*gtest))   ;
            cs[ 2 ] = (ls[2]-gtest)   ;
            cs[ 4 ] = (ls[4]-(ls[3]*gtest))   ;
            cs[ 5 ] = (ls[5]-gtest)   ;
            lb_dcstep(cs,double((f-(stp*gtest))),double((g-gtest)),ls[13],ls[14])  ;
            ls[ 1 ] = (cs[1]+(cs[0]*gtest))   ;
            ls[ 2 ] = (cs[2]+gtest)   ;
            ls[ 4 ] = (cs[4]+(cs[3]*gtest))   ;
            ls[ 5 ] = (cs[5]+gtest)   ;
        } else {
            cs[ 1 ] = ls[1]   ;
            cs[ 2 ] = ls[2]   ;
            cs[ 4 ] = ls[4]   ;
            cs[ 5 ] = ls[5]   ;
            lb_dcstep(cs,f,g,ls[13],ls[14])  ;
            ls[ 1 ] = cs[1]   ;
            ls[ 2 ] = cs[2]   ;
            ls[ 4 ] = cs[4]   ;
            ls[ 5 ] = cs[5]   ;
        }  ;
        ls[ 0 ] = cs[0]   ;
        ls[ 3 ] = cs[3]   ;
        ls[ 6 ] = cs[7]   ;
        double nstp = cs[6];
        double stx = cs[0];
        double sty = cs[3];
        if( ls[6] == 1.0 ) {
            if( lb_abs(double((sty-stx))) >= (0.66*ls[12]) ) {
                nstp = (stx+(0.5*(sty-stx)))  ;
            } else {
                0  ;
            }  ;
            ls[ 12 ] = ls[11]   ;
            ls[ 11 ] = lb_abs(double((sty-stx)))   ;
        } else {
            0  ;
        }  ;
        if( ls[6] == 1.0 ) {
            ls[ 13 ] = lb_min(stx,sty)   ;
            ls[ 14 ] = lb_max(stx,sty)   ;
        } else {
            ls[ 13 ] = (nstp+(1.1*(nstp-stx)))   ;
            ls[ 14 ] = (nstp+(4.0*(nstp-stx)))   ;
        }  ;
        nstp = lb_max(nstp,stpmin)  ;
        nstp = lb_min(nstp,stpmax)  ;
        if( (ls[6] == 1.0 && ((nstp <= ls[13] || nstp >= ls[14]) || (ls[14]-ls[13]) <= (xtol*ls[14]))) ) {
            nstp = stx  ;
        } else {
            0  ;
        }  ;
        ls[ 15 ] = nstp   ;
        ;
    } else {
        0  ;
    }  ;
    return task ;
}
static __global__ void scm2cpp_k71(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* a, const double* b, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(a[j]*b[j]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline double
lb_dot( scm2cpp::cspan<double> a,  scm2cpp::cspan<double> b,  std::int64_t  nv )
{   double acc = 0.0;
    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k71<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(a), scm2cpp::cu::dev(b), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k71");
            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(a);
            scm2cpp::cu::need_host(b);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                acc = (acc+(a[j]*b[j]))  ;
            }
        }
    }  ;
    return acc ;
}
static __global__ void scm2cpp_k72(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* mem, const double* v, std::int64_t slot, std::int64_t nv, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(mem[(((long long)slot*nv)+j)]*v[j]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline double
lb_dot_row( scm2cpp::cspan<double> mem,  std::int64_t  slot,  scm2cpp::cspan<double> v,  std::int64_t  nv )
{   double acc = 0.0;
    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k72<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(mem), scm2cpp::cu::dev(v), slot, nv, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k72");
            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(mem);
            scm2cpp::cu::need_host(v);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                acc = (acc+(mem[(((long long)slot*nv)+j)]*v[j]))  ;
            }
        }
    }  ;
    return acc ;
}
static __global__ void scm2cpp_k73(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* a, const double* b, std::int64_t ra, std::int64_t nv, std::int64_t rb, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double acc = 0.0;
    {   acc = (acc+(a[(((long long)ra*nv)+j)]*b[(((long long)rb*nv)+j)]))  ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, acc);
}


inline double
lb_dot_rows( scm2cpp::cspan<double> a,  std::int64_t  ra,  scm2cpp::cspan<double> b,  std::int64_t  rb,  std::int64_t  nv )
{   double acc = 0.0;
    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k73<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(a), scm2cpp::cu::dev(b), ra, nv, rb, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k73");
            acc = acc + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
        } else {
            scm2cpp::cu::need_host(a);
            scm2cpp::cu::need_host(b);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                acc = (acc+(a[(((long long)ra*nv)+j)]*b[(((long long)rb*nv)+j)]))  ;
            }
        }
    }  ;
    return acc ;
}


SCM2CPP_FN inline double
lb_projgr( scm2cpp::cspan<double> g,  scm2cpp::cspan<double> w,  std::int64_t  ib,  double  lbv,  std::int64_t  nv )
{   double acc = 0.0;
    for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
        double gj = g[j];
        double gp = ( ( (j == ib && gj >= 0.0) ) ? (lb_min(double((w[j]-lbv)),gj)) : (gj) );
        double v = lb_abs(gp);
        if( v > acc ) {
            acc = v  ;
        } else {
            0  ;
        }  ;
        ;
        ;
        ;
    }  ;
    return acc ;
}
static __global__ void scm2cpp_k74(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* q, const double* ymem, double a, std::int64_t slot, std::int64_t nv, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   q[ j ] = (q[j]-(a*ymem[(((long long)slot*nv)+j)]))   ;
    }
}
static __global__ void scm2cpp_k75(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* q, double theta, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   q[ j ] = (q[j]/theta)   ;
    }
}
static __global__ void scm2cpp_k76(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* q, const double* al, const double* smem, std::int64_t slot2, double bb, std::int64_t nv, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   q[ j ] = (q[j]+((al[slot2]-bb)*smem[(((long long)slot2*nv)+j)]))   ;
    }
}


inline std::int64_t
lb_hv( scm2cpp::span<double> q,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv )
{   for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t slot = ((head+((col-1)-ii)) % m);
        scm2cpp::cu::need_host(rho);
        scm2cpp::cu::need_host(smem);
        scm2cpp::cu::need_host(q);
        double a = (rho[slot]*lb_dot_row(smem,slot,q,nv));
        scm2cpp::cu::need_host(al);
        al[ slot ] = a   ;
        scm2cpp::cu::wrote_host(al);
        {   long scm2cpp_cnt = (long)(nv) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k74<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(q), scm2cpp::cu::dev(ymem), a, slot, nv, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k74");
                scm2cpp::cu::wrote_dev(q);
            } else {
                scm2cpp::cu::need_host(q);
                scm2cpp::cu::need_host(ymem);
                for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                    q[ j ] = (q[j]-(a*ymem[(((long long)slot*nv)+j)]))   ;
                }
                scm2cpp::cu::wrote_host(q);
            }
        }  ;
        ;
        ;
    }  ;
    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k75<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(q), theta, scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k75");
            scm2cpp::cu::wrote_dev(q);
        } else {
            scm2cpp::cu::need_host(q);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                q[ j ] = (q[j]/theta)   ;
            }
            scm2cpp::cu::wrote_host(q);
        }
    }  ;
    for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t slot2 = ((head+ii) % m);
        scm2cpp::cu::need_host(rho);
        scm2cpp::cu::need_host(ymem);
        scm2cpp::cu::need_host(q);
        double bb = (rho[slot2]*lb_dot_row(ymem,slot2,q,nv));
        {
            long scm2cpp_cnt = (long)(nv) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k76<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(q), scm2cpp::cu::dev(al), scm2cpp::cu::dev(smem), slot2, bb, nv, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k76");
                scm2cpp::cu::wrote_dev(q);
            } else {
                scm2cpp::cu::need_host(q);
                scm2cpp::cu::need_host(al);
                scm2cpp::cu::need_host(smem);
                for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                    q[ j ] = (q[j]+((al[slot2]-bb)*smem[(((long long)slot2*nv)+j)]))   ;
                }
                scm2cpp::cu::wrote_host(q);
            }
        }  ;
        ;
        ;
    }  ;
    return 0 ;
}
static __global__ void scm2cpp_k77(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* bm, const double* smem, std::int64_t ii, std::int64_t nv, double theta, std::int64_t si, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   bm[ (((long long)ii*nv)+j) ] = (theta*smem[(((long long)si*nv)+j)])   ;
    }
}


inline double
lb_vbv( scm2cpp::cspan<double> v,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  nv )
{   for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t si = ((head+ii) % m);
        {   long scm2cpp_cnt = (long)(nv) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k77<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(bm), scm2cpp::cu::dev(smem), ii, nv, theta, si, scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k77");
                scm2cpp::cu::wrote_dev(bm);
            } else {
                scm2cpp::cu::need_host(bm);
                scm2cpp::cu::need_host(smem);
                for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                    bm[ (((long long)ii*nv)+j) ] = (theta*smem[(((long long)si*nv)+j)])   ;
                }
                scm2cpp::cu::wrote_host(bm);
            }
        }  ;
        for( std::int64_t jj = 0 ; !(jj == ii) ; jj = (jj+1) ) {
            std::int64_t sj = ((head+jj) % m);
            scm2cpp::cu::need_host(bm);
            scm2cpp::cu::need_host(smem);
            scm2cpp::cu::need_host(sb);
            scm2cpp::cu::need_host(rho);
            scm2cpp::cu::need_host(ymem);
            double cb = (lb_dot_rows(bm,jj,smem,si,nv)/sb[jj]);
            double cy = (rho[sj]*lb_dot_rows(ymem,sj,smem,si,nv));
            scm2cpp::cu::need_host(bm);
            scm2cpp::cu::need_host(ymem);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                bm[ (((long long)ii*nv)+j) ] = ((bm[(((long long)ii*nv)+j)]-(cb*bm[(((long long)jj*nv)+j)]))+(cy*ymem[(((long long)sj*nv)+j)]))   ;
            }  ;
            scm2cpp::cu::wrote_host(bm);
            ;
            ;
        }  ;
        sb[ ii ] = lb_dot_rows(bm,ii,smem,si,nv)   ;
        ;
    }  ;
    scm2cpp::cu::need_host(v);
    double acc = (theta*lb_dot(v,v,nv));
    for( std::int64_t ii = 0 ; !(ii == col) ; ii = (ii+1) ) {
        std::int64_t si2 = ((head+ii) % m);
        scm2cpp::cu::need_host(bm);
        scm2cpp::cu::need_host(v);
        scm2cpp::cu::need_host(ymem);
        double bv = lb_dot_row(bm,ii,v,nv);
        double yv = lb_dot_row(ymem,si2,v,nv);
        scm2cpp::cu::need_host(sb);
        scm2cpp::cu::need_host(rho);
        acc = ((acc-((bv*bv)/sb[ii]))+(rho[si2]*(yv*yv)))  ;
        ;
        ;
    }  ;
    return acc ;
}
static __global__ void scm2cpp_k78(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* q, const double* g, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   q[ j ] = g[j]   ;
    }
}
static __global__ void scm2cpp_k79(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* d, const double* q, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   d[ j ] = (0.0-q[j])   ;
    }
}
static __global__ void scm2cpp_k80(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* e, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   e[ j ] = 0.0   ;
    }
}
static __global__ void scm2cpp_k81(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* d, const double* e, double lam, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   d[ j ] = (d[j]+(lam*e[j]))   ;
    }
}
static __global__ void scm2cpp_k82(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* g, double* d, double dtm, double alpha, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   double xcpj = ((0.0-dtm)*g[j]);
        d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
        ;
    }
}


inline std::int64_t
lb_direction( scm2cpp::cspan<double> w,  scm2cpp::cspan<double> g,  scm2cpp::span<double> d,  scm2cpp::span<double> q,  scm2cpp::span<double> e,  scm2cpp::cspan<double> smem,  scm2cpp::cspan<double> ymem,  scm2cpp::cspan<double> rho,  scm2cpp::span<double> al,  scm2cpp::span<double> bm,  scm2cpp::span<double> sb,  double  theta,  std::int64_t  col,  std::int64_t  head,  std::int64_t  m,  std::int64_t  ib,  double  lbv,  std::int64_t  nv )
{  {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k78<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(q), scm2cpp::cu::dev(g), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k78");
            scm2cpp::cu::wrote_dev(q);
        } else {
            scm2cpp::cu::need_host(q);
            scm2cpp::cu::need_host(g);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                q[ j ] = g[j]   ;
            }
            scm2cpp::cu::wrote_host(q);
        }
    }  ;
    lb_hv(q,smem,ymem,rho,al,theta,col,head,m,nv)  ;
    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
            scm2cpp_k79<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(d), scm2cpp::cu::dev(q), scm2cpp_red);
            scm2cpp::cu::launched("scm2cpp_k79");
            scm2cpp::cu::wrote_dev(d);
        } else {
            scm2cpp::cu::need_host(d);
            scm2cpp::cu::need_host(q);
            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                d[ j ] = (0.0-q[j])   ;
            }
            scm2cpp::cu::wrote_host(d);
        }
    }  ;
    if( ib >= 0 ) {
        scm2cpp::cu::need_host(g);
        scm2cpp::cu::need_host(w);
        double gs = g[ib];
        double tl = (w[ib]-lbv);
        std::int64_t fixed = 0;
        double delta = 0.0;
        double dtm = 0.0;
        if( (tl <= 0.0 && gs >= 0.0) ) {
            fixed = 1  ;
        } else {
            dtm = (lb_dot(g,g,nv)/lb_vbv(g,smem,ymem,rho,bm,sb,theta,col,head,m,nv))  ;
            if( (gs > 0.0 && dtm >= (tl/gs)) ) {
                fixed = 1  ;
                delta = (0.0-tl)  ;
            } else {
                0  ;
            }  ;
        }  ;
        if( fixed == 1 ) {
            {
                long scm2cpp_cnt = (long)(nv) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k80<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(e), scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k80");
                    scm2cpp::cu::wrote_dev(e);
                } else {
                    scm2cpp::cu::need_host(e);
                    for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                        e[ j ] = 0.0   ;
                    }
                    scm2cpp::cu::wrote_host(e);
                }
            }  ;
            scm2cpp::cu::need_host(e);
            e[ ib ] = 1.0   ;
            scm2cpp::cu::wrote_host(e);
            lb_hv(e,smem,ymem,rho,al,theta,col,head,m,nv)  ;
            scm2cpp::cu::need_host(q);
            scm2cpp::cu::need_host(e);
            double lam = ((delta+q[ib])/e[ib]);
            {
                long scm2cpp_cnt = (long)(nv) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k81<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(d), scm2cpp::cu::dev(e), lam, scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k81");
                    scm2cpp::cu::wrote_dev(d);
                } else {
                    scm2cpp::cu::need_host(d);
                    scm2cpp::cu::need_host(e);
                    for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                        d[ j ] = (d[j]+(lam*e[j]))   ;
                    }
                    scm2cpp::cu::wrote_host(d);
                }
            }  ;
            ;
            scm2cpp::cu::need_host(d);
            d[ ib ] = delta   ;
            scm2cpp::cu::wrote_host(d);
        } else {
            scm2cpp::cu::need_host(w);
            scm2cpp::cu::need_host(d);
            if( (w[ib]+d[ib]) < lbv ) {
                scm2cpp::cu::need_host(d);
                scm2cpp::cu::need_host(g);
                scm2cpp::cu::need_host(w);
                double ddp = ((lb_dot(d,g,nv)-(d[ib]*gs))+((lbv-w[ib])*gs));
                if( ddp > 0.0 ) {
                    scm2cpp::cu::need_host(d);
                    scm2cpp::cu::need_host(w);
                    double dus = (d[ib]-((0.0-dtm)*gs));
                    double xcps = (w[ib]-(dtm*gs));
                    double alpha = 1.0;
                    if( dus < 0.0 ) {
                        double temp2 = (lbv-xcps);
                        if( temp2 >= 0.0 ) {
                            alpha = 0.0  ;
                        } else {
                            if( dus < temp2 ) {
                                alpha = (temp2/dus)  ;
                            } else {
                                0  ;
                            }  ;
                        }  ;
                        ;
                    } else {
                        0  ;
                    }  ;
                    {   long scm2cpp_cnt = (long)(nv) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k82<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(g), scm2cpp::cu::dev(d), dtm, alpha, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k82");
                            scm2cpp::cu::wrote_dev(d);
                        } else {
                            scm2cpp::cu::need_host(g);
                            scm2cpp::cu::need_host(d);
                            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                                double xcpj = ((0.0-dtm)*g[j]);
                                d[ j ] = (xcpj+(alpha*(d[j]-xcpj)))   ;
                                ;
                            }
                            scm2cpp::cu::wrote_host(d);
                        }
                    }  ;
                    scm2cpp::cu::need_host(d);
                    scm2cpp::cu::need_host(w);
                    if( alpha < 1.0 ) {
                        d[ ib ] = (lbv-w[ib])   ;
                    } else {
                        0  ;
                    }  ;
                    scm2cpp::cu::wrote_host(d);
                    ;
                } else {
                    scm2cpp::cu::need_host(d);
                    scm2cpp::cu::need_host(w);
                    d[ ib ] = (lbv-w[ib])   ;
                    scm2cpp::cu::wrote_host(d);
                }  ;
                ;
            } else {
                0  ;
            }  ;
        }  ;
        ;
    } else {
        0  ;
    }  ;
    return 0 ;
}
static __global__ void scm2cpp_k83(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* t, const double* w, double* gold, const double* g, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   t[ j ] = w[j]   ;
        gold[ j ] = g[j]   ;
    }
}
static __global__ void scm2cpp_k84(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* w, const double* t, const double* d, double stp, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   w[ j ] = (t[j]+(stp*d[j]))   ;
    }
}
static __global__ void scm2cpp_k85(long scm2cpp_cnt, std::int64_t scm2cpp_lo, double* w, const double* t, double* g, const double* gold, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    {   w[ j ] = t[j]   ;
        g[ j ] = gold[j]   ;
    }
}
static __global__ void scm2cpp_k86(long scm2cpp_cnt, std::int64_t scm2cpp_lo, const double* g, const double* gold, double* smem, const double* d, double* ymem, std::int64_t slot3, std::int64_t nv, double stp2, double* scm2cpp_red) {
    long scm2cpp_t = blockIdx.x * (long)blockDim.x + threadIdx.x;
    if (scm2cpp_t >= scm2cpp_cnt) return;
    std::int64_t j = scm2cpp_lo + (std::int64_t)scm2cpp_t;
    double rr = 0.0;
    {   double yj = (g[j]-gold[j]);
        smem[ (((long long)slot3*nv)+j) ] = (stp2*d[j])   ;
        ymem[ (((long long)slot3*nv)+j) ] = yj   ;
        rr = (rr+(yj*yj))  ;
        ;
    }
    scm2cpp::cu::atomic_add(scm2cpp_red + 0, rr);
}


inline std::int64_t
lbfgs( std::int64_t  kind,  scm2cpp::span<double> w,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  scm2cpp::span<double> out,  std::int64_t  m,  std::int64_t  maxiter,  double  pgtol,  double  ftol,  std::int64_t  maxls,  std::int64_t  ib,  double  lbv,  std::int64_t  nv,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{   std::vector<double> g(nv,0.0);
    scm2cpp::cu::fresh(g);
    std::vector<double> gold(nv,0.0);
    scm2cpp::cu::fresh(gold);
    std::vector<double> d(nv,0.0);
    scm2cpp::cu::fresh(d);
    std::vector<double> t(nv,0.0);
    scm2cpp::cu::fresh(t);
    std::vector<double> q(nv,0.0);
    scm2cpp::cu::fresh(q);
    std::vector<double> e(nv,0.0);
    scm2cpp::cu::fresh(e);
    std::vector<double> smem((m*nv),0.0);
    scm2cpp::cu::fresh(smem);
    std::vector<double> ymem((m*nv),0.0);
    scm2cpp::cu::fresh(ymem);
    std::vector<double> bm((m*nv),0.0);
    scm2cpp::cu::fresh(bm);
    std::vector<double> rho(m,0.0);
    scm2cpp::cu::fresh(rho);
    std::vector<double> sb(m,0.0);
    scm2cpp::cu::fresh(sb);
    std::vector<double> al(m,0.0);
    scm2cpp::cu::fresh(al);
    std::array<double,16> ls = scm2cpp::filled_array<double,16>(0.0);
    scm2cpp::cu::fresh(ls);
    std::array<double,8> cs = scm2cpp::filled_array<double,8>(0.0);
    scm2cpp::cu::fresh(cs);
    double eps = 2.220446049250313e-16;
    std::int64_t iter = 0;
    std::int64_t col = 0;
    std::int64_t head = 0;
    double theta = 1.0;
    std::int64_t nfg = 0;
    std::int64_t done = 0;
    scm2cpp::cu::need_host(w);
    scm2cpp::cu::need_host(g);
    scm2cpp::cu::need_host(x);
    scm2cpp::cu::need_host(y);
    scm2cpp::cu::need_host(aux);
    scm2cpp::cu::need_host(work);
    double f = lbfgs_fg(kind,w,g,x,y,aux,work,n,p,k);
    nfg = 1  ;
    scm2cpp::cu::need_host(g);
    scm2cpp::cu::need_host(w);
    if( lb_projgr(g,w,ib,lbv,nv) <= pgtol ) {
        done = 1  ;
    } else {
        0  ;
    }  ;
    for(  ; !(done == 1) ;  ) {
        lb_direction(w,g,d,q,e,smem,ymem,rho,al,bm,sb,theta,col,head,m,ib,lbv,nv)  ;
        {   long scm2cpp_cnt = (long)(nv) - (long)(0);
            if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                scm2cpp_k83<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(t), scm2cpp::cu::dev(w), scm2cpp::cu::dev(gold), scm2cpp::cu::dev(g), scm2cpp_red);
                scm2cpp::cu::launched("scm2cpp_k83");
                scm2cpp::cu::wrote_dev(t);
                scm2cpp::cu::wrote_dev(gold);
            } else {
                scm2cpp::cu::need_host(t);
                scm2cpp::cu::need_host(w);
                scm2cpp::cu::need_host(gold);
                scm2cpp::cu::need_host(g);
                for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                    t[ j ] = w[j]   ;
                    gold[ j ] = g[j]   ;
                }
                scm2cpp::cu::wrote_host(t);
                scm2cpp::cu::wrote_host(gold);
            }
        }  ;
        scm2cpp::cu::need_host(d);
        scm2cpp::cu::need_host(g);
        double fold = f;
        double dnorm = sqrt(lb_dot(d,d,nv));
        double gdold = lb_dot(g,d,nv);
        double stpmx = 10000000000.0;
        double gd = 0.0;
        std::int64_t task = 0;
        std::int64_t ifun = 0;
        std::int64_t fail = 0;
        scm2cpp::cu::need_host(d);
        scm2cpp::cu::need_host(w);
        if( ib >= 0 ) {
            if( iter == 0 ) {
                stpmx = 1.0  ;
            } else {
                if( d[ib] < 0.0 ) {
                    double a2 = (lbv-w[ib]);
                    if( a2 >= 0.0 ) {
                        stpmx = 0.0  ;
                    } else {
                        if( (d[ib]*stpmx) < a2 ) {
                            stpmx = (a2/d[ib])  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
            }  ;
        } else {
            0  ;
        }  ;
        if( gdold >= 0.0 ) {
            fail = 1  ;
        } else {
            scm2cpp::cu::need_host(ls);
            lb_search_start(ls,f,gdold,( ( iter == 0 ) ? (lb_min(double((1.0/dnorm)),stpmx)) : (1.0) ),0.0,stpmx,0.001)  ;
            scm2cpp::cu::wrote_host(ls);
            for(  ; !((fail == 1 || !(task == 0))) ;  ) {
                ifun = (ifun+1)  ;
                if( ifun > maxls ) {
                    fail = 1  ;
                } else {
                    scm2cpp::cu::need_host(ls);
                    double stp = ls[15];
                    {
                        long scm2cpp_cnt = (long)(nv) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k84<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), scm2cpp::cu::dev(t), scm2cpp::cu::dev(d), stp, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k84");
                            scm2cpp::cu::wrote_dev(w);
                        } else {
                            scm2cpp::cu::need_host(w);
                            scm2cpp::cu::need_host(t);
                            scm2cpp::cu::need_host(d);
                            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                                w[ j ] = (t[j]+(stp*d[j]))   ;
                            }
                            scm2cpp::cu::wrote_host(w);
                        }
                    }  ;
                    f = lbfgs_fg(kind,w,g,x,y,aux,work,n,p,k)  ;
                    nfg = (nfg+1)  ;
                    gd = lb_dot(g,d,nv)  ;
                    scm2cpp::cu::need_host(ls);
                    scm2cpp::cu::need_host(cs);
                    task = lb_search_step(ls,cs,f,gd,0.001,0.9,0.1,0.0,stpmx)  ;
                    scm2cpp::cu::wrote_host(ls);
                    scm2cpp::cu::wrote_host(cs);
                    ;
                }  ;
            }  ;
        }  ;
        if( fail == 1 ) {
            {
                long scm2cpp_cnt = (long)(nv) - (long)(0);
                if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                    double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                    scm2cpp_k85<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(w), scm2cpp::cu::dev(t), scm2cpp::cu::dev(g), scm2cpp::cu::dev(gold), scm2cpp_red);
                    scm2cpp::cu::launched("scm2cpp_k85");
                    scm2cpp::cu::wrote_dev(w);
                    scm2cpp::cu::wrote_dev(g);
                } else {
                    scm2cpp::cu::need_host(w);
                    scm2cpp::cu::need_host(t);
                    scm2cpp::cu::need_host(g);
                    scm2cpp::cu::need_host(gold);
                    for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                        w[ j ] = t[j]   ;
                        g[ j ] = gold[j]   ;
                    }
                    scm2cpp::cu::wrote_host(w);
                    scm2cpp::cu::wrote_host(g);
                }
            }  ;
            f = fold  ;
            if( col == 0 ) {
                done = 1  ;
            } else {
                col = 0  ;
                head = 0  ;
                theta = 1.0  ;
            }  ;
        } else {
            scm2cpp::cu::need_host(ls);
            double stp2 = ls[15];
            iter = (iter+1)  ;
            if( iter >= maxiter ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            scm2cpp::cu::need_host(g);
            scm2cpp::cu::need_host(w);
            if( lb_projgr(g,w,ib,lbv,nv) <= pgtol ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            if( (fold-f) <= (ftol*lb_max(lb_max(lb_abs(fold),lb_abs(f)),1.0)) ) {
                done = 1  ;
            } else {
                0  ;
            }  ;
            if( done == 0 ) {
                double dr = ((gd-gdold)*stp2);
                double ddum = ((0.0-gdold)*stp2);
                if( dr > (eps*ddum) ) {
                    std::int64_t slot3 = ( ( col < m ) ? (((head+col) % m)) : (head) );
                    double rr = 0.0;
                    {
                        long scm2cpp_cnt = (long)(nv) - (long)(0);
                        if (scm2cpp_cnt >= scm2cpp::cu::min_trip()) {
                            double* scm2cpp_red = scm2cpp::cu::reduction_slots(1);
                            scm2cpp_k86<<<(unsigned)((scm2cpp_cnt + 255) / 256), 256>>>(scm2cpp_cnt, 0, scm2cpp::cu::dev(g), scm2cpp::cu::dev(gold), scm2cpp::cu::dev(smem), scm2cpp::cu::dev(d), scm2cpp::cu::dev(ymem), slot3, nv, stp2, scm2cpp_red);
                            scm2cpp::cu::launched("scm2cpp_k86");
                            scm2cpp::cu::wrote_dev(smem);
                            scm2cpp::cu::wrote_dev(ymem);
                            rr = rr + scm2cpp::cu::reduction_value(scm2cpp_red, 0);
                        } else {
                            scm2cpp::cu::need_host(g);
                            scm2cpp::cu::need_host(gold);
                            scm2cpp::cu::need_host(smem);
                            scm2cpp::cu::need_host(d);
                            scm2cpp::cu::need_host(ymem);
                            for( std::int64_t j = 0 ; !(j == nv) ; j = (j+1) ) {
                                double yj = (g[j]-gold[j]);
                                smem[ (((long long)slot3*nv)+j) ] = (stp2*d[j])   ;
                                ymem[ (((long long)slot3*nv)+j) ] = yj   ;
                                rr = (rr+(yj*yj))  ;
                                ;
                            }
                            scm2cpp::cu::wrote_host(smem);
                            scm2cpp::cu::wrote_host(ymem);
                        }
                    }  ;
                    scm2cpp::cu::need_host(rho);
                    rho[ slot3 ] = (1.0/dr)   ;
                    scm2cpp::cu::wrote_host(rho);
                    theta = (rr/dr)  ;
                    if( col < m ) {
                        col = (col+1)  ;
                    } else {
                        head = ((head+1) % m)  ;
                    }  ;
                    ;
                    ;
                    0  ;
                } else {
                    0  ;
                }  ;
                ;
            } else {
                0  ;
            }  ;
            ;
        }  ;
        ;
    }  ;
    scm2cpp::cu::need_host(out);
    out[ 0 ] = f   ;
    scm2cpp::cu::wrote_host(out);
    scm2cpp::cu::need_host(out);
    out[ 1 ] = double(nfg)   ;
    scm2cpp::cu::wrote_host(out);
    return iter ;
}


SCM2CPP_FN inline double
lbfgs_fg( std::int64_t  kind,  scm2cpp::cspan<double> w,  scm2cpp::span<double> g,  scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  const std::array<double,4> & aux,  scm2cpp::span<double> work,  std::int64_t  n,  std::int64_t  p,  std::int64_t  k )
{
    if( kind == 0 ) {
        return logistic_fg(w,g,x,y,work,aux[0],( ( aux[1] == 1.0 ) ? (1) : (0) ),( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p,k) ;
    }
    else {
        if( kind == 1 ) {
            return huber_fg(w,g,x,y,work,aux[0],aux[1],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
        else {
            return glm_fg(w,g,x,y,work,std::int64_t(aux[1]),aux[3],aux[0],( ( aux[2] == 1.0 ) ? (1) : (0) ),n,p) ;
        }
    }
}
#endif // GPU_HPP
