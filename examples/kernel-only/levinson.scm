;; Levinson-Durbin: the Yule-Walker equations R phi = r solved in
;; O(p^2) by using what makes them special -- R is Toeplitz, its
;; every entry one of the p+1 autocovariances.  A general solver
;; would pay O(p^3) and learn nothing on the way; this recursion
;; raises the order one step at a time and the by-products are the
;; point as much as the solution is:
;;
;;   PACF[m-1]  the reflection coefficient of order m, which is the
;;              partial autocorrelation at lag m -- the standard
;;              order-selection plot;
;;   ERRS[m-1]  the prediction-error power at order m, from which
;;              every order's AIC/BIC follows, so fitting once at
;;              the largest order prices every smaller model too.
;;
;; PHI returns the order-p coefficients of
;;   x_t = phi_1 x_{t-1} + ... + phi_p x_{t-p} + e_t.
;; WORK is a scratch copy of the previous order's coefficients: the
;; update reads them reversed while writing them forward, so it
;; cannot run in place.  All four vectors need p entries; R needs
;; p+1.

(define (levinson r phi work pacf errs p)
  (let ((e (vector-ref r 0)))
    (do ((m 1 (+ m 1)))
        ((> m p))
      (let ((acc (vector-ref r m)))
        (do ((j 1 (+ j 1)))
            ((= j m))
          (set! acc (- acc (* (vector-ref phi (- j 1))
                              (vector-ref r (- m j))))))
        (let ((k (/ acc e)))
          (do ((j 0 (+ j 1)))
              ((= j m))
            (vector-set! work j (vector-ref phi j)))
          (do ((j 0 (+ j 1)))
              ((= j (- m 1)))
            (vector-set! phi j (- (vector-ref work j)
                                  (* k (vector-ref work (- m 2 j))))))
          (vector-set! phi (- m 1) k)
          (vector-set! pacf (- m 1) k)
          (set! e (* e (- 1.0 (* k k))))
          (vector-set! errs (- m 1) e)))))
  0)
