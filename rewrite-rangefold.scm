#lang racket
;;;; Range folds as table reads (by default; --plain off, -I NAME narrows).
;;;;
;;;; A range fold is the fold, under a group's add, of the elements of a
;;;; vector -- or of a vector of vectors, at any depth -- over one
;;;; half-open range per axis:
;;;;
;;;;   (let ((acc Z))
;;;;     (do ((r R0 (+ r 1))) ((>= r R1))
;;;;       (let ((row (vector-ref m r)))
;;;;         (do ((c C0 (+ c 1))) ((>= c C1))
;;;;           (let ((x (vector-ref row c)))
;;;;             (set! acc (ADD acc x))))))
;;;;     acc)
;;;;
;;;; which is what (for*/sum ((row (in-vector m R0 R1)) (x (in-vector row
;;;; C0 C1))) x) and the for/sum+ forms expand to (array-macros.scm), and
;;;; what the same loops written by hand look like; = for >= in the tests
;;;; and (vector-ref row c) in place of the innermost let are the same
;;;; shape, and so is a subscript K + D or D - K, read as the range it
;;;; covers -- (for/sum ((a (in-range w))) (vector-ref ps (- c a))) folds
;;;; ps over [c-w+1, c+1).  When the array is not written in a loop around the fold, the
;;;; fold is a read of one table: T, the folds from the origin, formed once
;;;; before the loop, and the box's fold by inclusion-exclusion over its
;;;; 2^k corners, k the rank -- for k = 2,
;;;;
;;;;   (SUB (ADD T[R1][C1] T[R0][C0]) (ADD T[R0][C1] T[R1][C0]))
;;;;
;;;; which needs the subtraction: the fold must be a group's, not merely a
;;;; monoid's.  Which adds are: + (with 0 or 0.0), and a function of the
;;;; program that adds componentwise --
;;;;
;;;;   (define (v+ a b) (vector (+ (vector-ref a 0) (vector-ref b 0))
;;;;                            (+ (vector-ref a 1) (vector-ref b 1))))
;;;;
;;;; each component a group's add over the same position of both
;;;; arguments (so m+ over v+ is one too) -- whose zero is the vector of
;;;; the components' zeros.  Its subtraction is the same function with
;;;; each component's add replaced by that add's subtraction, written
;;;; into the program as v+-inverse.
;;;;
;;;; A function whose body is a range fold over one of its parameters (the
;;;; rect-sum of the README) is a kernel: a call of it, from a loop that
;;;; does not write the array passed, is a table read the same way, the
;;;; arguments bound once.
;;;;
;;;; Where the table goes: before the outermost loop around the fold
;;;; that neither binds the array's name nor writes it -- set!s it,
;;;; vector-set!s it or a row of it read in that loop, or passes it to a
;;;; function of the program that writes its arguments.  A fold in no such
;;;; loop is left alone: one fold costs what forming the table costs.  The
;;;; folds of one array under one add before one loop share a table.  A
;;;; write through an alias the check cannot see is what rewriting by
;;;; default (or naming the array in -I) asserts there is not.
;;;;
;;;; How often: by default a fold is rewritten only when every loop from
;;;; it out to the table's counts -- a do over K from LO by 1 until K + D
;;;; reaches HI, no bound seeing a name bound inside the table's loop --
;;;; and the table is formed only when, there, the product of the counts
;;;; is 5 or more and, if the box's size (its bounds' differences, as
;;;; linear forms) does not change inside the loop, that many boxes cover
;;;; at least the array's elements.  Otherwise the table's extents are 0,
;;;; so every non-empty box falls back on the loops: one code path, no
;;;; slower than the loops but for the guard.  An array named in -I is
;;;; rewritten even where its loops do not count.  A table of integers
;;;; under + is int64 (int64-elements): its prefix sums outgrow the
;;;; elements.
;;;;
;;;; The read is guarded: a box outside the table (or a range with lo >
;;;; hi, which the loops fold to Z) takes the loops as written, so the
;;;; table's extents -- the shortest row at each depth -- never change
;;;; what a ragged array folds to.  What the table changes is the order
;;;; of the additions: exact for integers, rounding-level for doubles.

