;;;; The support vector machine in kernel form, hand-written: dual
;;;; coordinate descent over a kernel matrix K that is already built
;;;; (K_ij = k(x_i, x_j) for any kernel; K = X X' is the linear one),
;;;; the sweep svm-kernel.scm derives when it hoists X X' -- written
;;;; out so that a nonlinear SVM can run it on an RBF or any other K,
;;;; where no primal vector exists.
;;;;
;;;; The solver keeps c_i = sum_j K_ij y_j alpha_j, the kernel
;;;; expansion of w . x_i, rather than w itself.  Changing alpha_i by d
;;;; changes c by d y_i K[:,i]: each dual step is O(n), the kernel
;;;; matrix is never rebuilt, and the diagonal K_ii is the step's
;;;; denominator.  ALPHA is the working state (warm-started if given),
;;;; C holds the expansion and is filled from ALPHA at entry, so a
;;;; cold start passes zeros for both.  TOL and ITERS end a fit as in
;;;; svm-kernel.scm: when a sweep's projected gradients span no more
;;;; than TOL, or after ITERS sweeps.
;;;;

(define (svm-dual k y alpha c cost iters tol n)
  (with-arrays ((k (n n)) (y (n)) (alpha (n)) (c (n)))
  ;; c = K (alpha . y)
  (do ((i 0 (+ i 1))) ((= i n))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j n))
        (set! acc (+ acc (* (vector-ref k (+ (* i n) j))
                            (* (vector-ref alpha j) (vector-ref y j))))))
      (vector-set! c i acc)))
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1)))
        ((or (= sweep iters) (= stop 1)))
      (let ((pgmax -1e300) (pgmin 1e300))
        (do ((i 0 (+ i 1)))
            ((= i n))
          (let ((old (vector-ref alpha i))
                (kii (vector-ref k (+ (* i n) i))))
            (let ((g (- (* (vector-ref y i) (vector-ref c i)) 1.0))
                  (pg 0.0))
              ;; the projected gradient, and its span over the sweep
              ;; for the stop test, as in svm-kernel.scm
              (if (= old 0.0)
                  (if (< g 0.0) (set! pg g) 0)
                  (if (= old cost)
                      (if (> g 0.0) (set! pg g) 0)
                      (set! pg g)))
              (if (> pg pgmax) (set! pgmax pg) 0)
              (if (< pg pgmin) (set! pgmin pg) 0)
              (let ((step (- old (/ g kii))))
                (let ((anew (if (< step 0.0) 0.0 (if (> step cost) cost step))))
                  (vector-set! alpha i anew)
                  (if (not (= anew old))
                      (let ((d (* (- anew old) (vector-ref y i))))
                        (do ((j 0 (+ j 1)))
                            ((= j n))
                          (vector-set! c j
                                       (+ (vector-ref c j)
                                          (* d (vector-ref k (+ (* j n) i)))))))
                      #f))))))
        (if (<= (- pgmax pgmin) tol) (set! stop 1) 0))))
  0))
