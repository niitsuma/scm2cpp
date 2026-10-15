
#ifndef CLASSIFIERS_HPP
#define CLASSIFIERS_HPP
#define SCM2CPP_MINIMAL
#include	<math.h>
#include	<array>
#include	<vector>
#include	"scm2cpp.hpp"

int
svm_liblinear( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  scm2cpp::span<double> alpha,  scm2cpp::span<double> xnorm,  double  cost,  int  iters,  double  tol,  int  seed,  int  n,  int  p );
int
svm_smo( scm2cpp::cspan<double> k,  scm2cpp::cspan<double> y,  scm2cpp::span<double> alpha,  scm2cpp::span<double> rho,  double  cost,  int  iters,  double  eps,  int  n );
SCM2CPP_FN int
shrinkable_P( scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  double  cost,  double  gmax1,  double  gmax2,  int  t );
SCM2CPP_FN int
swap_position( scm2cpp::span<int> index,  scm2cpp::span<double> yy,  scm2cpp::span<double> a,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t );
SCM2CPP_FN int
reconstruct_gradient( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> index,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::span<double> g,  scm2cpp::cspan<double> gbar,  double  cost,  int  active,  int  n );
SCM2CPP_FN int
select_working_set( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> index,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  scm2cpp::cspan<double> qd,  double  cost,  double  eps,  int  active,  int  n,  std::array<int,2> & wi );
int
logistic_l1( scm2cpp::cspan<double> x,  scm2cpp::cspan<double> y,  scm2cpp::span<double> w,  double  cost,  double  tol,  int  maxnewton,  int  seed,  int  n,  int  p );



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
{   std::vector<int> index(n,0);
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
        yy[ t ] = y[t]   ;
        g[ t ] = -1.0   ;
        qd[ t ] = k[((t*n)+t)]   ;
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
                reconstruct_gradient(k,index,yy,a,g,gbar,cost,active,n)  ;
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
                            swap_position(index,yy,a,g,gbar,qd,t,active)  ;
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
        if( select_working_set(k,index,yy,a,g,qd,cost,eps,active,n,wi) == 1 ) {
            reconstruct_gradient(k,index,yy,a,g,gbar,cost,active,n)  ;
            active = n  ;
            if( select_working_set(k,index,yy,a,g,qd,cost,eps,active,n,wi) == 1 ) {
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
            int pi = index[i];
            int pj = index[j];
            double qij = ((yi*yj)*k[((pi*n)+pj)]);
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
                int pt = index[t];
                double yt = yy[t];
                g[ t ] = (g[t]+(yt*(((yi*di)*k[((pi*n)+pt)])+((yj*dj)*k[((pj*n)+pt)]))))   ;
                ;
            }  ;
            if( !(ui == ( ( ni >= cost ) ? (1) : (0) )) ) {
                for( int t = 0 ; !(t == n) ; t = (t+1) ) {
                    gbar[ t ] = (gbar[t]+(( ( ui == 1 ) ? ((0.0-cost)) : (cost) )*((yi*yy[t])*k[((pi*n)+index[t])])))   ;
                }  ;
            } else {
                0  ;
            }  ;
            if( !(uj == ( ( nj >= cost ) ? (1) : (0) )) ) {
                for( int t = 0 ; !(t == n) ; t = (t+1) ) {
                    gbar[ t ] = (gbar[t]+(( ( uj == 1 ) ? ((0.0-cost)) : (cost) )*((yj*yy[t])*k[((pj*n)+index[t])])))   ;
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
        reconstruct_gradient(k,index,yy,a,g,gbar,cost,active,n)  ;
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
swap_position( scm2cpp::span<int> index,  scm2cpp::span<double> yy,  scm2cpp::span<double> a,  scm2cpp::span<double> g,  scm2cpp::span<double> gbar,  scm2cpp::span<double> qd,  int  s,  int  t )
{   int i0 = index[s];
    double y0 = yy[s];
    double a0 = a[s];
    double g0 = g[s];
    double b0 = gbar[s];
    double q0 = qd[s];
    index[ s ] = index[t]   ;
    index[ t ] = i0   ;
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
reconstruct_gradient( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> index,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::span<double> g,  scm2cpp::cspan<double> gbar,  double  cost,  int  active,  int  n )
{   for( int t = active ; !(t >= n) ; t = (t+1) ) {
        g[ t ] = (gbar[t]-1.0)   ;
    }  ;
    for( int s = 0 ; !(s >= active) ; s = (s+1) ) {
        double as = a[s];
        if( (as > 0.0 && as < cost) ) {
            int ps = index[s];
            double ys = yy[s];
            for( int t = active ; !(t >= n) ; t = (t+1) ) {
                g[ t ] = (g[t]+(as*((ys*yy[t])*k[((ps*n)+index[t])])))   ;
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
select_working_set( scm2cpp::cspan<double> k,  scm2cpp::cspan<int> index,  scm2cpp::cspan<double> yy,  scm2cpp::cspan<double> a,  scm2cpp::cspan<double> g,  scm2cpp::cspan<double> qd,  double  cost,  double  eps,  int  active,  int  n,  std::array<int,2> & wi )
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
        int pi = index[gmaxi];
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
                        double quad = ((qdi+qd[t])-(2.0*(yi*(yi*(yt*k[((pi*n)+index[t])])))));
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
                        double quad = ((qdi+qd[t])+(2.0*(yi*(yi*(yt*k[((pi*n)+index[t])])))));
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

    struct let24256 {
        let24256() {}
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
    double eps = ((tol*(1.0*let24256()(( ( npos < (n-npos) ) ? (npos) : ((n-npos)) ))))/(1.0*n));
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
#endif // CLASSIFIERS_HPP
