;;;; Non-negative matrix factorization by coordinate descent, written the
;;;; plain way: scikit-learn's NMF(solver="cd") -- the iteration of
;;;; _fit_coordinate_descent and _update_cdnmf_fast, Frobenius loss, no
;;;; regularization, no shuffling -- with the residual kept instead of
;;;; the Gram matrices.
;;;;
;;;;   min_{W >= 0, H >= 0}  1/2 ||X - W H||^2
;;;;
;;;; One half step, NMF-HALF, updates W (n by k) with H fixed, given as
;;;; HT (p by k, H transposed, as scikit-learn holds it): the residual
;;;; R = X - W HT' is formed, and each coordinate W[i,t], component t
;;;; outer and row i inner, steps to max(0, W[i,t] - grad / hess) with
;;;; grad = -R[i,:] . HT[:,t] and hess = |HT[:,t]|^2, the row of R moving
;;;; along the column of HT.  The other half step is the same function
;;;; on the transposes (X', HT, W), as scikit-learn calls it.  Returns
;;;; the summed projected-gradient violation of the half step.
;;;;
;;;; R is the scratch the derivation finds: decremented by a scaled
;;;; column of HT, read only in dot products against columns of HT.  So
;;;; --derive memoises R HT (n by k) over the hoisted HT'HT (k by k) and
;;;; folds the norms into its diagonal -- the XHt and HHt that
;;;; scikit-learn's _update_coordinate_descent builds by hand -- under
;;;; (if (< k p) ..).
;;;;
;;;; NMF drives it: ITERS iterations of the two half steps, stopping when
;;;; the violation falls to TOL times the first iteration's, as
;;;; scikit-learn's.  X is n rows of p; XT is X transposed (p rows of n);
;;;; W (n by k) and HT (p by k) are the starting point and come back
;;;; fitted.  Returns the number of iterations.  R is local to the half
;;;; step and nothing reads it after the sweep, so the derived form does
;;;; not restore it.
;;;;

(define (nmf-half x w ht n p k)
  (let ((r (make-vector (* n p) 0.0)))
  (with-arrays ((x (n p)) (w (n k)) (ht (p k)) (r (n p)))
  ;; R = X - W HT', in the algebra's own forms so that --blas makes the
  ;; product a gemm (the sweep below stays plain loops)
  (array-set! r x)
  (array-dec! r (matmul w (transpose ht)))
  (let ((violation 0.0))
    (do ((t 0 (+ t 1))) ((= t k))
      ;; the Hessian of component t: |HT[:,t]|^2
      (let ((hess 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (set! hess (+ hess (* (vector-ref ht (+ (* j k) t))
                                (vector-ref ht (+ (* j k) t))))))
        (do ((i 0 (+ i 1))) ((= i n))
          ;; grad = -R[i,:] . HT[:,t]: the loop --derive replaces by a
          ;; read of the memo
          (let ((grad 0.0)
                (old (vector-ref w (+ (* i k) t))))
            (do ((j 0 (+ j 1))) ((= j p))
              (set! grad (- grad (* (vector-ref r (+ (* i p) j))
                                    (vector-ref ht (+ (* j k) t))))))
            ;; the projected gradient and the violation
            (let ((pg (if (= old 0.0) (if (< grad 0.0) grad 0.0) grad)))
              (set! violation (+ violation (if (< pg 0.0) (- 0.0 pg) pg))))
            (if (not (= hess 0.0))
                (let ((wnew (- old (/ grad hess))))
                  (let ((wc (if (< wnew 0.0) 0.0 wnew)))
                    (vector-set! w (+ (* i k) t) wc)
                    ;; R[i,:] -= (wc - old) HT[:,t]
                    (if (not (= wc old))
                        (do ((j 0 (+ j 1))) ((= j p))
                          (vector-set! r (+ (* i p) j)
                                       (- (vector-ref r (+ (* i p) j))
                                          (* (vector-ref ht (+ (* j k) t)) (- wc old)))))
                        #f)))
                #f)))))
    violation))))

(define (nmf x xt w ht iters tol n p k)
  (let ((vinit 0.0) (stop 0) (it 0))
    (do () ((or (= stop 1) (>= it iters)))
      (set! it (+ it 1))
      (let ((v (+ (nmf-half x w ht n p k)
                  (nmf-half xt ht w p n k))))
        (if (= it 1) (set! vinit v) 0)
        (if (or (= vinit 0.0) (<= (/ v vinit) tol)) (set! stop 1) 0)))
    it))
