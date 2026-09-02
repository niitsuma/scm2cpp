;; The soft-thresholding operator every lasso kernel here steps through:
;; S(z, g) = sign(z) * max(|z| - g, 0).  Written once and included by
;; each kernel as (include "soft-threshold.scm").

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))
