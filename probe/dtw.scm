;; dtw.scm on a series of 8 points and one of 9.  Translated plainly; the
;; oracle runs the same program.  Each line is what the dtw of the darts
;; library (darts 0.48.1) gives on the same data:
;;
;;   no window: the distance 1 and the path 0,0 0,1 1,2 2,3 3,4 3,5 4,6
;;     5,7 6,8 7,8;
;;   the window of SakoeChiba(2), 37 cells, packed: the same distance
;;     and path;
;;   the two series read as 4 points of 2 components (the last value of
;;     the second left out): the distance 6, the path 0,0 0,1 1,2 2,3 3,3;
;;   that path as the half-length path of the multi-grid solver, the
;;     window around it at radius 0 (35 cells, row 7 without column 9:
;;     the distance in it is 2, the path ends 6,7 7,8) and at radius 1
;;     (50 cells: 1 again, the first path).
;;
;; A path is printed from its start; the kernel writes it from its end.
(include "../examples/kernel-only/dtw.scm")

(define (show-path path k)
  (do ((t (- k 1) (- t 1))) ((< t 0))
    (display (vector-ref path (* 2 t))) (display ",")
    (display (vector-ref path (+ (* 2 t) 1))) (display " "))
  (newline))

(define (show-window rng n)
  (do ((i 0 (+ i 1))) ((> i n))
    (display (vector-ref rng (* 2 i))) (display "-")
    (display (vector-ref rng (+ (* 2 i) 1))) (display " "))
  (newline))

;; OFF[i] = where row i of the packed matrix starts; returns the cells
(define (offsets rng off n)
  (vector-set! off 0 0)
  (do ((i 0 (+ i 1))) ((> i n))
    (vector-set! off (+ i 1)
                 (+ (vector-ref off i)
                    (max 0 (- (vector-ref rng (+ (* 2 i) 1)) (vector-ref rng (* 2 i)))))))
  (vector-ref off (+ n 1)))

(define (main)
  (let ((n 8) (m 9) (inf 1e300)
        (x (vector 0.0 1.0 2.0 3.0 2.0 1.0 0.0 1.0))
        (y (vector 0.0 0.0 1.0 2.0 3.0 3.0 2.0 1.0 0.0))
        (whole (make-vector 90 0.0))
        (packed (make-vector 90 0.0))
        (rng (make-vector 18 0))
        (band (vector 0 1  1 4  1 5  1 6  2 7  3 8  4 9  5 10  6 10))
        (off (make-vector 10 0))
        (path (make-vector 34 0))
        (low (make-vector 34 0)))    ; as long as PATH: one type for both
    ;; no window: every row the columns 1 .. m
    (do ((i 1 (+ i 1))) ((> i n))
      (vector-set! rng (* 2 i) 1)
      (vector-set! rng (+ (* 2 i) 1) (+ m 1)))
    (vector-set! rng 0 0)
    (vector-set! rng 1 1)
    (display (dtw-cost x y rng whole n m 1 inf)) (newline)
    (show-path path (dtw-path whole path n m))
    ;; a band, packed
    (display (offsets band off n)) (display " ")
    (display (dtw-cost-packed x y band off packed n m 1 inf)) (newline)
    (show-path path (dtw-path-packed packed band off path n m inf))
    ;; 4 points of 2 components each
    (do ((i 1 (+ i 1))) ((> i 4))
      (vector-set! rng (* 2 i) 1)
      (vector-set! rng (+ (* 2 i) 1) 5))
    (display (dtw-cost x y rng whole 4 4 2 inf)) (newline)
    (let ((kp (dtw-path whole low 4 4)))
      (show-path low kp)
      ;; the window around that path on the grid twice as fine
      (do ((radius 0 (+ radius 1))) ((= radius 2))
        (display (dtw-expand-window low kp rng n m radius)) (display " ")
        (show-window rng n)
        (display (offsets rng off n)) (display " ")
        (display (dtw-cost-packed x y rng off packed n m 1 inf)) (newline)
        (show-path path (dtw-path-packed packed rng off path n m inf))))
    0))
