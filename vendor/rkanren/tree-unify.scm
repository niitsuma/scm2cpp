#lang racket
(provide == unify

	 update-prefix
	 occurs-check
	 ext-s
)

(require "mk.scm"
         "ck.scm")

;; ---UNIFICATION--------------------------------------------------

(define ext-s
  (lambda (x v s)
    (if (and (pair? s) (hash? (cdr s)))
        (cons (cons (cons x v) (car s)) (hash-set (cdr s) x v))
        (cons (cons x v) s))))

(define occurs-check
  (lambda (x v s)
    (let occurs-check ((x x) (v v) (seen '()))
      (let ((v (walk v s)))
        (cond
          ((var? v) (eq? v x))
          ((recursive-representation? v)
           => (lambda (u)
                (and (not (memq u seen))
                     (occurs-check x (caddr v) (cons u seen)))))
          ((pair? v)
           (or (occurs-check x (car v) seen)
               (occurs-check x (cdr v) seen)))
          (else #f))))))

;; Where miniKanren refuses a self-referential binding, take it and say
;; so -- bind the variable to (==> x t), naming the recursion -- and
;; unify equi-recursively: an annotation is transparent against its
;; body, and a pair of terms already under comparison counts as equal
;; rather than being unrolled again, which is what terminates. This is
;; the recursive miniKanren occurs check and unify-ons-trees, carried
;; into cKanren's unifier; the constraint framework around it is
;; untouched.
(define unify
  (lambda (e s)
    (unify/seen e s '())))

(define unify/seen
  (lambda (e s seen)
    (cond
      ((null? e) s)
      (else
       (let loop ((u (caar e)) (v (cdar e)) (e (cdr e)) (seen seen))
         (let ((u (walk u s)) (v (walk v s)))
           (cond
             ((eq? u v) (unify/seen e s seen))
             ((member (cons u v) seen) (unify/seen e s seen))
             ((var? u)
              (unify/seen e (ext-s u (if (occurs-check u v s)
                                         (make-recursive-representation u v)
                                         v)
                                  s)
                          seen))
             ((var? v)
              (unify/seen e (ext-s v (if (occurs-check v u s)
                                         (make-recursive-representation v u)
                                         u)
                                  s)
                          seen))
             ((recursive-representation? u)
              (loop (caddr u) v e (cons (cons u v) seen)))
             ((recursive-representation? v)
              (loop u (caddr v) e (cons (cons u v) seen)))
             ((and (pair? u) (pair? v))
              (loop (car u) (car v)
                `((,(cdr u) . ,(cdr v)) . ,e)
                seen))
             ((equal? u v) (unify/seen e s seen))
             (else #f))))))))

;; ---GOAL---------------------------------------------------------

(define == (lambda (u v) (goal-construct (==-c u v))))

(define ==-c
  (lambda (u v)
    (lambdam@ (a : s c)
      (cond
        ((unify `((,u . ,v)) s)
         => (lambda (s^)
              ((update-prefix s s^) a)))
        (else #f)))))

(define update-prefix
  (lambda (s s^)
    (let ((alist (lambda (S) (if (and (pair? S) (hash? (cdr S))) (car S) S))))
      (let ((stop (alist s)))
        (let loop ((l (alist s^)))
          (cond
            ((eq? l stop) identitym)
            ((null? l) identitym)
            (else
              (composem
                (update-s (caar l) (cdar l))
                (loop (cdr l))))))))))
