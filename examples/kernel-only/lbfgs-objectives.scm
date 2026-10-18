;;;; The objectives lbfgs.scm minimises, behind its one entry lbfgs-fg:
;;;; KIND 0 is logistic-lbfgs.scm's (AUX: l2, multi, fit_intercept), 1
;;;; huber.scm's (AUX: epsilon, alpha, fit_intercept), 2 glm.scm's (AUX:
;;;; alpha, family, fit_intercept, power).
;;;; A program takes the L-BFGS fits by including this file.
;;;;

(include "logistic-lbfgs.scm")
(include "huber.scm")
(include "glm.scm")
(include "lbfgs.scm")

(define (lbfgs-fg kind w g x y aux work n p k)
  (if (= kind 0)
      (logistic-fg w g x y work (vector-ref aux 0)
                   (if (= (vector-ref aux 1) 1.0) 1 0) (if (= (vector-ref aux 2) 1.0) 1 0) n p k)
      (if (= kind 1)
          (huber-fg w g x y work (vector-ref aux 0) (vector-ref aux 1)
                    (if (= (vector-ref aux 2) 1.0) 1 0) n p)
          (glm-fg w g x y work (inexact->exact (vector-ref aux 1)) (vector-ref aux 3)
                  (vector-ref aux 0) (if (= (vector-ref aux 2) 1.0) 1 0) n p))))
