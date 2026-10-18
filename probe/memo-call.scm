;; (memo-call M E KEY ...): E evaluated once per distinct key, the table
;; an ordinary (make-hash) -- in C++ scm2cpp.hpp's memo_get over an
;; unordered_map from the key's bytes.  COL-SUM sums column J of X and
;; counts its own runs in TICK; the loop asks for twelve columns of
;; three, by a scalar key, and for the rows an index set selects, by
;; (memo-range IDX K).  Prints the sums and how many times each body ran.
(define (col-sum x tick j n p)
  (vector-set! tick 0 (+ (vector-ref tick 0) 1))
  (let ((s 0.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (set! s (+ s (vector-ref x (+ (* i p) j)))))
    s))

(define (rows-sum x tick idx k p)
  (vector-set! tick 1 (+ (vector-ref tick 1) 1))
  (let ((s 0.0))
    (do ((c 0 (+ c 1))) ((= c k))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! s (+ s (vector-ref x (+ (* (vector-ref idx c) p) j))))))
    s))

(define (main)
  (let ((n 4) (p 3)
        (x (vector 1.0 2.0 3.0  4.0 5.0 6.0  7.0 8.0 9.0  10.0 11.0 12.0))
        (tick (make-vector 2 0))
        (idx (make-vector 4 0))
        (m (make-hash))
        (m2 (make-hash))
        (tot 0.0))
    (do ((t 0 (+ t 1))) ((= t 12))
      (set! tot (+ tot (memo-call m (col-sum x tick (remainder t p) n p) (remainder t p))))
      (vector-set! idx 0 (remainder t 2))
      (vector-set! idx 1 3)
      (set! tot (+ tot (memo-call m2 (rows-sum x tick idx 2 p) (memo-range idx 2)))))
    (display tot) (display " ")
    (display (vector-ref tick 0)) (display " ")
    (display (vector-ref tick 1)) (newline)
    0))
