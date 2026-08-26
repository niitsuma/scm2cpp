
#ifndef AUTOCOV_HPP
#define AUTOCOV_HPP
#define SCM2CPP_MINIMAL
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN int 
 autocov( scm2cpp::cspan<double> x  ,  scm2cpp::span<double> r  ,  int  n  ,  int  p );


  
 SCM2CPP_FN inline int 
 autocov( scm2cpp::cspan<double> x  ,  scm2cpp::span<double> r  ,  int  n  ,  int  p ) 
 {  for( int k = 0 ; !(k > p) ; k = (k+1) ){ double acc = 0.0; for( int i = 0 ; !(i == (n-k)) ; i = (i+1) ){ acc = (acc+(x[i]*x[(i+k)]))  ;
}  ;
 r[ k ] = acc   ;
  ;
}  ;
  return 0 ;}
#endif // AUTOCOV_HPP
