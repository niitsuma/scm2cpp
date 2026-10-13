;; The BLAS binding --blas loads (rewrite-blas.scm lowers the matmul
;; forms to these ops).  x is row-major p x n as the flat kernels store
;; it; scm2cpp-blas.hpp reads it as the column-major n x p matrix BLAS
;; expects, so no transposition is ever performed.
;;
;;   (blas-gram! g x p n)              g = x x^T          (dsyrk + mirror)
;;   (blas-gemv! c x v p n)            c = x v            (dgemv)
;;   (blas-gemv-t-add! r x d a p n)    r += a x^T d       (dgemv, beta = 1)
;;   (blas-gemm-nt! g a b p q n)       g = a b^T          (dgemm)
;;   (blas-gemm-nn! g a b p q n)       g = a b            (dgemm)
;;   (blas-gemm-tn-add! r d x a p q n) r += a d^T x       (dgemm, beta = 1)
;;   (blas-gram-t! g x n p)            g = x^T x          (dsyrk + mirror; x n rows of p)
;;   (blas-gemv-add! r x d a p n)      r += a x d         (dgemv, beta = 1)
;;   (blas-gemm-nn-add! r a b al p q n) r += al a b        (dgemm, beta = 1)
;;
;; The models are the products written out, for binding-check.rkt.
(defop blas-gram!
  (sig ((vector double) (vector double) int int) void)
  (cpp "scm2cpp::blas_gram(~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemv!
  (sig ((vector double) (vector double) (vector double) int int) void)
  (cpp "scm2cpp::blas_gemv(~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemv-t-add!
  (sig ((vector double) (vector double) (vector double) double int int) void)
  (cpp "scm2cpp::blas_gemv_t_add(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemm-nt!
  (sig ((vector double) (vector double) (vector double) int int int) void)
  (cpp "scm2cpp::blas_gemm_nt(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemm-nn!
  (sig ((vector double) (vector double) (vector double) int int int) void)
  (cpp "scm2cpp::blas_gemm_nn(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemm-tn-add!
  (sig ((vector double) (vector double) (vector double) double int int int) void)
  (cpp "scm2cpp::blas_gemm_tn_add(~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gram-t!
  (sig ((vector double) (vector double) int int) void)
  (cpp "scm2cpp::blas_gram_t(~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemv-add!
  (sig ((vector double) (vector double) (vector double) double int int) void)
  (cpp "scm2cpp::blas_gemv_add(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))
(defop blas-gemm-nn-add!
  (sig ((vector double) (vector double) (vector double) double int int int) void)
  (cpp "scm2cpp::blas_gemm_nn_add(~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0)
  (header "\"scm2cpp-blas.hpp\""))

(model blas-gram!
  (lambda (g x p n)
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! g (+ (* i p) j)
          (let loop ((k 0) (s 0.0))
            (if (= k n) s
                (loop (+ k 1) (+ s (* (vector-ref x (+ (* i n) k))
                                      (vector-ref x (+ (* j n) k))))))))))))
(model blas-gemv!
  (lambda (c x v p n)
    (do ((i 0 (+ i 1))) ((= i p))
      (vector-set! c i
        (let loop ((k 0) (s 0.0))
          (if (= k n) s
              (loop (+ k 1) (+ s (* (vector-ref x (+ (* i n) k)) (vector-ref v k))))))))))
(model blas-gemv-t-add!
  (lambda (r x d a p n)
    (do ((k 0 (+ k 1))) ((= k n))
      (vector-set! r k
        (let loop ((i 0) (s (vector-ref r k)))
          (if (= i p) s
              (loop (+ i 1) (+ s (* a (vector-ref d i) (vector-ref x (+ (* i n) k)))))))))))
(model blas-gemm-nt!
  (lambda (g a b p q n)
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j q))
        (vector-set! g (+ (* i q) j)
          (let loop ((k 0) (s 0.0))
            (if (= k n) s
                (loop (+ k 1) (+ s (* (vector-ref a (+ (* i n) k))
                                      (vector-ref b (+ (* j n) k))))))))))))
(model blas-gemm-nn!
  (lambda (g a b p q n)
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j q))
        (vector-set! g (+ (* i q) j)
          (let loop ((k 0) (s 0.0))
            (if (= k n) s
                (loop (+ k 1) (+ s (* (vector-ref a (+ (* i n) k))
                                      (vector-ref b (+ (* k q) j))))))))))))
