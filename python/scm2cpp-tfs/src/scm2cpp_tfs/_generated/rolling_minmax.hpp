
#ifndef ROLLING_MINMAX_HPP
#define ROLLING_MINMAX_HPP
#define SCM2CPP_MINIMAL
#include	<vector>
#include	"scm2cpp.hpp"

SCM2CPP_FN int 
 rolling_min( scm2cpp::cspan<double> x  ,  scm2cpp::span<int> q  ,  scm2cpp::span<double> out  ,  int  n  ,  int  w );
SCM2CPP_FN int 
 rolling_max( scm2cpp::cspan<double> x  ,  scm2cpp::span<int> q  ,  scm2cpp::span<double> out  ,  int  n  ,  int  w );


  
 SCM2CPP_FN inline int 
 rolling_min( scm2cpp::cspan<double> x  ,  scm2cpp::span<int> q  ,  scm2cpp::span<double> out  ,  int  n  ,  int  w ) 
 {  int head = 0;int tail = 0; for( int i = 0 ; !(i == n) ; i = (i+1) ){ double xi = x[i];int run = 1; for( int z = 0 ; !(run == 0) ; z = 0 ){ if( tail > head ) {  if( x[q[(tail-1)]] >= xi ) {  tail = (tail-1)  ;
 } else {  run = 0  ;
 }  ;
 } else {  run = 0  ;
 }  ;
}  ;
 q[ tail ] = i   ;
 tail = (tail+1)  ;
 if( q[head] <= (i-w) ) {  head = (head+1)  ;
 } else {  0  ;
 }  ;
 if( i >= (w-1) ) {  out[ (i-(w-1)) ] = x[q[head]]   ;
 } else {  0  ;
 }  ;
  ;
}  ;
  ;
  return 0 ;}

  
 SCM2CPP_FN inline int 
 rolling_max( scm2cpp::cspan<double> x  ,  scm2cpp::span<int> q  ,  scm2cpp::span<double> out  ,  int  n  ,  int  w ) 
 {  int head = 0;int tail = 0; for( int i = 0 ; !(i == n) ; i = (i+1) ){ double xi = x[i];int run = 1; for( int z = 0 ; !(run == 0) ; z = 0 ){ if( tail > head ) {  if( x[q[(tail-1)]] <= xi ) {  tail = (tail-1)  ;
 } else {  run = 0  ;
 }  ;
 } else {  run = 0  ;
 }  ;
}  ;
 q[ tail ] = i   ;
 tail = (tail+1)  ;
 if( q[head] <= (i-w) ) {  head = (head+1)  ;
 } else {  0  ;
 }  ;
 if( i >= (w-1) ) {  out[ (i-(w-1)) ] = x[q[head]]   ;
 } else {  0  ;
 }  ;
  ;
}  ;
  ;
  return 0 ;}
#endif // ROLLING_MINMAX_HPP
