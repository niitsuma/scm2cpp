;;;; liblinear's solver for the L1-regularized L2-loss SVM, whole:
;;;; solve_l1r_l2_svc (coordinate descent with a Newton step and a line
;;;; search, Chang, Hsieh and Lin 2008, with shrinking), the code
;;;; scikit-learn's LinearSVC(penalty="l1", dual=False) runs, written out
;;;; in the subset.
;;;;
;;;;   min_w  sum_j |w_j| + C sum_i max(0, 1 - y_i w.x_i)^2
;;;;
;;;; Each outer iteration permutes the active coordinates at random and
;;;; visits them: the loss's gradient and second derivative along w_j
;;;; over the points with b_i = 1 - y_i w.x_i > 0, the violation of the
;;;; optimality conditions (a coordinate at zero whose gradient stays
;;;; inside (-1, 1) by the last iteration's largest violation over n is
;;;; shrunk), the Newton step d of the one-variable model with the L1
;;;; term, halved until the sufficient-decrease test passes (first its
;;;; quadratic upper bound, then the exact loss, at most 20 times, b
;;;; recomputed from w if all 20 fail).  The fit ends when the summed
;;;; violation falls below EPS times its first value -- liblinear's
;;;; primal_solver_tol, TOL max(min(pos, neg), 1) / n -- over all the
;;;; coordinates, or after MAXITER outer iterations.
;;;;
;;;; X is stored by columns, as liblinear transposes it: p rows of n.
;;;; Y is +1/-1.  W gets the coefficients; returns the number of outer
;;;; iterations.  The random numbers are Park-Miller's minimal standard
;;;; by Schrage's method, seeded by SEED.
;;;;

