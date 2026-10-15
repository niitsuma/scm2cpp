
#ifndef CLASSIFIERS_HPP
#define CLASSIFIERS_HPP
#define SCM2CPP_MINIMAL
#include	<cmath>
#include	<math.h>
#include	<array>
#include	<vector>
#include	"scm2cpp.hpp"

int
svm_liblinear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> alpha,  scm2cpp::span<double> xnorm,  double  cost,  int  iters,  double  tol,  int  seed,  int  n,  int  p );
int
svm_smo( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y,  scm2cpp::span<double> alpha,  scm2cpp::span<double> rho,  double  cost,  int  iters,  double  eps,  int  n );
int
smo_solve( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y,  scm2cpp::cspan<double> lin,  scm2cpp::span<double> alpha,  std::array<double,1> & rho,  double  cost,  int  iters,  double  eps,  int  n,  int  nk );
SCM2CPP_FN int
shrinkable_P( scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  double  cost,  double  gmax1,  double  gmax2,  int  t );
SCM2CPP_FN int
swap_position( scm2cpp::span<int> index,  scm2cpp::span<int> krow,  scm2cpp::span<double> pp,  scm2cpp::span<double> yy,  scm2cpp::span<double> a,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t );
SCM2CPP_FN int
reconstruct_gradient( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> krow,  scm2cpp::cspan<double> pp,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::span<double> g,  scm2cpp::cspan<double> gbar,  double  cost,  int  active,  int  n,  int  nk );
SCM2CPP_FN int
select_working_set( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> krow,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  scm2cpp::cspan<double> qd,  double  cost,  double  eps,  int  active,  int  nk,  std::array<int,2> & wi );
int
svr_smo( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> z,  scm2cpp::span<double> beta,  scm2cpp::span<double> rho,  double  cost,  double  epsilon,  int  iters,  double  eps,  int  n );
int
logistic_l1( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  double  cost,  double  tol,  int  maxnewton,  int  seed,  int  n,  int  p );
int
svr_liblinear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> beta,  scm2cpp::span<double> xnorm,  double  cost,  double  epsilon,  int  iters,  double  tol,  int  seed,  int  n,  int  p );
SCM2CPP_FN double
ols_rows( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> rows,  int  m,  scm2cpp::span<double> w,  scm2cpp::span<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  scm2cpp::span<double> xm,  int  n,  int  p );
int
ransac( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> subsets,  scm2cpp::span<double> coef,  scm2cpp::span<double> mask,  scm2cpp::span<double> out,  double  maxtrials,  int  minsamples,  double  thresh,  double  stopprob,  int  n,  int  p );
SCM2CPP_FN double
sgd_loss( int  loss,  double  y,  double  p,  double  epsilon );
SCM2CPP_FN double
sgd_grad( int  loss,  double  y,  double  p,  double  epsilon );
SCM2CPP_FN int
sgd( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> out,  int  loss,  int  lr,  int  pen,  double  alpha,  double  eta0,  double  powert,  double  epsilon,  int  maxiter,  double  tol,  int  niternochange,  int  fitint,  int  n,  int  p );
SCM2CPP_FN double
sgd_min( double  a,  double  b );
SCM2CPP_FN double
min_pos( scm2cpp::cspan<double> v,  int  m );
SCM2CPP_FN double
round_even( double  y );
SCM2CPP_FN int
cholesky_delete( scm2cpp::span<double> l,  int  go,  int  n,  int  k );
SCM2CPP_FN int
swap_rc( scm2cpp::span<double> g,  int  a,  int  b,  int  p );
int
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  int  rec,  double  nsamples,  double  alphamin,  int  method,  int  maxiter,  double  eps,  int  p );
int
svm_l1( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  double  cost,  double  tol,  int  maxiter,  int  seed,  int  n,  int  p );
SCM2CPP_FN double
svm_l1_abs( double  a );
SCM2CPP_FN double
eig_hypot( double  a,  double  b );
SCM2CPP_FN int
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m );
SCM2CPP_FN double
eig_abs( double  a );
SCM2CPP_FN int
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  int  m );
SCM2CPP_FN int
ts_minnorm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> aa,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> ab,  int  s,  int  ns,  int  fitint,  int  p,  int  d );
SCM2CPP_FN int
ts_fit( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> aa,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> ab,  int  s,  int  ns,  int  fitint,  int  p,  int  d );
SCM2CPP_FN double
ts_abs( double  v );
int
theilsen( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> coef,  int  nsub,  int  ns,  int  fitint,  int  maxiter,  double  tol,  int  p );



inline int
svm_liblinear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> alpha,  scm2cpp::span<double> xnorm,  double  cost,  int  iters,  double  tol,  int  seed,  int  n,  int  p )
{   for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        double acc = 0.0;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            acc = (acc+(x[((i*p)+j)]*x[((i*p)+j)]))  ;
        }  ;
        xnorm[ i ] = acc   ;
        ;
    }  ;
    std::vector<int> index(n,0);
    int rng = seed;
    int active = n;
    double pgmaxold = 1e+300;
    double pgminold = -1e+300;
    int stop = 0;
    int sweeps = 0;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        index[ i ] = i   ;
    }  ;
    for( int sweep = 0 ; !((sweep == iters || stop == 1)) ; sweep = (sweep+1) ) {
        double pgmax = -1e+300;
        double pgmin = 1e+300;
        for( int i = 0 ; !(i == active) ; i = (i+1) ) {
            rng = ((16807*(rng % 127773))-(2836*(rng / 127773)))  ;
            if( rng < 0 ) {
                rng = (rng+2147483647)  ;
            } else {
                0  ;
            }  ;
            int j = (i+(rng % (active-i)));
            int t = index[i];
            index[ i ] = index[j]   ;
            index[ j ] = t   ;
            ;
        }  ;
        int s = 0;
        for(  ; !(s >= active) ;  ) {
            int i = index[s];
            double dot = 0.0;
            double old = alpha[i];
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                dot = (dot+(x[((i*p)+j)]*w[j]))  ;
            }  ;
            double g = ((y[i]*dot)-1.0);
            double pg = 0.0;
            int shrunk = 0;
            if( old == 0.0 ) {
                if( g > pgmaxold ) {
                    shrunk = 1  ;
                } else {
                    if( g < 0.0 ) {
                        pg = g  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
            } else {
                if( old == cost ) {
                    if( g < pgminold ) {
                        shrunk = 1  ;
                    } else {
                        if( g > 0.0 ) {
                            pg = g  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                } else {
                    pg = g  ;
                }  ;
            }  ;
            if( shrunk == 1 ) {
                active = (active-1)  ;
                index[ s ] = index[active]   ;
                index[ active ] = i   ;
            } else {
                if( pg > pgmax ) {
                    pgmax = pg  ;
                } else {
                    0  ;
                }  ;
                if( pg < pgmin ) {
                    pgmin = pg  ;
                } else {
                    0  ;
                }  ;
                if( (pg > 1e-12 || pg < -1e-12) ) {
                    double step = (old-(g/xnorm[i]));
                    double anew = ( ( step < 0.0 ) ? (0.0) : (( ( step > cost ) ? (cost) : (step) )) );
                    alpha[ i ] = anew   ;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        w[ j ] = (w[j]+(x[((i*p)+j)]*((anew-old)*y[i])))   ;
                    }  ;
                    ;
                    ;
                } else {
                    0  ;
                }  ;
                s = (s+1)  ;
            }  ;
            ;
            ;
            ;
        }  ;
        ;
        sweeps = (sweeps+1)  ;
        if( (pgmax-pgmin) <= tol ) {
            if( active == n ) {
                stop = 1  ;
            } else {
                active = n  ;
                pgmaxold = 1e+300  ;
                pgminold = -1e+300  ;
            }  ;
        } else {
            pgmaxold = ( ( pgmax <= 0.0 ) ? (1e+300) : (pgmax) )  ;
            pgminold = ( ( pgmin >= 0.0 ) ? (-1e+300) : (pgmin) )  ;
        }  ;
        ;
    }  ;
    return sweeps ;
}


inline int
svm_smo( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y,  scm2cpp::span<double> alpha,  scm2cpp::span<double> rho,  double  cost,  int  iters,  double  eps,  int  n )
{   std::vector<double> lin(n,-1.0);
    std::vector<double> yv(n,0.0);
    std::vector<double> av(n,0.0);
    std::array<double,1> rv = scm2cpp::filled_array<double,1>(0.0);
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        yv[ i ] = y[i]   ;
    }  ;
    int it = smo_solve(k,yv,lin,av,rv,cost,iters,eps,n,n);
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        alpha[ i ] = av[i]   ;
    }  ;
    rho[ 0 ] = rv[0]   ;
    return it ;
}


