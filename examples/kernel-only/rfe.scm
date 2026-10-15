;;;; Recursive feature elimination around ridge regression, whole:
;;;; scikit-learn's RFE(Ridge(alpha)) -- or RFE(LinearRegression()) with
;;;; ALPHA 0 -- written out in the subset over the Gram matrix.
;;;;
;;;; X is centred on its means and y on its mean (Ridge's and
;;;; LinearRegression's preprocessing); G = Xc'Xc and c = Xc'y are formed
;;;; once (products: --blas dsyrk and dgemv).  Each round fits the
;;;; supported features, (G_SS + ALPHA I) w = c_S by Cholesky -- the
;;;; normal equations Ridge's "cholesky" solver solves, and the solution
;;;; LinearRegression's lstsq finds for a full-rank set; the factor is
;;;; formed once and each dropped feature taken out of it by plane
;;;; rotations (lars.scm's cholesky-delete), so a round costs two
;;;; triangular solves -- ranks them by
;;;; w^2 in a stable ascending order (np.argsort(kind="stable")), drops
;;;; the first min(STEP, |S| - NSEL), and adds one to the ranking of
;;;; every feature already dropped.  scikit-learn refits from X every
;;;; round; here the supported block of G is taken instead, the same
;;;; numbers to rounding.  The last fit gives COEF (zero off the support).
;;;;
;;;; X is n rows of p.  SUPPORT (p, int) gets 1 for the kept features,
;;;; RANKING (p, int) scikit-learn's ranking_.  Returns the rounds.
;;;;
;;;;[ja] リッジ回帰を使う再帰的特徴削除全体: scikit-learn の
;;;;[ja] RFE(Ridge(alpha))(ALPHA 0 なら RFE(LinearRegression()))を Gram 行列の上で
;;;;[ja] そのままサブセットで書いたもの。G = Xc'Xc と c = Xc'y は一度だけ
;;;;[ja] (行列積)。各回、残っている特徴の (G_SS + ALPHA I) w = c_S を
;;;;[ja] コレスキー分解で解き(因子は一度だけ作り、落とした特徴は lars.scm の
;;;;[ja] cholesky-delete で取り除く)、w^2 の安定な昇順で min(STEP, |S| - NSEL) 個を落とす。

(include "lars.scm")
;;;;[ja] scikit-learn は毎回 X から当てはめ直す。

;; L L' = G_SS + ALPHA I over the K features IDX (row stride P)
(define (rfe-chol g idx l alpha k p)
  (do ((j 0 (+ j 1))) ((= j k))
    (let ((s (+ (vector-ref g (+ (* (vector-ref idx j) p) (vector-ref idx j))) alpha)))
      (do ((m 0 (+ m 1))) ((= m j))
        (set! s (- s (* (vector-ref l (+ (* j p) m)) (vector-ref l (+ (* j p) m))))))
      (vector-set! l (+ (* j p) j) (sqrt s))
      (do ((i (+ j 1) (+ i 1))) ((>= i k))
        (let ((t (vector-ref g (+ (* (vector-ref idx i) p) (vector-ref idx j)))))
          (do ((m 0 (+ m 1))) ((= m j))
            (set! t (- t (* (vector-ref l (+ (* i p) m)) (vector-ref l (+ (* j p) m))))))
          (vector-set! l (+ (* i p) j) (/ t (vector-ref l (+ (* j p) j))))))))
  0)

;; w from L L' w = c_S over the K features IDX
(define (rfe-solve c idx w l k p)
  (do ((i 0 (+ i 1))) ((= i k))
    (let ((t (vector-ref c (vector-ref idx i))))
      (do ((m 0 (+ m 1))) ((= m i))
        (set! t (- t (* (vector-ref l (+ (* i p) m)) (vector-ref w m)))))
      (vector-set! w i (/ t (vector-ref l (+ (* i p) i))))))
  (do ((ii 0 (+ ii 1))) ((= ii k))
    (let ((i (- (- k 1) ii)))
      (let ((t (vector-ref w i)))
        (do ((m (+ i 1) (+ m 1))) ((>= m k))
          (set! t (- t (* (vector-ref l (+ (* m p) i)) (vector-ref w m)))))
        (vector-set! w i (/ t (vector-ref l (+ (* i p) i)))))))
  0)

(define (rfe x y coef support ranking alpha nsel step n p)
  (let ((xc (make-vector (* n p) 0.0))
        (yc (make-vector n 0.0))
        (mx (make-vector p 0.0))
        (g (make-vector (* p p) 0.0))
        (c (make-vector p 0.0))
        (l (make-vector (* p p) 0.0))
        (w (make-vector p 0.0))
        (idx (make-vector p 0))
        (ord (make-vector p 0))
        (gone (make-vector p 0))
        (ym 0.0) (rounds 0) (k p))
    (do ((i 0 (+ i 1))) ((= i n))
      (set! ym (+ ym (vector-ref y i)))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! mx j (+ (vector-ref mx j) (vector-ref x (+ (* i p) j))))))
    (set! ym (/ ym (exact->inexact n)))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! mx j (/ (vector-ref mx j) (exact->inexact n))))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! yc i (- (vector-ref y i) ym))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! xc (+ (* i p) j) (- (vector-ref x (+ (* i p) j)) (vector-ref mx j)))))
    (with-arrays ((xc (n p)) (g (p p)))
      (array-set! g (matmul (transpose xc) xc)))
    (with-arrays ((xc (n p)) (yc (n)) (c (p)))
      (array-set! c (matmul (transpose xc) yc)))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! support j 1)
      (vector-set! ranking j 1)
      (vector-set! idx j j))
    (rfe-chol g idx l alpha p p)
    (do () ((<= k nsel))
      (begin
        (rfe-solve c idx w l k p)
        ;; a stable ascending order of w^2 (insertion sort)
        (do ((i 0 (+ i 1))) ((= i k))
          (let ((key (* (vector-ref w i) (vector-ref w i))) (jj (- i 1)))
            (do () ((or (< jj 0)
                        (<= (* (vector-ref w (vector-ref ord jj)) (vector-ref w (vector-ref ord jj))) key)))
              (vector-set! ord (+ jj 1) (vector-ref ord jj))
              (set! jj (- jj 1)))
            (vector-set! ord (+ jj 1) i)))
        (let ((thr (if (< step (- k nsel)) step (- k nsel))))
          (do ((r 0 (+ r 1))) ((= r thr))
            (vector-set! support (vector-ref idx (vector-ref ord r)) 0))
          ;; the dropped positions out of L, the highest first, and out of IDX
          (do ((t 0 (+ t 1))) ((= t k)) (vector-set! gone t 0))
          (do ((r 0 (+ r 1))) ((= r thr)) (vector-set! gone (vector-ref ord r) 1))
          (let ((cur k))
            (do ((tt 0 (+ tt 1))) ((= tt k))
              (let ((pos (- (- k 1) tt)))
                (if (= (vector-ref gone pos) 1)
                    (begin
                      (cholesky-delete l pos cur p)
                      (do ((u pos (+ u 1))) ((>= u (- cur 1)))
                        (vector-set! idx u (vector-ref idx (+ u 1))))
                      (set! cur (- cur 1)))
                    0))))
          (do ((j 0 (+ j 1))) ((= j p))
            (if (= (vector-ref support j) 0) (vector-set! ranking j (+ (vector-ref ranking j) 1)) 0))
          (set! k (- k thr))
          (set! rounds (+ rounds 1)))))
    ;; the last fit, on the support
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! coef j 0.0))
    (rfe-solve c idx w l k p)
    (do ((i 0 (+ i 1))) ((= i k))
      (vector-set! coef (vector-ref idx i) (vector-ref w i)))
    rounds))
