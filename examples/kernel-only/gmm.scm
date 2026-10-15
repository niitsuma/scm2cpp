;;;; The Gaussian mixture by EM, full covariances, whole: scikit-learn's
;;;; GaussianMixture(covariance_type="full") -- BaseMixture.fit_predict
;;;; with _estimate_gaussian_parameters, _compute_precision_cholesky and
;;;; _estimate_log_gaussian_prob -- written out in the subset.
;;;;
;;;; RESP is the start's responsibilities (n x K; scikit-learn's
;;;; init_params="kmeans" makes them the one-hot labels of KMeans, which
;;;; the caller runs).  From them the M step: nk = the column sums plus
;;;; 10 eps, the means resp'X / nk (a product), each covariance
;;;; diff' diag(resp_k) diff / nk + REG I (a product), its Cholesky factor
;;;; L and the precision factor U = L^-T, the weights nk / n at the start
;;;; and nk / sum nk after.  The E step: for each component
;;;; y = X U - mu U (a product), log N = -(p log 2pi + |y|^2) / 2 +
;;;; sum log diag U; with the log weights, the log-sum-exp per point is
;;;; log p(x), its mean the lower bound, and resp = exp(wlp - lse).  The
;;;; fit stops when the bound moves by less than TOL, or after MAXITER
;;;; iterations; a last E step gives LABELS (the argmax).
;;;;
;;;; X is n rows of p.  WEIGHTS (K), MEANS (K x p), PREC (K x p x p, U
;;;; per component) get the result; OUT[0] the lower bound, OUT[1] 1.0
;;;; when converged.  Returns n_iter_.
;;;;
;;;;[ja] EM による混合ガウス(full 共分散)全体: scikit-learn の
;;;;[ja] GaussianMixture(covariance_type="full") をそのままサブセットで
;;;;[ja] 書いたもの。初期の責務 RESP は呼び出し側(KMeans のラベル)。M ステップは
;;;;[ja] 平均と共分散を行列積で作り、コレスキー因子 L から精度因子 U = L^-T。
;;;;[ja] E ステップは y = X U - mu U(行列積)から対数尤度、log-sum-exp、
;;;;[ja] 下界。下界の変化が TOL 未満か MAXITER で終了し、最後の E ステップで
;;;;[ja] ラベル。

;; the M step from RESP: weights, means, precision factors.  NORM 1
;; divides the weights by n (the start), 0 by their sum.
(define (gmm-mstep x resp weights means prec dw cov l u reg norm n p kc)
  (let ((tot 0.0))
    ;; nk, row by row
    (do ((c 0 (+ c 1))) ((= c kc)) (vector-set! weights c 0.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((c 0 (+ c 1))) ((= c kc))
        (vector-set! weights c (+ (vector-ref weights c) (vector-ref resp (+ (* i kc) c))))))
    (do ((c 0 (+ c 1))) ((= c kc))
      (vector-set! weights c (+ (vector-ref weights c) (* 10.0 2.220446049250313e-16)))
      (set! tot (+ tot (vector-ref weights c))))
    (with-arrays ((x (n p)) (resp (n kc)) (means (kc p)))
      (array-set! means (matmul (transpose resp) x)))
    (do ((c 0 (+ c 1))) ((= c kc))
      (let ((nk (vector-ref weights c)))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! means (+ (* c p) j) (/ (vector-ref means (+ (* c p) j)) nk)))
        ;; diff and resp_k diff, then diff' diag(resp_k) diff
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((r (vector-ref resp (+ (* i kc) c))))
            (do ((j 0 (+ j 1))) ((= j p))
              (let ((dv (- (vector-ref x (+ (* i p) j)) (vector-ref means (+ (* c p) j)))))
                (vector-set! u (+ (* i p) j) dv)
                (vector-set! dw (+ (* i p) j) (* r dv))))))
        (with-arrays ((dw (n p)) (u (n p)) (cov (p p)))
          (array-set! cov (matmul (transpose dw) u)))
        (do ((t 0 (+ t 1))) ((= t (* p p)))
          (vector-set! cov t (/ (vector-ref cov t) nk)))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! cov (+ (* j p) j) (+ (vector-ref cov (+ (* j p) j)) reg)))
        ;; L L' = cov, then U = L^-T into PREC's block c
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((s (vector-ref cov (+ (* j p) j))))
            (do ((m 0 (+ m 1))) ((= m j))
              (set! s (- s (* (vector-ref l (+ (* j p) m)) (vector-ref l (+ (* j p) m))))))
            (vector-set! l (+ (* j p) j) (sqrt s))
            (do ((i (+ j 1) (+ i 1))) ((>= i p))
              (let ((t2 (vector-ref cov (+ (* i p) j))))
                (do ((m 0 (+ m 1))) ((= m j))
                  (set! t2 (- t2 (* (vector-ref l (+ (* i p) m)) (vector-ref l (+ (* j p) m))))))
                (vector-set! l (+ (* i p) j) (/ t2 (vector-ref l (+ (* j p) j))))))))
        (do ((t 0 (+ t 1))) ((= t (* p p))) (vector-set! prec (+ (* c (* p p)) t) 0.0))
        ;; column e of L^-1 by forward substitution is row e of U
        (do ((e 0 (+ e 1))) ((= e p))
          (do ((i e (+ i 1))) ((= i p))
            (let ((t3 (if (= i e) 1.0 0.0)))
              (do ((m e (+ m 1))) ((= m i))
                (set! t3 (- t3 (* (vector-ref l (+ (* i p) m)) (vector-ref prec (+ (* c (* p p)) (+ (* e p) m)))))))
              (vector-set! prec (+ (* c (* p p)) (+ (* e p) i)) (/ t3 (vector-ref l (+ (* i p) i)))))))))
    (do ((c 0 (+ c 1))) ((= c kc))
      (vector-set! weights c (/ (vector-ref weights c) (if (= norm 1) (exact->inexact n) tot))))
    0))

