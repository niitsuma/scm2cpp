;; scm2cpp --save-scm: the program after macro
;; expansion and rewriting, before C++ emission.
(define (soft-threshold z g)
  (cond ((> z g) (- z g)) ((< z (- 0.0 g)) (+ z g)) (else 0.0)))

(define (lasso x beta resid xnorm lams betas iters n p nlam)
  (begin
    (let ((b04427 (make-vector p 0.0))
          (g4426 (make-vector (* p p) 0.0))
          (c4425 (make-vector p 0.0)))
      (begin
        (do ((k2491 0 (+ k2491 1)))
            ((= k2491 p))
          (do ((k2492 k2491 (+ k2492 1)))
              ((= k2492 p))
            (vector-set!
             g4426
             (+ (* k2491 p) k2492)
             (let sum2495 ((i2493 0) (r2494 0.0))
               (if (not (= i2493 n))
                 (sum2495
                  (+ i2493 1)
                  (+
                   r2494
                   (*
                    (vector-ref x (+ (* k2491 n) i2493))
                    (vector-ref x (+ (* k2492 n) i2493)))))
                 r2494)))
            (vector-set!
             g4426
             (+ (* k2492 p) k2491)
             (vector-ref g4426 (+ (* k2491 p) k2492)))))
        (do ((k4432 0 (+ k4432 1)))
            ((= k4432 p))
          (vector-set!
           c4425
           k4432
           (let sum2498 ((i2496 0) (r2497 0.0))
             (if (not (= i2496 n))
               (sum2498
                (+ i2496 1)
                (+
                 r2497
                 (*
                  (vector-ref x (+ (* k4432 n) i2496))
                  (vector-ref resid i2496))))
               r2497))))
        (do ((k4428 0 (+ k4428 1)))
            ((= k4428 p))
          (vector-set! b04427 k4428 (vector-ref beta k4428)))
        (do ((l 0 (+ l 1)))
            ((= l nlam))
          (let ((lam (vector-ref lams l)))
            (let ((stop 0))
              (do ((sweep 0 (+ sweep 1)))
                  ((or (= sweep iters) (= stop 1)))
                (let ((moved 0))
                  (do ((j 0 (+ j 1)))
                      ((= j p))
                    (let ((rho (vector-ref c4425 j)) (old (vector-ref beta j)))
                      (set! rho (+ rho (* old (vector-ref xnorm j))))
                      (let ((bnew
                             (/
                              (soft-threshold rho (* lam (* 1.0 n)))
                              (vector-ref xnorm j))))
                        (vector-set! beta j bnew)
                        (if (not (= bnew old))
                          (begin
                            (set! moved 1)
                            (begin
                              (do ((k4429 0 (+ k4429 1)))
                                  ((= k4429 p))
                                (vector-set!
                                 c4425
                                 k4429
                                 (-
                                  (vector-ref c4425 k4429)
                                  (*
                                   (vector-ref g4426 (+ (* j p) k4429))
                                   (- bnew old)))))))
                          #f))))
                  (if (= moved 0) (set! stop 1) 0))))
            (do ((j 0 (+ j 1)))
                ((= j p))
              (vector-set! betas (+ (* l p) j) (vector-ref beta j)))))
        (do ((j4430 0 (+ j4430 1)))
            ((= j4430 p))
          (do ((i2499 0 (+ i2499 1)))
              ((= i2499 n))
            (vector-set!
             resid
             i2499
             (-
              (vector-ref resid i2499)
              (*
               (vector-ref x (+ (* j4430 n) i2499))
               (- (vector-ref beta j4430) (vector-ref b04427 j4430)))))))
        0)))
  0)