(define (svm-l1 x y w cost tol maxiter seed n p)
  (let ((index (make-vector p 0))
        (b (make-vector n 1.0))
        (xjsq (make-vector p 0.0))
        (rng seed) (npos 0) (iter 0) (active p)
        (gmaxold 1e300) (ginit -1.0) (done 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (if (> (vector-ref y i) 0.0) (set! npos (+ npos 1)) 0))
    (let ((eps (/ (* tol (exact->inexact (let ((mn (if (< npos (- n npos)) npos (- n npos)))) (if (< mn 1) 1 mn))))
                  (exact->inexact n))))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! w j 0.0)
        (vector-set! index j j)
        (let ((acc 0.0))
          (do ((i 0 (+ i 1))) ((= i n))
            (let ((val (* (vector-ref x (+ (* j n) i)) (vector-ref y i))))
              (set! acc (+ acc (* cost (* val val))))))
          (vector-set! xjsq j acc)))
      (do () ((or (= done 1) (>= iter maxiter)))
        (let ((gmaxnew 0.0) (gnorm1new 0.0) (s 0))
          ;; the random permutation of the active part
          (do ((j 0 (+ j 1))) ((= j active))
            (set! rng (- (* 16807 (remainder rng 127773)) (* 2836 (quotient rng 127773))))
            (if (< rng 0) (set! rng (+ rng 2147483647)) 0)
            (let ((k (+ j (remainder rng (- active j)))))
              (let ((tmp (vector-ref index k)))
                (vector-set! index k (vector-ref index j))
                (vector-set! index j tmp))))
          (do () ((>= s active))
            (let ((j (vector-ref index s)) (gl 0.0) (h 0.0) (shrunk 0))
              (do ((i 0 (+ i 1))) ((= i n))
                (if (> (vector-ref b i) 0.0)
                    (let ((val (* (vector-ref x (+ (* j n) i)) (vector-ref y i))))
                      (let ((tmp (* cost val)))
                        (set! gl (- gl (* tmp (vector-ref b i))))
                        (set! h (+ h (* tmp val)))))
                    0))
              (set! gl (* 2.0 gl))
              (set! h (* 2.0 h))
              (if (< h 1e-12) (set! h 1e-12) 0)
              (let ((wj (vector-ref w j)) (gp (+ gl 1.0)) (gn (- gl 1.0)) (viol 0.0))
                (if (= wj 0.0)
                    (if (< gp 0.0)
                        (set! viol (- 0.0 gp))
                        (if (> gn 0.0)
                            (set! viol gn)
                            (if (and (> gp (/ gmaxold (exact->inexact n))) (< gn (- 0.0 (/ gmaxold (exact->inexact n)))))
                                (begin
                                  (set! active (- active 1))
                                  (let ((tmp2 (vector-ref index s)))
                                    (vector-set! index s (vector-ref index active))
                                    (vector-set! index active tmp2))
                                  (set! shrunk 1))
                                0)))
                    (set! viol (if (> wj 0.0) (svm-l1-abs gp) (svm-l1-abs gn))))
                (if (= shrunk 0)
                    (begin
                      (if (> viol gmaxnew) (set! gmaxnew viol) 0)
                      (set! gnorm1new (+ gnorm1new viol))
                      (let ((d (if (< gp (* h wj)) (/ (- 0.0 gp) h)
                                   (if (> gn (* h wj)) (/ (- 0.0 gn) h) (- 0.0 wj)))))
                        (if (>= (svm-l1-abs d) 1e-12)
                            (let ((delta (+ (- (svm-l1-abs (+ wj d)) (svm-l1-abs wj)) (* gl d)))
                                  (dold 0.0) (nls 0) (fin 0) (lossold 0.0))
                              (do () ((or (= fin 1) (>= nls 20)))
                                (let ((ddiff (- dold d))
                                      (cnd (- (- (svm-l1-abs (+ wj d)) (svm-l1-abs wj)) (* 0.01 delta))))
                                  (if (<= (+ (+ (* (vector-ref xjsq j) (* d d)) (* gl d)) cnd) 0.0)
                                      (begin
                                        (do ((i 0 (+ i 1))) ((= i n))
                                          (vector-set! b i (+ (vector-ref b i)
                                                              (* ddiff (* (vector-ref x (+ (* j n) i)) (vector-ref y i))))))
                                        (set! fin 1))
                                      (let ((lossnew 0.0))
                                        (if (= nls 0) (set! lossold 0.0) 0)
                                        (do ((i 0 (+ i 1))) ((= i n))
                                          (let ((bi (vector-ref b i)))
                                            (if (and (= nls 0) (> bi 0.0)) (set! lossold (+ lossold (* cost (* bi bi)))) 0)
                                            (let ((bnew (+ bi (* ddiff (* (vector-ref x (+ (* j n) i)) (vector-ref y i))))))
                                              (vector-set! b i bnew)
                                              (if (> bnew 0.0) (set! lossnew (+ lossnew (* cost (* bnew bnew)))) 0))))
                                        (if (<= (+ cnd (- lossnew lossold)) 0.0)
                                            (set! fin 1)
                                            (begin
                                              (set! dold d)
                                              (set! d (* 0.5 d))
                                              (set! delta (* 0.5 delta))
                                              (set! nls (+ nls 1))))))))
                              (vector-set! w j (+ wj d))
                              ;; b from w when the search ran out
                              (if (>= nls 20)
                                  (begin
                                    (do ((i 0 (+ i 1))) ((= i n)) (vector-set! b i 1.0))
                                    (do ((jj 0 (+ jj 1))) ((= jj p))
                                      (if (not (= (vector-ref w jj) 0.0))
                                          (do ((i 0 (+ i 1))) ((= i n))
                                            (vector-set! b i (- (vector-ref b i)
                                                                (* (vector-ref w jj) (* (vector-ref x (+ (* jj n) i)) (vector-ref y i))))))
                                          0)))
                                  0))
                            0))
                      (set! s (+ s 1)))
                    0))))
          (if (= iter 0) (set! ginit gnorm1new) 0)
          (set! iter (+ iter 1))
          (if (<= gnorm1new (* eps ginit))
              (if (= active p)
                  (set! done 1)
                  (begin (set! active p) (set! gmaxold 1e300)))
              (set! gmaxold gmaxnew)))))
    iter))

(define (svm-l1-abs a) (if (< a 0.0) (- 0.0 a) a))
