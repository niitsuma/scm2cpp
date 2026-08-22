;; The array-and-fold macro layer, exercised on its own.  The macros are
;; the ones examples/kernel-only/lasso-cov-arrays.scm defines; each file
;; carries its own copy because a translation unit is one file.  What is
;; probed: 2-D and 3-D subscripts, a fold in expression position, a fold
;; whose accumulator survives across an inner effectful loop, and the
;; two-argument and three-argument range-for.

(define-macro (range-for spec . body)
  (if (null? (cddr spec))
      (append (list 'do (list (list (car spec) 0 (list '+ (car spec) 1)))
                    (list (list '= (car spec) (cadr spec))))
              body)
      (append (list 'do (list (list (car spec) (cadr spec)
                                    (list '+ (car spec) 1)))
                    (list (list '= (car spec) (car (cddr spec)))))
              body)))

(define-macro (range-fold spec e)
  (let ((acc (car (car spec)))  (init (cadr (car spec)))
        (i   (car (cadr spec))) (n    (cadr (cadr spec)))
        (loop (gensym 'fold)))
    (list 'let loop (list (list i 0) (list acc init))
          (list 'if (list '= i n) acc
                (list loop (list '+ i 1) e)))))

(define-macro (with-arrays decls . body)
  (letrec
      ((subscript
        (lambda (dims ixs)
          (let loop ((acc (car ixs)) (dims (cdr dims)) (ixs (cdr ixs)))
            (if (null? ixs)
                acc
                (loop (list '+ (list '* acc (car dims)) (car ixs))
                      (cdr dims) (cdr ixs))))))
       (walk
        (lambda (f)
          (cond ((not (pair? f)) f)
                ((eq? (car f) 'quote) f)
                ((and (eq? (car f) 'array-ref) (pair? (cdr f))
                      (assq (cadr f) decls))
                 (list 'vector-ref (cadr f)
                       (subscript (cadr (assq (cadr f) decls))
                                  (map walk (cddr f)))))
                ((and (eq? (car f) 'array-set!) (pair? (cdr f))
                      (assq (cadr f) decls))
                 (let ((args (map walk (cddr f))))
                   (let ((v   (list-ref args (- (length args) 1)))
                         (ixs (reverse (cdr (reverse args)))))
                     (list 'vector-set! (cadr f)
                           (subscript (cadr (assq (cadr f) decls)) ixs)
                           v))))
                ((and (memq (car f) '(array-inc! array-dec!)) (pair? (cdr f))
                      (assq (cadr f) decls))
                 (let ((args (map walk (cddr f))))
                   (let ((v   (list-ref args (- (length args) 1)))
                         (ixs (reverse (cdr (reverse args))))
                         (op  (if (eq? (car f) 'array-inc!) '+ '-)))
                     (let ((sub (subscript (cadr (assq (cadr f) decls)) ixs)))
                       (list 'vector-set! (cadr f) sub
                             (list op (list 'vector-ref (cadr f) sub) v))))))
                (else (map walk f))))))
    (cons 'begin (map walk body))))

(define (main)
  (let ((rows 3) (cols 2))
    (let ((a (make-vector (* rows cols) 0.0))
          (x (make-vector cols 0.0))
          (y (make-vector rows 0.0))
          (t (make-vector 8 0.0)))
      (with-arrays ((a (rows cols))
                    (t (2 2 2)))
        ;; fill A[i][j] = 10*i + j
        (range-for (i rows)
          (range-for (j cols)
            (array-set! a i j (+ (* 10.0 i) (* 1.0 j)))))
        (vector-set! x 0 2.0)
        (vector-set! x 1 0.5)
        ;; y = A x, the inner product as a fold in expression position
        (range-for (i rows)
          (vector-set! y i
                       (range-fold ((acc 0.0) (j cols))
                         (+ acc (* (array-ref a i j) (vector-ref x j))))))
        (display (vector-ref y 0)) (newline)
        (display (vector-ref y 1)) (newline)
        (display (vector-ref y 2)) (newline)
        ;; total of A, one fold over rows carrying an inner effectful loop
        (display
         (range-fold ((s 0.0) (i rows))
           (let ((row (range-fold ((r 0.0) (j cols))
                        (+ r (array-ref a i j)))))
             (+ s row))))
        (newline)
        ;; 3-D corner writes, and a start-offset loop reading them back
        (array-set! t 0 0 0 1.0)
        (array-set! t 1 1 1 7.0)
        ;; updating assignment through a 2-D subscript
        (array-inc! a 2 1 0.5)
        (array-dec! a 0 0 (array-ref a 2 1))
        (display (array-ref a 0 0)) (newline)
        (range-for (k 4 8)
          (vector-set! t k (+ (vector-ref t k) 0.25)))
        (display (vector-ref t 0)) (newline)
        (display (vector-ref t 7)) (newline))))
  0)
