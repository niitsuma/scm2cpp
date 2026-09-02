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
          (c (make-vector 2 0.0))
          (r (vector 1.0 1.0 1.0))
          (d (vector 1.0 -1.0)))
      (blas-gram! g x 2 3)
      (blas-gemv! c x r 2 3)
      (blas-gemv-t-add! r x d -1.0 2 3)
      (display (vector-ref g 0)) (newline)
      (display (vector-ref g 1)) (newline)
      (display (vector-ref g 3)) (newline)
      (display (vector-ref c 0)) (newline)
      (display (vector-ref c 1)) (newline)
      (display (vector-ref r 0)) (newline)
      (display (vector-ref r 2)) (newline)
      0))
  (main))
