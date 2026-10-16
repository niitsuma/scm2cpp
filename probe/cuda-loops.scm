;; The loops --cuda emits as kernels, without the products: an elementwise
;; map through a function the device calls, a sum reduction, a loop nest
;; whose outer loop is short and whose inner loop is long (the inner one
;; the kernel, with its own reduction), an int array, and a host statement
;; between device ones (the arrays brought back and marked).  Translated
;; plainly and with --cuda (SCM2CPP_CUDA_MIN 64, so the long loops run on
;; the device and the short ones on the host); the oracle runs the same
;; program.
(define (soft x t) (if (> x t) (- x t) (if (< x (- 0.0 t)) (+ x t) 0.0)))

(define (work x y count n k)
  (let ((z (make-vector n 0.0)) (rowsum (make-vector k 0.0)) (s 0.0) (big 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! z i (soft (* 2.0 (vector-ref x i)) 0.25)))
    (do ((i 0 (+ i 1))) ((= i n))
      (set! s (+ s (* (vector-ref z i) (vector-ref y i)))))
    ;; rows of y as k blocks of n / k: a short outer loop, a long inner one
    (do ((c 0 (+ c 1))) ((= c k))
      (let ((acc 0.0) (m (quotient n k)))
        (do ((i 0 (+ i 1))) ((= i m))
          (set! acc (+ acc (vector-ref z (+ (* c m) i)))))
        (vector-set! rowsum c acc)))
    ;; a host statement in between
    (vector-set! z 0 (+ (vector-ref z 0) 100.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! count i (if (> (vector-ref z i) 0.0) 1 0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (set! big (+ big (vector-ref count i))))
    (display s) (newline)
    (do ((c 0 (+ c 1))) ((= c k)) (display (vector-ref rowsum c)) (display " "))
    (newline)
    (display (vector-ref z 0)) (display " ") (display big) (newline)
    0))

(define (main)
  (let ((n 512) (k 4))
    (let ((x (make-vector n 0.0)) (y (make-vector n 0.0)) (count (make-vector n 0)))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! x i (- (* 0.0078125 (exact->inexact (remainder (* i 37) 128))) 0.5))
        (vector-set! y i (* 0.25 (exact->inexact (remainder i 8)))))
      (work x y count n k))
    0))
