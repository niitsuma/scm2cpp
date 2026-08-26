
#ifndef LEVINSON_HPP
#define LEVINSON_HPP
#define SCM2CPP_MINIMAL
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN int 
 levinson( scm2cpp::cspan<double> r  ,  scm2cpp::span<double> phi  ,  scm2cpp::span<double> work  ,  scm2cpp::span<double> pacf  ,  scm2cpp::span<double> errs  ,  int  p );


  
 SCM2CPP_FN inline int 
 levinson( scm2cpp::cspan<double> r  ,  scm2cpp::span<double> phi  ,  scm2cpp::span<double> work  ,  scm2cpp::span<double> pacf  ,  scm2cpp::span<double> errs  ,  int  p ) 
 {  double e = r[0]; for( int m = 1 ; !(m > p) ; m = (m+1) ){ double acc = r[m]; for( int j = 1 ; !(j == m) ; j = (j+1) ){ acc = (acc-(phi[(j-1)]*r[(m-j)]))  ;
}  ;
 double k = (acc/e); for( int j = 0 ; !(j == m) ; j = (j+1) ){ work[ j ] = phi[j]   ;
}  ;
 for( int j = 0 ; !(j == (m-1)) ; j = (j+1) ){ phi[ j ] = (work[j]-(k*work[(m-2-j)]))   ;
}  ;
 phi[ (m-1) ] = k   ;
 pacf[ (m-1) ] = k   ;
 e = (e*(1.0-(k*k)))  ;
 errs[ (m-1) ] = e   ;
  ;
  ;
}  ;
  ;
  return 0 ;}
#endif // LEVINSON_HPP
