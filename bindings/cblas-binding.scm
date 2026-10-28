;; The BLAS binding --blas loads (rewrite-blas.scm lowers the
;; contractions of the array algebra to these ops).  Every array is
;; flat and row-major; a contraction whose summed axes sit at the
;; front or the back of each operand is one call over the matrices
;; the other axes flatten to.
;;
;;   (blas-gemm! y a b al be ta tb m n k)   y (m x n) = al op(a) op(b) + be y
;;   (blas-gemv! y a v al be ta m k)        y (m) = al op(a) v + be y
;;   (blas-syrk! y a al be ta m k)          y (m x m) = al op(a) op(a)^T + be y  (dsyrk + mirror)
;;   (blas-gemm-batched! y a b al be ta tb m n k batch)
;;                                          the gemm over batch contiguous slabs
;;                                          (a contraction with leading labels
;;                                          shared by both operands and y)
;;
;;   (lapack-syevd! a v ev m)               the symmetric eigenproblem, sym-eigen.scm's
;;                                          contract: a destroyed, v the vectors as
;;                                          columns, ev the values (LAPACKE_dsyevd);
;;                                          rewrite-blas.scm puts it in place of
;;                                          (sym-eigen a v ev e m)
;;   (lapack-syevr-top! a v ev m k)         the k largest eigenpairs, sym-eigen-top's contract:
;;                                          ev decreasing, v m x k (LAPACKE_dsyevr, range 'I'),
;;                                          in place of (sym-eigen-top a v ev e m k)
;;   (lapack-sygvd! a b v ev m)              A v = lam B v, sym-eigen-gen's contract: v the
;;                                          vectors (V'BV = I), ev the values (LAPACKE_dsygvd,
;;                                          itype 1), in place of (sym-eigen-gen a b v ev e m)
;;   (lapack-posv! a b m q)                 A W = B for A positive definite, gram.scm's
;;                                          spd-solve contract: a destroyed, b overwritten
;;                                          by W, LAPACK's info returned (LAPACKE_dposv),
;;                                          in place of (spd-solve a b m q)
;;   (lapack-posv-rcond! a b m q)           the same, then the reciprocal 1-norm condition
;;                                          number of A (LAPACKE_dpocon on the factor),
;;                                          -1.0 when A is not positive definite, in place
;;                                          of (spd-solve-rcond a b m q)
;;   (lapack-gesdd! a u s vt m n)           the thin SVD, sym-svd.scm's contract (LAPACKE_dgesdd,
;;                                          jobz 'S'), in place of (sym-svd a u s vt m n)
;;
;; ta = 1 says a is stored k x m (so op(a) = a^T), else m x k; tb = 1
;; says b is stored n x k, else k x n.  The models are the products
;; written out, for binding-check.rkt.
(defop blas-gemm!
  (sig ((vector double) (vector double) (vector double) double double int int int int int) void)
  (cpp "scm2cpp::blas_gemm(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemv!
  (sig ((vector double) (vector double) (vector double) double double int int int) void)
  (cpp "scm2cpp::blas_gemv(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-syrk!
  (sig ((vector double) (vector double) double double int int int) void)
  (cpp "scm2cpp::blas_syrk(~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-syevd!
  (sig ((vector double) (vector double) (vector double) int) int)
  (cpp "scm2cpp::lapack_syevd(~a, ~a, ~a, ~a)")
  (mutates 0 1 2)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-syevr-top!
  (sig ((vector double) (vector double) (vector double) int int) int)
  (cpp "scm2cpp::lapack_syevr_top(~a, ~a, ~a, ~a, ~a)")
  (mutates 0 1 2)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-sygvd!
  (sig ((vector double) (vector double) (vector double) (vector double) int) int)
  (cpp "scm2cpp::lapack_sygvd(~a, ~a, ~a, ~a, ~a)")
  (mutates 0 1 2 3)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-posv!
  (sig ((vector double) (vector double) int int) int)
  (cpp "scm2cpp::lapack_posv(~a, ~a, ~a, ~a)")
  (mutates 0 1)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-posv-rcond!
  (sig ((vector double) (vector double) int int) double)
  (cpp "scm2cpp::lapack_posv_rcond(~a, ~a, ~a, ~a)")
  (mutates 0 1)
  (header "\"scm2cpp-blas.hpp\""))
(defop lapack-gesdd!
  (sig ((vector double) (vector double) (vector double) (vector double) int int) int)
  (cpp "scm2cpp::lapack_gesdd(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0 1 2 3)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemm-batched!
  (sig ((vector double) (vector double) (vector double) double double int int int int int int) void)
  (cpp "scm2cpp::blas_gemm_batched(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))

(model blas-gemm!
  (lambda (y a b alpha beta ta tb m n k)
    (do ((i 0 (+ i 1))) ((= i m))
      (do ((j 0 (+ j 1))) ((= j n))
        (vector-set! y (+ (* i n) j)
          (+ (* beta (vector-ref y (+ (* i n) j)))
             (* alpha
                (let loop ((l 0) (s 0.0))
                  (if (= l k) s
                      (loop (+ l 1)
                            (+ s (* (vector-ref a (if (= ta 1) (+ (* l m) i) (+ (* i k) l)))
                                    (vector-ref b (if (= tb 1) (+ (* j k) l) (+ (* l n) j)))))))))))))))
(model blas-gemm-batched!
  (lambda (y a b alpha beta ta tb m n k batch)
    (do ((l 0 (+ l 1))) ((= l batch))
      (do ((i 0 (+ i 1))) ((= i m))
        (do ((j 0 (+ j 1))) ((= j n))
          (vector-set! y (+ (* l (* m n)) (+ (* i n) j))
            (+ (* beta (vector-ref y (+ (* l (* m n)) (+ (* i n) j))))
               (* alpha
                  (let loop ((q 0) (s 0.0))
                    (if (= q k) s
                        (loop (+ q 1)
                              (+ s (* (vector-ref a (+ (* l (* m k)) (if (= ta 1) (+ (* q m) i) (+ (* i k) q))))
                                      (vector-ref b (+ (* l (* k n)) (if (= tb 1) (+ (* j k) q) (+ (* q n) j)))))))))))))))))
(model blas-gemv!
  (lambda (y a v alpha beta ta m k)
    (do ((i 0 (+ i 1))) ((= i m))
      (vector-set! y i
        (+ (* beta (vector-ref y i))
           (* alpha
              (let loop ((l 0) (s 0.0))
                (if (= l k) s
                    (loop (+ l 1)
                          (+ s (* (vector-ref a (if (= ta 1) (+ (* l m) i) (+ (* i k) l)))
                                  (vector-ref v l))))))))))))
(model blas-syrk!
  (lambda (y a alpha beta ta m k)
    (do ((i 0 (+ i 1))) ((= i m))
      (do ((j 0 (+ j 1))) ((= j m))
        (vector-set! y (+ (* i m) j)
          (+ (* beta (vector-ref y (+ (* i m) j)))
             (* alpha
                (let loop ((l 0) (s 0.0))
                  (if (= l k) s
                      (loop (+ l 1)
                            (+ s (* (vector-ref a (if (= ta 1) (+ (* l m) i) (+ (* i k) l)))
                                    (vector-ref a (if (= ta 1) (+ (* l m) j) (+ (* j k) l)))))))))))))))

;; one-sided Jacobi on a tall A (the test's), the vectors normalised
;; and sorted by value; the binding test reads only what is determined
(model lapack-gesdd!
  (lambda (a u s vt m n)
    (define (at i j) (vector-ref a (+ (* i n) j)))
    (define q (make-vector (* n n) 0.0))
    (for ([i n]) (vector-set! q (+ (* i n) i) 1.0))
    (for ([sweep 60])
      (for* ([p n] [r (in-range (+ p 1) n)])
        (let ([al (for/sum ([i m]) (* (at i p) (at i p)))]
              [be (for/sum ([i m]) (* (at i r) (at i r)))]
              [ga (for/sum ([i m]) (* (at i p) (at i r)))])
          (when (> (abs ga) (* 1e-15 (sqrt (* al be))))
            (let* ([z (/ (- be al) (* 2.0 ga))]
                   [t (/ (if (< z 0.0) -1.0 1.0) (+ (abs z) (sqrt (+ 1.0 (* z z)))))]
                   [c (/ 1.0 (sqrt (+ 1.0 (* t t))))]
                   [sn (* c t)])
              (for ([i m])
                (let ([x (at i p)] [y (at i r)])
                  (vector-set! a (+ (* i n) p) (- (* c x) (* sn y)))
                  (vector-set! a (+ (* i n) r) (+ (* sn x) (* c y)))))
              (for ([i n])
                (let ([x (vector-ref q (+ (* i n) p))] [y (vector-ref q (+ (* i n) r))])
                  (vector-set! q (+ (* i n) p) (- (* c x) (* sn y)))
                  (vector-set! q (+ (* i n) r) (+ (* sn x) (* c y))))))))))
    (define norms (for/list ([j n]) (sqrt (for/sum ([i m]) (* (at i j) (at i j))))))
    (define ord (sort (for/list ([j n]) j) > #:key (lambda (j) (list-ref norms j))))
    (for ([j n] [col ord])
      (let ([sg (list-ref norms col)])
        (vector-set! s j sg)
        (for ([i m]) (vector-set! u (+ (* i n) j) (/ (at i col) sg)))
        (for ([i n]) (vector-set! vt (+ (* j n) i) (vector-ref q (+ (* i n) col))))))
    0))

;; cyclic Jacobi: a different algorithm from dsyevd on purpose, so the
;; test compares what is determined -- the values in order, and the
;; vectors up to sign (their squares)
(model lapack-syevd!
  (lambda (a v ev m)
    (define (at i j) (vector-ref a (+ (* i m) j)))
    (define (put! i j x) (vector-set! a (+ (* i m) j) x))
    (do ((i 0 (+ i 1))) ((= i m))
      (do ((j 0 (+ j 1))) ((= j m))
        (vector-set! v (+ (* i m) j) (if (= i j) 1.0 0.0))))
    (do ((sweep 0 (+ sweep 1))) ((= sweep 60))
      (do ((p 0 (+ p 1))) ((= p m))
        (do ((q (+ p 1) (+ q 1))) ((>= q m))
          (when (> (abs (at p q)) 1e-300)
            (let* ([theta (/ (- (at q q) (at p p)) (* 2.0 (at p q)))]
                   [t (/ (if (< theta 0.0) -1.0 1.0)
                         (+ (abs theta) (sqrt (+ (* theta theta) 1.0))))]
                   [c (/ 1.0 (sqrt (+ (* t t) 1.0)))]
                   [s (* t c)])
              (do ((k 0 (+ k 1))) ((= k m))
                (let ([akp (at k p)] [akq (at k q)])
                  (put! k p (- (* c akp) (* s akq)))
                  (put! k q (+ (* s akp) (* c akq)))))
              (do ((k 0 (+ k 1))) ((= k m))
                (let ([apk (at p k)] [aqk (at q k)])
                  (put! p k (- (* c apk) (* s aqk)))
                  (put! q k (+ (* s apk) (* c aqk)))))
              (do ((k 0 (+ k 1))) ((= k m))
                (let ([vkp (vector-ref v (+ (* k m) p))] [vkq (vector-ref v (+ (* k m) q))])
                  (vector-set! v (+ (* k m) p) (- (* c vkp) (* s vkq)))
                  (vector-set! v (+ (* k m) q) (+ (* s vkp) (* c vkq))))))))))
    ;; ascending, as dsyevd gives them
    (do ((i 0 (+ i 1))) ((= i m)) (vector-set! ev i (at i i)))
    (do ((i 0 (+ i 1))) ((= i m))
      (do ((j (+ i 1) (+ j 1))) ((>= j m))
        (when (< (vector-ref ev j) (vector-ref ev i))
          (let ([t (vector-ref ev i)]) (vector-set! ev i (vector-ref ev j)) (vector-set! ev j t))
          (do ((k 0 (+ k 1))) ((= k m))
            (let ([t (vector-ref v (+ (* k m) i))])
              (vector-set! v (+ (* k m) i) (vector-ref v (+ (* k m) j)))
              (vector-set! v (+ (* k m) j) t))))))
    0))

(binding-test
  (define (main)
    (let ((x (vector 0.5 2.0 3.0 4.0 5.0 6.25))   ; 2 x 3
          (m (vector 1.0 0.5 -1.0 2.0 0.25 -0.5))   ; 3 x 2
          (g (make-vector 4 0.0))
          (gt (make-vector 9 0.0))
          (f (vector 1.0 2.0 3.0 4.0))
          (c (make-vector 2 0.0))
          (r (vector 1.0 1.0 1.0))
          (r2 (vector 1.0 1.0 1.0))
          (d (vector 1.0 -1.0))
          (s (make-vector 4 0.0))
          (st (make-vector 9 0.0))
          (yb (make-vector 2 0.0)))
      (blas-gemm! g x x 1.0 0.0 0 1 2 2 3)      ; g = x x^T
      (blas-gemm! gt x x 1.0 0.0 1 0 3 3 2)     ; gt = x^T x (x read as 2 rows of 3: ta)
      (blas-gemm! f x m 0.5 1.0 0 0 2 2 3)      ; f += 0.5 x m
      (blas-gemv! c x r 1.0 0.0 0 2 3)          ; c = x r
      (blas-gemv! r2 x d -1.0 1.0 1 3 2)        ; r2 -= x^T d
      (blas-syrk! s x 1.0 0.0 0 2 3)            ; s = x x^T
      (blas-syrk! st x 1.0 0.0 1 3 2)           ; st = x^T x
      (blas-gemm-batched! yb x m 1.0 0.0 0 0 1 1 3 2)   ; two 1x3 . 3x1 slabs
      (display (vector-ref g 0)) (newline)      ; x x^T: 13.25
      (display (vector-ref g 3)) (newline)      ; 80.0625
      (display (vector-ref gt 0)) (newline)     ; x^T x: 16.25
      (display (vector-ref gt 8)) (newline)     ; 48.0625
      (display (vector-ref f 0)) (newline)      ; f += 0.5 x m: 0.625
      (display (vector-ref f 3)) (newline)      ; 8.4375
      (display (vector-ref c 0)) (newline)      ; x r: 5.5
      (display (vector-ref c 1)) (newline)      ; 15.25
      (display (vector-ref r2 0)) (newline)     ; r2 -= x^T d: 4.5
      (display (vector-ref r2 2)) (newline)     ; 4.25
      (display (vector-ref s 1)) (newline)      ; syrk x x^T: 30.75
      (display (vector-ref st 5)) (newline)     ; syrk x^T x: 37.25
      (display (vector-ref yb 0)) (newline)     ; batched: -1.5
      (display (vector-ref yb 1)) (newline)     ; 6.125
      0))
  (main))

;; lapack-syevd!: eigenvalues 1.25, 2 and 3 (ascending), vectors
;; (0 0 1), (1 -1 0)/sqrt 2, (1 1 0)/sqrt 2.  Printed on a grid of 1/1024
;; and offset by 1/8, so that two algorithms print the same digits and
;; no value is integral; the vectors as their squares (no sign).
;; Cholesky and the two triangular solves
(model lapack-posv!
  (lambda (a b m q)
    (define (at x i j w) (vector-ref x (+ (* i w) j)))
    (define l (make-vector (* m m) 0.0))
    (for* ([j m] [i (in-range j m)])
      (let ([s (- (at a i j m) (for/sum ([k j]) (* (at l i k m) (at l j k m))))])
        (vector-set! l (+ (* i m) j) (if (= i j) (sqrt s) (/ s (at l j j m))))))
    (for ([c q])
      (for ([i m])
        (vector-set! b (+ (* i q) c)
                     (/ (- (at b i c q) (for/sum ([k i]) (* (at l i k m) (at b k c q)))) (at l i i m))))
      (for ([ii m])
        (let ([i (- m 1 ii)])
          (vector-set! b (+ (* i q) c)
                       (/ (- (at b i c q) (for/sum ([k (in-range (+ i 1) m)]) (* (at l k i m) (at b k c q))))
                          (at l i i m))))))
    0))

;; lapack-posv!'s model, then 1 / (|A|_1 |A^-1|_1) exactly (dpocon
;; estimates it; on the test's matrix the estimate is exact)
(model lapack-posv-rcond!
  (lambda (a b m q)
    (define (dup x) (build-vector (vector-length x) (lambda (t) (vector-ref x t))))
    (define a0 (dup a))
    (define (norm1 x)
      (for/fold ([top 0.0]) ([c m])
        (max top (for/sum ([i m]) (abs (vector-ref x (+ (* i m) c)))))))
    (define inv (make-vector (* m m) 0.0))
    (for ([c m]) (vector-set! inv (+ (* c m) c) 1.0))
    (lapack-posv! (dup a0) inv m m)
    (lapack-posv! a b m q)
    (/ 1.0 (* (norm1 a0) (norm1 inv)))))

;; B = L L', C = L^-1 A L^-T by the dsyevd model, V = L^-T W
(model lapack-sygvd!
  (lambda (a b v ev m)
    (define (at x i j) (vector-ref x (+ (* i m) j)))
    (define l (make-vector (* m m) 0.0))
    (for* ([j m] [i (in-range j m)])
      (let ([s (- (at b i j) (for/sum ([k j]) (* (at l i k) (at l j k))))])
        (vector-set! l (+ (* i m) j) (if (= i j) (sqrt s) (/ s (at l j j))))))
    ;; c = L^-1 a L^-T by two substitutions
    (define t (make-vector (* m m) 0.0))
    (for* ([col m] [i m])
      (vector-set! t (+ (* i m) col)
                   (/ (- (at a i col) (for/sum ([k i]) (* (at l i k) (at t k col)))) (at l i i))))
    (define c (make-vector (* m m) 0.0))
    (for* ([r m] [i m])
      (vector-set! c (+ (* r m) i)
                   (/ (- (at t r i) (for/sum ([k i]) (* (at l i k) (at c r k)))) (at l i i))))
    (define w (make-vector (* m m) 0.0))
    (lapack-syevd! c w ev m)
    (for* ([col m] [ii m])
      (let ([i (- m 1 ii)])
        (vector-set! v (+ (* i m) col)
                     (/ (- (at w i col) (for/sum ([k (in-range (+ i 1) m)]) (* (at l k i) (at v k col))))
                        (at l i i)))))
    0))

;; the whole problem by the model above, then the k largest, reversed
(model lapack-syevr-top!
  (lambda (a v ev m k)
    (define vf (make-vector (* m m) 0.0))
    (define evf (make-vector m 0.0))
    (lapack-syevd! a vf evf m)
    (for ([c k])
      (vector-set! ev c (vector-ref evf (- m 1 c)))
      (for ([j m])
        (vector-set! v (+ (* j k) c) (vector-ref vf (+ (* j m) (- m 1 c))))))
    0))

(binding-test
  (define (main)
    (let ((a (vector 2.5 0.5 0.0  0.5 2.5 0.0  0.0 0.0 1.25))
          (v (make-vector 9 0.0))
          (ev (make-vector 3 0.0)))
      (lapack-syevd! a v ev 3)
      (do ((i 0 (+ i 1))) ((= i 3))
        (display (+ 0.125 (/ (floor (+ (* 1024.0 (vector-ref ev i)) 0.5)) 1024.0)))
        (newline))
      (do ((t 0 (+ t 1))) ((= t 9))
        (display (+ 0.125 (/ (floor (+ (* 1024.0 (* (vector-ref v t) (vector-ref v t))) 0.5)) 1024.0)))
        (newline))
      0))
  (main))

;; lapack-syevr-top!: the same matrix, its two largest pairs: 3 and 2
;; (decreasing), the vectors (1 1 0)/sqrt 2 and (1 -1 0)/sqrt 2 as
;; their squares, on the same grid
(binding-test
  (define (main)
    (let ((a (vector 2.5 0.5 0.0  0.5 2.5 0.0  0.0 0.0 1.25))
          (v (make-vector 6 0.0))
          (ev (make-vector 2 0.0)))
      (lapack-syevr-top! a v ev 3 2)
      (do ((i 0 (+ i 1))) ((= i 2))
        (display (+ 0.125 (/ (floor (+ (* 1024.0 (vector-ref ev i)) 0.5)) 1024.0)))
        (newline))
      (do ((t 0 (+ t 1))) ((= t 6))
        (display (+ 0.125 (/ (floor (+ (* 1024.0 (* (vector-ref v t) (vector-ref v t))) 0.5)) 1024.0)))
        (newline))
      0))
  (main))

;; lapack-sygvd!: A v = lam B v for A = diag(2, 3, 1.25) + 0.5 in the
;; (0, 1) corner and B = diag(2, 1, 0.5); its values (ascending, as
;; dsygvd gives them) and the vectors as their squares (V'BV = I fixes
;; the scale, not the sign), on a grid of 1/16 (what
;; C++ prints in six digits)
(binding-test
  (define (main)
    (let ((a (vector 2.0 0.5 0.0  0.5 3.0 0.0  0.0 0.0 1.25))
          (b (vector 2.0 0.0 0.0  0.0 1.0 0.0  0.0 0.0 0.5))
          (v (make-vector 9 0.0))
          (ev (make-vector 3 0.0)))
      (lapack-sygvd! a b v ev 3)
      (do ((i 0 (+ i 1))) ((= i 3))
        (display (+ 0.125 (/ (floor (+ (* 16.0 (vector-ref ev i)) 0.5)) 16.0)))
        (newline))
      (do ((t 0 (+ t 1))) ((= t 9))
        (display (+ 0.125 (/ (floor (+ (* 16.0 (* (vector-ref v t) (vector-ref v t))) 0.5)) 16.0)))
        (newline))
      0))
  (main))

;; lapack-posv!: A = [[4 2 0] [2 5 1] [0 1 3]], B two columns; the
;; solution W on a grid of 1/16 (the factor left in A is not compared:
;; its layout is LAPACK's)
(binding-test
  (define (main)
    (let ((a (vector 4.0 2.0 0.0  2.0 5.0 1.0  0.0 1.0 3.0))
          (a0 (vector 4.0 2.0 0.0  2.0 5.0 1.0  0.0 1.0 3.0))
          (b (vector 1.5 -0.5  2.25 1.0  -0.75 0.5)))
      (lapack-posv! a b 3 2)
      (do ((t 0 (+ t 1))) ((= t 6))
        (display (+ 0.125 (/ (floor (+ (* 16.0 (vector-ref b t)) 0.5)) 16.0)))
        (newline))
      0))
  (main))

;; lapack-posv-rcond!: the same A and B; the solution on the same grid
;; and the reciprocal condition number, 0.25 (dpocon's estimate is exact
;; here), plus 1/8 so that it is not integral
(binding-test
  (define (main)
    (let ((a (vector 4.0 2.0 0.0  2.0 5.0 1.0  0.0 1.0 3.0))
          (b (vector 1.5 -0.5  2.25 1.0  -0.75 0.5)))
      (let ((rc (lapack-posv-rcond! a b 3 2)))
        (do ((t 0 (+ t 1))) ((= t 6))
          (display (+ 0.125 (/ (floor (+ (* 16.0 (vector-ref b t)) 0.5)) 16.0)))
          (newline))
        (display (+ 0.125 (/ (floor (+ (* 1024.0 rc) 0.5)) 1024.0)))
        (newline))
      0))
  (main))

;; lapack-gesdd!: a 3 x 2 matrix; its singular values and the product
;; U diag(S) Vt (the matrix back, whatever the signs); the values on a
;; grid of 1/16, so that they print in the six digits C++ shows
(binding-test
  (define (main)
    (let ((a (vector 1.5 0.5  -0.25 2.0  0.75 -1.0))
          (u (make-vector 6 0.0))
          (s (make-vector 2 0.0))
          (vt (make-vector 4 0.0)))
      (lapack-gesdd! a u s vt 3 2)
      (do ((j 0 (+ j 1))) ((= j 2))
        (display (+ 0.125 (/ (floor (+ (* 16.0 (vector-ref s j)) 0.5)) 16.0)))
        (newline))
      (do ((i 0 (+ i 1))) ((= i 3))
        (do ((j 0 (+ j 1))) ((= j 2))
          (let ((acc (+ (* (vector-ref u (* i 2)) (* (vector-ref s 0) (vector-ref vt j)))
                        (* (vector-ref u (+ (* i 2) 1)) (* (vector-ref s 1) (vector-ref vt (+ 2 j)))))))
            (display (+ 0.125 (/ (floor (+ (* 1024.0 acc) 0.5)) 1024.0)))
            (newline))))
      0))
  (main))
