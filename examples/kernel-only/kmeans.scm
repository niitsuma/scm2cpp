;;;; k-means by Lloyd's algorithm, whole: scikit-learn's
;;;; _kmeans_single_lloyd with lloyd_iter_chunked_dense, written out in
;;;; the subset, the distances by tiled matrix products.
;;;;
;;;; Each iteration assigns every point to the centre minimising
;;;; |c|^2 - 2 x.c (scikit-learn's form: |x|^2 is the same for every
;;;; centre and left out; ties go to the lower index), the dot products
;;;; a tile of BS points against all K centres at a time, (matmul xb
;;;; (transpose centers)), the product --blas and --cublas hand to a gemm;
;;;; the new centres are the means of their points, an emptied cluster
;;;; taking the point farthest from its own centre (scikit-learn's
;;;; _relocate_empty_clusters_dense).  The fit stops when the labels
;;;; repeat (strict convergence) or the squared centre shift sums to at
;;;; most TOL, after MAXITER iterations at most; without strict
;;;; convergence the labels are recomputed against the final centres.
;;;;
;;;; X is n rows of p, CENTERS k rows of p (the start, and the result);
;;;; LABELS gets each point's centre, OUT[0] the inertia (the summed
;;;; squared distance to the assigned centres).  scikit-learn centres X
;;;; and the start on the mean of X first, and scales its tol by the
;;;; mean variance of X; the caller does both, as the package and the
;;;; benchmark do.  Returns the number of iterations.
;;;;

;; the K squared norms of the centres
(define (center-norms centers cn k p)
  (do ((c 0 (+ c 1))) ((= c k))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! acc (+ acc (* (vector-ref centers (+ (* c p) j)) (vector-ref centers (+ (* c p) j))))))
      (vector-set! cn c acc)))
  0)

;; tile[r, c] = x[s0 + r] . centers[c] for the M points from S0 (rows past
;; M zero)
(define (center-tile x xb centers tile s0 m bs n p k)
  (with-arrays ((xb (bs p)) (centers (k p)) (tile (bs k)))
    (do ((r 0 (+ r 1))) ((= r bs))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! xb (+ (* r p) j)
                     (if (< r m) (vector-ref x (+ (* (+ s0 r) p) j)) 0.0))))
    (array-set! tile (matmul xb (transpose centers)))
    0))

;; every point to its nearest centre; returns nothing, LABELS filled
(define (assign x xb centers cn tile labels bs n p k)
  (center-norms centers cn k p)
  (do ((s0 0 (+ s0 bs))) ((>= s0 n))
    (let ((m (if (< (+ s0 bs) n) bs (- n s0))))
      (center-tile x xb centers tile s0 m bs n p k)
      (do ((r 0 (+ r 1))) ((= r m))
        (let ((best 0) (bd 1e300))
          (do ((c 0 (+ c 1))) ((= c k))
            (let ((d (- (vector-ref cn c) (* 2.0 (vector-ref tile (+ (* r k) c))))))
              (if (< d bd) (begin (set! bd d) (set! best c)) 0)))
          (vector-set! labels (+ s0 r) best)))))
  0)

(define (kmeans x centers labels out maxiter tol bs n p k)
  (let ((newc (make-vector (* k p) 0.0))
        (cn (make-vector k 0.0))
        (weight (make-vector k 0.0))
        (xb (make-vector (* bs p) 0.0))
        (tile (make-vector (* bs k) 0.0))
        (lab (make-vector n 0))
        (old (make-vector n -1))
        (dist (make-vector n 0.0))
        (taken (make-vector n 0))
        (strict 0) (done 0) (it 0))
    (do () ((or (= done 1) (>= it maxiter)))
      ;; the E-step, then the means
      (assign x xb centers cn tile lab bs n p k)
      (do ((t 0 (+ t 1))) ((= t (* k p))) (vector-set! newc t 0.0))
      (do ((c 0 (+ c 1))) ((= c k)) (vector-set! weight c 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((c (vector-ref lab i)))
          (vector-set! weight c (+ (vector-ref weight c) 1.0))
          (do ((j 0 (+ j 1))) ((= j p))
            (vector-set! newc (+ (* c p) j) (+ (vector-ref newc (+ (* c p) j)) (vector-ref x (+ (* i p) j)))))))
      ;; emptied clusters take the points farthest from their centres
      (let ((nempty 0))
        (do ((c 0 (+ c 1))) ((= c k))
          (if (= (vector-ref weight c) 0.0) (set! nempty (+ nempty 1)) 0))
        (if (> nempty 0)
            (begin
              (do ((i 0 (+ i 1))) ((= i n))
                (vector-set! taken i 0)
                (let ((c (vector-ref lab i)) (acc 0.0))
                  (do ((j 0 (+ j 1))) ((= j p))
                    (let ((d (- (vector-ref x (+ (* i p) j)) (vector-ref centers (+ (* c p) j)))))
                      (set! acc (+ acc (* d d)))))
                  (vector-set! dist i acc)))
              (do ((c 0 (+ c 1))) ((= c k))
                (if (= (vector-ref weight c) 0.0)
                    (let ((far 0) (fd -1.0))
                      (do ((i 0 (+ i 1))) ((= i n))
                        (if (and (= (vector-ref taken i) 0) (> (vector-ref dist i) fd))
                            (begin (set! fd (vector-ref dist i)) (set! far i))
                            0))
                      (vector-set! taken far 1)
                      (let ((oc (vector-ref lab far)))
                        (do ((j 0 (+ j 1))) ((= j p))
                          (let ((v (vector-ref x (+ (* far p) j))))
                            (vector-set! newc (+ (* oc p) j) (- (vector-ref newc (+ (* oc p) j)) v))
                            (vector-set! newc (+ (* c p) j) v)))
                        (vector-set! weight c 1.0)
                        (vector-set! weight oc (- (vector-ref weight oc) 1.0))))
                    0)))
            0))
      ;; the means, and the squared shift of the centres
      (let ((shift 0.0))
        (do ((c 0 (+ c 1))) ((= c k))
          (do ((j 0 (+ j 1))) ((= j p))
            (let ((v (if (> (vector-ref weight c) 0.0)
                         (/ (vector-ref newc (+ (* c p) j)) (vector-ref weight c))
                         (vector-ref newc (+ (* c p) j)))))
              (let ((d (- v (vector-ref centers (+ (* c p) j)))))
                (set! shift (+ shift (* d d))))
              (vector-set! centers (+ (* c p) j) v))))
        (set! it (+ it 1))
        (let ((same 1))
          (do ((i 0 (+ i 1))) ((= i n))
            (if (not (= (vector-ref lab i) (vector-ref old i))) (set! same 0) 0))
          (if (= same 1)
              (begin (set! strict 1) (set! done 1))
              (if (<= shift tol) (set! done 1) 0)))
        (do ((i 0 (+ i 1))) ((= i n)) (vector-set! old i (vector-ref lab i)))))
    ;; without strict convergence, the labels of the final centres
    (if (= strict 0) (assign x xb centers cn tile lab bs n p k) 0)
    (let ((inertia 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((c (vector-ref lab i)))
          (vector-set! labels i (* 1.0 c))
          (do ((j 0 (+ j 1))) ((= j p))
            (let ((d (- (vector-ref x (+ (* i p) j)) (vector-ref centers (+ (* c p) j)))))
              (set! inertia (+ inertia (* d d)))))))
      (vector-set! out 0 inertia))
    it))
