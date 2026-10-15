;;;; Stochastic gradient descent for a linear model, whole: scikit-learn's
;;;; _plain_sgd for the L2 penalty or none, written out in the subset:
;;;; SGDClassifier's defaults (the hinge loss, the "optimal" learning
;;;; rate) and SGDRegressor's (the squared error, "invscaling"),
;;;; Perceptron (the hinge at threshold 0, "constant", no penalty) and the
;;;; passive-aggressive updates ("pa1", "pa2"; the hinge, or the
;;;; epsilon-insensitive loss for regression), which scikit-learn now
;;;; spells as SGDClassifier / SGDRegressor options.
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
;;;; LOSS is 0 for the hinge, 1 for the squared error, 2 for the
;;;; perceptron's hinge (threshold 0), 3 for the epsilon-insensitive loss
;;;; (EPSILON); LR is 0 for "optimal", 1 "invscaling", 2 "constant" (ETA0),
;;;; 3 "pa1", 4 "pa2" (ETA0 the C of PA: the step min(C, loss / |x|^2) or
;;;; loss / (|x|^2 + 1 / 2C), signed by y, a point with |x| = 0 skipped
;;;; under pa1, the objective the loss alone).  PEN 1 is the L2 penalty
;;;; (ALPHA), 0 none.  X is n rows of p.  W comes back with
;;;; the weights and OUT[0] with the intercept (FITINT 1 fits it).
;;;; Returns the number of epochs.
;;;;
;;;;[ja] 線形モデルの確率的勾配降下全体: scikit-learn の _plain_sgd(L2 正則化)
;;;;[ja] をそのままサブセットで書いたもの。SGDClassifier の既定(hinge 損失、
;;;;[ja] 学習率 "optimal")と SGDRegressor の既定(二乗誤差、"invscaling")、
;;;;[ja] Perceptron(閾値 0 の hinge、"constant"、正則化なし)、passive-aggressive
;;;;[ja] ("pa1"、"pa2"; 回帰は epsilon-insensitive 損失)。
;;;;[ja] 点は順に回る(scikit-learn の shuffle=False)。w は scikit-learn の
;;;;[ja] WeightVector と同じくスケールとベクトルの積で持ち、縮小を O(1) にする。
;;;;[ja] エポックの平均目的関数が最良から TOL 以上下がらない回数が NITERNOCHANGE
;;;;[ja] 続くか、MAXITER エポックで終了。

;; the loss and its gradient at (y, p)
(define (sgd-loss loss y p epsilon)
  (if (= loss 1)
      (* 0.5 (* (- p y) (- p y)))
      (if (= loss 3)
          (let ((r (- (if (< (- y p) 0.0) (- p y) (- y p)) epsilon)))
            (if (> r 0.0) r 0.0))
          (let ((th (if (= loss 0) 1.0 0.0)) (z (* p y)))
            (if (<= z th) (- th z) 0.0)))))

(define (sgd-grad loss y p epsilon)
  (if (= loss 1)
      (- p y)
      (if (= loss 3)
          (if (> (- y p) epsilon) -1.0 (if (> (- p y) epsilon) 1.0 0.0))
          (let ((th2 (if (= loss 0) 1.0 0.0)) (z2 (* p y)))
            (if (<= z2 th2) (- 0.0 y) 0.0)))))

(define (sgd x y w out loss lr pen alpha eta0 powert epsilon maxiter tol niternochange fitint n p)
  (let ((wscale 1.0) (sqnorm 0.0) (b 0.0) (t 1.0)
        (optinit 0.0) (best 1e300) (noimp 0) (epoch 0) (done 0))
    (do ((j 0 (+ j 1))) ((= j p))
      (set! sqnorm (+ sqnorm (* (vector-ref w j) (vector-ref w j)))))
    ;; the "optimal" schedule's offset: typw = sqrt(1 / sqrt(alpha))
    (if (= lr 0)
        (let ((typw (sqrt (/ 1.0 (sqrt alpha)))))
          (let ((g (sgd-grad loss 1.0 (- 0.0 typw) epsilon)))
            (let ((eta00 (/ typw (if (> g 1.0) g 1.0))))
              (set! optinit (/ 1.0 (* eta00 alpha))))))
        0)
    (do () ((or (= done 1) (>= epoch maxiter)))
      (let ((objsum 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((dot 0.0) (sx 0.0))
            (do ((j 0 (+ j 1))) ((= j p))
              (set! dot (+ dot (* (vector-ref x (+ (* i p) j)) (vector-ref w j)))))
            ;; |x|^2, for the passive-aggressive steps
            (if (>= lr 3)
                (do ((j 0 (+ j 1))) ((= j p))
                  (set! sx (+ sx (* (vector-ref x (+ (* i p) j)) (vector-ref x (+ (* i p) j))))))
                0)
            (let ((pr (+ (* wscale dot) b))
                  (yi (vector-ref y i)))
              (let ((eta (if (= lr 0)
                             (/ 1.0 (* alpha (- (+ optinit t) 1.0)))
                             (if (= lr 1)
                                 (/ (* 1.0 eta0) (expt t (* 1.0 powert)))
                                 eta0)))
                    (li (sgd-loss loss yi pr epsilon))
                    (dl (if (< lr 3) (sgd-grad loss yi pr epsilon) 0.0)))
                (set! objsum (+ objsum li))
                (if (and (< lr 3) (= pen 1))
                    (set! objsum (+ objsum (* alpha (* 0.5 sqnorm))))
                    0)
                (if (not (and (= lr 3) (= sx 0.0)))
                    (begin
                      (let ((step (if (= lr 3)
                                      (sgd-min eta0 (/ li sx))
                                      (if (= lr 4)
                                          (/ li (+ sx (/ 0.5 eta0)))
                                          (* (- 0.0 eta) (if (< dl -1e12) -1e12 (if (> dl 1e12) 1e12 dl)))))))
                        (let ((update (if (>= lr 3)
                                          (if (or (= loss 0) (= loss 2))
                                              (* step yi)
                                              (if (< (- yi pr) 0.0) (- 0.0 step) step))
                                          step)))
                          ;; the L2 shrinkage, by the scale
                          (if (= pen 1)
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
                              0)
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
                              0)))
                      (set! t (+ t 1.0)))
                    0)))))
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

(define (sgd-min a b) (if (< a b) a b))
