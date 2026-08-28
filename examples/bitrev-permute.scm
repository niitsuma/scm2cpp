;; The bit-reversal permutation two ways.
;;
;; fft's l3 loop swaps elements in bit-reversed order while threading an
;; index j from one iteration to the next -- correct, and inherently
;; sequential.  The same permutation is a gather: build the bit-reversed
;; index table br once by doubling -- br over 2n is br over n, doubled,
;; with the odd half offset -- and then a[i] takes a[br[i]], every
;; iteration independent of every other.  This program runs both on the
;; same data and prints both results, which must agree; the gather is
;; the shape -P omp can parallelise, the swap loop is not.
(define n 16)
(define (fill! v)
  (do ((i 0 (+ i 1))) ((= i n))
    (vector-set! v i (* 1.0 (+ (* i i) 3)))))

(define (bitrev-swap! a)
  ;; the classical in-place version, j threaded across iterations
  (let ((j 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (if (< i j)
          (let ((t (vector-ref a i)))
            (vector-set! a i (vector-ref a j))
            (vector-set! a j t))
          0)
      (let ((k (quotient n 2)))
        (let grind ()
          (if (and (>= k 1) (>= j k))
              (begin (set! j (- j k))
                     (set! k (quotient k 2))
                     (grind))
              0))
        (set! j (+ j k))))))

(define (main)
  (let ((a (make-vector n 0.0))
        (b (make-vector n 0.0))
        (br (make-vector n 0)))
    (fill! a)
    (fill! b)
    (bitrev-swap! a)
    ;; the index table, one entry at a time: br[i] reverses the
    ;; log2(n) low bits of i.  An inner loop per entry -- O(n log n)
    ;; like the swap version -- but every entry independent, and the
    ;; table is data the gather below can consume.
    (let ((bits 0) (t 1))
      (let count ()
        (if (< t n) (begin (set! bits (+ bits 1)) (set! t (* 2 t)) (count)) 0))
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((r 0) (k i))
          (do ((b 0 (+ b 1))) ((= b bits))
            (set! r (+ (* 2 r) (remainder k 2)))
            (set! k (quotient k 2)))
          (vector-set! br i r))))
    (with-arrays ((b (n)) (br (n)))
      (array-permute! b br))
    (do ((i 0 (+ i 1))) ((= i n))
      (display (- (vector-ref a i) (vector-ref b i)))
      (display " "))
    (newline)
    (display (vector-ref a 1)) (display " ")
    (display (vector-ref b 1))
    (newline)
    0))
