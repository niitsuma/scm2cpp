;; nmf-cd.scm's NMF on a 6 x 5 non-negative matrix, rank 2, from a
;; fixed start: translated plainly, with --derive, --derive --blas and
;; --derive --cublas against the same oracle.  The derivation memoises
;; R HT over the hoisted HT'HT and distributes the residual fill
;; through it (c = X HT - W G, R never formed) under (if (< k p) ..);
;; k = 2 < p = 5 here, so the derived branch runs.  Dyadic data: the
;; steps divide by norms, so the digits are compared to the oracle's
;; tolerance, not exactly.
(include "../examples/kernel-only/nmf-cd.scm")

(define (main)
  (let ((n 6) (p 5) (k 2)
        (x (vector 1.0 0.5 2.0 0.25 1.5
                   0.5 1.0 0.75 1.25 0.25
                   2.0 0.25 1.0 0.5 1.75
                   0.75 1.5 0.5 1.0 0.5
                   1.25 0.75 1.5 0.25 1.0
                   0.25 1.25 0.5 1.5 0.75))
        (xt (make-vector 30 0.0))
        (w0 (vector 0.5 0.25 0.75 0.5 0.25 1.0 1.0 0.5 0.5 0.75 0.25 0.25))
        (ht0 (vector 0.5 1.0 0.25 0.5 1.0 0.25 0.75 0.5 0.5 0.75)))
    ;; W and HT swap places in the second half step, so they must be
    ;; one kind of vector: runtime-sized copies of the literals
    (let ((w (make-vector (* n k) 0.0))
          (ht (make-vector (* p k) 0.0)))
    (do ((i 0 (+ i 1))) ((= i 12)) (vector-set! w i (vector-ref w0 i)))
    (do ((i 0 (+ i 1))) ((= i 10)) (vector-set! ht i (vector-ref ht0 i)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! xt (+ (* j n) i) (vector-ref x (+ (* i p) j)))))
    (let ((it (nmf x xt w ht 50 1e-6 n p k)))
      (display it) (newline)
      (do ((i 0 (+ i 1))) ((= i 12))
        (display (vector-ref w i)) (display " "))
      (newline)
      (do ((i 0 (+ i 1))) ((= i 10))
        (display (vector-ref ht i)) (display " "))
      (newline)))
    0))
