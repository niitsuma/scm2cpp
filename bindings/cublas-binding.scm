;; The cuBLAS binding --cublas loads: the ops of cblas-binding.scm with
;; the matrix operand on the device.  rewrite-blas.scm uploads each
;; matrix once at the entry of the scope that reads it,
;;   (let ((dx (dmat-upload x p n))) ...)
;; and hands dx to the products; vectors stay on the host and cross
;; per call (scm2cpp-cublas.hpp).  The models are those of the cblas
;; binding over the host copy, dmat-upload being the identity.
(deftype dmat (cpp "scm2cpp::device_matrix") (header "\"scm2cpp-cublas.hpp\""))
(defop dmat-upload
  (sig ((vector double) int int) (dmat))
  (cpp "scm2cpp::dmat_upload(~a, ~a, ~a)"))
(defop blas-gram!
  (sig ((vector double) (dmat) int int) void)
  (cpp "scm2cpp::blas_gram(~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemv!
  (sig ((vector double) (dmat) (vector double) int int) void)
  (cpp "scm2cpp::blas_gemv(~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemv-t-add!
  (sig ((vector double) (dmat) (vector double) double int int) void)
  (cpp "scm2cpp::blas_gemv_t_add(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemm-nt!
  (sig ((vector double) (dmat) (dmat) int int int) void)
  (cpp "scm2cpp::blas_gemm_nt(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemm-nn!
  (sig ((vector double) (dmat) (dmat) int int int) void)
  (cpp "scm2cpp::blas_gemm_nn(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemm-tn-add!
  (sig ((vector double) (vector double) (dmat) double int int int) void)
  (cpp "scm2cpp::blas_gemm_tn_add(~a, ~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gram-t!
  (sig ((vector double) (dmat) int int) void)
  (cpp "scm2cpp::blas_gram_t(~a, ~a, ~a, ~a)")
  (mutates 0))
(defop blas-gemv-add!
  (sig ((vector double) (dmat) (vector double) double int int) void)
  (cpp "scm2cpp::blas_gemv_add(~a, ~a, ~a, ~a, ~a, ~a)")
  (mutates 0))

(model dmat-upload (lambda (x p n) x))
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
          (e (vector 0.25 -0.5)))
      (let ((dx (dmat-upload x 2 3)))
        (blas-gram! g dx 2 3)
        (blas-gemv! c dx r 2 3)
        (blas-gemv-t-add! r dx d -1.0 2 3)
        (blas-gram-t! gt dx 2 3)
        (blas-gemv-add! e dx r 2.0 2 3))
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
      0))
  (main))
