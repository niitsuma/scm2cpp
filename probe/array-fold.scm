;; The built-in array-and-fold layer of array-macros.scm, exercised on
;; its own.  What is probed: 2-D and 3-D subscripts, a fold in expression
;; position, a fold whose accumulator rides across an inner effectful
;; loop, the two- and three-argument range-for, and the whole-vector
;; forms: array-dot, range-sum, array-dec-scaled!.

(define (main)
  (let ((rows 3) (cols 2))
    (let ((a (make-vector (* rows cols) 0.0))
          (s2 (make-vector (* rows cols) 0.0))
          (x (make-vector cols 0.0))
          (y (make-vector rows 0.0))
          (t (make-vector 8 0.0)))
      (with-arrays ((a (rows cols))
                    (x (cols)) (y (rows))
                    (t (2 2 2)))
        ;; fill A[i][j] = 10*i + j
        (range-for (i rows)
          (range-for (j cols)
            (array-set! a i j (+ (* 10.0 i) (* 1.0 j)))))
        (vector-set! x 0 2.0)
        (vector-set! x 1 0.5)
        ;; y = A x, the inner product as a fold in expression position
        (range-for (i rows)
          (vector-set! y i
                       (range-fold ((acc 0.0) (j cols))
                         (+ acc (* (array-ref a i j) (vector-ref x j))))))
        (display (vector-ref y 0)) (newline)
        (display (vector-ref y 1)) (newline)
        (display (vector-ref y 2)) (newline)
        ;; total of A, one fold over rows carrying an inner effectful loop
        (display
         (range-fold ((s 0.0) (i rows))
           (let ((row (range-fold ((r 0.0) (j cols))
                        (+ r (array-ref a i j)))))
             (+ s row))))
        (newline)
        ;; 3-D corner writes, and a start-offset loop reading them back
        (array-set! t 0 0 0 1.0)
        (array-set! t 1 1 1 7.0)
        ;; updating assignment through a 2-D subscript
        (array-inc! a 2 1 0.5)
        (array-dec! a 0 0 (array-ref a 2 1))
        (display (array-ref a 0 0)) (newline)
        (range-for (k 4 8)
          (vector-set! t k (+ (vector-ref t k) 0.25)))
        (display (vector-ref t 0)) (newline)
        (display (vector-ref t 7)) (newline)
        ;; whole-vector forms: inner product, sum, and vector -=
        (display (array-dot (row a 1) x)) (newline)
        (display (range-sum (i rows) (vector-ref y i))) (newline)
        ;; slices: numpy's u[lo:hi:step] as a read-only affine view.
        ;; sum of y[0:2], dot of a row segment with a stepped slice of
        ;; itself, and a dec through a slice operand.
        (display (array-sum (slice y 0 2))) (newline)
        (display (array-dot (slice y 0 3 2) (slice y 0 3 2))) (newline)
        (array-dec! x (scale 0.1 (row a 0)))
        ;; a compound vector expression: scalar broadcast over + and *
        (array-inc! x (+ (* (row a 0) 0.5) x))
        (display (vector-ref x 0)) (display " ")
        (display (vector-ref x 1)) (newline))))
  0)