(model blas-gram-t!
  (lambda (g x n p)
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! g (+ (* i p) j)
          (let loop ((k 0) (s 0.0))
            (if (= k n) s
                (loop (+ k 1) (+ s (* (vector-ref x (+ (* k p) i))
                                      (vector-ref x (+ (* k p) j))))))))))))
(model blas-gemv-add!
  (lambda (r x v a p n)
    (do ((i 0 (+ i 1))) ((= i p))
      (vector-set! r i
        (let loop ((k 0) (s (vector-ref r i)))
          (if (= k n) s
              (loop (+ k 1) (+ s (* a (vector-ref x (+ (* i n) k)) (vector-ref v k))))))))))
(model blas-gemm-nn-add!
  (lambda (r a b al p q n)
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j q))
        (vector-set! r (+ (* i q) j)
          (let loop ((k 0) (s (vector-ref r (+ (* i q) j))))
            (if (= k n) s
                (loop (+ k 1) (+ s (* al (vector-ref a (+ (* i n) k))
                                        (vector-ref b (+ (* k q) j))))))))))))
(model blas-gemm-tn-add!
  (lambda (r d x a p q n)
    (do ((i 0 (+ i 1))) ((= i q))
      (do ((k 0 (+ k 1))) ((= k n))
        (vector-set! r (+ (* i n) k)
          (let loop ((j 0) (s (vector-ref r (+ (* i n) k))))
            (if (= j p) s
                (loop (+ j 1) (+ s (* a (vector-ref d (+ (* j q) i))
                                        (vector-ref x (+ (* j n) k))))))))))))

(binding-test
  (define (main)
    (let ((x (vector 0.5 2.0 3.0 4.0 5.0 6.25))   ; 2 x 3
          (g (make-vector 4 0.0))
          (gt (make-vector 9 0.0))
          (c (make-vector 2 0.0))
          (r (vector 1.0 1.0 1.0))
          (d (vector 1.0 -1.0))
          (e (vector 0.25 -0.5))
          (m (vector 1.0 0.5 -1.0 2.0 0.25 -0.5))   ; 3 x 2
          (f (vector 1.0 2.0 3.0 4.0)))
      (blas-gram! g x 2 3)
      (blas-gemv! c x r 2 3)
      (blas-gemv-t-add! r x d -1.0 2 3)
      (blas-gram-t! gt x 2 3)                   ; x read as 2 rows of 3: x^T x is 3 x 3
      (blas-gemv-add! e x r 2.0 2 3)            ; e += 2 x r (46.25, 128.625: six digits, as C++ prints)
      (blas-gemm-nn-add! f x m 0.5 2 2 3)       ; f (2 x 2) += 0.5 x (2 x 3) m (3 x 2)
      (display (vector-ref g 0)) (newline)
      (display (vector-ref g 1)) (newline)
      (display (vector-ref g 3)) (newline)
      (display (vector-ref c 0)) (newline)
      (display (vector-ref c 1)) (newline)
      (display (vector-ref r 0)) (newline)
      (display (vector-ref r 2)) (newline)
      (display (vector-ref gt 0)) (newline)
      (display (vector-ref gt 5)) (newline)
      (display (vector-ref gt 7)) (newline)
      (display (vector-ref e 0)) (newline)
      (display (vector-ref e 1)) (newline)
      (display (vector-ref f 0)) (newline)
      (display (vector-ref f 3)) (newline)
      0))
  (main))