inline int
smo_solve( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y,  scm2cpp::cspan<double> lin,  scm2cpp::span<double> alpha,  std::array<double,1> & rho,  double  cost,  int  iters,  double  eps,  int  n,  int  nk )
{   std::vector<int> index(n,0);
    std::vector<int> krow(n,0);
    std::vector<double> pp(n,0.0);
    std::vector<double> yy(n,0.0);
    std::vector<double> a(n,0.0);
    std::vector<double> g(n,0.0);
    std::vector<double> gbar(n,0.0);
    std::vector<double> qd(n,0.0);
    int active = n;
    int unshrink = 0;
    int counter = (( ( n < 1000 ) ? (n) : (1000) )+1);
    int iter = 0;
    int done = 0;
    for( int t = 0 ; !(t == n) ; t = (t+1) ) {
        index[ t ] = t   ;
        krow[ t ] = (t % nk)   ;
        pp[ t ] = lin[t]   ;
        yy[ t ] = y[t]   ;
        g[ t ] = lin[t]   ;
        qd[ t ] = k[((krow[t]*nk)+krow[t])]   ;
    }  ;
    for(  ; !((done == 1 || iter >= iters)) ;  ) {
        counter = (counter-1)  ;
        if( counter == 0 ) {
            counter = ( ( n < 1000 ) ? (n) : (1000) )  ;
            double gmax1 = -1e+300;
            double gmax2 = -1e+300;
            for( int t = 0 ; !(t == active) ; t = (t+1) ) {
                double gt = g[t];
                double at = a[t];
                if( yy[t] > 0.0 ) {
                    if( (at < cost && (0.0-gt) > gmax1) ) {
                        gmax1 = (0.0-gt)  ;
                    } else {
                        0  ;
                    }  ;
                    if( (at > 0.0 && gt > gmax2) ) {
                        gmax2 = gt  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( (at < cost && (0.0-gt) > gmax2) ) {
                        gmax2 = (0.0-gt)  ;
                    } else {
                        0  ;
                    }  ;
                    if( (at > 0.0 && gt > gmax1) ) {
                        gmax1 = gt  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                ;
            }  ;
            if( (unshrink == 0 && (gmax1+gmax2) <= (eps*10.0)) ) {
                unshrink = 1  ;
                reconstruct_gradient(k,krow,pp,yy,a,g,gbar,cost,active,n,nk)  ;
                active = n  ;
            } else {
                0  ;
            }  ;
            int t = 0;
            for(  ; !(t >= active) ;  ) {
                if( shrinkable_P(yy,a,g,cost,gmax1,gmax2,t) == 1 ) {
                    active = (active-1)  ;
                    int found = 0;
                    for(  ; !((found == 1 || active <= t)) ;  ) {
                        if( shrinkable_P(yy,a,g,cost,gmax1,gmax2,active) == 0 ) {
                            swap_position(index,krow,pp,yy,a,g,gbar,qd,t,active)  ;
                            found = 1  ;
                        } else {
                            active = (active-1)  ;
                        }  ;
                    }  ;
                    ;
                    t = (t+1)  ;
                } else {
                    t = (t+1)  ;
                }  ;
            }  ;
            ;
            ;
        } else {
            0  ;
        }  ;
        std::array<int,2> wi = scm2cpp::filled_array<int,2>(0);
        if( select_working_set(k,krow,yy,a,g,qd,cost,eps,active,nk,wi) == 1 ) {
            reconstruct_gradient(k,krow,pp,yy,a,g,gbar,cost,active,n,nk)  ;
            active = n  ;
            if( select_working_set(k,krow,yy,a,g,qd,cost,eps,active,nk,wi) == 1 ) {
                done = 1  ;
            } else {
                counter = 1  ;
            }  ;
        } else {
            0  ;
        }  ;
        if( done == 0 ) {
            int i = wi[0];
            int j = wi[1];
            iter = (iter+1)  ;
            double ai = a[i];
            double aj = a[j];
            double yi = yy[i];
            double yj = yy[j];
            int pi = krow[i];
            int pj = krow[j];
            double qij = ((yi*yj)*k[((pi*nk)+pj)]);
            int ui = ( ( ai >= cost ) ? (1) : (0) );
            int uj = ( ( aj >= cost ) ? (1) : (0) );
            double ni = ai;
            double nj = aj;
            if( !(yi == yj) ) {
                double quad = ((qd[i]+qd[j])+(2.0*qij));
                if( quad <= 0.0 ) {
                    quad = 1e-12  ;
                } else {
                    0  ;
                }  ;
                double delta = (((0.0-g[i])-g[j])/quad);
                double diff = (ai-aj);
                ni = (ai+delta)  ;
                nj = (aj+delta)  ;
                if( diff > 0.0 ) {
                    if( nj < 0.0 ) {
                        nj = 0.0  ;
                        ni = diff  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( ni < 0.0 ) {
                        ni = 0.0  ;
                        nj = (0.0-diff)  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                if( diff > 0.0 ) {
                    if( ni > cost ) {
                        ni = cost  ;
                        nj = (cost-diff)  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( nj > cost ) {
                        nj = cost  ;
                        ni = (cost+diff)  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                ;
                ;
            } else {
                double quad = ((qd[i]+qd[j])-(2.0*qij));
                if( quad <= 0.0 ) {
                    quad = 1e-12  ;
                } else {
                    0  ;
                }  ;
                double delta = ((g[i]-g[j])/quad);
                double sum = (ai+aj);
                ni = (ai-delta)  ;
                nj = (aj+delta)  ;
                if( sum > cost ) {
                    if( ni > cost ) {
                        ni = cost  ;
                        nj = (sum-cost)  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( nj < 0.0 ) {
                        nj = 0.0  ;
                        ni = sum  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                if( sum > cost ) {
                    if( nj > cost ) {
                        nj = cost  ;
                        ni = (sum-cost)  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( ni < 0.0 ) {
                        ni = 0.0  ;
                        nj = sum  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
                ;
                ;
            }  ;
            a[ i ] = ni   ;
            a[ j ] = nj   ;
            double di = (ni-ai);
            double dj = (nj-aj);
            for( int t = 0 ; !(t == active) ; t = (t+1) ) {
                int pt = krow[t];
                double yt = yy[t];
                g[ t ] = (g[t]+(yt*(((yi*di)*k[((pi*nk)+pt)])+((yj*dj)*k[((pj*nk)+pt)]))))   ;
                ;
            }  ;
            if( !(ui == ( ( ni >= cost ) ? (1) : (0) )) ) {
                for( int t = 0 ; !(t == n) ; t = (t+1) ) {
                    gbar[ t ] = (gbar[t]+(( ( ui == 1 ) ? ((0.0-cost)) : (cost) )*((yi*yy[t])*k[((pi*nk)+krow[t])])))   ;
                }  ;
            } else {
                0  ;
            }  ;
            if( !(uj == ( ( nj >= cost ) ? (1) : (0) )) ) {
                for( int t = 0 ; !(t == n) ; t = (t+1) ) {
                    gbar[ t ] = (gbar[t]+(( ( uj == 1 ) ? ((0.0-cost)) : (cost) )*((yj*yy[t])*k[((pj*nk)+krow[t])])))   ;
                }  ;
            } else {
                0  ;
            }  ;
            ;
            ;
            ;
            ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    if( active < n ) {
        reconstruct_gradient(k,krow,pp,yy,a,g,gbar,cost,active,n,nk)  ;
        active = n  ;
    } else {
        0  ;
    }  ;
    int nfree = 0;
    double sumfree = 0.0;
    double ub = 1e+300;
    double lb = -1e+300;
    for( int t = 0 ; !(t == n) ; t = (t+1) ) {
        double yg = (yy[t]*g[t]);
        double at = a[t];
        double yt = yy[t];
        if( at >= cost ) {
            if( yt < 0.0 ) {
                if( yg < ub ) {
                    ub = yg  ;
                } else {
                    0  ;
                }  ;
            } else {
                if( yg > lb ) {
                    lb = yg  ;
                } else {
                    0  ;
                }  ;
            }  ;
        } else {
            if( at <= 0.0 ) {
                if( yt > 0.0 ) {
                    if( yg < ub ) {
                        ub = yg  ;
                    } else {
                        0  ;
                    }  ;
                } else {
                    if( yg > lb ) {
                        lb = yg  ;
                    } else {
                        0  ;
                    }  ;
                }  ;
            } else {
                nfree = (nfree+1)  ;
                sumfree = (sumfree+yg)  ;
            }  ;
        }  ;
        ;
    }  ;
    rho[ 0 ] = ( ( nfree > 0 ) ? ((sumfree/(1.0*nfree))) : (((ub+lb)/2.0)) )   ;
    ;
    for( int t = 0 ; !(t == n) ; t = (t+1) ) {
        alpha[ index[t] ] = a[t]   ;
    }  ;
    return iter ;
}


SCM2CPP_FN inline int
shrinkable_P( scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  double  cost,  double  gmax1,  double  gmax2,  int  t )
{
    double at = a[t];
    double gt = g[t];
    double yt = yy[t];
    if( at >= cost ) {
        if( yt > 0.0 ) {
            if( (0.0-gt) > gmax1 ) {
                return 1 ;
            }
            else {
                return 0 ;
            }
        }
        else {
            if( (0.0-gt) > gmax2 ) {
                return 1 ;
            }
            else {
                return 0 ;
            }
        }
    }
    else {
        if( at <= 0.0 ) {
            if( yt > 0.0 ) {
                if( gt > gmax2 ) {
                    return 1 ;
                }
                else {
                    return 0 ;
                }
            }
            else {
                if( gt > gmax1 ) {
                    return 1 ;
                }
                else {
                    return 0 ;
                }
            }
        }
        else {
            return 0 ;
        }
    }
}


SCM2CPP_FN inline int
swap_position( scm2cpp::span<int> index,  scm2cpp::span<int> krow,  scm2cpp::span<double> pp,  scm2cpp::span<double> yy,  scm2cpp::span<double> a,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t )
{   int i0 = index[s];
    double y0 = yy[s];
    double a0 = a[s];
    double g0 = g[s];
    double b0 = gbar[s];
    double q0 = qd[s];
    int r0 = krow[s];
    double p0 = pp[s];
    index[ s ] = index[t]   ;
    index[ t ] = i0   ;
    krow[ s ] = krow[t]   ;
    krow[ t ] = r0   ;
    pp[ s ] = pp[t]   ;
    pp[ t ] = p0   ;
    yy[ s ] = yy[t]   ;
    yy[ t ] = y0   ;
    a[ s ] = a[t]   ;
    a[ t ] = a0   ;
    g[ s ] = g[t]   ;
    g[ t ] = g0   ;
    gbar[ s ] = gbar[t]   ;
    gbar[ t ] = b0   ;
    qd[ s ] = qd[t]   ;
    qd[ t ] = q0   ;
    return 0 ;
}


SCM2CPP_FN inline int
reconstruct_gradient( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> krow,  scm2cpp::cspan<double> pp,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::span<double> g,  scm2cpp::cspan<double> gbar,  double  cost,  int  active,  int  n,  int  nk )
{   for( int t = active ; !(t >= n) ; t = (t+1) ) {
        g[ t ] = (gbar[t]+pp[t])   ;
    }  ;
    for( int s = 0 ; !(s >= active) ; s = (s+1) ) {
        double as = a[s];
        if( (as > 0.0 && as < cost) ) {
            int ps = krow[s];
            double ys = yy[s];
            for( int t = active ; !(t >= n) ; t = (t+1) ) {
                g[ t ] = (g[t]+(as*((ys*yy[t])*k[((ps*nk)+krow[t])])))   ;
            }  ;
            ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
select_working_set( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> krow,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  scm2cpp::cspan<double> qd,  double  cost,  double  eps,  int  active,  int  nk,  std::array<int,2> & wi )
{   double gmax = -1e+300;
    int gmaxi = -1;
    double gmax2 = -1e+300;
    int gmini = -1;
    double objmin = 1e+300;
    for( int t = 0 ; !(t == active) ; t = (t+1) ) {
        double gt = g[t];
        double at = a[t];
        if( yy[t] > 0.0 ) {
            if( (at < cost && (0.0-gt) >= gmax) ) {
                gmax = (0.0-gt)  ;
                gmaxi = t  ;
            } else {
                0  ;
            }  ;
        } else {
            if( (at > 0.0 && gt >= gmax) ) {
                gmax = gt  ;
                gmaxi = t  ;
            } else {
                0  ;
            }  ;
        }  ;
        ;
    }  ;
    if( gmaxi >= 0 ) {
        int pi = krow[gmaxi];
        double yi = yy[gmaxi];
        double qdi = qd[gmaxi];
        for( int t = 0 ; !(t == active) ; t = (t+1) ) {
            double gt = g[t];
            double at = a[t];
            double yt = yy[t];
            if( yt > 0.0 ) {
                if( at > 0.0 ) {
                    double gd = (gmax+gt);
                    if( gt >= gmax2 ) {
                        gmax2 = gt  ;
                    } else {
                        0  ;
                    }  ;
                    if( gd > 0.0 ) {
                        double quad = ((qdi+qd[t])-(2.0*(yi*(yi*(yt*k[((pi*nk)+krow[t])])))));
                        double obj = ((0.0-(gd*gd))/( ( quad > 0.0 ) ? (quad) : (1e-12) ));
                        if( obj <= objmin ) {
                            objmin = obj  ;
                            gmini = t  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        ;
                    } else {
                        0  ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
            } else {
                if( at < cost ) {
                    double gd = (gmax-gt);
                    if( (0.0-gt) >= gmax2 ) {
                        gmax2 = (0.0-gt)  ;
                    } else {
                        0  ;
                    }  ;
                    if( gd > 0.0 ) {
                        double quad = ((qdi+qd[t])+(2.0*(yi*(yi*(yt*k[((pi*nk)+krow[t])])))));
                        double obj = ((0.0-(gd*gd))/( ( quad > 0.0 ) ? (quad) : (1e-12) ));
                        if( obj <= objmin ) {
                            objmin = obj  ;
                            gmini = t  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        ;
                    } else {
                        0  ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
            }  ;
            ;
        }  ;
        ;
    } else {
        0  ;
    }  ;
    wi[ 0 ] = gmaxi   ;
    wi[ 1 ] = gmini   ;
    if( ((gmax+gmax2) < eps || gmini < 0) ) {
        return 1 ;
    }
    else {
        return 0 ;
    }
}


inline int
svr_smo( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> z,  scm2cpp::span<double> beta,  scm2cpp::span<double> rho,  double  cost,  double  epsilon,  int  iters,  double  eps,  int  n )
{   std::vector<double> y2((2*n),0.0);
    std::vector<double> lin((2*n),0.0);
    std::vector<double> a2((2*n),0.0);
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        y2[ i ] = 1.0   ;
        y2[ (i+n) ] = -1.0   ;
        lin[ i ] = (epsilon-z[i])   ;
        lin[ (i+n) ] = (epsilon+z[i])   ;
    }  ;
    std::array<double,1> rv = scm2cpp::filled_array<double,1>(0.0);
    int it = smo_solve(k,y2,lin,a2,rv,cost,iters,eps,int((2*n)),n);
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        beta[ i ] = (a2[i]-a2[(i+n)])   ;
    }  ;
    rho[ 0 ] = rv[0]   ;
    return it ;
}


inline int
logistic_l1( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  double  cost,  double  tol,  int  maxnewton,  int  seed,  int  n,  int  p )
{   std::vector<int> index(p,0);
    std::vector<double> hdiag(p,0.0);
    std::vector<double> grad(p,0.0);
    std::vector<double> wpd(p,0.0);
    std::vector<double> xjneg(p,0.0);
    std::vector<double> xtd(n,0.0);
    std::vector<double> ewx(n,0.0);
    std::vector<double> ewxnew(n,0.0);
    std::vector<double> tau(n,0.0);
    std::vector<double> d(n,0.0);
    int rng = seed;
    int npos = 0;
    int newton = 0;
    double wnorm = 0.0;
    double ginit = -1.0;
    double gmaxold = 1e+300;
    int qpnochange = 0;
    double innereps = 1.0;
    int done = 0;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( y[i] > 0.0 ) {
            npos = (npos+1)  ;
        } else {
            0  ;
        }  ;
    }  ;

    struct let24289 {
        let24289() {}
        int operator()( int  m  )
        {
            if( m < 1 ) {
                return 1 ;
            }
            else {
                return m ;
            }
        }
    }  ;
    double eps = ((tol*(1.0*let24289()(( ( npos < (n-npos) ) ? (npos) : ((n-npos)) ))))/(1.0*n));
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        w[ j ] = 0.0   ;
        wpd[ j ] = 0.0   ;
        index[ j ] = j   ;
        double acc = 0.0;
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            if( y[i] < 0.0 ) {
                acc = (acc+(cost*x[((j*n)+i)]))  ;
            } else {
                0  ;
            }  ;
        }  ;
        xjneg[ j ] = acc   ;
        ;
    }  ;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        ewx[ i ] = 1.0   ;
        tau[ i ] = (cost*0.5)   ;
        d[ i ] = (cost*0.25)   ;
    }  ;
    for(  ; !((done == 1 || newton >= maxnewton)) ;  ) {
        double gmaxnew = 0.0;
        double gnorm1new = 0.0;
        int active = p;
        int s = 0;
        for(  ; !(s >= active) ;  ) {
            int j = index[s];
            double h = 1e-12;
            double tmp = 0.0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                double v = x[((j*n)+i)];
                h = (h+((v*v)*d[i]))  ;
                tmp = (tmp+(v*tau[i]))  ;
                ;
            }  ;
            hdiag[ j ] = h   ;
            grad[ j ] = ((0.0-tmp)+xjneg[j])   ;
            double gp = (grad[j]+1.0);
            double gn = (grad[j]-1.0);
            double wj = w[j];
            double viol = 0.0;
            int shrunk = 0;
            if( wj == 0.0 ) {
                if( gp < 0.0 ) {
                    viol = (0.0-gp)  ;
                } else {
                    if( gn > 0.0 ) {
                        viol = gn  ;
                    } else {
                        if( (gp > (gmaxold/(1.0*n)) && gn < (0.0-(gmaxold/(1.0*n)))) ) {
                            shrunk = 1  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                }  ;
            } else {
                if( wj > 0.0 ) {
                    viol = ( ( gp < 0.0 ) ? ((0.0-gp)) : (gp) )  ;
                } else {
                    viol = ( ( gn < 0.0 ) ? ((0.0-gn)) : (gn) )  ;
                }  ;
            }  ;
            if( shrunk == 1 ) {
                active = (active-1)  ;
                index[ s ] = index[active]   ;
                index[ active ] = j   ;
            } else {
                if( viol > gmaxnew ) {
                    gmaxnew = viol  ;
                } else {
                    0  ;
                }  ;
                gnorm1new = (gnorm1new+viol)  ;
                s = (s+1)  ;
            }  ;
            ;
            ;
        }  ;
        ;
        if( newton == 0 ) {
            ginit = gnorm1new  ;
        } else {
            0  ;
        }  ;
        if( (gnorm1new <= (eps*ginit) || qpnochange >= 10) ) {
            done = 1  ;
        } else {
            qpnochange = (qpnochange+1)  ;
            int iter = 0;
            double qpgmaxold = 1e+300;
            int qpactive = active;
            int stopqp = 0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                xtd[ i ] = 0.0   ;
            }  ;
            for(  ; !((stopqp == 1 || iter >= 1000)) ;  ) {
                double qpgmaxnew = 0.0;
                double qpgnorm1new = 0.0;
                for( int t = 0 ; !(t == qpactive) ; t = (t+1) ) {
                    rng = ((16807*(rng % 127773))-(2836*(rng / 127773)))  ;
                    if( rng < 0 ) {
                        rng = (rng+2147483647)  ;
                    } else {
                        0  ;
                    }  ;
                    int k = (t+(rng % (qpactive-t)));
                    int tt = index[t];
                    index[ t ] = index[k]   ;
                    index[ k ] = tt   ;
                    ;
                }  ;
                int s = 0;
                for(  ; !(s >= qpactive) ;  ) {
                    int j = index[s];
                    double h = hdiag[j];
                    double g = (grad[j]+((wpd[j]-w[j])*1e-12));
                    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                        g = (g+(x[((j*n)+i)]*(d[i]*xtd[i])))  ;
                    }  ;
                    double gp = (g+1.0);
                    double gn = (g-1.0);
                    double wj = wpd[j];
                    double viol = 0.0;
                    int shrunk = 0;
                    if( wj == 0.0 ) {
                        if( gp < 0.0 ) {
                            viol = (0.0-gp)  ;
                        } else {
                            if( gn > 0.0 ) {
                                viol = gn  ;
                            } else {
                                if( (gp > (qpgmaxold/(1.0*n)) && gn < (0.0-(qpgmaxold/(1.0*n)))) ) {
                                    shrunk = 1  ;
                                } else {
                                    0  ;
                                }  ;
                            }  ;
                        }  ;
                    } else {
                        if( wj > 0.0 ) {
                            viol = ( ( gp < 0.0 ) ? ((0.0-gp)) : (gp) )  ;
                        } else {
                            viol = ( ( gn < 0.0 ) ? ((0.0-gn)) : (gn) )  ;
                        }  ;
                    }  ;
                    if( shrunk == 1 ) {
                        qpactive = (qpactive-1)  ;
                        index[ s ] = index[qpactive]   ;
                        index[ qpactive ] = j   ;
                    } else {
                        double z = ( ( gp < (h*wj) ) ? (((0.0-gp)/h)) : (( ( gn > (h*wj) ) ? (((0.0-gn)/h)) : ((0.0-wj)) )) );
                        if( (z > 1e-12 || z < -1e-12) ) {
                            double zc = ( ( z < -10.0 ) ? (-10.0) : (( ( z > 10.0 ) ? (10.0) : (z) )) );
                            qpnochange = 0  ;
                            if( viol > qpgmaxnew ) {
                                qpgmaxnew = viol  ;
                            } else {
                                0  ;
                            }  ;
                            qpgnorm1new = (qpgnorm1new+viol)  ;
                            wpd[ j ] = (wj+zc)   ;
                            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                                xtd[ i ] = (xtd[i]+(x[((j*n)+i)]*zc))   ;
                            }  ;
                            ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        s = (s+1)  ;
                    }  ;
                    ;
                    ;
                    ;
                }  ;
                ;
                iter = (iter+1)  ;
                if( qpgnorm1new <= (innereps*ginit) ) {
                    if( qpactive == active ) {
                        stopqp = 1  ;
                    } else {
                        qpactive = active  ;
                        qpgmaxold = 1e+300  ;
                    }  ;
                } else {
                    qpgmaxold = qpgmaxnew  ;
                }  ;
                ;
            }  ;
            double delta = 0.0;
            double wnormnew = 0.0;
            double negsum = 0.0;
            int found = 0;
            int nls = 0;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                delta = (delta+(grad[j]*(wpd[j]-w[j])))  ;
                double v = wpd[j];
                if( !(v == 0.0) ) {
                    wnormnew = (wnormnew+( ( v < 0.0 ) ? ((0.0-v)) : (v) ))  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
            delta = (delta+(wnormnew-wnorm))  ;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                if( y[i] < 0.0 ) {
                    negsum = (negsum+(cost*xtd[i]))  ;
                } else {
                    0  ;
                }  ;
            }  ;
            for(  ; !((found == 1 || nls >= 20)) ;  ) {
                double cond0 = (((wnormnew-wnorm)+negsum)-(0.01*delta));
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    double ex = exp(xtd[i]);
                    ewxnew[ i ] = (ewx[i]*ex)   ;
                    cond0 = (cond0+(cost*log(((1.0+ewxnew[i])/(ex+ewxnew[i])))))  ;
                    ;
                }  ;
                if( cond0 <= 0.0 ) {
                    found = 1  ;
                    wnorm = wnormnew  ;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        w[ j ] = wpd[j]   ;
                    }  ;
                    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                        double e = ewxnew[i];
                        ewx[ i ] = e   ;
                        double tt = (1.0/(1.0+e));
                        tau[ i ] = (cost*tt)   ;
                        d[ i ] = (cost*(e*(tt*tt)))   ;
                        ;
                        ;
                    }  ;
                } else {
                    wnormnew = 0.0  ;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        double v = ((w[j]+wpd[j])*0.5);
                        wpd[ j ] = v   ;
                        if( !(v == 0.0) ) {
                            wnormnew = (wnormnew+( ( v < 0.0 ) ? ((0.0-v)) : (v) ))  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                    }  ;
                    delta = (delta*0.5)  ;
                    negsum = (negsum*0.5)  ;
                    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                        xtd[ i ] = (xtd[i]*0.5)   ;
                    }  ;
                    nls = (nls+1)  ;
                }  ;
                ;
            }  ;
            if( nls >= 20 ) {
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    double acc = 0.0;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        acc = (acc+(w[j]*x[((j*n)+i)]))  ;
                    }  ;
                    ewx[ i ] = exp(acc)   ;
                    ;
                }  ;
            } else {
                0  ;
            }  ;
            ;
            if( iter == 1 ) {
                innereps = (innereps*0.25)  ;
            } else {
                0  ;
            }  ;
            ;
            newton = (newton+1)  ;
            gmaxold = gmaxnew  ;
        }  ;
        ;
    }  ;
    return newton ;
}


inline int
svr_liblinear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> beta,  scm2cpp::span<double> xnorm,  double  cost,  double  epsilon,  int  iters,  double  tol,  int  seed,  int  n,  int  p )
{   std::vector<int> index(n,0);
    int rng = seed;
    int active = n;
    double gmaxold = 1e+300;
    double ginit = -1.0;
    int iter = 0;
    int done = 0;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        double acc = 0.0;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            acc = (acc+(x[((i*p)+j)]*x[((i*p)+j)]))  ;
        }  ;
        xnorm[ i ] = acc   ;
        ;
        beta[ i ] = 0.0   ;
        index[ i ] = i   ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        w[ j ] = 0.0   ;
    }  ;
    for(  ; !((done == 1 || iter >= iters)) ;  ) {
        double gmaxnew = 0.0;
        double gnorm1new = 0.0;
        for( int t = 0 ; !(t == active) ; t = (t+1) ) {
            rng = ((16807*(rng % 127773))-(2836*(rng / 127773)))  ;
            if( rng < 0 ) {
                rng = (rng+2147483647)  ;
            } else {
                0  ;
            }  ;
            int k = (t+(rng % (active-t)));
            int tt = index[t];
            index[ t ] = index[k]   ;
            index[ k ] = tt   ;
            ;
        }  ;
        int s = 0;
        for(  ; !(s >= active) ;  ) {
            int i = index[s];
            double g = (0.0-y[i]);
            double h = xnorm[i];
            double b = beta[i];
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                g = (g+(x[((i*p)+j)]*w[j]))  ;
            }  ;
            double gp = (g+epsilon);
            double gn = (g-epsilon);
            double viol = 0.0;
            int shrunk = 0;
            if( b == 0.0 ) {
                if( gp < 0.0 ) {
                    viol = (0.0-gp)  ;
                } else {
                    if( gn > 0.0 ) {
                        viol = gn  ;
                    } else {
                        if( (gp > gmaxold && gn < (0.0-gmaxold)) ) {
                            shrunk = 1  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                }  ;
            } else {
                if( b >= cost ) {
                    if( gp > 0.0 ) {
                        viol = gp  ;
                    } else {
                        if( gp < (0.0-gmaxold) ) {
                            shrunk = 1  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                } else {
                    if( b <= (0.0-cost) ) {
                        if( gn < 0.0 ) {
                            viol = (0.0-gn)  ;
                        } else {
                            if( gn > gmaxold ) {
                                shrunk = 1  ;
                            } else {
                                0  ;
                            }  ;
                        }  ;
                    } else {
                        if( b > 0.0 ) {
                            viol = ( ( gp < 0.0 ) ? ((0.0-gp)) : (gp) )  ;
                        } else {
                            viol = ( ( gn < 0.0 ) ? ((0.0-gn)) : (gn) )  ;
                        }  ;
                    }  ;
                }  ;
            }  ;
            if( shrunk == 1 ) {
                active = (active-1)  ;
                index[ s ] = index[active]   ;
                index[ active ] = i   ;
            } else {
                if( viol > gmaxnew ) {
                    gmaxnew = viol  ;
                } else {
                    0  ;
                }  ;
                gnorm1new = (gnorm1new+viol)  ;
                double d = ( ( gp < (h*b) ) ? (((0.0-gp)/h)) : (( ( gn > (h*b) ) ? (((0.0-gn)/h)) : ((0.0-b)) )) );
                if( (d > 1e-12 || d < -1e-12) ) {
                    double bn = (b+d);
                    double bc = ( ( bn < (0.0-cost) ) ? ((0.0-cost)) : (( ( bn > cost ) ? (cost) : (bn) )) );
                    beta[ i ] = bc   ;
                    if( !(bc == b) ) {
                        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                            w[ j ] = (w[j]+((bc-b)*x[((i*p)+j)]))   ;
                        }  ;
                    } else {
                        false  ;
                    }  ;
                    ;
                    ;
                } else {
                    0  ;
                }  ;
                ;
                s = (s+1)  ;
            }  ;
            ;
            ;
            ;
        }  ;
        ;
        if( iter == 0 ) {
            ginit = gnorm1new  ;
        } else {
            0  ;
        }  ;
        iter = (iter+1)  ;
        if( gnorm1new <= (tol*ginit) ) {
            if( active == n ) {
                done = 1  ;
            } else {
                active = n  ;
                gmaxold = 1e+300  ;
            }  ;
        } else {
            gmaxold = gmaxnew  ;
        }  ;
        ;
    }  ;
    return iter ;
}


SCM2CPP_FN inline double
ols_rows( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> rows,  int  m,  scm2cpp::span<double> w,  scm2cpp::span<double> g,  scm2cpp::span<double> c,  scm2cpp::span<double> l,  scm2cpp::span<double> z,  scm2cpp::span<double> xm,  int  n,  int  p )
{   double ym = 0.0;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        xm[ j ] = 0.0   ;
    }  ;
    for( int r = 0 ; !(r == m) ; r = (r+1) ) {
        int i = rows[r];
        ym = (ym+y[i])  ;
        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
            xm[ j ] = (xm[j]+x[((i*p)+j)])   ;
        }  ;
        ;
    }  ;
    ym = (ym/(1.0*m))  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        xm[ j ] = (xm[j]/(1.0*m))   ;
    }  ;
    for( int t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
        g[ t ] = 0.0   ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        c[ j ] = 0.0   ;
    }  ;
    for( int r = 0 ; !(r == m) ; r = (r+1) ) {
        int i = rows[r];
        double yc = (y[i]-ym);
        for( int a = 0 ; !(a == p) ; a = (a+1) ) {
            double xa = (x[((i*p)+a)]-xm[a]);
            c[ a ] = (c[a]+(xa*yc))   ;
            for( int b = 0 ; !(b > a) ; b = (b+1) ) {
                double xb = (x[((i*p)+b)]-xm[b]);
                g[ ((a*p)+b) ] = (g[((a*p)+b)]+(xa*xb))   ;
                ;
            }  ;
            ;
        }  ;
        ;
        ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double s = g[((j*p)+j)];
        for( int k = 0 ; !(k == j) ; k = (k+1) ) {
            s = (s-(l[((j*p)+k)]*l[((j*p)+k)]))  ;
        }  ;
        l[ ((j*p)+j) ] = sqrt(( ( s > 0.0 ) ? (s) : (1e-300) ))   ;
        for( int i = (j+1) ; !(i >= p) ; i = (i+1) ) {
            double t = g[((i*p)+j)];
            for( int k = 0 ; !(k == j) ; k = (k+1) ) {
                t = (t-(l[((i*p)+k)]*l[((j*p)+k)]))  ;
            }  ;
            l[ ((i*p)+j) ] = (t/l[((j*p)+j)])   ;
            ;
        }  ;
        ;
    }  ;
    for( int i = 0 ; !(i == p) ; i = (i+1) ) {
        double t = c[i];
        for( int k = 0 ; !(k == i) ; k = (k+1) ) {
            t = (t-(l[((i*p)+k)]*z[k]))  ;
        }  ;
        z[ i ] = (t/l[((i*p)+i)])   ;
        ;
    }  ;
    for( int ii = 0 ; !(ii == p) ; ii = (ii+1) ) {
        int i = ((p-1)-ii);
        double t = z[i];
        for( int k = (i+1) ; !(k >= p) ; k = (k+1) ) {
            t = (t-(l[((k*p)+i)]*w[k]))  ;
        }  ;
        w[ i ] = (t/l[((i*p)+i)])   ;
        ;
        ;
    }  ;
    double b = ym;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        b = (b-(xm[j]*w[j]))  ;
    }  ;
    return b ;
}


inline int
ransac( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> subsets,  scm2cpp::span<double> coef,  scm2cpp::span<double> mask,  scm2cpp::span<double> out,  double  maxtrials,  int  minsamples,  double  thresh,  double  stopprob,  int  n,  int  p )
{   std::vector<int> rows(n,0);
    std::vector<int> inl(n,0);
    std::vector<double> w(p,0.0);
    std::vector<double> g((p*p),0.0);
    std::vector<double> c(p,0.0);
    std::vector<double> l((p*p),0.0);
    std::vector<double> z(p,0.0);
    std::vector<double> xm(p,0.0);
    int nbest = 1;
    double scorebest = -1e+300;
    int found = 0;
    int trials = 0;
    double limit = (1.0*maxtrials);
    double eps = 2.220446049250313e-16;
    for(  ; !((1.0*trials) >= limit) ;  ) {
        int t = trials;
        trials = (trials+1)  ;
        for( int r = 0 ; !(r == minsamples) ; r = (r+1) ) {
            rows[ r ] = subsets[((t*minsamples)+r)]   ;
        }  ;
        double b = ols_rows(x,y,rows,minsamples,w,g,c,l,z,xm,n,p);
        int ninl = 0;
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            double pred = b;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                pred = (pred+(x[((i*p)+j)]*w[j]))  ;
            }  ;
            double res = (y[i]-pred);
            if( ( ( res < 0.0 ) ? ((0.0-res)) : (res) ) <= thresh ) {
                inl[ ninl ] = i   ;
                ninl = (ninl+1)  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( ninl >= nbest ) {
            double ym = 0.0;
            double sstot = 0.0;
            double ssres = 0.0;
            for( int r = 0 ; !(r == ninl) ; r = (r+1) ) {
                ym = (ym+y[inl[r]])  ;
            }  ;
            ym = (ym/(1.0*ninl))  ;
            for( int r = 0 ; !(r == ninl) ; r = (r+1) ) {
                int i = inl[r];
                double pred = b;
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    pred = (pred+(x[((i*p)+j)]*w[j]))  ;
                }  ;
                double dr = (y[i]-pred);
                double dt = (y[i]-ym);
                ssres = (ssres+(dr*dr))  ;
                sstot = (sstot+(dt*dt))  ;
                ;
                ;
                ;
            }  ;
            double score = ( ( sstot > 0.0 ) ? ((1.0-(ssres/sstot))) : (( ( ssres > 0.0 ) ? (0.0) : (1.0) )) );
            if( !((ninl == nbest && score < scorebest)) ) {
                found = 1  ;
                nbest = ninl  ;
                scorebest = score  ;
                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                    mask[ i ] = 0.0   ;
                }  ;
                for( int r = 0 ; !(r == ninl) ; r = (r+1) ) {
                    mask[ inl[r] ] = 1.0   ;
                }  ;
                double ratio = ((1.0*nbest)/(1.0*n));
                double nom = ( ( (1.0-stopprob) > eps ) ? ((1.0-stopprob)) : (eps) );
                struct let24311 {
                    double & ratio;
                    int & minsamples;
                    let24311( double & ratio,  int & minsamples ):ratio(ratio),minsamples(minsamples)  {}
                    double operator()( double  acc  )
                {   for( int s = 0 ; !(s == minsamples) ; s = (s+1) ) {
                            acc = (acc*ratio)  ;
                        }  ;
                        return acc ;
                    }
                }  ;
                double pw = let24311(ratio,minsamples)(1.0);
                double denom = ( ( (1.0-pw) > eps ) ? ((1.0-pw)) : (eps) );
                struct let24339 {
                    let24339() {}
                    double operator()( double  q  )
                    {
                        double cq = (0.0-std::floor((0.0-q)));
                        if( cq < 0.0 ) {
                            return (0.0-cq) ;
                        }
                        else {
                            return cq ;
                        }
                    }
                }  ;
                double dyn = ( ( nom == 1.0 ) ? (0.0) : (( ( denom == 1.0 ) ? (1e+300) : (let24339()((log(nom)/log(denom)))) )) );
                if( dyn < limit ) {
                    limit = dyn  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
                ;
                ;
            } else {
                0  ;
            }  ;
            ;
            ;
        } else {
            0  ;
        }  ;
        ;
        ;
    }  ;
    int m = 0;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( mask[i] == 1.0 ) {
            rows[ m ] = i   ;
            m = (m+1)  ;
        } else {
            0  ;
        }  ;
    }  ;
    out[ 0 ] = ols_rows(x,y,rows,m,coef,g,c,l,z,xm,n,p)   ;
    ;
    return trials ;
}


SCM2CPP_FN inline double
sgd_loss( int  loss,  double  y,  double  p,  double  epsilon )
{
    if( loss == 1 ) {
        return (0.5*((p-y)*(p-y))) ;
    }
    else {
        if( loss == 3 ) {
            double r = (( ( (y-p) < 0.0 ) ? ((p-y)) : ((y-p)) )-epsilon);
            if( r > 0.0 ) {
                return r ;
            }
            else {
                return 0.0 ;
            }
        }
        else {
            double th = ( ( loss == 0 ) ? (1.0) : (0.0) );
            double z = (p*y);
            if( z <= th ) {
                return (th-z) ;
            }
            else {
                return 0.0 ;
            }
        }
    }
}


SCM2CPP_FN inline double
sgd_grad( int  loss,  double  y,  double  p,  double  epsilon )
{
    if( loss == 1 ) {
        return (p-y) ;
    }
    else {
        if( loss == 3 ) {
            if( (y-p) > epsilon ) {
                return -1.0 ;
            }
            else {
                if( (p-y) > epsilon ) {
                    return 1.0 ;
                }
                else {
                    return 0.0 ;
                }
            }
        }
        else {
            double th2 = ( ( loss == 0 ) ? (1.0) : (0.0) );
            double z2 = (p*y);
            if( z2 <= th2 ) {
                return (0.0-y) ;
            }
            else {
                return 0.0 ;
            }
        }
    }
}


SCM2CPP_FN inline int
sgd( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> out,  int  loss,  int  lr,  int  pen,  double  alpha,  double  eta0,  double  powert,  double  epsilon,  int  maxiter,  double  tol,  int  niternochange,  int  fitint,  int  n,  int  p )
{   double wscale = 1.0;
    double sqnorm = 0.0;
    double b = 0.0;
    double t = 1.0;
    double optinit = 0.0;
    double best = 1e+300;
    int noimp = 0;
    int epoch = 0;
    int done = 0;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        sqnorm = (sqnorm+(w[j]*w[j]))  ;
    }  ;
    if( lr == 0 ) {
        double typw = sqrt((1.0/sqrt(alpha)));
        double g = sgd_grad(loss,1.0,double((0.0-typw)),epsilon);
        double eta00 = (typw/( ( g > 1.0 ) ? (g) : (1.0) ));
        optinit = (1.0/(eta00*alpha))  ;
        ;
        ;
        ;
    } else {
        0  ;
    }  ;
    for(  ; !((done == 1 || epoch >= maxiter)) ;  ) {
        double objsum = 0.0;
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            double dot = 0.0;
            double sx = 0.0;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                dot = (dot+(x[((i*p)+j)]*w[j]))  ;
            }  ;
            if( lr >= 3 ) {
                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                    sx = (sx+(x[((i*p)+j)]*x[((i*p)+j)]))  ;
                }  ;
            } else {
                0  ;
            }  ;
            double pr = ((wscale*dot)+b);
            double yi = y[i];
            double eta = ( ( lr == 0 ) ? ((1.0/(alpha*((optinit+t)-1.0)))) : (( ( lr == 1 ) ? (((1.0*eta0)/std::pow(t, (1.0*powert)))) : (eta0) )) );
            double li = sgd_loss(loss,yi,pr,epsilon);
            double dl = ( ( lr < 3 ) ? (sgd_grad(loss,yi,pr,epsilon)) : (0.0) );
            objsum = (objsum+li)  ;
            if( (lr < 3 && pen == 1) ) {
                objsum = (objsum+(alpha*(0.5*sqnorm)))  ;
            } else {
                0  ;
            }  ;
            if( !((lr == 3 && sx == 0.0)) ) {
                double step = ( ( lr == 3 ) ? (sgd_min(eta0,double((li/sx)))) : (( ( lr == 4 ) ? ((li/(sx+(0.5/eta0)))) : (((0.0-eta)*( ( dl < -1000000000000.0 ) ? (-1000000000000.0) : (( ( dl > 1000000000000.0 ) ? (1000000000000.0) : (dl) )) ))) )) );
                double update = ( ( lr >= 3 ) ? (( ( (loss == 0 || loss == 2) ) ? ((step*yi)) : (( ( (yi-pr) < 0.0 ) ? ((0.0-step)) : (step) )) )) : (step) );
                if( pen == 1 ) {
                    double c = (1.0-(eta*alpha));
                    double cc = ( ( c > 0.0 ) ? (c) : (0.0) );
                    wscale = (wscale*cc)  ;
                    sqnorm = (sqnorm*(cc*cc))  ;
                    if( wscale < 1e-9 ) {
                        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                            w[ j ] = (w[j]*wscale)   ;
                        }  ;
                        wscale = 1.0  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                    ;
                } else {
                    0  ;
                }  ;
                if( !(update == 0.0) ) {
                    double acc = 0.0;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        double v = (w[j]+(x[((i*p)+j)]*(update/wscale)));
                        w[ j ] = v   ;
                        acc = (acc+(v*v))  ;
                        ;
                    }  ;
                    sqnorm = (acc*(wscale*wscale))  ;
                    ;
                } else {
                    0  ;
                }  ;
                if( (fitint == 1 && !(update == 0.0)) ) {
                    b = (b+update)  ;
                } else {
                    0  ;
                }  ;
                ;
                ;
                t = (t+1.0)  ;
            } else {
                0  ;
            }  ;
            ;
            ;
            ;
        }  ;
        epoch = (epoch+1)  ;
        double mean = (objsum/(1.0*n));
        if( mean > (best-tol) ) {
            noimp = (noimp+1)  ;
        } else {
            noimp = 0  ;
        }  ;
        if( mean < best ) {
            best = mean  ;
        } else {
            0  ;
        }  ;
        ;
        if( noimp >= niternochange ) {
            done = 1  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        w[ j ] = (w[j]*wscale)   ;
    }  ;
    out[ 0 ] = b   ;
    return epoch ;
}


SCM2CPP_FN inline double
sgd_min( double  a,  double  b )
{
    if( a < b ) {
        return a ;
    }
    else {
        return b ;
    }
}


SCM2CPP_FN inline double
min_pos( scm2cpp::cspan<double> v,  int  m )
{   double r = 1.7976931348623157e+308;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        double x = v[i];
        if( (x > 0.0 && x < r) ) {
            r = x  ;
        } else {
            0  ;
        }  ;
        ;
    }  ;
    return r ;
}


SCM2CPP_FN inline double
round_even( double  y )
{
    double r = std::floor(y);
    double d = (y-r);
    if( d > 0.5 ) {
        return (r+1.0) ;
    }
    else {
        if( d < 0.5 ) {
            return r ;
        }
        else {
            if( (2.0*std::floor((0.5*r))) == r ) {
                return r ;
            }
            else {
                return (r+1.0) ;
            }
        }
    }
}


SCM2CPP_FN inline int
cholesky_delete( scm2cpp::span<double> l,  int  go,  int  n,  int  k )
{   for( int i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        for( int j = 0 ; !(j == (i+2)) ; j = (j+1) ) {
            l[ ((i*k)+j) ] = l[(((i+1)*k)+j)]   ;
        }  ;
    }  ;
    for( int i = go ; !(i >= (n-1)) ; i = (i+1) ) {
        double a = l[((i*k)+i)];
        double b = l[((i*k)+(i+1))];
        double aa = ( ( a < 0.0 ) ? ((0.0-a)) : (a) );
        double ab = ( ( b < 0.0 ) ? ((0.0-b)) : (b) );
        double roe = ( ( aa > ab ) ? (a) : (b) );
        double scale = (aa+ab);
        double r = ( ( scale == 0.0 ) ? (0.0) : ((( ( roe < 0.0 ) ? (-1.0) : (1.0) )*(scale*sqrt((((a/scale)*(a/scale))+((b/scale)*(b/scale))))))) );
        double c = ( ( scale == 0.0 ) ? (1.0) : ((a/r)) );
        double s = ( ( scale == 0.0 ) ? (0.0) : ((b/r)) );
        double cc = ( ( r < 0.0 ) ? ((0.0-c)) : (c) );
        double ss = ( ( r < 0.0 ) ? ((0.0-s)) : (s) );
        l[ ((i*k)+i) ] = ( ( r < 0.0 ) ? ((0.0-r)) : (r) )   ;
        l[ ((i*k)+(i+1)) ] = 0.0   ;
        for( int t = (i+1) ; !(t >= n) ; t = (t+1) ) {
            double x = l[((t*k)+i)];
            double y = l[((t*k)+(i+1))];
            l[ ((t*k)+i) ] = ((cc*x)+(ss*y))   ;
            l[ ((t*k)+(i+1)) ] = ((cc*y)-(ss*x))   ;
            ;
        }  ;
        ;
        ;
        ;
        ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
swap_rc( scm2cpp::span<double> g,  int  a,  int  b,  int  p )
{   for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double rv = g[((a*p)+j)];
        g[ ((a*p)+j) ] = g[((b*p)+j)]   ;
        g[ ((b*p)+j) ] = rv   ;
        ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        double cv = g[((j*p)+a)];
        g[ ((j*p)+a) ] = g[((j*p)+b)]   ;
        g[ ((j*p)+b) ] = cv   ;
        ;
    }  ;
    return 0 ;
}


inline int
lars( scm2cpp::span<double> g,  scm2cpp::cspan<double> cov,  scm2cpp::span<double> coef,  scm2cpp::span<double> path,  scm2cpp::span<double> alphas,  int  rec,  double  nsamples,  double  alphamin,  int  method,  int  maxiter,  double  eps,  int  p )
{   std::vector<double> g0((p*p),0.0);
    std::vector<double> cov0(p,0.0);
    std::vector<double> cbuf(p,0.0);
    std::vector<int> index(p,0);
    std::vector<int> active(p,0);
    std::vector<double> sign(p,0.0);
    int kmax = ( ( maxiter < p ) ? (maxiter) : (p) );
    std::vector<double> prev(p,0.0);
    std::vector<double> dir(p,0.0);
    std::vector<double> ls(p,0.0);
    std::vector<double> zz(p,0.0);
    std::vector<double> ratio(p,0.0);
    std::vector<int> idx(p,0);
    std::vector<int> dropv(p,0);
    int cs = 0;
    int na = 0;
    int niter = 0;
    int drop = 0;
    int done = 0;
    double alpha = 0.0;
    double prevalpha = 0.0;
    double tiny32 = 1.1754943508222875e-38;
    double eqtol = 1.1920928955078125e-7;
    std::vector<double> l((kmax*kmax),0.0);
    for( int t = 0 ; !(t == (p*p)) ; t = (t+1) ) {
        g0[ t ] = g[t]   ;
    }  ;
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        cov0[ j ] = cov[j]   ;
        cbuf[ j ] = cov[j]   ;
        index[ j ] = j   ;
        coef[ j ] = 0.0   ;
        if( rec == 1 ) {
            path[ j ] = 0.0   ;
        } else {
            0  ;
        }  ;
    }  ;
    for(  ; !(done == 1) ;  ) {
        int clen = (p-cs);
        int cidx = 0;
        double cval = 0.0;
        double cabs = 0.0;
        for( int t = 0 ; !(t == clen) ; t = (t+1) ) {
            double v = cbuf[(cs+t)];
            double av = ( ( v < 0.0 ) ? ((0.0-v)) : (v) );
            if( av > cabs ) {
                cabs = av  ;
                cidx = t  ;
                cval = v  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        alpha = (cabs/(1.0*nsamples))  ;
        if( rec == 1 ) {
            alphas[ niter ] = alpha   ;
        } else {
            0  ;
        }  ;
        if( alpha <= (alphamin+eqtol) ) {
            if( ( ( (alpha-alphamin) < 0.0 ) ? ((alphamin-alpha)) : ((alpha-alphamin)) ) > eqtol ) {
                if( niter > 0 ) {
                    double ss = ((prevalpha-alphamin)/(prevalpha-alpha));
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        coef[ j ] = (prev[j]+(ss*(coef[j]-prev[j])))   ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
                alpha = alphamin  ;
                if( rec == 1 ) {
                    alphas[ niter ] = alphamin   ;
                    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                        path[ ((niter*p)+j) ] = coef[j]   ;
                    }  ;
                } else {
                    0  ;
                }  ;
            } else {
                0  ;
            }  ;
            done = 1  ;
        } else {
            if( (niter >= maxiter || na >= p) ) {
                done = 1  ;
            } else {
                int degenerate = 0;
                if( drop == 0 ) {
                    int m = na;
                    int nn = (cidx+na);
                    sign[ na ] = ( ( cval > 0.0 ) ? (1.0) : (( ( cval < 0.0 ) ? (-1.0) : (0.0) )) )   ;
                    double tc = cbuf[(cs+cidx)];
                    cbuf[ (cs+cidx) ] = cbuf[cs]   ;
                    cbuf[ cs ] = tc   ;
                    ;
                    int ti = index[nn];
                    index[ nn ] = index[m]   ;
                    index[ m ] = ti   ;
                    ;
                    cs = (cs+1)  ;
                    swap_rc(g,m,nn,p)  ;
                    double c = g[((na*p)+na)];
                    double v = 0.0;
                    for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                        double t = g[((na*p)+i)];
                        for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                            t = (t-(l[((i*kmax)+s)]*l[((na*kmax)+s)]))  ;
                        }  ;
                        double li = (t/l[((i*kmax)+i)]);
                        l[ ((na*kmax)+i) ] = li   ;
                        v = (v+(li*li))  ;
                        ;
                        ;
                    }  ;
                    double dd = sqrt(( ( (c-v) < 0.0 ) ? ((v-c)) : ((c-v)) ));
                    double dg = ( ( dd > (1.0*eps) ) ? (dd) : ((1.0*eps)) );
                    l[ ((na*kmax)+na) ] = dg   ;
                    if( dg < 1e-7 ) {
                        cs = (cs-1)  ;
                        cbuf[ cs ] = 0.0   ;
                        double tc = cbuf[(cs+cidx)];
                        cbuf[ (cs+cidx) ] = cbuf[cs]   ;
                        cbuf[ cs ] = tc   ;
                        ;
                        degenerate = 1  ;
                    } else {
                        active[ na ] = index[na]   ;
                        na = (na+1)  ;
                    }  ;
                    ;
                    ;
                    ;
                    ;
                } else {
                    false  ;
                }  ;
                if( degenerate == 0 ) {
                    if( (method == 1 && niter > 0 && prevalpha < alpha) ) {
                        done = 1  ;
                    } else {
                        double aa = 0.0;
                        int clen2 = (p-cs);
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            double t = sign[i];
                            for( int s = 0 ; !(s == i) ; s = (s+1) ) {
                                t = (t-(l[((i*kmax)+s)]*zz[s]))  ;
                            }  ;
                            zz[ i ] = (t/l[((i*kmax)+i)])   ;
                            ;
                        }  ;
                        for( int ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                            int i = ((na-1)-ii);
                            double t = zz[i];
                            for( int s = (i+1) ; !(s >= na) ; s = (s+1) ) {
                                t = (t-(l[((s*kmax)+i)]*ls[s]))  ;
                            }  ;
                            ls[ i ] = (t/l[((i*kmax)+i)])   ;
                            ;
                            ;
                        }  ;
                        if( (na == 1 && ls[0] == 0.0) ) {
                            ls[ 0 ] = 1.0   ;
                            aa = 1.0  ;
                        } else {
                            double sm = 0.0;
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                sm = (sm+(ls[i]*sign[i]))  ;
                            }  ;
                            aa = (1.0/sqrt(sm))  ;
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                ls[ i ] = (aa*ls[i])   ;
                            }  ;
                            ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            double acc = 0.0;
                            for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                                acc = (acc+(g[((i*p)+(na+t))]*ls[i]))  ;
                            }  ;
                            dir[ t ] = (round_even(double((acc*1e+15)))/1e+15)   ;
                            ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            ratio[ t ] = ((cabs-cbuf[(cs+t)])/((aa-dir[t])+tiny32))   ;
                        }  ;
                        double gfirst = min_pos(ratio,clen2);
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            ratio[ t ] = ((cabs+cbuf[(cs+t)])/((aa+dir[t])+tiny32))   ;
                        }  ;
                        double gsecond = min_pos(ratio,clen2);
                        double gam = ( ( ( ( gfirst < gsecond ) ? (gfirst) : (gsecond) ) < (cabs/aa) ) ? (( ( gfirst < gsecond ) ? (gfirst) : (gsecond) )) : ((cabs/aa)) );
                        int nidx = 0;
                        drop = 0  ;
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            zz[ i ] = ((0.0-coef[active[i]])/(ls[i]+tiny32))   ;
                        }  ;
                        double zpos = min_pos(zz,na);
                        if( zpos < gam ) {
                            for( int ii = 0 ; !(ii == na) ; ii = (ii+1) ) {
                                int i = ((na-1)-ii);
                                if( zz[i] == zpos ) {
                                    idx[ nidx ] = i   ;
                                    nidx = (nidx+1)  ;
                                } else {
                                    0  ;
                                }  ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int i = idx[r];
                                sign[ i ] = (0.0-sign[i])   ;
                                ;
                            }  ;
                            if( method == 1 ) {
                                gam = zpos  ;
                            } else {
                                0  ;
                            }  ;
                            drop = 1  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        niter = (niter+1)  ;
                        prevalpha = alpha  ;
                        for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                            prev[ j ] = coef[j]   ;
                            coef[ j ] = 0.0   ;
                        }  ;
                        for( int i = 0 ; !(i == na) ; i = (i+1) ) {
                            int a = active[i];
                            coef[ a ] = (prev[a]+(gam*ls[i]))   ;
                            ;
                        }  ;
                        if( rec == 1 ) {
                            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                                path[ ((niter*p)+j) ] = coef[j]   ;
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        for( int t = 0 ; !(t == clen2) ; t = (t+1) ) {
                            cbuf[ (cs+t) ] = (cbuf[(cs+t)]-(gam*dir[t]))   ;
                        }  ;
                        if( (drop == 1 && method == 1) ) {
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                cholesky_delete(l,idx[r],na,kmax)  ;
                            }  ;
                            na = (na-1)  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                int dropped = active[ii];
                                for( int i = ii ; !(i >= na) ; i = (i+1) ) {
                                    active[ i ] = active[(i+1)]   ;
                                }  ;
                                dropv[ r ] = dropped   ;
                                ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                for( int i = ii ; !(i >= na) ; i = (i+1) ) {
                                    int ti = index[i];
                                    index[ i ] = index[(i+1)]   ;
                                    index[ (i+1) ] = ti   ;
                                    ;
                                    swap_rc(g,i,int((i+1)),p)  ;
                                }  ;
                                ;
                            }  ;
                            for( int rr = 0 ; !(rr == nidx) ; rr = (rr+1) ) {
                                int r = ((nidx-1)-rr);
                                int d = dropv[r];
                                double t = cov0[d];
                                for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                                    t = (t-(g0[((d*p)+j)]*coef[j]))  ;
                                }  ;
                                cs = (cs-1)  ;
                                cbuf[ cs ] = t   ;
                                ;
                                ;
                                ;
                            }  ;
                            for( int r = 0 ; !(r == nidx) ; r = (r+1) ) {
                                int ii = idx[r];
                                for( int i = ii ; !(i >= (p-1)) ; i = (i+1) ) {
                                    sign[ i ] = sign[(i+1)]   ;
                                }  ;
                                sign[ (p-1) ] = 0.0   ;
                                ;
                            }  ;
                        } else {
                            0  ;
                        }  ;
                        ;
                        ;
                        ;
                        ;
                    }  ;
                } else {
                    0  ;
                }  ;
                ;
            }  ;
        }  ;
        ;
    }  ;
    ;
    return niter ;
}