;; the E step: RESP gets the responsibilities, the lower bound returned;
;; WLP (n x K) is scratch
(define (gmm-estep x resp weights means prec wlp y u mu n p kc)
  (do ((c 0 (+ c 1))) ((= c kc))
    (let ((logdet 0.0) (lw (log (vector-ref weights c))))
      (do ((t 0 (+ t 1))) ((= t (* p p)))
        (vector-set! u t (vector-ref prec (+ (* c (* p p)) t))))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! logdet (+ logdet (log (vector-ref u (+ (* j p) j)))))
        (let ((acc 0.0))
          (do ((m 0 (+ m 1))) ((= m p))
            (set! acc (+ acc (* (vector-ref means (+ (* c p) m)) (vector-ref u (+ (* m p) j))))))
          (vector-set! mu j acc)))
      (with-arrays ((x (n p)) (u (p p)) (y (n p)))
        (array-set! y (matmul x u)))
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((sq 0.0))
          (do ((j 0 (+ j 1))) ((= j p))
            (let ((v (- (vector-ref y (+ (* i p) j)) (vector-ref mu j))))
              (set! sq (+ sq (* v v)))))
          (vector-set! wlp (+ (* i kc) c)
                       (+ (+ (* -0.5 (+ (* (exact->inexact p) 1.8378770664093453) sq)) logdet) lw))))))
  (let ((lb 0.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((amax (vector-ref wlp (* i kc))) (se 0.0))
        (do ((c 1 (+ c 1))) ((= c kc))
          (if (> (vector-ref wlp (+ (* i kc) c)) amax) (set! amax (vector-ref wlp (+ (* i kc) c))) 0))
        (do ((c 0 (+ c 1))) ((= c kc))
          (set! se (+ se (exp (- (vector-ref wlp (+ (* i kc) c)) amax)))))
        (let ((lse (+ (log se) amax)))
          (set! lb (+ lb lse))
          (do ((c 0 (+ c 1))) ((= c kc))
            (vector-set! resp (+ (* i kc) c) (exp (- (vector-ref wlp (+ (* i kc) c)) lse)))))))
    (/ lb (exact->inexact n))))

(define (gmm-abs a) (if (< a 0.0) (- 0.0 a) a))

(define (gmm x resp weights means prec labels out maxiter tol reg n p kc)
  (let ((dw (make-vector (* n p) 0.0))
        (y (make-vector (* n p) 0.0))
        (wlp (make-vector (* n kc) 0.0))
        (cov (make-vector (* p p) 0.0))
        (l (make-vector (* p p) 0.0))
        (u (make-vector (* p p) 0.0))
        (mu (make-vector p 0.0))
        (lb -1e300) (it 0) (conv 0) (done 0))
    (gmm-mstep x resp weights means prec dw cov l y reg 1 n p kc)
    (do () ((or (= done 1) (>= it maxiter)))
      (let ((prev lb))
        (set! lb (gmm-estep x resp weights means prec wlp y u mu n p kc))
        (gmm-mstep x resp weights means prec dw cov l y reg 0 n p kc)
        (set! it (+ it 1))
        (if (and (> it 1) (< (gmm-abs (- lb prev)) tol))
            (begin (set! conv 1) (set! done 1))
            0)))
    ;; the labels of the last parameters
    (gmm-estep x resp weights means prec wlp y u mu n p kc)
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((best 0) (bv (vector-ref resp (* i kc))))
        (do ((c 1 (+ c 1))) ((= c kc))
          (if (> (vector-ref resp (+ (* i kc) c)) bv) (begin (set! bv (vector-ref resp (+ (* i kc) c))) (set! best c)) 0))
        (vector-set! labels i (exact->inexact best))))
    (vector-set! out 0 lb)
    (vector-set! out 1 (exact->inexact conv))
    it))

