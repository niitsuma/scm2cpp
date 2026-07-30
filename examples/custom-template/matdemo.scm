;; Row sums of a user-header matrix: every operation on m goes through
;; the binding, so the generated C++ speaks foo::Matrix directly.
(define (rowsum m r n)
  (let ((acc 0.0))
    (do ((j 0 (+ j 1))) ((= j n))
      (set! acc (+ acc (mat-ref m r j))))
    acc))

(define (main)
  (let ((m (mat-new 4 6)))
    (do ((i 0 (+ i 1))) ((= i 4))
      (do ((j 0 (+ j 1))) ((= j 6))
        (mat-set! m i j (* 1.0 (+ (* i 6) j)))))
    (display (rowsum m 0 6)) (newline)
    (display (rowsum m 3 6)) (newline)
    (display (mat-rows m)) (newline)
    0))