inline int
svm_l1( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  double  cost,  double  tol,  int  maxiter,  int  seed,  int  n,  int  p )
{   std::vector<int> index(p,0);
    std::vector<double> b(n,1.0);
    std::vector<double> xjsq(p,0.0);
    int rng = seed;
    int npos = 0;
    int iter = 0;
    int active = p;
    double gmaxold = 1e+300;
    double ginit = -1.0;
    int done = 0;
    for( int i = 0 ; !(i == n) ; i = (i+1) ) {
        if( y[i] > 0.0 ) {
            npos = (npos+1)  ;
        } else {
            0  ;
        }  ;
    }  ;

    struct let24389 {
        let24389() {}
        int operator()( int  mn  )
        {
            if( mn < 1 ) {
                return 1 ;
            }
            else {
                return mn ;
            }
        }
    }  ;
    double eps = ((tol*double(let24389()(( ( npos < (n-npos) ) ? (npos) : ((n-npos)) ))))/double(n));
    for( int j = 0 ; !(j == p) ; j = (j+1) ) {
        w[ j ] = 0.0   ;
        index[ j ] = j   ;
        double acc = 0.0;
        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
            double val = (x[((j*n)+i)]*y[i]);
            acc = (acc+(cost*(val*val)))  ;
            ;
        }  ;
        xjsq[ j ] = acc   ;
        ;
    }  ;
    for(  ; !((done == 1 || iter >= maxiter)) ;  ) {
        double gmaxnew = 0.0;
        double gnorm1new = 0.0;
        int s = 0;
        for( int j = 0 ; !(j == active) ; j = (j+1) ) {
            rng = ((16807*(rng % 127773))-(2836*(rng / 127773)))  ;
            if( rng < 0 ) {
                rng = (rng+2147483647)  ;
            } else {
                0  ;
            }  ;
            int k = (j+(rng % (active-j)));
            int tmp = index[k];
            index[ k ] = index[j]   ;
            index[ j ] = tmp   ;
            ;
            ;
        }  ;
        for(  ; !(s >= active) ;  ) {
            int j = index[s];
            double gl = 0.0;
            double h = 0.0;
            int shrunk = 0;
            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                if( b[i] > 0.0 ) {
                    double val = (x[((j*n)+i)]*y[i]);
                    double tmp = (cost*val);
                    gl = (gl-(tmp*b[i]))  ;
                    h = (h+(tmp*val))  ;
                    ;
                    ;
                } else {
                    0  ;
                }  ;
            }  ;
            gl = (2.0*gl)  ;
            h = (2.0*h)  ;
            if( h < 1e-12 ) {
                h = 1e-12  ;
            } else {
                0  ;
            }  ;
            double wj = w[j];
            double gp = (gl+1.0);
            double gn = (gl-1.0);
            double viol = 0.0;
            if( wj == 0.0 ) {
                if( gp < 0.0 ) {
                    viol = (0.0-gp)  ;
                } else {
                    if( gn > 0.0 ) {
                        viol = gn  ;
                    } else {
                        if( (gp > (gmaxold/double(n)) && gn < (0.0-(gmaxold/double(n)))) ) {
                            active = (active-1)  ;
                            int tmp2 = index[s];
                            index[ s ] = index[active]   ;
                            index[ active ] = tmp2   ;
                            ;
                            shrunk = 1  ;
                        } else {
                            0  ;
                        }  ;
                    }  ;
                }  ;
            } else {
                viol = ( ( wj > 0.0 ) ? (svm_l1_abs(gp)) : (svm_l1_abs(gn)) )  ;
            }  ;
            if( shrunk == 0 ) {
                if( viol > gmaxnew ) {
                    gmaxnew = viol  ;
                } else {
                    0  ;
                }  ;
                gnorm1new = (gnorm1new+viol)  ;
                double d = ( ( gp < (h*wj) ) ? (((0.0-gp)/h)) : (( ( gn > (h*wj) ) ? (((0.0-gn)/h)) : ((0.0-wj)) )) );
                if( svm_l1_abs(d) >= 1e-12 ) {
                    double delta = ((svm_l1_abs(double((wj+d)))-svm_l1_abs(wj))+(gl*d));
                    double dold = 0.0;
                    int nls = 0;
                    int fin = 0;
                    double lossold = 0.0;
                    for(  ; !((fin == 1 || nls >= 20)) ;  ) {
                        double ddiff = (dold-d);
                        double cnd = ((svm_l1_abs(double((wj+d)))-svm_l1_abs(wj))-(0.01*delta));
                        if( (((xjsq[j]*(d*d))+(gl*d))+cnd) <= 0.0 ) {
                            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                                b[ i ] = (b[i]+(ddiff*(x[((j*n)+i)]*y[i])))   ;
                            }  ;
                            fin = 1  ;
                        } else {
                            double lossnew = 0.0;
                            if( nls == 0 ) {
                                lossold = 0.0  ;
                            } else {
                                0  ;
                            }  ;
                            for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                                double bi = b[i];
                                if( (nls == 0 && bi > 0.0) ) {
                                    lossold = (lossold+(cost*(bi*bi)))  ;
                                } else {
                                    0  ;
                                }  ;
                                double bnew = (bi+(ddiff*(x[((j*n)+i)]*y[i])));
                                b[ i ] = bnew   ;
                                if( bnew > 0.0 ) {
                                    lossnew = (lossnew+(cost*(bnew*bnew)))  ;
                                } else {
                                    0  ;
                                }  ;
                                ;
                                ;
                            }  ;
                            if( (cnd+(lossnew-lossold)) <= 0.0 ) {
                                fin = 1  ;
                            } else {
                                dold = d  ;
                                d = (0.5*d)  ;
                                delta = (0.5*delta)  ;
                                nls = (nls+1)  ;
                            }  ;
                            ;
                        }  ;
                        ;
                    }  ;
                    w[ j ] = (wj+d)   ;
                    if( nls >= 20 ) {
                        for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                            b[ i ] = 1.0   ;
                        }  ;
                        for( int jj = 0 ; !(jj == p) ; jj = (jj+1) ) {
                            if( !(w[jj] == 0.0) ) {
                                for( int i = 0 ; !(i == n) ; i = (i+1) ) {
                                    b[ i ] = (b[i]-(w[jj]*(x[((jj*n)+i)]*y[i])))   ;
                                }  ;
                            } else {
                                0  ;
                            }  ;
                        }  ;
                    } else {
                        0  ;
                    }  ;
                    ;
                } else {
                    0  ;
                }  ;
                ;
                s = (s+1)  ;
            } else {
                0  ;
            }  ;
            ;
            ;
        }  ;
        if( iter == 0 ) {
            ginit = gnorm1new  ;
        } else {
            0  ;
        }  ;
        iter = (iter+1)  ;
        if( gnorm1new <= (eps*ginit) ) {
            if( active == p ) {
                done = 1  ;
            } else {
                active = p  ;
                gmaxold = 1e+300  ;
            }  ;
        } else {
            gmaxold = gmaxnew  ;
        }  ;
        ;
    }  ;
    ;
    return iter ;
}


