;; scm2cpp --save-scm: the program after macro
;; expansion and rewriting, before C++ emission.
(define (soft-threshold z g)
  (cond ((> z g) (- z g)) ((< z (- 0.0 g)) (+ z g)) (else 0.0)))

(define (lasso x beta resid xnorm lams betas iters n p nlam)
  (begin
    (let ((b0471 (make-vector p 0.0))
          (g470 (make-vector (* p p) 0.0))
          (c469 (make-vector p 0.0)))
      (begin
        (do ((k2491 0 (+ k2491 1)))
            ((= k2491 p))
          (do ((k2492 k2491 (+ k2492 1)))
              ((= k2492 p))
            (vector-set!
             g470
             (+ (* k2491 p) k2492)
             (let sum2496 ((i2494 0) (r2495 0.0))
               (if (not (= i2494 n))
                 (sum2496
                  (+ i2494 1)
                  (+
                   r2495
                   (*
                    (vector-ref x (+ (* k2491 n) i2494))
                    (vector-ref x (+ (* k2492 n) i2494)))))
                 r2495)))
            (vector-set!
             g470
             (+ (* k2492 p) k2491)
             (vector-ref g470 (+ (* k2491 p) k2492)))))
        (do ((k2497 0 (+ k2497 1)))
            ((= k2497 p))
          (vector-set!
           c469
           k2497
           (let sum2502 ((i2500 0) (r2501 0.0))
             (if (not (= i2500 n))
               (sum2502
                (+ i2500 1)
                (+
                 r2501
                 (*
                  (vector-ref x (+ (* k2497 n) i2500))
                  (vector-ref resid i2500))))
               r2501))))
        (do ((k472 0 (+ k472 1)))
            ((= k472 p))
          (vector-set! b0471 k472 (vector-ref beta k472)))
        (do ((l 0 (+ l 1)))
            ((= l nlam))
          (let ((lam (vector-ref lams l)))
            (let ((stop 0))
              (do ((sweep 0 (+ sweep 1)))
                  ((or (= sweep iters) (= stop 1)))
                (let ((moved 0))
                  (do ((j 0 (+ j 1)))
                      ((= j p))
                    (let ((rho (vector-ref c469 j)) (old (vector-ref beta j)))
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
                              (do ((k473 0 (+ k473 1)))
                                  ((= k473 p))
                                (vector-set!
                                 c469
                                 k473
                                 (-
                                  (vector-ref c469 k473)
                                  (*
                                   (vector-ref g470 (+ (* j p) k473))
                                   (- bnew old)))))))
                          #f))))
                  (if (= moved 0) (set! stop 1) 0))))
            (do ((j 0 (+ j 1)))
                ((= j p))
              (vector-set! betas (+ (* l p) j) (vector-ref beta j)))))
        (do ((k2503 0 (+ k2503 1)))
            ((= k2503 p))
          (do ((i2506 0 (+ i2506 1)))
              ((= i2506 n))
            (vector-set!
             resid
             i2506
             (-
              (vector-ref resid i2506)
              (*
               (vector-ref x (+ (* k2503 n) i2506))
               (- (vector-ref beta k2503) (vector-ref b0471 k2503)))))))
        0)))
  0)

