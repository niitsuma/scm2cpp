
#ifndef TFS_PREDICT_HPP
#define TFS_PREDICT_HPP
#define SCM2CPP_MINIMAL
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN int 
 tfs_predict( scm2cpp::cspan<double> ps  ,  scm2cpp::cspan<double> beta  ,  scm2cpp::span<double> yhat  ,  int  nobs  ,  int  wmax  ,  int  p );


  
 SCM2CPP_FN inline int 
 tfs_predict( scm2cpp::cspan<double> ps  ,  scm2cpp::cspan<double> beta  ,  scm2cpp::span<double> yhat  ,  int  nobs  ,  int  wmax  ,  int  p ) 
 {  for( int r = 0 ; !(r == nobs) ; r = (r+1) ){ double acc = 0.0;int t = (wmax+r); for( int j = 0 ; !(j == p) ; j = (j+1) ){ double b = beta[j]; if( b == 0.0 ) {  0  ;
 } else {  int w = (j+1); acc = (acc+(b*((ps[t]-ps[(t-w)])/(1.0*w))))  ;
  ;
 }  ;
  ;
}  ;
 yhat[ r ] = acc   ;
  ;
}  ;
  return 0 ;}
#endif // TFS_PREDICT_HPP