(require racket/match)

(provide lower-range-folds)

;; ---- shapes ----

(define (simple? e)
  (or (symbol? e) (number? e)
      (and (pair? e) (memq (car e) '(+ - * quotient vector-length vector-ref))
           (andmap simple? (cdr e)))))

(define (mentions? e names)
  (cond [(symbol? e) (and (memq e names) #t)]
        [(pair? e) (or (mentions? (car e) names) (mentions? (cdr e) names))]
        [else #f]))

;; Index arithmetic, folding numbers: A + B and A - B.
(define (plus a b)
  (cond [(and (number? a) (number? b)) (+ a b)]
        [(eqv? b 0) a] [(eqv? a 0) b]
        [else `(+ ,a ,b)]))
(define (minus a b)
  (cond [(and (number? a) (number? b)) (- a b)]
        [(eqv? b 0) a]
        [(equal? a b) 0]
        [else `(- ,a ,b)]))

;; IX as S*K + D, S = 1 or -1 and D free of K: (S . D), or #f.
(define (unit-offset ix k)
  (define (free? e) (not (mentions? e (list k))))
  (cond
    [(eq? ix k) (cons 1 0)]
    [(free? ix) #f]
    [else
     (match ix
       [`(+ ,a ,b)
        (cond [(free? b) (let ([r (unit-offset a k)]) (and r (cons (car r) (plus (cdr r) b))))]
              [(free? a) (let ([r (unit-offset b k)]) (and r (cons (car r) (plus a (cdr r)))))]
              [else #f])]
       [`(- ,a ,b)
        (cond [(free? b) (let ([r (unit-offset a k)]) (and r (cons (car r) (minus (cdr r) b))))]
              [(free? a) (let ([r (unit-offset b k)]) (and r (cons (- (car r)) (minus a (cdr r)))))]
              [else #f])]
       [_ #f])]))

;; The range of IX = S*K + D as K runs over [LO, HI): (LO' HI').
(define (index-range ix k lo hi)
  (match (unit-offset ix k)
    [(cons 1 d) (list (plus lo d) (plus hi d))]
    [(cons -1 d) (list (plus (minus d hi) 1) (plus (minus d lo) 1))]
    [_ #f]))

;; One level of the nest: the do over K reading SRC at S*K + D, and what
;; is inside.  Returns a list of (LO HI K X) per level -- the range of
;; the index read, X the element's name (#f at the innermost level when
;; it is read in place) -- and the add; or #f.  The exit test is >=, =
;; or > (then the last K is HI itself).
(define (peel e src acc)
  (match e
    [`(do ((,K ,LO (+ ,K2 1))) ((,(and T (or '>= '= '>)) ,K3 ,HI0)) ,BODY)
     #:when (and (symbol? K) (eq? K K2) (eq? K K3))
     (define HI (if (eq? T '>) (plus HI0 1) HI0))
     (match BODY
       [`(set! ,A (,ADD ,A2 (vector-ref ,S ,IX)))
        #:when (and (eq? A acc) (eq? A2 acc) (eq? S src) (symbol? ADD)
                    (index-range IX K LO HI))
        (cons (list (append (index-range IX K LO HI) (list K #f))) ADD)]
       [`(let ((,X (vector-ref ,S ,IX))) ,INNER)
        #:when (and (symbol? X) (eq? S src) (index-range IX K LO HI))
        (define lv (append (index-range IX K LO HI) (list K X)))
        (match INNER
          [`(set! ,A (,ADD ,A2 ,X2))
           #:when (and (eq? A acc) (eq? A2 acc) (eq? X2 X) (symbol? ADD))
           (cons (list lv) ADD)]
          [_ (let ([r (peel INNER X acc)])
               (and r (cons (cons lv (car r)) (cdr r))))])]
       [_ #f])]
    [_ #f]))

;; The range fold E is, as (V axes ADD Z) with axes ((LO HI) ..), or #f.
(define (match-range-fold e)
  (match e
    [`(let ((,ACC ,Z)) ,LOOP ,ACC2)
     #:when (and (symbol? ACC) (eq? ACC ACC2))
     (match LOOP
       [`(do ,_ ,_ (,(or 'set! 'let) ,_ ...))
        (let* ([v (match LOOP
                    [`(do ,_ ,_ (set! ,_ (,_ ,_ (vector-ref ,S ,_)))) S]
                    [`(do ,_ ,_ (let ((,_ (vector-ref ,S ,_))) ,_)) S]
                    [_ #f])]
               [r (and (symbol? v) (peel LOOP v ACC))])
          (and r
               (let* ([levels (car r)] [add (cdr r)]
                      [inner (append (list ACC v)
                                     (map caddr levels)
                                     (filter values (map cadddr levels)))])
                 ;; the box is a box: no bound sees the loops' own names
                 (and (not (memq add inner))
                      (andmap (lambda (l) (and (simple? (car l)) (simple? (cadr l))
                                               (not (mentions? (car l) (remq v inner)))
                                               (not (mentions? (cadr l) (remq v inner)))))
                              levels)
                      (not (mentions? Z inner))
                      (list v (map (lambda (l) (list (car l) (cadr l))) levels) add Z)))))]
       [_ #f])]
    [_ #f]))

;; ---- groups ----

;; The subtraction of ADD with zero Z, as (values SUB new-defs), or (values
;; #f '()).  DEFS: name -> define form.
(define (group-sub add z defs)
  (cond
    [(eq? add '+)
     (if (and (number? z) (zero? z)) (values '- '()) (values #f '()))]
    [(hash-ref defs add #f)
     => (lambda (d)
          (match d
            [`(define (,_ ,A ,B) (vector ,cs ...))
             #:when (and (symbol? A) (symbol? B) (not (eq? A B)) (pair? cs))
             (match z
               [`(vector ,zs ...)
                #:when (= (length zs) (length cs))
                (let loop ([cs cs] [zs zs] [i 0] [subs '()] [extra '()])
                  (if (null? cs)
                      (let ([name (string->symbol (format "~a-inverse" add))])
                        (values name
                                (cons `(define (,name ,A ,B) (vector ,@(reverse subs)))
                                      extra)))
                      (match (car cs)
                        [`(,G (vector-ref ,A2 ,I) (vector-ref ,B2 ,I2))
                         #:when (and (eq? A2 A) (eq? B2 B) (eqv? I i) (eqv? I2 i) (symbol? G))
                         (let-values ([(gs gx) (group-sub G (car zs) defs)])
                           (if gs
                               (loop (cdr cs) (cdr zs) (+ i 1)
                                     (cons `(,gs (vector-ref ,A ,i) (vector-ref ,B ,i)) subs)
                                     (append gx extra))
                               (values #f '())))]
                        [_ (values #f '())])))]
               [_ (values #f '())])]
            [_ (values #f '())]))]
    [else (values #f '())]))

;; ---- the helpers written into the program ----

(define (vref* t is) (for/fold ([e t]) ([i is]) `(vector-ref ,e ,i)))
(define (vset* t is v) `(vector-set! ,(vref* t (drop-right is 1)) ,(last is) ,v))
;; nested counting loops, VARS from LOS to HIS (exclusive)
(define (loops vars los his body)
  (if (null? vars) body
      `(do ((,(car vars) ,(car los) (+ ,(car vars) 1))) ((>= ,(car vars) ,(car his)))
         ,(loops (cdr vars) (cdr los) (cdr his) body))))

;; The table, inline before the loop (in place, so inference types it
;; from V's own type -- a helper function would be typed once, by
;; itself, its element type defaulting): TAB[i1+1]..[ik+1] the fold of V
;; over [0,i1] x .. x [0,ik], Z on every face at index 0, the extents
;; the shortest row at each depth.  INNER is the loop, in TAB's scope.
;; FRESH makes the names, so none can capture one of the loop's.
(define (build-code v tab k add z inner fresh guard)
  (define ns (for/list ([d k]) (fresh 'rangefold-n)))
  (define on (fresh 'rangefold-on))
  (define is (for/list ([d k]) (fresh 'rangefold-i)))
  ;; every row fresh: (make-vector n row) shares one row in Scheme
  (define (proto d)
    (if (= d k) z `(make-vector (+ ,(list-ref ns d) 1) ,(proto (+ d 1)))))
  (define fresh-rows
    (for/list ([d (- k 1)])
      (let ([js (take is (+ d 1))])
        (loops js (make-list (+ d 1) 0) (map (lambda (n) `(+ ,n 1)) (take ns (+ d 1)))
               (vset* tab js (proto (+ d 1)))))))
  (define copy
    (loops is (make-list k 0) ns
           (vset* tab (map (lambda (i) `(+ ,i 1)) is) (vref* v is))))
  (define passes
    (for/list ([d k])
      (loops is (make-list k 1) (map (lambda (n) `(+ ,n 1)) ns)
             (vset* tab is `(,add ,(vref* tab (list-set is d `(- ,(list-ref is d) 1)))
                                  ,(vref* tab is))))))
  ;; GUARD (of the extents) false: every extent 0, a table of one
  ;; element; then only an empty box fits, and it reads Z
  (define body
    (let ([b `(let ((,tab ,(proto 0))) ,@fresh-rows ,copy ,@passes ,inner)])
      (if guard
          `(let ((,on ,(guard ns)))
             ,@(for/list ([n ns]) `(set! ,n (if ,on ,n 0)))
             ,b)
          b)))
  ;; n1 = (vector-length v); each deeper extent the minimum over the
  ;; rows above it, 0 when there are none
  (for/foldr ([inner body]) ([d k])
    (let ([n (list-ref ns d)])
      (if (= d 0)
          `(let ((,n (vector-length ,v))) ,inner)
          (let ([outer (take ns d)] [ois (take is d)])
            `(let ((,n (if (> (* ,@outer) 0)
                           (vector-length ,(vref* v (make-list d 0)))
                           0)))
               ,(loops ois (make-list d 0) outer
                       `(set! ,n (min ,n (vector-length ,(vref* v ois)))))
               ,inner))))))

;; the box's fold, by inclusion-exclusion over its 2^k corners
(define (query-code tab k add sub ls hs)
  (define corners                       ; (even? . indices)
    (for/list ([m (expt 2 k)])
      (let ([is (for/list ([d k]) (if (bitwise-bit-set? m d) (list-ref ls d) (list-ref hs d)))])
        (cons (even? (for/sum ([d k]) (if (bitwise-bit-set? m d) 1 0))) is))))
  (define (fold-add es) (for/fold ([e (car es)]) ([x (cdr es)]) `(,add ,e ,x)))
  (define pos (map (lambda (c) (vref* tab (cdr c))) (filter car corners)))
  (define neg (map (lambda (c) (vref* tab (cdr c))) (filter (lambda (c) (not (car c))) corners)))
  `(,sub ,(fold-add pos) ,(fold-add neg)))

;; the box lies in the table
(define (fits-code tab k ls hs)
  `(and ,@(append*
           (for/list ([d k])
             (let ([ext `(- (vector-length ,(vref* tab (make-list d 0))) 1)])
               `((<= 0 ,(list-ref ls d)) (<= ,(list-ref ls d) ,(list-ref hs d))
                 (<= ,(list-ref hs d) ,ext)))))))

;; ---- writes ----

;; Does E write V: set! it, vector-set! it or a row of it, or pass it to
;; a function of the program that writes its arguments (WRITERS)?
(define (writes? e v writers)
  (define rows (list v))                ; names bound to rows of v in e
  (let walk ([e e])
    (match e
      [`(quote ,_) #f]
      [`(set! ,x ,val) (or (memq x rows) (walk val))]
      [`(,(or 'vector-set! 'vector-fill!) ,t ,args ...)
       (or (let root ([t t]) (match t
                               [(? symbol?) (memq t rows)]
                               [`(vector-ref ,u ,_) (root u)]
                               [_ #t]))
           (ormap walk args))]
      [`(,(or 'let 'let*) ,(? list? bs) ,body ...)
       (for ([b bs])
         (when (and (pair? b) (pair? (cdr b)) (mentions? (cadr b) rows))
           (set! rows (cons (car b) rows))))
       (or (ormap (lambda (b) (and (pair? b) (pair? (cdr b)) (walk (cadr b)))) bs)
           (ormap walk body))]
      [`(,f ,args ...)
       #:when (and (symbol? f) (memq f writers))
       (or (ormap (lambda (a) (mentions? a rows)) args) (ormap walk args))]
      [(? pair?) (ormap walk e)]
      [_ #f])))

;; functions of the program that may write an argument: any that
;; vector-set!s or set!s anything but their own fresh locals is counted
(define (program-writers defs)
  (for/list ([(f d) defs]
             #:when (let scan ([e d])
                      (match e
                        [`(quote ,_) #f]
                        [`(,(or 'vector-set! 'vector-fill!) ,(? symbol? t) ,_ ...)
                         (match d [`(define (,_ ,ps ...) ,_ ...) (and (memq t ps) #t)] [_ #t])]
                        [`(,(or 'vector-set! 'vector-fill!) ,_ ...) #t]
                        [(? pair?) (ormap scan e)]
                        [_ #f])))
    f))

;; ---- how often ----

;; E as a linear form: hash term -> coefficient, the constant under 1.
(define (linear e)
  (define h (make-hash))
  (let add ([e e] [c 1])
    (match e
      [(? number?) (hash-update! h 1 (lambda (x) (+ x (* c e))) 0)]
      [`(+ ,as ...) (for ([a as]) (add a c))]
      [`(- ,a) (add a (- c))]
      [`(- ,a ,bs ...) (add a c) (for ([b bs]) (add b (- c)))]
      [`(* ,(? number? m) ,a) (add a (* c m))]
      [`(* ,a ,(? number? m)) (add a (* c m))]
      [_ (hash-update! h e (lambda (x) (+ x c)) 0)]))
  h)
;; A - B, simplified as linear forms
(define (difference a b)
  (define h (linear a))
  (for ([(t c) (linear b)]) (hash-update! h t (lambda (x) (- x c)) 0))
  (define (term t c) (if (= c 1) t `(* ,c ,t)))
  (define (sum es) (cond [(null? es) 0] [(null? (cdr es)) (car es)] [else `(+ ,@es)]))
  (define k (hash-ref h 1 0))
  ;; the positive terms (and constant) first, the negative ones taken off
  (define pos (append (for/list ([(t c) h] #:when (and (not (eqv? t 1)) (> c 0))) (term t c))
                      (if (> k 0) (list k) '())))
  (define neg (append (for/list ([(t c) h] #:when (and (not (eqv? t 1)) (< c 0))) (term t (- c)))
                      (if (< k 0) (list (- k)) '())))
  (if (null? neg) (sum pos) `(- ,(sum pos) ,@neg)))

;; (* e ..) and (and e ..) without the one-operand forms
(define (product es) (cond [(null? es) 1] [(null? (cdr es)) (car es)] [else `(* ,@es)]))
(define (conj es) (cond [(null? es) #t] [(null? (cdr es)) (car es)] [else `(and ,@es)]))

;; The number of times the counting loop FORM runs, or #f: a do over K
;; from LO by 1 while not K + D >= HI (or = HI, or > HI).
(define (loop-count form)
  (match form
    [`(do ((,K ,LO (+ ,K2 1))) ((,(and T (or '>= '= '>)) ,E ,HI) ,_ ...) ,_ ...)
     #:when (and (symbol? K) (eq? K K2) (not (mentions? HI (list K))))
     (match (unit-offset E K)
       [(cons 1 d)
        `(max 0 ,(difference (minus (if (eq? T '>) (plus HI 1) HI) d) LO))]
       [_ #f])]
    [_ #f]))

;; ---- the pass ----

(define (bound-by e)                    ; names a form binds for its body
  (match e
    [`(do ((,xs ,_ ...) ...) ,_ ...) xs]
    [`(let ,(? symbol? n) ((,xs ,_) ...) ,_ ...) (cons n xs)]
    [`(,(or 'let 'let* 'letrec) ((,xs ,_) ...) ,_ ...) xs]
    [`(lambda ,ps ,_ ...) (if (list? ps) ps '())]
    [_ '()]))

(define (loop-form? e)
  (match e
    [`(do ,_ ...) #t]
    [`(let ,(? symbol?) ,_ ...) #t]
    [_ #f]))

;; PROG is (begin form ..).  HINTED? takes an array name and a rank.
;; COUNTED?: a fold is rewritten only where the loops between it and its
;; table count -- each a do over K from LO by 1 to a bound, none of the
;; bounds seeing a name bound inside the table's loop -- and then the
;; table is formed only when, before the loop, those loops are seen to
;; run the fold 5 times or more and, if the box's size does not change
;; inside the loop, the folds to cover at least the array's elements.
;; Otherwise (names given) a fold whose loops do not count is rewritten
;; without that check.  Returns the program, the folds rewritten and the
;; names of the tables under +.
(define (lower-range-folds prog hinted? [counted? #f])
  (define forms (if (and (pair? prog) (eq? (car prog) 'begin)) (cdr prog) (list prog)))
  (define defs
    (for/hasheq ([f forms] #:when (match f [`(define (,(? symbol?) ,_ ...) ,_ ...) #t] [_ #f]))
      (values (caadr f) f)))
  (define writers (program-writers defs))
  ;; kernels: name -> (params vparam-index axes add z)
  (define kernels
    (for*/hasheq ([(f d) defs]
                  [m (in-value (match d
                                 [`(define (,_ ,ps ...) ,body) (cons ps (match-range-fold body))]
                                 [_ #f]))]
                  #:when (and m (cdr m) (memq (car (cdr m)) (car m))
                              (andmap symbol? (car m))))
      (let ([ps (car m)] [rf (cdr m)])
        (values f (list ps (index-of ps (car rf)) (cadr rf) (caddr rf) (cadddr rf))))))
  (define helpers (make-hash))          ; key -> define form, in order
  (define helper-order '())
  (define (helper! key mk)
    (hash-ref helpers key
              (lambda ()
                (let ([d (mk)])
                  (hash-set! helpers key d)
                  (set! helper-order (append helper-order (list d)))
                  d))))
  (define counter 0)
  (define (fresh base) (set! counter (+ counter 1))
    (string->symbol (format "~a~a" base counter)))
  (define rewritten '())
  (define tables '())
  (define current-fn #f)

  ;; A site: the array V, axes, add, zero, and the expression to fall
  ;; back on; returns the guarded read or #f.  PATH: frames from the
  ;; site outwards, each (bind names) or (loop form tables-box).
  (define (site->read v axes add z fallback path wrap)
    (define k (length axes))
    (define-values (sub extra) (group-sub add z defs))
    (define target
      (and sub (hinted? v k)
           (let scan ([path path] [best #f])
             (match path
               ['() best]
               [(cons `(bind ,names) rest)
                (if (memq v names) best (scan rest best))]
               [(cons `(loop ,form ,box) rest)
                (if (writes? form v writers) best (scan rest (car path)))]))))
    ;; the names bound inside the target's loop, and its loops' counts
    (define-values (inside counts)
      (if target
          (let scan ([path path] [names '()] [counts '()])
            (match path
              [(cons `(bind ,ns) rest) (scan rest (append ns names) counts)]
              [(cons (and f `(loop ,form ,_)) rest)
               (if (eq? f target)
                   (values names (cons (loop-count form) counts))
                   (scan rest names (cons (loop-count form) counts)))]
              [(cons _ rest) (scan rest names counts)]))
          (values '() '())))
    (define trips
      (and (andmap values counts)
           (not (ormap (lambda (c) (mentions? c inside)) counts))
           (product counts)))
    (define size                        ; the box's, when the loops keep it
      (let ([ds (map (lambda (a) (difference (cadr a) (car a))) axes)])
        (and (not (ormap (lambda (d) (mentions? d inside)) ds))
             (product (map (lambda (d) (if (number? d) (max 0 d) `(max 0 ,d))) ds)))))
    (define guard
      (and trips
           (lambda (ns)
             (conj (cons `(>= ,trips 5)
                         (if size (list `(>= (* ,trips ,size) ,(product ns))) '()))))))
    (and target
         (or trips (not counted?))
         (let* ([box (caddr target)]
                [key (list v k add z)]
                [tab (cond [(assoc key (unbox box)) => cadr]
                           [else (let ([t (fresh 'rangefold-tab)])
                                   (set-box! box (append (unbox box) (list (list key t '()))))
                                   t)])]
                [ls (map car axes)] [hs (map cadr axes)])
           ;; the table's guards: one per fold, any of them enough; a fold
           ;; with none forms it always
           (set-box! box (for/list ([e (unbox box)])
                           (if (equal? (car e) key)
                               (list key tab (cons guard (caddr e)))
                               e)))
           ;; a + table of integers is int64: its prefix sums outgrow
           ;; the elements (componentwise adds keep their functions' types)
           (when (eq? add '+) (set! tables (cons tab tables)))
           (for ([d extra]) (helper! (list 'inverse (caadr d)) (lambda () d)))
           (set! rewritten (cons (list v k add) rewritten))
           (wrap `(if ,(fits-code tab k ls hs) ,(query-code tab k add sub ls hs) ,fallback)))))

  (define (rewrite e path)
    (cond
      [(not (pair? e)) e]
      [(eq? (car e) 'quote) e]
      [(match-range-fold e)
       => (lambda (rf)
            (or (site->read (car rf) (cadr rf) (caddr rf) (cadddr rf) e path values)
                e))]
      [(and (symbol? (car e)) (hash-ref kernels (car e) #f)
            (= (length (cdr e)) (length (car (hash-ref kernels (car e))))))
       => (lambda (_)
            (match-define (list ps vi axes add z) (hash-ref kernels (car e)))
            (define args (map (lambda (a) (rewrite a path)) (cdr e)))
            (define varg (list-ref args vi))
            ;; the arguments go into the bounds as written, so they must
            ;; be simple (no let in expression position: it would become
            ;; a functor, out of the table's scope)
            (define ren (lambda (x) (let sub ([x x])
                                      (cond [(symbol? x) (let ([i (index-of ps x)]) (if i (list-ref args i) x))]
                                            [(pair? x) (cons (sub (car x)) (sub (cdr x)))]
                                            [else x]))))
            (or (and (symbol? varg) (andmap simple? args)
                     (site->read varg (map (lambda (a) (map ren a)) axes) add z
                                 (cons (car e) args) path values))
                (cons (car e) args)))]
      [(loop-form? e)
       (let* ([box (box '())]
              [inner (cons `(bind ,(bound-by e)) (cons `(loop ,e ,box) path))]
              [e2 (rewrite-children e inner)])
         (for/foldr ([inner e2]) ([t (unbox box)])
           (match-define (list (list v k add z) tab guards) t)
           (build-code v tab k add z inner fresh
                       (and (andmap values guards)
                            (lambda (ns)
                              (let ([gs (remove-duplicates (map (lambda (g) (g ns)) guards))])
                                (if (null? (cdr gs)) (car gs) `(or ,@gs))))))))]
      [else
       (let ([b (bound-by e)])
         (rewrite-children e (if (null? b) path (cons `(bind ,b) path))))]))

  ;; the loop's own frame sits outside its bindings: a do's init
  ;; expressions are inside the loop form but evaluated once; they are
  ;; still rewritten, only conservatively
  (define (rewrite-children e path)
    (let walk ([g e])
      (cond [(pair? g) (cons (rewrite (car g) path) (walk (cdr g)))]
            [else g])))

  (define out
    (for/list ([f forms])
      (match f
        [`(define (,name ,ps ...) ,body ...)
         (set! current-fn name)
         `(define (,name ,@ps)
            ,@(map (lambda (b) (rewrite b (list `(bind ,ps)))) body))]
        [_ f])))
  (values (if (null? rewritten) prog `(begin ,@helper-order ,@out))
          (reverse rewritten)
          (remove-duplicates tables)))
