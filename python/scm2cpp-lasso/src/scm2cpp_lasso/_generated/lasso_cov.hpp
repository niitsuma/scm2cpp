
#ifndef LASSO_COV_HPP
#define LASSO_COV_HPP
#define SCM2CPP_MINIMAL
#include	<math.h>
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN double 
 soft_threshold( double  z  ,  double  g );
SCM2CPP_FN int 
 build_S( scm2cpp::cspan<double> ps  ,  scm2cpp::span<double> s  ,  scm2cpp::span<double> q  ,  scm2cpp::span<double> cs  ,  int  n  ,  int  nobs  ,  int  wmax );
SCM2CPP_FN int 
 build_P( scm2cpp::cspan<double> ps  ,  scm2cpp::cspan<double> y  ,  scm2cpp::span<double> pv  ,  int  nobs  ,  int  wmax );
SCM2CPP_FN int 
 build_G( scm2cpp::cspan<double> s  ,  scm2cpp::cspan<double> pv  ,  scm2cpp::span<double> g  ,  scm2cpp::span<double> c  ,  int  wmax  ,  int  p );
SCM2CPP_FN int 
 cov_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> beta  ,  double  lam  ,  int  iters  ,  double  nobs  ,  int  p );
SCM2CPP_FN int 
 enet_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> beta  ,  double  lam1  ,  double  lam2  ,  int  iters  ,  double  nobs  ,  int  p );
