;; dbscan.scm on twelve points in the plane: two dense groups, a bridge
;; point that is a border of both, and noise.  Translated plainly; the
;; oracle runs the same program.  Prints the cluster count, the labels
;; and the core flags -- scikit-learn's DBSCAN(eps=1.5, min_samples=4)
;; gives the same labels on these points: two unit squares of core
;; points, the point (2, -0.9) within eps of one corner of each but not
;; core itself, so a border of both that goes to the first cluster.  Tiles of 4 x 5, so the row
;; and column blocks both end short.
(include "../examples/kernel-only/dbscan.scm")

(define (main)
  (let ((n 12) (p 2)
        (x (vector 0.0 0.0  1.0 0.0  0.0 1.0  1.0 1.0
                   2.0 -0.9
                   3.0 0.0  4.0 0.0  3.0 1.0  4.0 1.0
                   8.0 8.0  -5.0 3.0  10.0 -4.0))
        (labels (make-vector 12 0.0))
        (core (make-vector 12 0.0)))
    (let ((k (dbscan x labels core 1.5 4 4 5 n p)))
      (display k) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref labels i)) (display " "))
      (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref core i)) (display " "))
      (newline))
    0))
