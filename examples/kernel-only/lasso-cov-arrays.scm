;; The covariance-update lasso of lasso-cov.scm, written against a small
;; array-and-fold layer instead of flat subscripts and set! accumulators.
;;
;; The layer is three source-level macros, defined right here: the
;; translator and the test oracle both expand define-macro the same way,
;; so nothing below reaches either of them -- what they see is exactly the
;; flat-vector program of lasso-cov.scm, and the generated C++ is the
;; same loop nest with the same arithmetic in the same order.
;;
;;   (range-for (i n) body ...)          loop i = 0 .. n-1
;;   (range-for (i a b) body ...)        loop i = a .. b-1
;;   (range-fold ((acc init) (i n)) e)   fold; e yields the next acc
;;   (with-arrays ((a (d0 d1 ...)) ...) body ...)
;;       within body, (array-ref a i j) and (array-set! a i j v) become
;;       row-major flat accesses; value last, as in SRFI 25.
;;
;; Storage stays a flat vector and the subscript stays one affine
;; expression, which is the representation the kernel already had; the
;; macros only move that arithmetic out of every call site and into one
;; declaration.  Views in the SRFI-231 style (curry, permute, sample) are
;; the natural next step for this layer and would fold into the same
;; affine form, but they are not needed by this kernel and not provided.

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
        ;; row-major: dims (d0 d1 d2), indices (i j k) -> ((i*d1+j)*d2+k).
        ;; For a 2-D (p p) array this is (+ (* i p) j), the exact
        ;; expression the flat kernel wrote by hand.
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
                (else (map walk f))))))
    (cons 'begin (map walk body))))

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

;; S(a,b) for every pair.  s is (wmax+1) x (wmax+1); one pass per lag.
(define (build-S ps s q cs n nobs wmax)
  (with-arrays ((s ((+ wmax 1) (+ wmax 1))))
    (range-for (dd (+ (* 2 wmax) 1))
      (let ((d (- dd wmax)))
        (range-for (i n) (vector-set! q i 0.0))
        (if (< d 0)
            (range-for (i (+ n d))
              (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d)))))
            (range-for (i d n)
              (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d))))))
        (vector-set! cs 0 0.0)
        (range-for (i n)
          (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
        (range-for (a (+ wmax 1))
          (let ((b (+ a d)))
            (if (< b 0)
                0
                (if (> b wmax)
                    0
                    (let ((m (- wmax a)))
                      (array-set! s a b
                                  (- (vector-ref cs (+ m nobs))
                                     (vector-ref cs m))))))))))
    0))

;; P(k) = sum_row ps[wmax+row-k] * y[row]: a fold, not a set! loop.
(define (build-P ps y pv nobs wmax)
  (range-for (k (+ wmax 1))
    (vector-set! pv k
                 (range-fold ((acc 0.0) (r nobs))
                   (+ acc (* (vector-ref ps (- (+ wmax r) k))
                             (vector-ref y r))))))
  0)

(define (build-G s pv g c wmax p)
  (with-arrays ((s ((+ wmax 1) (+ wmax 1)))
                (g (p p)))
    (let ((s00 (array-ref s 0 0)))
      (range-for (j p)
        (let ((wj (+ j 1)))
          (range-for (k p)
            (let ((wk (+ k 1)))
              (array-set! g j k
                          (/ (- (+ s00 (array-ref s wj wk))
                                (+ (array-ref s 0 wk)
                                   (array-ref s wj 0)))
                             (* wj wk)))))
          (vector-set! c j (/ (- (vector-ref pv 0) (vector-ref pv wj)) wj)))))
    0))

;; The sweeps.  The moved flag was a set! in the flat kernel; here it is
;; the accumulator of the coordinate fold, and the early exit reads it.
(define (cov-descend g c beta lam iters nobs p)
  (with-arrays ((g (p p)))
    (let ((stop 0))
      (do ((sweep 0 (+ sweep 1)))
          ((or (= sweep iters) (= stop 1)))
        (let ((moved
               (range-fold ((m 0) (j p))
                 (let ((gjj (array-ref g j j))
                       (old (vector-ref beta j)))
                   (let ((bnew (/ (soft-threshold
                                   (+ (vector-ref c j) (* old gjj))
                                   (* lam (* 1.0 nobs)))
                                  gjj)))
                     (vector-set! beta j bnew)
                     (let ((d (- bnew old)))
                       (if (= d 0.0)
                           m
                           (begin
                             (range-for (k p)
                               (vector-set! c k (- (vector-ref c k)
                                                   (* d (array-ref g j k)))))
                             1))))))))
          (if (= moved 0) (set! stop 1) 0))))
    0))