SCM2CPP_FN int 
 mt_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> w  ,  double  lam1  ,  double  lam2  ,  int  iters  ,  double  nobs  ,  int  p  ,  int  ntask );


  
 SCM2CPP_FN inline double 
 soft_threshold( double  z  ,  double  g ) 
 { if(z > g){   return (z-g) ;} else if(z < (0.0-g)){   return (z+g) ;} else {   return 0.0 ;}}

  
 SCM2CPP_FN inline int 
 build_S( scm2cpp::cspan<double> ps  ,  scm2cpp::span<double> s  ,  scm2cpp::span<double> q  ,  scm2cpp::span<double> cs  ,  int  n  ,  int  nobs  ,  int  wmax ) 
 {  for( int d = (0-wmax) ; !(d == (wmax+1)) ; d = (d+1) ){ for( int i = 0 ; !(i == n) ; i = (i+1) ){ q[ i ] = 0.0   ;
}  ;
 if( d < 0 ) {  for( int i = 0 ; !(i == (n+d)) ; i = (i+1) ){ q[ i ] = (ps[i]*ps[(i-d)])   ;
}  ;
 } else {  for( int i = d ; !(i == n) ; i = (i+1) ){ q[ i ] = (ps[i]*ps[(i-d)])   ;
}  ;
 }  ;
 cs[ 0 ] = 0.0   ;
 for( int i = 0 ; !(i == n) ; i = (i+1) ){ cs[ (i+1) ] = (cs[i]+q[i])   ;
}  ;
 for( int a = 0 ; !(a == (wmax+1)) ; a = (a+1) ){ int b = (a+d); if( b < 0 ) {  0  ;
 } else {  if( b > wmax ) {  0  ;
 } else {  int m = (wmax-a); s[ ((a*(wmax+1))+b) ] = (cs[(m+nobs)]-cs[m])   ;
  ;
 }  ;
 }  ;
  ;
}  ;
}  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 build_P( scm2cpp::cspan<double> ps  ,  scm2cpp::cspan<double> y  ,  scm2cpp::span<double> pv  ,  int  nobs  ,  int  wmax ) 
 {  for( int k = 0 ; !(k == (wmax+1)) ; k = (k+1) ){ double acc = 0.0; for( int r = 0 ; !(r == nobs) ; r = (r+1) ){ acc = (acc+(ps[((wmax+r)-k)]*y[r]))  ;
}  ;
 pv[ k ] = acc   ;
  ;
}  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 build_G( scm2cpp::cspan<double> s  ,  scm2cpp::cspan<double> pv  ,  scm2cpp::span<double> g  ,  scm2cpp::span<double> c  ,  int  wmax  ,  int  p ) 
 {  double s00 = s[0]; for( int j = 0 ; !(j == p) ; j = (j+1) ){ int wj = (j+1); for( int k = 0 ; !(k == p) ; k = (k+1) ){ int wk = (k+1); g[ ((j*p)+k) ] = (((s00+s[((wj*(wmax+1))+wk)])-(s[wk]+s[(wj*(wmax+1))]))/(wj*wk))   ;
  ;
}  ;
 c[ j ] = ((pv[0]-pv[wj])/wj)   ;
  ;
}  ;
  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 cov_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> beta  ,  double  lam  ,  int  iters  ,  double  nobs  ,  int  p ) 
 {  int stop = 0; for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ){ int moved = 0; for( int j = 0 ; !(j == p) ; j = (j+1) ){ double gjj = g[((j*p)+j)];double old = beta[j]; double bnew = (soft_threshold(double((c[j]+(old*gjj))),double((lam*(1.0*nobs))))/gjj); beta[ j ] = bnew   ;
 double d = (bnew-old); if( d == 0.0 ) {  0  ;
 } else {  moved = 1  ;
 for( int k = 0 ; !(k == p) ; k = (k+1) ){ c[ k ] = (c[k]-(d*g[((j*p)+k)]))   ;
}  ;
 }  ;
  ;
  ;
  ;
}  ;
 if( moved == 0 ) {  stop = 1  ;
 } else {  0  ;
 }  ;
  ;
}  ;
  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 enet_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> beta  ,  double  lam1  ,  double  lam2  ,  int  iters  ,  double  nobs  ,  int  p ) 
 {  int stop = 0; for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ){ int moved = 0; for( int j = 0 ; !(j == p) ; j = (j+1) ){ double gjj = g[((j*p)+j)];double old = beta[j]; double bnew = (soft_threshold(double((c[j]+(old*gjj))),double((lam1*(1.0*nobs))))/(gjj+(lam2*(1.0*nobs)))); beta[ j ] = bnew   ;
 double d = (bnew-old); if( d == 0.0 ) {  0  ;
 } else {  moved = 1  ;
 for( int k = 0 ; !(k == p) ; k = (k+1) ){ c[ k ] = (c[k]-(d*g[((j*p)+k)]))   ;
}  ;
 }  ;
  ;
  ;
  ;
}  ;
 if( moved == 0 ) {  stop = 1  ;
 } else {  0  ;
 }  ;
  ;
}  ;
  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 mt_descend( scm2cpp::cspan<double> g  ,  scm2cpp::span<double> c  ,  scm2cpp::span<double> w  ,  double  lam1  ,  double  lam2  ,  int  iters  ,  double  nobs  ,  int  p  ,  int  ntask ) 
 {  int stop = 0; for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ){ int moved = 0; for( int j = 0 ; !(j == p) ; j = (j+1) ){ double gjj = g[((j*p)+j)];double nrm2 = 0.0; for( int t = 0 ; !(t == ntask) ; t = (t+1) ){ double z = (c[((j*ntask)+t)]+(gjj*w[((j*ntask)+t)])); nrm2 = (nrm2+(z*z))  ;
  ;
}  ;
 double nrm = sqrt(nrm2);double thr = (lam1*(1.0*nobs)); double scale = ( ( nrm > thr ) ? (((nrm-thr)/(nrm*(gjj+(lam2*(1.0*nobs)))))) : (0.0) ); for( int t = 0 ; !(t == ntask) ; t = (t+1) ){ double old = w[((j*ntask)+t)]; double wnew = (scale*(c[((j*ntask)+t)]+(gjj*old))); w[ ((j*ntask)+t) ] = wnew   ;
 double d = (wnew-old); if( d == 0.0 ) {  0  ;
 } else {  moved = 1  ;
 for( int k = 0 ; !(k == p) ; k = (k+1) ){ c[ ((k*ntask)+t) ] = (c[((k*ntask)+t)]-(d*g[((j*p)+k)]))   ;
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
 if( moved == 0 ) {  stop = 1  ;
 } else {  0  ;
 }  ;
  ;
}  ;
  ;
  return 0 ;}
#endif // LASSO_COV_HPP