SCM2CPP_FN inline double
svm_l1_abs( double  a )
{
    if( a < 0.0 ) {
        return (0.0-a) ;
    }
    else {
        return a ;
    }
}


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


SCM2CPP_FN inline int
sym_eigen( scm2cpp::span<double> a,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  int  m )
{   for( int ii = 0 ; !(ii == (m-1)) ; ii = (ii+1) ) {
        int i = ((m-1)-ii);
        int l = (i-1);
        double h = 0.0;
        double scale = 0.0;
        if( l > 0 ) {
            for( int k = 0 ; !(k > l) ; k = (k+1) ) {
                double ak = a[((i*m)+k)];
                scale = (scale+( ( ak < 0.0 ) ? ((0.0-ak)) : (ak) ))  ;
                ;
            }  ;
            if( scale == 0.0 ) {
                e[ i ] = a[((i*m)+l)]   ;
            } else {
                for( int k = 0 ; !(k > l) ; k = (k+1) ) {
                    a[ ((i*m)+k) ] = (a[((i*m)+k)]/scale)   ;
                    h = (h+(a[((i*m)+k)]*a[((i*m)+k)]))  ;
                }  ;
                double f = a[((i*m)+l)];
                double g = ( ( f >= 0.0 ) ? ((0.0-sqrt(h))) : (sqrt(h)) );
                e[ i ] = (scale*g)   ;
                h = (h-(f*g))  ;
                a[ ((i*m)+l) ] = (f-g)   ;
                double ff = 0.0;
                for( int j = 0 ; !(j > l) ; j = (j+1) ) {
                    a[ ((j*m)+i) ] = (a[((i*m)+j)]/h)   ;
                    double gg = 0.0;
                    for( int k = 0 ; !(k > j) ; k = (k+1) ) {
                        gg = (gg+(a[((j*m)+k)]*a[((i*m)+k)]))  ;
                    }  ;
                    for( int k = (j+1) ; !(k > l) ; k = (k+1) ) {
                        gg = (gg+(a[((k*m)+j)]*a[((i*m)+k)]))  ;
                    }  ;
                    e[ j ] = (gg/h)   ;
                    ff = (ff+(e[j]*a[((i*m)+j)]))  ;
                    ;
                }  ;
                double hh = (ff/(h+h));
                for( int j = 0 ; !(j > l) ; j = (j+1) ) {
                    double f2 = a[((i*m)+j)];
                    double g2 = (e[j]-(hh*f2));
                    e[ j ] = g2   ;
                    for( int k = 0 ; !(k > j) ; k = (k+1) ) {
                        a[ ((j*m)+k) ] = (a[((j*m)+k)]-((f2*e[k])+(g2*a[((i*m)+k)])))   ;
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
            e[ i ] = a[((i*m)+l)]   ;
        }  ;
        ev[ i ] = h   ;
        ;
        ;
    }  ;
    ev[ 0 ] = 0.0   ;
    e[ 0 ] = 0.0   ;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        if( !(ev[i] == 0.0) ) {
            for( int j = 0 ; !(j == i) ; j = (j+1) ) {
                double g3 = 0.0;
                for( int k = 0 ; !(k == i) ; k = (k+1) ) {
                    g3 = (g3+(a[((i*m)+k)]*a[((k*m)+j)]))  ;
                }  ;
                for( int k = 0 ; !(k == i) ; k = (k+1) ) {
                    a[ ((k*m)+j) ] = (a[((k*m)+j)]-(g3*a[((k*m)+i)]))   ;
                }  ;
                ;
            }  ;
        } else {
            0  ;
        }  ;
        ev[ i ] = a[((i*m)+i)]   ;
        a[ ((i*m)+i) ] = 1.0   ;
        for( int j = 0 ; !(j == i) ; j = (j+1) ) {
            a[ ((j*m)+i) ] = 0.0   ;
            a[ ((i*m)+j) ] = 0.0   ;
        }  ;
    }  ;
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        for( int j = 0 ; !(j == m) ; j = (j+1) ) {
            v[ ((j*m)+i) ] = a[((i*m)+j)]   ;
        }  ;
    }  ;
    for( int i = 1 ; !(i == m) ; i = (i+1) ) {
        e[ (i-1) ] = e[i]   ;
    }  ;
    e[ (m-1) ] = 0.0   ;
    for( int l = 0 ; !(l == m) ; l = (l+1) ) {
        int fin = 0;
        int iter = 0;
        for(  ; !((fin == 1 || iter > 60)) ;  ) {
            int mm = l;
            int found = 0;
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
                int under = 0;
                int i = (mm-1);
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
                        for( int k = 0 ; !(k == m) ; k = (k+1) ) {
                            double zf = v[(((i+1)*m)+k)];
                            double zi = v[((i*m)+k)];
                            v[ (((i+1)*m)+k) ] = ((s*zi)+(c*zf))   ;
                            v[ ((i*m)+k) ] = ((c*zi)-(s*zf))   ;
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
    for( int i = 0 ; !(i == m) ; i = (i+1) ) {
        for( int j = (i+1) ; !(j >= m) ; j = (j+1) ) {
            double tmp = v[((i*m)+j)];
            v[ ((i*m)+j) ] = v[((j*m)+i)]   ;
            v[ ((j*m)+i) ] = tmp   ;
            ;
        }  ;
    }  ;
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


SCM2CPP_FN inline int
eig_order( scm2cpp::cspan<double> ev,  scm2cpp::span<int> ord,  int  m )
{   for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        ord[ j ] = j   ;
    }  ;
    for( int j = 0 ; !(j == m) ; j = (j+1) ) {
        int best = j;
        for( int r = (j+1) ; !(r >= m) ; r = (r+1) ) {
            if( ev[ord[r]] > ev[ord[best]] ) {
                best = r  ;
            } else {
                0  ;
            }  ;
        }  ;
        int tmp = ord[j];
        ord[ j ] = ord[best]   ;
        ord[ best ] = tmp   ;
        ;
        ;
    }  ;
    return 0 ;
}


SCM2CPP_FN inline int
ts_minnorm( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> aa,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> ab,  int  s,  int  ns,  int  fitint,  int  p,  int  d )
{   for( int t = 0 ; !(t == (d*d)) ; t = (t+1) ) {
        aa[ t ] = 0.0   ;
    }  ;
    for( int t = 0 ; !(t == d) ; t = (t+1) ) {
        ab[ t ] = 0.0   ;
    }  ;
    for( int r = 0 ; !(r == ns) ; r = (r+1) ) {
        int i = idx[((s*ns)+r)];
        for( int u = 0 ; !(u == d) ; u = (u+1) ) {
            double xu = ( ( u < fitint ) ? (1.0) : (x[((i*p)+(u-fitint))]) );
            ab[ u ] = (ab[u]+(xu*y[i]))   ;
            for( int q = 0 ; !(q == d) ; q = (q+1) ) {
                double xq = ( ( q < fitint ) ? (1.0) : (x[((i*p)+(q-fitint))]) );
                aa[ ((u*d)+q) ] = (aa[((u*d)+q)]+(xu*xq))   ;
                ;
            }  ;
            ;
        }  ;
        ;
    }  ;
    sym_eigen(aa,v,ev,e,d)  ;
    double mx = 0.0;
    for( int r = 0 ; !(r == d) ; r = (r+1) ) {
        if( ts_abs(ev[r]) > mx ) {
            mx = ts_abs(ev[r])  ;
        } else {
            0  ;
        }  ;
    }  ;
    double cut = (mx*(double(d)*2.220446049250313e-16));
    for( int u = 0 ; !(u == d) ; u = (u+1) ) {
        double acc = 0.0;
        for( int r = 0 ; !(r == d) ; r = (r+1) ) {
            if( ts_abs(ev[r]) > cut ) {
                double vab = 0.0;
                for( int q = 0 ; !(q == d) ; q = (q+1) ) {
                    vab = (vab+(v[((q*d)+r)]*ab[q]))  ;
                }  ;
                acc = (acc+((v[((u*d)+r)]*vab)/ev[r]))  ;
                ;
            } else {
                0  ;
            }  ;
        }  ;
        w[ ((s*d)+u) ] = acc   ;
        ;
    }  ;
    ;
    ;
    return 0 ;
}


SCM2CPP_FN inline int
ts_fit( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> a,  scm2cpp::span<double> b,  scm2cpp::span<double> aa,  scm2cpp::span<double> v,  scm2cpp::span<double> ev,  scm2cpp::span<double> e,  scm2cpp::span<double> ab,  int  s,  int  ns,  int  fitint,  int  p,  int  d )
{   int singular = 0;
    double scale = 0.0;
    if( ns == d ) {
        for( int r = 0 ; !(r == d) ; r = (r+1) ) {
            int i = idx[((s*ns)+r)];
            if( fitint == 1 ) {
                a[ (r*d) ] = 1.0   ;
            } else {
                0  ;
            }  ;
            for( int j = 0 ; !(j == p) ; j = (j+1) ) {
                a[ ((r*d)+(j+fitint)) ] = x[((i*p)+j)]   ;
            }  ;
            b[ r ] = y[i]   ;
            ;
        }  ;
        for( int t = 0 ; !(t == (d*d)) ; t = (t+1) ) {
            if( ts_abs(a[t]) > scale ) {
                scale = ts_abs(a[t])  ;
            } else {
                0  ;
            }  ;
        }  ;
        for( int c = 0 ; !(c == d) ; c = (c+1) ) {
            int piv = c;
            double big = ts_abs(a[((c*d)+c)]);
            for( int r = (c+1) ; !(r >= d) ; r = (r+1) ) {
                if( ts_abs(a[((r*d)+c)]) > big ) {
                    big = ts_abs(a[((r*d)+c)])  ;
                    piv = r  ;
                } else {
                    0  ;
                }  ;
            }  ;
            if( big <= (scale*(double(d)*2.220446049250313e-16)) ) {
                singular = 1  ;
            } else {
                if( !(piv == c) ) {
                    for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                        double tmp = a[((c*d)+j)];
                        a[ ((c*d)+j) ] = a[((piv*d)+j)]   ;
                        a[ ((piv*d)+j) ] = tmp   ;
                        ;
                    }  ;
                    double tb = b[c];
                    b[ c ] = b[piv]   ;
                    b[ piv ] = tb   ;
                    ;
                } else {
                    0  ;
                }  ;
                for( int r = (c+1) ; !(r >= d) ; r = (r+1) ) {
                    double fct = (a[((r*d)+c)]/a[((c*d)+c)]);
                    for( int j = c ; !(j == d) ; j = (j+1) ) {
                        a[ ((r*d)+j) ] = (a[((r*d)+j)]-(fct*a[((c*d)+j)]))   ;
                    }  ;
                    b[ r ] = (b[r]-(fct*b[c]))   ;
                    ;
                }  ;
            }  ;
            ;
        }  ;
        if( singular == 0 ) {
            for( int cc = 0 ; !(cc == d) ; cc = (cc+1) ) {
                int c = ((d-1)-cc);
                double t = b[c];
                for( int j = (c+1) ; !(j >= d) ; j = (j+1) ) {
                    t = (t-(a[((c*d)+j)]*w[((s*d)+j)]))  ;
                }  ;
                w[ ((s*d)+c) ] = (t/a[((c*d)+c)])   ;
                ;
                ;
            }  ;
        } else {
            0  ;
        }  ;
    } else {
        singular = 1  ;
    }  ;
    if( singular == 1 ) {
        ts_minnorm(x,y,idx,w,aa,v,ev,e,ab,s,ns,fitint,p,d)  ;
    } else {
        0  ;
    }  ;
    ;
    return 0 ;
}


SCM2CPP_FN inline double
ts_abs( double  v )
{
    if( v < 0.0 ) {
        return (0.0-v) ;
    }
    else {
        return v ;
    }
}


inline int
theilsen( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::cspan<int> idx,  scm2cpp::span<double> w,  scm2cpp::span<double> coef,  int  nsub,  int  ns,  int  fitint,  int  maxiter,  double  tol,  int  p )
{   int d = (p+fitint);
    int it = 0;
    std::vector<double> a((d*d),0.0);
    std::vector<double> b(d,0.0);
    std::vector<double> aa((d*d),0.0);
    std::vector<double> v((d*d),0.0);
    std::vector<double> ev(d,0.0);
    std::vector<double> e(d,0.0);
    std::vector<double> ab(d,0.0);
    std::vector<double> old(d,0.0);
    std::vector<double> num(d,0.0);
    std::vector<double> qv(d,0.0);
    double eps = 2.220446049250313e-16;
    for( int s = 0 ; !(s == nsub) ; s = (s+1) ) {
        ts_fit(x,y,idx,w,a,b,aa,v,ev,e,ab,s,ns,fitint,p,d)  ;
    }  ;
    if( d == 1 ) {
        std::vector<double> v(nsub,0.0);
        for( int s = 0 ; !(s == nsub) ; s = (s+1) ) {
            v[ s ] = w[s]   ;
        }  ;
        for( int s = 1 ; !(s == nsub) ; s = (s+1) ) {
            double key = v[s];
            int j = (s-1);
            for(  ; !((j < 0 || v[j] <= key)) ;  ) {
                v[ (j+1) ] = v[j]   ;
                j = (j-1)  ;
            }  ;
            v[ (j+1) ] = key   ;
            ;
        }  ;
        coef[ 0 ] = ( ( (nsub % 2) == 1 ) ? (v[(nsub / 2)]) : ((0.5*(v[((nsub / 2)-1)]+v[(nsub / 2)]))) )   ;
        it = 1  ;
        ;
    } else {
        double tol2 = (tol*tol);
        int done = 0;
        for( int j = 0 ; !(j == d) ; j = (j+1) ) {
            double acc = 0.0;
            for( int s = 0 ; !(s == nsub) ; s = (s+1) ) {
                acc = (acc+w[((s*d)+j)])  ;
            }  ;
            old[ j ] = (acc/double(nsub))   ;
            ;
        }  ;
        for(  ; !((done == 1 || it >= maxiter)) ;  ) {
            int inx = 0;
            double sinv = 0.0;
            for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                num[ j ] = 0.0   ;
                qv[ j ] = 0.0   ;
            }  ;
            for( int s = 0 ; !(s == nsub) ; s = (s+1) ) {
                double dn = 0.0;
                for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                    double df = (w[((s*d)+j)]-old[j]);
                    dn = (dn+(df*df))  ;
                    ;
                }  ;
                dn = sqrt(dn)  ;
                if( dn >= eps ) {
                    sinv = (sinv+(1.0/dn))  ;
                    for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                        qv[ j ] = (qv[j]+((w[((s*d)+j)]-old[j])/dn))   ;
                        num[ j ] = (num[j]+(w[((s*d)+j)]/dn))   ;
                    }  ;
                } else {
                    inx = 1  ;
                }  ;
                ;
            }  ;
            double qn = 0.0;
            for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                qn = (qn+(qv[j]*qv[j]))  ;
            }  ;
            qn = sqrt(qn)  ;
            int usedir = ( ( qn > eps ) ? (1) : (0) );
            double qn2 = ( ( usedir == 1 ) ? (qn) : (1.0) );
            double moved = 0.0;
            struct let24455 {
                let24455() {}
                double operator()( double  t5  )
                {
                    if( t5 > 0.0 ) {
                        return t5 ;
                    }
                    else {
                        return 0.0 ;
                    }
                }
            }  ;

            struct let24477 {
                let24477() {}
                double operator()( double  t6  )
                {
                    if( t6 < 1.0 ) {
                        return t6 ;
                    }
                    else {
                        return 1.0 ;
                    }
                }
            }  ;
            double wa = let24455()((1.0-(double(inx)/qn2)));
            double wb = let24477()((double(inx)/qn2));
            for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                double nd = ( ( usedir == 1 ) ? ((num[j]/sinv)) : (1.0) );
                double nw = ((wa*nd)+(wb*old[j]));
                moved = (moved+((old[j]-nw)*(old[j]-nw)))  ;
                coef[ j ] = nw   ;
                ;
                ;
            }  ;
            ;
            if( moved < tol2 ) {
                done = 1  ;
            } else {
                for( int j = 0 ; !(j == d) ; j = (j+1) ) {
                    old[ j ] = coef[j]   ;
                }  ;
                it = (it+1)  ;
            }  ;
            ;
            ;
            ;
            ;
        }  ;
        ;
    }  ;
    ;
    return it ;
}
#endif // CLASSIFIERS_HPP
