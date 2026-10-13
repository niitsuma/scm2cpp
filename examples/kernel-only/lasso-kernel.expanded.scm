;; scm2cpp --save-scm: the program after macro
;; expansion and rewriting, before C++ emission.
(define (soft-threshold z g)
  (cond ((> z g) (- z g)) ((< z (- 0.0 g)) (+ z g)) (else 0.0)))

(define (lasso x beta resid xnorm lams betas iters tol n p nlam)
  (begin
    (if (< p n)
      (begin
        (let ((b024255 (make-vector p 0.0))
              (g24254 (make-vector (* p p) 0.0))
              (c24253 (make-vector p 0.0)))
          (begin
            (do ((y2491 0 (+ y2491 1)))
                ((= y2491 p))
              (do ((y2492 y2491 (+ y2492 1)))
                  ((= y2492 p))
                (vector-set!
                 g24254
                 (+ (* y2491 p) y2492)
                 (let fold2499 ((k2493 0) (sum2498 0.0))
                   (if (not (= k2493 n))
                     (fold2499
                      (+ k2493 1)
                      (+
                       sum2498
                       (*
                        (vector-ref x (+ (* y2491 n) k2493))
                        (vector-ref x (+ (* y2492 n) k2493)))))
                     sum2498)))
                (vector-set!
                 g24254
                 (+ (* y2492 p) y2491)
                 (vector-ref g24254 (+ (* y2491 p) y2492)))))
            (do ((y2494 0 (+ y2494 1)))
                ((= y2494 p))
              (vector-set!
               c24253
               y2494
               (let fold2501 ((k2495 0) (sum2500 0.0))
                 (if (not (= k2495 n))
                   (fold2501
                    (+ k2495 1)
                    (+
                     sum2500
                     (*
                      (vector-ref x (+ (* y2494 n) k2495))
                      (vector-ref resid k2495))))
                   sum2500))))
            (do ((k24256 0 (+ k24256 1)))
                ((= k24256 p))
              (vector-set! b024255 k24256 (vector-ref beta k24256)))
            (do ((l 0 (+ l 1)))
                ((= l nlam))
              (let ((lam (vector-ref lams l)))
                (let ((stop 0))
                  (do ((sweep 0 (+ sweep 1)))
                      ((or (= sweep iters) (= stop 1)))
                    (let ((maxmove 0.0))
                      (do ((j 0 (+ j 1)))
                          ((= j p))
                        (let ((rho (vector-ref c24253 j))
                              (old (vector-ref beta j)))
                          (set! rho (+ rho (* old (vector-ref xnorm j))))
                          (let ((bnew
                                 (/
                                  (soft-threshold rho (* lam (* 1.0 n)))
                                  (vector-ref xnorm j))))
                            (vector-set! beta j bnew)
                            (if (not (= bnew old))
                              (begin
                                (if (> (- bnew old) maxmove)
                                  (set! maxmove (- bnew old))
                                  0)
                                (if (> (- old bnew) maxmove)
                                  (set! maxmove (- old bnew))
                                  0)
                                (begin
                                  (do ((k24257 0 (+ k24257 1)))
                                      ((= k24257 p))
                                    (vector-set!
                                     c24253
                                     k24257
                                     (-
                                      (vector-ref c24253 k24257)
                                      (*
                                       (vector-ref g24254 (+ (* j p) k24257))
                                       (- bnew old)))))))
                              #f))))
                      (if (<= maxmove tol) (set! stop 1) 0))))
                (do ((j 0 (+ j 1)))
                    ((= j p))
                  (vector-set! betas (+ (* l p) j) (vector-ref beta j)))))
            (do ((y2496 0 (+ y2496 1)))
                ((= y2496 n))
              (vector-set!
               resid
               y2496
               (-
                (vector-ref resid y2496)
                (let fold2503 ((k2497 0) (sum2502 0.0))
                  (if (not (= k2497 p))
                    (fold2503
                     (+ k2497 1)
                     (+
                      sum2502
                      (*
                       (- (vector-ref beta k2497) (vector-ref b024255 k2497))
                       (vector-ref x (+ (* k2497 n) y2496)))))
                    sum2502)))))
            0)))
      (begin
        (do ((l 0 (+ l 1)))
            ((= l nlam))
          (let ((lam (vector-ref lams l)))
            (let ((stop 0))
              (do ((sweep 0 (+ sweep 1)))
                  ((or (= sweep iters) (= stop 1)))
                (let ((maxmove 0.0))
                  (do ((j 0 (+ j 1)))
                      ((= j p))
                    (let ((rho 0.0) (old (vector-ref beta j)))
                      (do ((i 0 (+ i 1)))
                          ((= i n))
                        (set! rho
                          (+
                           rho
                           (*
                            (vector-ref x (+ (* j n) i))
                            (vector-ref resid i)))))
                      (set! rho (+ rho (* old (vector-ref xnorm j))))
                      (let ((bnew
                             (/
                              (soft-threshold rho (* lam (* 1.0 n)))
                              (vector-ref xnorm j))))
                        (vector-set! beta j bnew)
                        (if (not (= bnew old))
                          (begin
                            (if (> (- bnew old) maxmove)
                              (set! maxmove (- bnew old))
                              0)
                            (if (> (- old bnew) maxmove)
                              (set! maxmove (- old bnew))
                              0)
                            (do ((i 0 (+ i 1)))
                                ((= i n))
                              (vector-set!
                               resid
                               i
                               (-
                                (vector-ref resid i)
                                (*
                                 (vector-ref x (+ (* j n) i))
                                 (- bnew old))))))
                          #f))))
                  (if (<= maxmove tol) (set! stop 1) 0))))
            (do ((j 0 (+ j 1)))
                ((= j p))
              (vector-set! betas (+ (* l p) j) (vector-ref beta j))))))))
  0)

