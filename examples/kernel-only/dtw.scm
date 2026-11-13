;;;; Dynamic time warping: the cost matrix, the warp path and the window
;;;; of the multi-grid solver.
;;;;
;;;; X is N points of D components by rows, Y is M points.  The cost of
;;;; matching x[i-1] with y[j-1] is the sum of the absolute differences
;;;; of their components, and
;;;;
;;;;   C[i,j] = cost(i,j) + min(C[i-1,j], C[i,j-1], C[i-1,j-1]),   C[0,0] = 0,
;;;;
;;;; over the cells of a window: row i takes the columns RNG[2i] ..
;;;; RNG[2i+1]-1 (row 0 is the cell (0,0) alone, a row i >= 1 starts at
;;;; column 1 or later), and a cell outside the window is INF.  C[N,M] is
;;;; the distance.  These are the cells, the order and the arithmetic of
;;;; the dtw of the darts library (darts.dataprocessing.dtw), which fills
;;;; them one at a time in Python; bench/darts-dtw-compare.py puts the
;;;; functions below in their place and compares.
;;;;
;;;; Two layouts of C.  Whole: (N+1) x (M+1) by rows, the cells outside
;;;; the window filled with INF.  Packed: the cells of the window only,
;;;; row i at OFF[i] (OFF[i+1] - OFF[i] is the length of row i), for a
;;;; narrow window over long series.

;; the sum of |x[i,k] - y[j,k]| over the D components
(define (dtw-dist x y i j d)
  (let ((s 0.0) (xo (* i d)) (yo (* j d)))
    (do ((k 0 (+ k 1))) ((= k d))
      (let ((v (- (vector-ref x (+ xo k)) (vector-ref y (+ yo k)))))
        (set! s (+ s (if (< v 0.0) (- 0.0 v) v)))))
    s))

;; COST, whole, is filled; returns the distance C[N,M].
(define (dtw-cost x y rng cost n m d inf)
  (let ((w (+ m 1)))
    (do ((t 0 (+ t 1))) ((= t (* (+ n 1) w)))
      (vector-set! cost t inf))
    (vector-set! cost 0 0.0)
    (do ((i 1 (+ i 1))) ((> i n))
      (let ((row (* i w))
            (up (* (- i 1) w))
            (end (vector-ref rng (+ (* 2 i) 1))))
        (do ((j (vector-ref rng (* 2 i)) (+ j 1))) ((>= j end))
          (let ((a (vector-ref cost (+ up j)))
                (b (vector-ref cost (+ row (- j 1))))
                (c (vector-ref cost (+ up (- j 1)))))
            (vector-set! cost (+ row j)
                         (+ (dtw-dist x y (- i 1) (- j 1) d)
                            (min a (min b c))))))))
    (vector-ref cost (+ (* n w) m))))

;; the cell (i,j) of a packed COST, INF outside the window
(define (dtw-cell cost rng off i j inf)
  (if (and (>= j (vector-ref rng (* 2 i)))
           (< j (vector-ref rng (+ (* 2 i) 1))))
      (vector-ref cost (+ (vector-ref off i) (- j (vector-ref rng (* 2 i)))))
      inf))

;; COST, packed (OFF[N+1] cells), is filled; returns the distance.
(define (dtw-cost-packed x y rng off cost n m d inf)
  (vector-set! cost 0 0.0)
  (do ((i 1 (+ i 1))) ((> i n))
    (let ((start (vector-ref rng (* 2 i)))
          (end (vector-ref rng (+ (* 2 i) 1)))
          (o (vector-ref off i)))
      (do ((j start (+ j 1))) ((>= j end))
        (let ((a (dtw-cell cost rng off (- i 1) j inf))
              (b (if (> j start) (vector-ref cost (+ o (- (- j 1) start))) inf))
              (c (dtw-cell cost rng off (- i 1) (- j 1) inf)))
          (vector-set! cost (+ o (- j start))
                       (+ (dtw-dist x y (- i 1) (- j 1) d)
                          (min a (min b c))))))))
  (dtw-cell cost rng off n m inf))

