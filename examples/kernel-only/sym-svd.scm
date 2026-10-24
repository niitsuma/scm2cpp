;;;; The thin singular value decomposition, for the kernels that need
;;;; one: A = U diag(S) Vt with k = min(m, n) values.  One-sided Jacobi
;;;; (Hestenes): rotate pairs of columns of A until every pair is
;;;; orthogonal, the rotations accumulated into V; the singular values
;;;; are then the column norms and U the normalised columns.  A wide A
;;;; is decomposed through its transpose.  Under --blas the call is
;;;; LAPACK's dgesdd instead (rewrite-blas.scm's lower-library-calls),
;;;; which meets the same contract; the signs of a pair (u_j, v_j) are
;;;; not determined by either, so a caller that needs them fixes them.
;;;;
;;;; A (m x n, row-major) is destroyed; S gets the k values in
;;;; decreasing order, U the m x k left vectors, VT the k x n right
;;;; ones (row-major both).  Returns the number of sweeps.
;;;;

;; One-sided Jacobi on W (r x c, r >= c, row-major): its columns become
;; orthogonal, Q (c x c) accumulates the rotations.  Returns the sweeps.
(define (svd-jacobi w q r c)
  (do ((i 0 (+ i 1))) ((= i c))
    (do ((j 0 (+ j 1))) ((= j c))
      (vector-set! q (+ (* i c) j) (if (= i j) 1.0 0.0))))
  (let ((sweeps 0) (rotated 1))
    (do () ((or (= rotated 0) (= sweeps 60)))
      (set! rotated 0)
      (set! sweeps (+ sweeps 1))
      (do ((p 0 (+ p 1))) ((= p c))
        (do ((qq (+ p 1) (+ qq 1))) ((>= qq c))
          (let ((alpha 0.0) (beta 0.0) (gamma 0.0))
            (do ((i 0 (+ i 1))) ((= i r))
              (let ((wp (vector-ref w (+ (* i c) p))) (wq (vector-ref w (+ (* i c) qq))))
                (set! alpha (+ alpha (* wp wp)))
                (set! beta (+ beta (* wq wq)))
                (set! gamma (+ gamma (* wp wq)))))
            (if (> (abs gamma) (* 1e-15 (sqrt (* alpha beta))))
                (let ((zeta (/ (- beta alpha) (* 2.0 gamma))))
                  (let ((t (/ (if (< zeta 0.0) -1.0 1.0)
                              (+ (abs zeta) (sqrt (+ 1.0 (* zeta zeta)))))))
                    (let ((cs (/ 1.0 (sqrt (+ 1.0 (* t t))))))
                      (let ((sn (* cs t)))
                        (set! rotated 1)
                        (do ((i 0 (+ i 1))) ((= i r))
                          (let ((wp (vector-ref w (+ (* i c) p))) (wq (vector-ref w (+ (* i c) qq))))
                            (vector-set! w (+ (* i c) p) (- (* cs wp) (* sn wq)))
                            (vector-set! w (+ (* i c) qq) (+ (* sn wp) (* cs wq)))))
                        (do ((i 0 (+ i 1))) ((= i c))
                          (let ((vp (vector-ref q (+ (* i c) p))) (vq (vector-ref q (+ (* i c) qq))))
                            (vector-set! q (+ (* i c) p) (- (* cs vp) (* sn vq)))
                            (vector-set! q (+ (* i c) qq) (+ (* sn vp) (* cs vq)))))))))
                0)))))
    sweeps))

;; W's columns (orthogonal) as values and unit vectors, largest first:
;; S[j] the norm of column ORD[j], L (r x c) the normalised columns in
;; that order, R (c x c) the rows of Q's transpose in that order.
(define (svd-collect w q s l rr ord r c)
  (do ((j 0 (+ j 1))) ((= j c))
    (let ((nrm 0.0))
      (do ((i 0 (+ i 1))) ((= i r))
        (set! nrm (+ nrm (* (vector-ref w (+ (* i c) j)) (vector-ref w (+ (* i c) j))))))
      (vector-set! s j (sqrt nrm))
      (vector-set! ord j j)))
  (do ((j 0 (+ j 1))) ((= j c))
    (let ((best j))
      (do ((t (+ j 1) (+ t 1))) ((>= t c))
        (if (> (vector-ref s (vector-ref ord t)) (vector-ref s (vector-ref ord best))) (set! best t) 0))
      (let ((tmp (vector-ref ord j)))
        (vector-set! ord j (vector-ref ord best))
        (vector-set! ord best tmp))))
  (let ((sv (make-vector c 0.0)))
    (do ((j 0 (+ j 1))) ((= j c))
      (let ((col (vector-ref ord j)))
        (let ((sg (vector-ref s col)))
          (vector-set! sv j sg)
          (do ((i 0 (+ i 1))) ((= i r))
            (vector-set! l (+ (* i c) j)
                         (if (> sg 0.0) (/ (vector-ref w (+ (* i c) col)) sg) 0.0)))
          (do ((i 0 (+ i 1))) ((= i c))
            (vector-set! rr (+ (* j c) i) (vector-ref q (+ (* i c) col)))))))
    (do ((j 0 (+ j 1))) ((= j c)) (vector-set! s j (vector-ref sv j))))
  0)

(define (sym-svd a u s vt m n)
  (if (>= m n)
      ;; tall: A V = U S, so U from A's columns, Vt from V
      (let ((q (make-vector (* n n) 0.0)) (ord (make-vector n 0)))
        (let ((sweeps (svd-jacobi a q m n)))
          (svd-collect a q s u vt ord m n)
          sweeps))
      ;; wide: A' = V S U', so the left vectors of A' are A's right ones
      (let ((w (make-vector (* n m) 0.0)) (q (make-vector (* m m) 0.0))
            (l (make-vector (* n m) 0.0)) (ord (make-vector m 0)))
        (do ((i 0 (+ i 1))) ((= i m))
          (do ((j 0 (+ j 1))) ((= j n))
            (vector-set! w (+ (* j m) i) (vector-ref a (+ (* i n) j)))))
        (let ((sweeps (svd-jacobi w q n m)))
          ;; l (n x m) = V, its columns the right vectors; rows of R = U'
          (svd-collect w q s l u ord n m)
          ;; u came out as U' (m x m, rows the left vectors): transpose
          (do ((i 0 (+ i 1))) ((= i m))
            (do ((j (+ i 1) (+ j 1))) ((>= j m))
              (let ((tmp (vector-ref u (+ (* i m) j))))
                (vector-set! u (+ (* i m) j) (vector-ref u (+ (* j m) i)))
                (vector-set! u (+ (* j m) i) tmp))))
          (do ((i 0 (+ i 1))) ((= i m))
            (do ((j 0 (+ j 1))) ((= j n))
              (vector-set! vt (+ (* i n) j) (vector-ref l (+ (* j m) i)))))
          sweeps))))
