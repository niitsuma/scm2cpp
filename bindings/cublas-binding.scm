;; The cuBLAS binding --cublas loads: the ops of cblas-binding.scm with
;; the matrix operands on the device.  rewrite-blas.scm uploads each
;; matrix a scope only reads once at the entry of that scope,
;;   (let ((dx (dmat-upload x rows cols))) ...)
;; and one the scope writes at each call; vectors stay on the host and
;; cross per call (scm2cpp-cublas.hpp).  The models are those of the
;; cblas binding over the host copy, dmat-upload being the identity.
(deftype dmat (cpp "scm2cpp::device_matrix") (header "\"scm2cpp-cublas.hpp\""))
(defop dmat-upload
  (sig ((vector double) int int) (dmat))
  (cpp "scm2cpp::dmat_upload(~a, ~a, ~a)"))
(defop blas-gemm!
  (sig ((vector double) (dmat) (dmat) double double int int int int int) void)
  (cpp "scm2cpp::blas_gemm(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemv!
  (sig ((vector double) (dmat) (vector double) double double int int int) void)
  (cpp "scm2cpp::blas_gemv(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-syrk!
  (sig ((vector double) (dmat) double double int int int) void)
  (cpp "scm2cpp::blas_syrk(~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemm-batched!
  (sig ((vector double) (dmat) (dmat) double double int int int int int int) void)
  (cpp "scm2cpp::blas_gemm_batched(~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))

(model dmat-upload (lambda (x p n) x))
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
      (let ((dx (dmat-upload x 2 3)))
        (blas-gemm! g dx dx 1.0 0.0 0 1 2 2 3)
        (blas-gemm! gt dx dx 1.0 0.0 1 0 3 3 2)
        (blas-gemm! f dx (dmat-upload m 3 2) 0.5 1.0 0 0 2 2 3)
        (blas-gemv! c dx r 1.0 0.0 0 2 3)
        (blas-gemv! r2 dx d -1.0 1.0 1 3 2)
        (blas-syrk! s dx 1.0 0.0 0 2 3)
        (blas-syrk! st dx 1.0 0.0 1 3 2)
        (blas-gemm-batched! yb dx (dmat-upload m 3 2) 1.0 0.0 0 0 1 1 3 2))
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
