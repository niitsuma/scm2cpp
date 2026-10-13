;; The BLAS binding --blas loads (rewrite-blas.scm lowers the
;; contractions of the array algebra to these ops).  Every array is
;; flat and row-major; a contraction whose summed axes sit at the
;; front or the back of each operand is one call over the matrices
;; the other axes flatten to.
;;
;;   (blas-gemm! y a b al be ta tb m n k)   y (m x n) = al op(a) op(b) + be y
;;   (blas-gemv! y a v al be ta m k)        y (m) = al op(a) v + be y
;;   (blas-syrk! y a al be ta m k)          y (m x m) = al op(a) op(a)^T + be y  (dsyrk + mirror)
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
          (st (make-vector 9 0.0)))
      (blas-gemm! g x x 1.0 0.0 0 1 2 2 3)      ; g = x x^T
      (blas-gemm! gt x x 1.0 0.0 1 0 3 3 2)     ; gt = x^T x (x read as 2 rows of 3: ta)
      (blas-gemm! f x m 0.5 1.0 0 0 2 2 3)      ; f += 0.5 x m
      (blas-gemv! c x r 1.0 0.0 0 2 3)          ; c = x r
      (blas-gemv! r2 x d -1.0 1.0 1 3 2)        ; r2 -= x^T d
      (blas-syrk! s x 1.0 0.0 0 2 3)            ; s = x x^T
      (blas-syrk! st x 1.0 0.0 1 3 2)           ; st = x^T x
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
      0))
  (main))
