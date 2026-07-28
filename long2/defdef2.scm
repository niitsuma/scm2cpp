;; The def-def.scm above with the pieces it was missing supplied.
;;  - rand was undefined; a linear congruential generator is given here
;;  - monte-carlo2 bound a self-calling lambda with let, which is not valid
;;    Scheme; it is written as a named let
;;  - the division is multiplied by 1.0 so that it is not truncated

(define seed 12345)
(define (rand)
  (set! seed (remainder (+ (* seed 1103515245) 12345) 2147483647))
  seed)

(define (gcd a b)
   (if (= b 0)
       a
       (gcd b (remainder a b))))

(define (cesaro-test)
   (= (gcd (rand) (rand)) 1))

(define (monte-carlo trials experiment)
  (define (iter trials-remaining trials-passed)
    (cond ((= trials-remaining 0)
           (/ (* 1.0 trials-passed) trials))
          ((experiment)
           (iter (- trials-remaining 1) (+ trials-passed 1)))
          (else
           (iter (- trials-remaining 1) trials-passed))))
  (iter trials 0))

(define (monte-carlo2 trials experiment)
  (letrec ((iter (lambda (trials-remaining trials-passed)
                   (cond ((= trials-remaining 0)
                          (/ (* 1.0 trials-passed) trials))
                         ((experiment)
                          (iter (- trials-remaining 1) (+ trials-passed 1)))
                         (else
                          (iter (- trials-remaining 1) trials-passed))))))
    (iter trials 0)))

(define (estimate-pi trials)
  (sqrt (/ 6.0 (monte-carlo trials cesaro-test))))

(define (main)
  (display (estimate-pi 1000))
  (newline)
  0)
