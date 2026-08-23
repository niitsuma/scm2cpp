;; The array-and-fold layer, available to every translation unit.
;;
;; These are ordinary define-macro definitions; they are listed here once
;; and seeded into macro expansion by the translator's pre-pass and by the
;; test oracle, which keeps the two expansions identical by construction.
;; A file that defines a macro of the same name shadows the built-in.
;;
;;   (range-for (i n) body ...)          loop i = 0 .. n-1
;;   (range-for (i a b) body ...)        loop i = a .. b-1
;;   (range-fold ((acc init) (i n)) e)   fold; e yields the next acc
;;   (range-sum (i n) e)                 sum of e, an unnamed fold
;;   (with-arrays ((a (d0 d1 ...)) ...) body ...)
;;       (array-ref a i j)               row-major affine subscript
;;       (array-set! a i j v)            value last, as in SRFI 25
;;       (array-inc! a i j e)            a[i][j] += e
;;       (array-dec! a i j e)            a[i][j] -= e
;;       (array-sum e)                   sum of a vector expression
;;       (array-set! s i j (array-sum (box v i j)))
;;                                       prefix box sum: s[i,j] gets the
;;                                       fold of v over [0,i]x[0,j]
;;       (array-dot u v)                 = (array-sum (* u v))
;;       (array-inc! y e)                y += e, elementwise
;;       (array-dec! y e)                y -= e, elementwise
;;       (row-inc! a i e)                row i of 2-D a, += e
;;       (row-dec! a i e)                row i of 2-D a, -= e
;;       where a vector expression is a declared 1-D name, (row a j)
;;       -- array-curry performed at expansion time -- (+ - *) over
;;       vector expressions and scalars with scalars broadcasting, or
;;       (scale c v), the scalar multiple named as such.  The expression
;;       tree stays visible until expansion, so rewrite rules can act on
;;       the algebra: y -= coef*u is the formula (array-dec! y (scale
;;       coef u)), not a fused primitive that hides its own structure.
;;
;;       scale exists beside the overloaded * because the two carry
;;       different information.  (* a b) needs the declarations to say
;;       whether it is a ring product or a module action; (scale c v)
;;       says so itself, which is what a rewrite rule wants to match on,
;;       and it is checked: expansion rejects a scale whose second
;;       operand is not a vector, where broadcast * would have quietly
;;       read a misspelled name as a scalar.  Emission keeps the element
;;       first and the scalar second, (* v_i c), the order the flat
;;       kernels wrote and the covariance rule's left-hand sides match.
;;
;; Storage stays one flat vector per array and every subscript stays one
;; affine expression, so the generated C++ is the loop nest the flat
;; kernels wrote by hand -- verified bit-for-bit on the lasso kernels.
;; The expansions of the updating forms keep the exact shapes the
;; covariance rule's left-hand sides expect, so writing a sweep with them
;; never unmatches a rewrite rule.

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
;; (range-sum (i n) e): the sum of e over i = 0 .. n-1, a fold whose
;; accumulator nobody names.  Expands through range-fold, keeping the
;; (+ acc e) shape the covariance rule's fold doorway matches.
(define-macro (range-sum spec e)
  (let ((acc (gensym 'sum)))
    (list 'range-fold (list (list acc 0.0) spec) (list '+ acc e))))

(define-macro (with-arrays decls . body)
  (letrec
      ((subscript
        ;; row-major: dims (d0 d1 d2), indices (i j k) -> ((i*d1+j)*d2+k).
        ;; For a 2-D (p p) array this is (+ (* i p) j), the exact
        ;; expression the flat kernel wrote by hand.
        (lambda (dims ixs)
          (let loop ((acc (car ixs)) (dims (cdr dims)) (ixs (cdr ixs)))
            (if (null? ixs)
                acc
                (loop (list '+ (list '* acc (car dims)) (car ixs))
                      (cdr dims) (cdr ixs))))))
       ;; A vector operand of the whole-vector forms: a 1-D name, or
       ;; (row a j) fixing the leading axis of a declared 2-D array --
       ;; array-curry done at expansion time.  elem gives its i-th
       ;; element, extent its length, taken from the declaration.
       (elem
        (lambda (opnd i walk)
          (cond ((symbol? opnd) (list 'vector-ref opnd i))
                ((and (pair? opnd) (eq? (car opnd) 'row)
                      (assq (cadr opnd) decls))
                 (list 'vector-ref (cadr opnd)
                       (subscript (cadr (assq (cadr opnd) decls))
                                  (list (walk (car (cddr opnd))) i))))
                (else (error "with-arrays: bad vector operand" opnd)))))
       (extent
        (lambda (opnd)
          (cond ((and (symbol? opnd) (assq opnd decls))
                 (car (cadr (assq opnd decls))))
                ((and (pair? opnd) (eq? (car opnd) 'row)
                      (assq (cadr opnd) decls))
                 (cadr (cadr (assq (cadr opnd) decls))))
                (else #f))))
       ;; The vector-expression algebra: a declared 1-D name, a row of a
       ;; declared 2-D array, or + - * over such things and scalars.  A
       ;; node is a vector iff some child is; everything else is scalar
       ;; and broadcasts, i.e. is emitted once per element as written.
       (vexpr?
        (lambda (e)
          (cond ((and (symbol? e) (assq e decls)
                      (= 1 (length (cadr (assq e decls))))) #t)
                ((and (pair? e) (eq? (car e) 'row)
                      (assq (cadr e) decls)) #t)
                ;; a scale is ours only when its vector operand is
                ;; recognisable here: a nested with-arrays' names must
                ;; pass through untouched for the inner scope to expand
                ((and (pair? e) (eq? (car e) 'scale) (= (length e) 3))
                 (vexpr? (car (cddr e))))
                ((and (pair? e) (memq (car e) '(+ - *)))
                 (ormap vexpr? (cdr e)))
                (else #f))))
       (velem
        (lambda (e i walk)
          (cond ((and (symbol? e) (assq e decls)) (list 'vector-ref e i))
                ((and (pair? e) (eq? (car e) 'row)) (elem e i walk))
                ((and (pair? e) (eq? (car e) 'scale))
                 (if (and (= (length e) 3)
                          (not (vexpr? (cadr e)))
                          (vexpr? (car (cddr e))))
                     (list '* (velem (car (cddr e)) i walk) (walk (cadr e)))
                     (error "scale: wants a scalar then a vector" e)))
                ((and (pair? e) (memq (car e) '(+ - *)))
                 (cons (car e)
                       (map (lambda (sub)
                              (if (vexpr? sub) (velem sub i walk) (walk sub)))
                            (cdr e))))
                (else (walk e)))))
       (vextent
        (lambda (e)
          (cond ((extent e) (extent e))
                ((and (pair? e) (eq? (car e) 'scale))
                 (vextent (car (cddr e))))
                ((and (pair? e) (memq (car e) '(+ - *)))
                 (ormap vextent (cdr e)))
                (else #f))))
       (walk
        (lambda (f)
          (cond ((not (pair? f)) f)
                ((eq? (car f) 'quote) f)
                ((and (eq? (car f) 'array-ref) (pair? (cdr f))
                      (assq (cadr f) decls))
                 (list 'vector-ref (cadr f)
                       (subscript (cadr (assq (cadr f) decls))
                                  (map walk (cddr f)))))
                ;; The prefix box sum, algebra-level: writing
                ;;   (array-set! s i j (array-sum (box v i j)))
                ;; inside the range-fors that bind i and j. The expansion
                ;; is DELIBERATELY the naive origin-anchored nest, spelled
                ;; in the exact shape the -I recogniser peels -- output
                ;; loops outside (the enclosing range-fors), one
                ;; accumulation loop per axis bounded by (+ i 1), the
                ;; +/0.0 centre, both subscripts in row-major normal
                ;; form. Semantics are therefore defined with no flag at
                ;; all, and when -I names the array, the existing
                ;; machinery swaps in integral_image and shares tables
                ;; exactly as it does for the hand-written nest. Four
                ;; nodes of algebra replace the specimen, not the
                ;; recogniser.
                ((and (eq? (car f) 'array-set!) (pair? (cdr f))
                      (assq (cadr f) decls)
                      (let ((val (list-ref f (- (length f) 1))))
                        (and (pair? val) (eq? (car val) 'array-sum)
                             (pair? (cadr val))
                             (eq? (car (cadr val)) 'box)
                             (assq (cadr (cadr val)) decls))))
                 (let* ((sname (cadr f))
                        (ixs (map walk (reverse (cdr (reverse (cddr f))))))
                        (bx (cadr (list-ref f (- (length f) 1))))
                        (vname (cadr bx))
                        (bixs (map walk (cddr bx)))
                        (sdims (cadr (assq sname decls)))
                        (vdims (cadr (assq vname decls)))
                        (acc (gensym 'acc))
                        (avs (map (lambda (_) (gensym 'a)) ixs)))
                   (if (not (and (equal? ixs bixs)
                                 (= (length ixs) (length sdims))
                                 (= (length ixs) (length vdims))))
                       (error "box: indices must be the enclosing loop variables of both arrays" f)
                       (list 'let (list (list acc 0.0))
                             (let loop ((as avs) (is ixs))
                               (if (null? as)
                                   (list 'set! acc
                                         (list '+ acc
                                               (list 'vector-ref vname
                                                     (subscript vdims avs))))
                                   (append
                                    (list 'do (list (list (car as) 0
                                                          (list '+ (car as) 1)))
                                          (list (list '= (car as)
                                                      (list '+ (car is) 1))))
                                    (list (loop (cdr as) (cdr is))))))
                             (list 'vector-set! sname
                                   (subscript sdims ixs) acc)))))
                ((and (eq? (car f) 'array-set!) (pair? (cdr f))
                      (assq (cadr f) decls))
                 (let ((args (map walk (cddr f))))
                   (let ((v   (list-ref args (- (length args) 1)))
                         (ixs (reverse (cdr (reverse args)))))
                     (list 'vector-set! (cadr f)
                           (subscript (cadr (assq (cadr f) decls)) ixs)
                           v))))
                ;; updating assignment: (array-dec! a i j e) takes e off
                ;; a[i][j] in place, array-inc! adds.  The expansion reads
                ;; and writes through the same subscript expression, which
                ;; states -- rather than leaves to be inferred -- that the
                ;; loci coincide; the subscript is duplicated, which is
                ;; sound because index expressions in this subset are
                ;; arithmetic on names, never effectful.  The shape is the
                ;; exact (vector-set! a S (- (vector-ref a S) e)) the
                ;; covariance rule's left-hand sides expect, so sugaring an
                ;; update site never unmatches a rule.
                ((and (memq (car f) '(array-inc! array-dec!)) (pair? (cdr f))
                      (assq (cadr f) decls)
                      ;; at least one index and a value: with a single
                      ;; operand the form is the whole-vector one below
                      (>= (length (cddr f)) 2))
                 (let ((args (map walk (cddr f))))
                   (let ((v   (list-ref args (- (length args) 1)))
                         (ixs (reverse (cdr (reverse args))))
                         (op  (if (eq? (car f) 'array-inc!) '+ '-)))
                     (let ((sub (subscript (cadr (assq (cadr f) decls)) ixs)))
                       (list 'vector-set! (cadr f) sub
                             (list op (list 'vector-ref (cadr f) sub) v))))))
                ;; (array-sum e): the sum of a vector expression, as the
                ;; same named-let fold range-fold produces -- so a sweep
                ;; whose rho is (array-sum (* (row x j) resid)) still
                ;; matches the covariance rule's fold doorway.
                ((and (eq? (car f) 'array-sum) (= (length f) 2))
                 (let ((i (gensym 'i)) (r (gensym 'r)) (loop (gensym 'sum)))
                   (list 'let loop (list (list i 0) (list r 0.0))
                         (list 'if (list '= i (vextent (cadr f))) r
                               (list loop (list '+ i 1)
                                     (list '+ r (velem (cadr f) i walk)))))))
                ;; (array-dot u v) reads better where the formula really
                ;; is an inner product; it is nothing but the sum above.
                ((and (eq? (car f) 'array-dot) (= (length f) 3))
                 (walk (list 'array-sum (list '* (cadr f) (car (cddr f))))))
                ;; (array-inc! y e) and (array-dec! y e) with a vector
                ;; expression: the whole-vector += and -= .  The element
                ;; emitted preserves the source's operand order, so
                ;; (array-dec! y (* u coef)) expands to the exact
                ;; (vector-set! y i (- (vector-ref y i) (* u_i coef)))
                ;; the rule left-hand sides spell, and the formula stays
                ;; a formula until this point -- a rewrite rule that
                ;; wants to factor or fuse it sees algebra, not an
                ;; opaque primitive.
                ;; row-targeted update: (row-dec! a i e) decrements row i
                ;; of a declared 2-D array by a vector expression -- the
                ;; matrix counterpart of the whole-vector forms, and the
                ;; update shape the matrix-scratch derivation recognises.
                ((and (memq (car f) '(row-inc! row-dec!))
                      (= (length f) 4)
                      (assq (cadr f) decls)
                      (vexpr? (car (cdddr f))))
                 (let* ((a (cadr f))
                        (i (walk (car (cddr f))))
                        (e (car (cdddr f)))
                        (k (gensym 'k))
                        (dims (cadr (assq a decls)))
                        (n (or (vextent e) (cadr dims)))
                        (op (if (eq? (car f) 'row-inc!) '+ '-))
                        (sub (subscript dims (list i k))))
                   (append
                    (list 'do (list (list k 0 (list '+ k 1)))
                          (list (list '= k n)))
                    (list (list 'vector-set! a sub
                                (list op (list 'vector-ref a sub)
                                      (velem e k walk)))))))
                ((and (memq (car f) '(array-inc! array-dec!))
                      (= (length f) 3)
                      (vexpr? (car (cddr f))))
                 (let ((i (gensym 'i))
                       (y (cadr f)) (e (car (cddr f)))
                       (op (if (eq? (car f) 'array-inc!) '+ '-)))
                   (append
                    (list 'do (list (list i 0 (list '+ i 1)))
                          (list (list '= i (or (vextent e) (extent y)))))
                    (list (list 'vector-set! y i
                                (list op (list 'vector-ref y i)
                                      (velem e i walk)))))))
                (else (map walk f))))))
    (cons 'begin (map walk body))))
