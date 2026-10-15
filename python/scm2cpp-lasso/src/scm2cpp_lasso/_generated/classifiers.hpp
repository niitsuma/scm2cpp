
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
smo_solve( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y2,  scm2cpp::cspan<double> lin,  scm2cpp::span<double> alpha,  std::array<double,1> & rho,  double  cost,  int  iters,  double  eps,  int  n,  int  nk );
SCM2CPP_FN int
shrinkable_P( scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  double  cost,  double  gmax1,  double  gmax2,  int  t );
SCM2CPP_FN int
swap_position( scm2cpp::span<int> index,  scm2cpp::span<int> krow,  scm2cpp::span<double> pp,  scm2cpp::span<double> yy,  scm2cpp::span<double> a2,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t );
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
smo_solve( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y2,  scm2cpp::cspan<double> lin,  scm2cpp::span<double> alpha,  std::array<double,1> & rho,  double  cost,  int  iters,  double  eps,  int  n,  int  nk )
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
        yy[ t ] = y2[t]   ;
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
swap_position( scm2cpp::span<int> index,  scm2cpp::span<int> krow,  scm2cpp::span<double> pp,  scm2cpp::span<double> yy,  scm2cpp::span<double> a2,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t )
{   int i0 = index[s];
    double y0 = yy[s];
    double a0 = a2[s];
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
    a2[ s ] = a2[t]   ;
    a2[ t ] = a0   ;
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

    struct let24285 {
        let24285() {}
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
    double eps = ((tol*(1.0*let24285()(( ( npos < (n-npos) ) ? (npos) : ((n-npos)) ))))/(1.0*n));
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
                struct let24307 {
                    double & ratio;
                    int & minsamples;
                    let24307( double & ratio,  int & minsamples ):ratio(ratio),minsamples(minsamples)  {}
                    double operator()( double  acc  )
                {   for( int s = 0 ; !(s == minsamples) ; s = (s+1) ) {
                            acc = (acc*ratio)  ;
                        }  ;
                        return acc ;
                    }
                }  ;
                double pw = let24307(ratio,minsamples)(1.0);
                double denom = ( ( (1.0-pw) > eps ) ? ((1.0-pw)) : (eps) );
                struct let24335 {
                    let24335() {}
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
                double dyn = ( ( nom == 1.0 ) ? (0.0) : (( ( denom == 1.0 ) ? (1e+300) : (let24335()((log(nom)/log(denom)))) )) );
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
#endif // CLASSIFIERS_HPP
