;;;; Stochastic gradient descent for a linear model, whole: scikit-learn's
;;;; _plain_sgd for the L2 penalty, written out in the subset, with the
;;;; two default set-ups -- SGDClassifier (the hinge loss, the "optimal"
;;;; learning rate) and SGDRegressor (the squared error, "invscaling").
;;;;
;;;; One epoch visits the points in order (scikit-learn's shuffle=False;
;;;; its shuffling draws from its own xorshift generator, which the subset
;;;; has no bit operations to reproduce).  At each point: the prediction
;;;; p = w.x + b, the step size eta (1/(alpha (t0 + t - 1)) for
;;;; "optimal", ETA0 / t^POWERT for "invscaling"), the loss and its
;;;; gradient at (y, p), the shrinkage of w by 1 - eta alpha, and the step
;;;; along x by -eta times the gradient (clipped at 1e12), the intercept
;;;; moving by the same step.  w is held as a scale times a vector, as in
;;;; scikit-learn's WeightVector, so the shrinkage costs O(1); the scale
;;;; is multiplied back into the vector when it falls below 1e-9.  An
;;;; epoch's mean objective -- loss plus alpha |w|^2 / 2 at each point --
;;;; that fails to fall below the best by TOL counts towards
;;;; NITERNOCHANGE; that many in a row end the fit, as do MAXITER epochs.
;;;;
;;;; LOSS is 0 for the hinge, 1 for the squared error; LR is 0 for
;;;; "optimal", 1 for "invscaling".  X is n rows of p.  W comes back with
;;;; the weights and OUT[0] with the intercept (FITINT 1 fits it).
;;;; Returns the number of epochs.
;;;;
;;;;[ja] 線形モデルの確率的勾配降下全体: scikit-learn の _plain_sgd(L2 正則化)
;;;;[ja] をそのままサブセットで書いたもの。SGDClassifier の既定(hinge 損失、
;;;;[ja] 学習率 "optimal")と SGDRegressor の既定(二乗誤差、"invscaling")。
;;;;[ja] 点は順に回る(scikit-learn の shuffle=False)。w は scikit-learn の
;;;;[ja] WeightVector と同じくスケールとベクトルの積で持ち、縮小を O(1) にする。
;;;;[ja] エポックの平均目的関数が最良から TOL 以上下がらない回数が NITERNOCHANGE
;;;;[ja] 続くか、MAXITER エポックで終了。

;; the loss and its gradient at (y, p)
(define (sgd-loss loss y p)
  (if (= loss 0)
      (let ((z (* p y))) (if (<= z 1.0) (- 1.0 z) 0.0))
      (* 0.5 (* (- p y) (- p y)))))

(define (sgd-grad loss y p)
  (if (= loss 0)
      (let ((z (* p y))) (if (<= z 1.0) (- 0.0 y) 0.0))
      (- p y)))

(define (sgd x y w out loss lr alpha eta0 powert maxiter tol niternochange fitint n p)
  (let ((wscale 1.0) (sqnorm 0.0) (b 0.0) (t 1.0)
        (optinit 0.0) (best 1e300) (noimp 0) (epoch 0) (done 0))
    (do ((j 0 (+ j 1))) ((= j p))
      (set! sqnorm (+ sqnorm (* (vector-ref w j) (vector-ref w j)))))
    ;; the "optimal" schedule's offset: typw = sqrt(1 / sqrt(alpha))
    (if (= lr 0)
        (let ((typw (sqrt (/ 1.0 (sqrt alpha)))))
          (let ((g (sgd-grad loss 1.0 (- 0.0 typw))))
            (let ((eta00 (/ typw (if (> g 1.0) g 1.0))))
              (set! optinit (/ 1.0 (* eta00 alpha))))))
        0)
    (do () ((or (= done 1) (>= epoch maxiter)))
      (let ((objsum 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((dot 0.0))
            (do ((j 0 (+ j 1))) ((= j p))
              (set! dot (+ dot (* (vector-ref x (+ (* i p) j)) (vector-ref w j)))))
            (let ((pr (+ (* wscale dot) b))
                  (yi (vector-ref y i)))
              (let ((eta (if (= lr 0)
                             (/ 1.0 (* alpha (- (+ optinit t) 1.0)))
                             (/ (* 1.0 eta0) (expt t (* 1.0 powert))))))
                (set! objsum (+ objsum (+ (sgd-loss loss yi pr) (* alpha (* 0.5 sqnorm)))))
                (let ((dl (sgd-grad loss yi pr)))
                  (let ((dlc (if (< dl -1e12) -1e12 (if (> dl 1e12) 1e12 dl))))
                    (let ((update (* (- 0.0 eta) dlc)))
                      ;; the L2 shrinkage, by the scale
                      (let ((c (- 1.0 (* eta alpha))))
                        (let ((cc (if (> c 0.0) c 0.0)))
                          (set! wscale (* wscale cc))
                          (set! sqnorm (* sqnorm (* cc cc)))
                          (if (< wscale 1e-9)
                              (begin
                                (do ((j 0 (+ j 1))) ((= j p))
                                  (vector-set! w j (* (vector-ref w j) wscale)))
                                (set! wscale 1.0))
                              0)))
                      ;; the step along x
                      (if (not (= update 0.0))
                          (let ((acc 0.0))
                            (do ((j 0 (+ j 1))) ((= j p))
                              (let ((v (+ (vector-ref w j) (* (vector-ref x (+ (* i p) j)) (/ update wscale)))))
                                (vector-set! w j v)
                                (set! acc (+ acc (* v v)))))
                            (set! sqnorm (* acc (* wscale wscale))))
                          0)
                      (if (and (= fitint 1) (not (= update 0.0)))
                          (set! b (+ b update))
                          0))))))
            (set! t (+ t 1.0))))
        (set! epoch (+ epoch 1))
        ;; the stopping rule on the epoch's mean objective
        (let ((mean (/ objsum (* 1.0 n))))
          (if (> mean (- best tol)) (set! noimp (+ noimp 1)) (set! noimp 0))
          (if (< mean best) (set! best mean) 0))
        (if (>= noimp niternochange) (set! done 1) 0)))
    ;; the scale into the weights
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! w j (* (vector-ref w j) wscale)))
    (vector-set! out 0 b)
    epoch))
