;; A named-let functor captures the surrounding variables. Which of them it
;; may hold as a const reference depends on what its body writes, and a
;; captured function's own parameter constness has to match the real
;; function's or the two do not convert. Here read-only (mref) and writing
;; (mset!) helpers are captured by the same loop over the same arrays.
(define (mref m a b n) (vector-ref m (+ (* a n) b)))
(define (mset! m a b n v) (vector-set! m (+ (* a n) b) v))
(define (fill! dst src n)
  (let loop-a ((a 0))
    (if (< a n)
        (begin
          (let loop-b ((b 0))
            (if (< b n)
                (begin
                  (mset! dst a b n (* 2.0 (mref src a b n)))
                  (loop-b (+ b 1)))
                #f))
          (loop-a (+ a 1)))
        #f))
  0)
(define (main)
  (let* ((n 3)
         (src (make-vector 9 0.0))
         (dst (make-vector 9 0.0)))
    (do ((i 0 (+ i 1))) ((= i 9))
      (vector-set! src i (+ 1.0 i)))
    (fill! dst src n)
    (display (mref dst 0 0 n)) (display " ")
    (display (mref dst 2 2 n)) (display " ")
    (display (mref src 2 2 n))
    (newline)
    0))