;; The warp path of a whole COST, from the end: PATH (2 (N + M) entries)
;; gets the pairs (i-1, j-1) of the cells from (N,M) back to (1,1), each
;; step to the first smallest of the diagonal, the row above and the
;; column before.  Returns the number of pairs.
(define (dtw-path cost path n m)
  (let ((w (+ m 1)) (i n) (j m) (k 0))
    (do ((z 0 0)) ((and (= i 0) (= j 0)))
      (vector-set! path (* 2 k) (- i 1))
      (vector-set! path (+ (* 2 k) 1) (- j 1))
      (set! k (+ k 1))
      (if (= i 0)
          (set! j (- j 1))
          (if (= j 0)
              (set! i (- i 1))
              (let ((cd (vector-ref cost (+ (* (- i 1) w) (- j 1))))
                    (cu (vector-ref cost (+ (* (- i 1) w) j)))
                    (cl (vector-ref cost (+ (* i w) (- j 1)))))
                (if (and (<= cd cu) (<= cd cl))
                    (begin (set! i (- i 1)) (set! j (- j 1)))
                    (if (<= cu cl)
                        (set! i (- i 1))
                        (set! j (- j 1))))))))
    k))

;; the same of a packed COST
(define (dtw-path-packed cost rng off path n m inf)
  (let ((i n) (j m) (k 0))
    (do ((z 0 0)) ((and (= i 0) (= j 0)))
      (vector-set! path (* 2 k) (- i 1))
      (vector-set! path (+ (* 2 k) 1) (- j 1))
      (set! k (+ k 1))
      (if (= i 0)
          (set! j (- j 1))
          (if (= j 0)
              (set! i (- i 1))
              (let ((cd (dtw-cell cost rng off (- i 1) (- j 1) inf))
                    (cu (dtw-cell cost rng off (- i 1) j inf))
                    (cl (dtw-cell cost rng off i (- j 1) inf)))
                (if (and (<= cd cu) (<= cd cl))
                    (begin (set! i (- i 1)) (set! j (- j 1)))
                    (if (<= cu cl)
                        (set! i (- i 1))
                        (set! j (- j 1))))))))
    k))

;; The window of the next finer grid around a path: LOW is the path of
;; the series at half the length (KP pairs, in any order), and every
;; cell (i,j) of it becomes the cells 2i+1 .. 2i+3 by 2j+1 .. 2j+3 less
;; two corners, widened by RADIUS both ways.  RNG (2 (N + 1) entries)
;; gets the window; returns its number of cells.
(define (dtw-expand-window low kp rng n m radius)
  (do ((i 0 (+ i 1))) ((> i n))
    (vector-set! rng (* 2 i) m)
    (vector-set! rng (+ (* 2 i) 1) 0))
  (vector-set! rng 0 0)
  (vector-set! rng 1 1)
  (do ((t 0 (+ t 1))) ((= t kp))
    (let ((i (vector-ref low (* 2 t)))
          (j (vector-ref low (+ (* 2 t) 1))))
      (do ((q 0 (+ q 1))) ((= q 3))
        (let ((column (+ (+ q (* 2 i)) 1))
              (s0 (if (= q 2) 1 0))
              (e0 (if (= q 1) 3 2)))
          (let ((start (max 1 (min (+ m 1) (- (+ s0 (* 2 j)) radius))))
                (end (max 1 (min (+ m 1) (+ (+ (+ e0 (* 2 j)) 1) radius))))
                (kc (min (+ radius 1) (min column (+ (- n column) 1)))))
            (do ((k 0 (+ k 1))) ((>= k kc))
              (let ((c (- column k)))
                (if (< start (vector-ref rng (* 2 c)))
                    (vector-set! rng (* 2 c) start)
                    0)
                (if (> end (vector-ref rng (+ (* 2 c) 1)))
                    (vector-set! rng (+ (* 2 c) 1) end)
                    0))))))))
  (let ((cells 0))
    (do ((i 0 (+ i 1))) ((> i n))
      (let ((len (- (vector-ref rng (+ (* 2 i) 1)) (vector-ref rng (* 2 i)))))
        (if (> len 0) (set! cells (+ cells len)) 0)))
    cells))
