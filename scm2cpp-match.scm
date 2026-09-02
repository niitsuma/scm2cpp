#lang racket

(provide 
 scm2cpp-match-port
 scm2cpp-match-values
 scm2cpp-match-list
 capi-functions
 compute-param-liveness!
 function-written-params function-output-params function-scratch-params
 param-liveness-alist
)

;;;; Signatures of the translated top-level functions, collected during
;;;; code generation for the optional C-API/Python output: one entry
;;;;   (fname ret-ctype ((param-name param-ctype by-ref?) ...))
;;;; per non-template function. Template functions cannot cross extern "C"
;;;; and are left out.
;;[ja] -M 用: extern "C" ラッパにする関数の署名の蓄積(テンプレート関数は除く)。
(define capi-function-list '())
;;[ja] 収集済みの C-API 用シグネチャを、定義順に並べ直して返す。
(define (capi-functions) (reverse capi-function-list))
;;[ja] 収集リストを空に戻す。翻訳のたびに呼んで前回分を捨てる。
(define (capi-reset!) (set! capi-function-list '()))
;;[ja] 1 関数分のシグネチャ entry を収集リストの先頭に積む。
(define (capi-add! entry) (set! capi-function-list (cons entry capi-function-list)))

(require srfi/1)
(require srfi/14)
(require mzlib/defmacro)
(require racket/pretty)
(require racket/file)

(require "alist-util.scm")
(require "cl-util.scm")
(require "list-util.scm")
(require "onlisp.scm")

;(require "./cl2scm/bsort.scm")



(require "schlep-name.scm")
(require "alpha-conv.scm")
(require "type-infer-util.scm")

(require "depend-analysis.scm")
(require "rewrite-derive.scm")
(require "custom-binding.scm")

;; ;; type= match
;;;;(require "type-infer-match.scm")

;; ;;type= ck
(require "type-symbols.scm")


;(require "type-infer-rel.scm")
(require "type-infer-match.scm")

;; ;;  type=racklog
;(require racklog)
;(require "schelog-util.scm")
;(require "type-infer.scm")
;(require "schlep-out.scm")


(require "scm2cpp-function.scm")


(require "scheme-macro-parser.rkt")




;;[ja] Scheme の組み込み関数名から、対応する C++ 側の関数名への対応表。
;;[ja] ここに載っている名前は呼び出し出力時にそのまま置き換えられる。
(define cpp-function-name-correspond-alist
  '(
    (eq? . "scm2cpp::is_eq")
    (eqv? . "scm2cpp::is_eqv")
    (equal? . "scm2cpp::is_equal")
    (cons . "scm2cpp::cons")
    (car . "scm2cpp::car")
    (cdr . "scm2cpp::cdr")
    (append . "scm2cpp::append")
    (list-ref . "scm2cpp::list_ref")
    (list-tail . "scm2cpp::list_tail")
    ;; An unqualified abs resolves to the integer version from <cstdlib>.
    (abs . "std::abs")
    ;(set-car! . "scm2cpp::set_car")
))

;;[ja] 関数名 f が対応表に載っているかを返す。載っていれば対応の組を返す。
(define (cpp-function-name-correspond-alist? f)
  (assoc f cpp-function-name-correspond-alist))


;;[ja] 対応表から関数名 f に対応する C++ 側の名前文字列を取り出す。
;;[ja] 載っていることを確認してから呼ぶ前提。
(define (cpp-function-name-in-correspond-alist f)
  (cdr (assoc f cpp-function-name-correspond-alist)))

;(cdr (assoc 'eq? cpp-function-name-correspond-alist))
;(assoc 'bbb cpp-function-name-correspond-alist)


;; (c-includes-add "aaa")
;; (c-includes-add "bbb")
;;  c-includes



;;[ja] 式 expr をアルファ変換にかけ、その自由変数の名前リストを返す。
;;[ja] 束縛されずに残った変数の一覧を alpha-conv の結果から取り出す。
(define (sexp-free-var expr )  
  (let-values ([(expr1 alpha1 free1)  (alpha-conv expr)])
    (let* (
	   (free1inv ( envinvert free1))
	   (freevars (map car free1inv))
	   )
      freevars)))

;;[ja] 式 expr に自由変数が 1 つでもあれば #t を返す述語。
(define  (sexp-free-var? expr ) 
  (> (length (sexp-free-var expr )) 0))

;; (sexp-free-var '(let ((x 1) (y 3)) (+ x y)))  ;-> ()
;; (sexp-free-var '(let ((x 1) (y 3)) (+ x z)))  ;-> (z)
;; (sexp-free-var '(let ((x 1) (y 3)) (+ x z u w)))  ;-> (w u z)
;; (sexp-free-var? '(let ((x 1) (y 3)) (+ x z u w))) ;#t 
;; (sexp-free-var? '(let ((x 1) (y 3)) (+ x y))) ;#f


;; ;;
;; (cpptype 'int symbol->string) 
;; (cpptype '(lambda (int int ) double) symbol->string) 
;; (cpptype '(vector int int double) symbol->string) 
;; (cpptype '(list int int double) symbol->string) 
;; (cpptype '(list int int int) symbol->string) 


;; (define(var-env->ctype v env-type)
;;   (if (var-non-fix-type? v env-type)
;;       (var-name-to-template-type-name (cname (vtype v)))
;; 	(type->ctype (vtype v))
;; 	))
;; (define (type->cpptype t)
  

  
  


;;;; Rewrite a tail-recursive named let into a do loop before code generation.
;;;; Such a let otherwise becomes a closure structure; as a plain for loop the
;;;; output is readable and later passes such as OpenMP can be applied to it.

;;[ja] 記号 name が式 expr のどこかに現れるかを木全体を走査して返す。
;;[ja] ループ本体に再帰名が残っていないことの確認などに使う。
(define (sexp-occurs? name expr)
  (cond [(eq? name expr) #t]
	[(pair? expr) (or (sexp-occurs? name (car expr))
			  (sexp-occurs? name (cdr expr)))]
	[else #f]))

;; Is this of the form (NAME arg ...)?
;;[ja] expr が名前 name をちょうど n-args 個の引数で呼ぶ形かを返す。
;;[ja] 名前付き let の自己末尾呼び出しを見つけるための述語。
(define (self-call? name expr n-args)
  (and (pair? expr) (eq? (car expr) name) (list? expr)
       (= (length (cdr expr)) n-args)))

;;[ja] 自己末尾再帰だけの名前付き let を do ループ式に書き換える。
;;[ja] 認識できる形なら do 式を、そうでなければ #f を返し、呼び出し側は
;;[ja] #f のとき従来通りクロージャ構造体として出力する。
(define (named-let->do name vars inits body)
  (define n (length vars))
  ;;[ja] 再帰呼び出しの引数 steps から do の束縛部 (v init step) を組む。
  (define (bindings steps) (map (lambda (v i s) (list v i s)) vars inits steps))
  ;;[ja] 与えられた式のどれにもループ名 name が現れないことを確かめる。
  ;;[ja] 末尾以外に再帰があると do には直せないので、その検出用。
  (define (clean? . exprs) (not (ormap (lambda (e) (sexp-occurs? name e)) exprs)))
  (match body
    ;; A value-returning named let may appear in expression position, whereas
    ;; do is only handled in statement position; leave those to the closure path.
    ;; Argument-less loop: (let NAME () (if TEST (begin STMT ... (NAME))))
    ;; -- with or without a literal else, the same liberty the
    ;; argument-carrying entry below already takes.
    [(list (list 'if test (list 'begin stmts ... (? (lambda (c) (self-call? name c 0)) _))
		 else ...))
     (and (= n 0)
	  (andmap (lambda (e) (or (number? e) (boolean? e) (string? e))) else)
	  (<= (length else) 1)
	  (apply clean? test stmts)
	  `(do () ((not ,test) ,(if (null? else) 0 (car else))) ,@stmts))]
    ;; (let NAME () (when TEST STMT ... (NAME)))
    [(list (list 'when test stmts ... (? (lambda (c) (self-call? name c 0)) _)))
     (and (= n 0) (apply clean? test stmts)
	  `(do () ((not ,test) 0) ,@stmts))]
    ;; (let NAME () (cond (TEST STMT ... (NAME))))
    [(list (list 'cond (list test stmts ... (? (lambda (c) (self-call? name c 0)) _))))
     (and (= n 0) (apply clean? test stmts)
	  `(do () ((not ,test) 0) ,@stmts))]
    ;;[ja] do-while 形: (let NAME () STMT ... (cond (TEST (NAME))))
    ;;[ja] — 本体を必ず 1 回実行し、末尾の TEST が立つ間繰り返す。
    ;;[ja] R5RS の do は本体の後に step を評価するので、番兵 g を
    ;;[ja] #t で始めて step で TEST に置き換えれば同じ意味になる
    ;;[ja] (fft の bit-reversal ループがこの形)。if/when 版も同様。
    [(list stmts ... (list 'cond (list test (? (lambda (c) (self-call? name c 0)) _))))
     (and (= n 0) (pair? stmts) (apply clean? test stmts)
	  (let ([g (gensym 'go)])
	    `(do ((,g #t ,test)) ((not ,g) 0) ,@stmts)))]
    [(list stmts ... (list 'when test (? (lambda (c) (self-call? name c 0)) _)))
     (and (= n 0) (pair? stmts) (apply clean? test stmts)
	  (let ([g (gensym 'go)])
	    `(do ((,g #t ,test)) ((not ,g) 0) ,@stmts)))]
    [(list stmts ... (list 'if test (? (lambda (c) (self-call? name c 0)) _)))
     (and (= n 0) (pair? stmts) (apply clean? test stmts)
	  (let ([g (gensym 'go)])
	    `(do ((,g #t ,test)) ((not ,g) 0) ,@stmts)))]
    ;; The same loop carrying variables:
    ;;   (let NAME ((v init) ...) (if TEST (begin STMT ... (NAME step ...)) ELSE))
    ;; The counted loop every program in this subset writes. Without this the
    ;; name stayed a self-referencing functor and each iteration was a call,
    ;; where a do becomes a plain for -- on the QAP solver, whose inner loops
    ;; are all of this shape, not one for reached the output.
    ;;
    ;; ELSE is restricted to a literal (or absent). A do is emitted in
    ;; statement position, so a loop whose result is used has to stay a
    ;; closure; a literal else is the mark of a loop run for its effects.
    ;; The step expressions become the do's steps, which are evaluated
    ;; against the old values exactly as the recursive call's arguments are.
    [(list (list 'if test (list 'begin stmts ... (? (lambda (c) (self-call? name c n)) call))
		 else ...))
     (and (> n 0)
	  (andmap (lambda (e) (or (number? e) (boolean? e) (string? e))) else)
	  (<= (length else) 1)
	  (apply clean? test (append stmts (cdr call)))
	  `(do ,(bindings (cdr call))
	       ((not ,test) ,(if (null? else) 0 (car else)))
	     ,@stmts))]
    ;; The same with a single statement and no begin.
    [(list (list 'if test (list 'begin (? (lambda (c) (self-call? name c n)) call))
		 else ...))
     (and (> n 0)
	  (andmap (lambda (e) (or (number? e) (boolean? e) (string? e))) else)
	  (<= (length else) 1)
	  (apply clean? test (cdr call))
	  `(do ,(bindings (cdr call))
	       ((not ,test) ,(if (null? else) 0 (car else)))))]
    [_ #f]))

;; (letrec ((F (lambda (p ...) BODY))) (F arg ...)) is equivalent to a named
;; let, which is already generated as a self-referencing closure structure.
;;[ja] lambda 1 つだけの letrec をそれと同値な名前付き let に直す。
;;[ja] 該当しない形なら #f を返す。
(define (letrec->named-let expr)
  (match expr
    [(list 'letrec (list (list f (list 'lambda (list ps ...) fbody ...)))
	   (list g args ...))
     (and (symbol? f) (eq? f g) (= (length ps) (length args))
	  `(let ,f ,(map list ps args) ,@fbody))]
    [_ #f]))

;;[ja] 型推論と出力の前に走る前処理パス。式全体を再帰的にたどり、
;;[ja] delay を make-promise に、let* を入れ子の let に、letrec を名前付き
;;[ja] let に、自己末尾再帰の名前付き let を do に正規化して返す。
;;[ja] quote の中身には触れない。
(define (rewrite-named-let expr)
  (match expr
    [(list 'quote _ ...) expr]
    ;; R5RS delay, opened into the promise machinery the runtime already
    ;; has: make_promise memoises and force calls through. This runs after
    ;; user macro expansion, so a file that defines its own delay macro --
    ;; the stream tests do -- never presents a bare delay here.
    [(list 'delay body ...)
     `(make-promise (lambda () ,@(map rewrite-named-let body)))]
    ;; let* as nested lets, here so that neither inference nor emission
    ;; ever sees it. Both lacked a clause and fell through to the
    ;; application path, which read a binding pair (n 6) as the call n(6).
    [(list 'let* (list bindings ...) body ...)
     (rewrite-named-let
      (if (null? bindings)
	  `(let () ,@body)
	  (let nest ([bs bindings])
	    (if (null? (cdr bs))
		`(let (,(car bs)) ,@body)
		`(let (,(car bs)) ,(nest (cdr bs)))))))]
    [(list 'letrec _ ...)
     (let ([rewritten (letrec->named-let (map rewrite-named-let expr))])
       (or (and rewritten (rewrite-named-let rewritten))
	   (map rewrite-named-let expr)))]
    ;;[ja] 値位置ループの正規化: 再帰呼び出しが else 側にある
    ;;[ja] (if TEST FINAL (NAME step...)) を枝交換で (if (not TEST) CALL FINAL)
    ;;[ja] に直す。出力器の IIFE-while 経路は then 側の再帰しか受けないため。
    [(list 'let (? symbol? name) (list (list vars inits) ...)
	   (list 'if test final (and call (list (? symbol? f) _ ...))))
     #:when (and (eq? f name)
		 (= (length (cdr call)) (length vars))
		 (not (sexp-occurs? name test))
		 (not (sexp-occurs? name final))
		 (not (ormap (lambda (e) (sexp-occurs? name e)) (cdr call))))
     (rewrite-named-let
      `(let ,name ,(map list vars inits) (if (not ,test) ,call ,final)))]
    [(list 'let (? symbol? name) (list (list vars inits) ...) body ...)
     (let* ([inits* (map rewrite-named-let inits)]
	    [body*  (map rewrite-named-let body)])
       (or (named-let->do name vars inits* body*)
	   `(let ,name ,(map list vars inits*) ,@body*)))]
    [(? list?) (map rewrite-named-let expr)]
    [_ expr]))

;;;; ---------------- write-free analysis ----------------
;;;;
;;;; "Write-free" is deliberately not called const. C's const is a promise
;;;; over a binding's whole lifetime, declared up front and enforced by the
;;;; compiler; write-freedom is a fact about one region of the program,
;;;; discovered afterwards by analysis. The same array is typically written
;;;; while it is filled and write-free from then on, a phase change const
;;;; cannot express. Where a whole parameter really is write-free for the
;;;; whole call, that does coincide with const, and the code generator then
;;;; emits the C++ keyword; the region-local notion is the more general one.
;;;;
;;;; mutation-summary maps each top-level function name to the 0-based
;;;; indices of the parameters it may write to -- directly through set!,
;;;; vector-set! and the like, or by passing the parameter on to a call
;;;; that writes it. Computed as a fixpoint from the empty map, which
;;;; terminates because the sets only grow.

;;[ja] 関数名 → その関数が書き込む仮引数の添字集合(不動点で計算)。
(define mutation-summary (make-hasheq))

;; Heads that never write to their arguments. Anything absent from this
;; list and without a summary is assumed to write every argument, so an
;; omission here only makes the analysis more conservative, never wrong.
;;[ja] 引数を書き換えないと分かっている頭部記号の一覧。ここにも
;;[ja] mutation-summary にもない頭部は全引数を書くとみなすので、
;;[ja] 抜けがあっても解析が保守的になるだけで間違いにはならない。
(define non-mutating-heads
  '(let let* letrec letrec* lambda define if cond when unless begin do else
    quote and or not delay make-promise
    make-hash hash-ref hash-has-key? hash-count
    vector-ref list-ref vector-length length car cdr cons list make-list
    make-vector display newline string-append number->string
    + - * / remainder quotient modulo max min abs expt
    sqrt sin cos tan exp log atan asin acos floor inexact->exact vector-copy
    zero? even? odd? negative? positive? null? pair?
    < > <= >= = eq? eqv? equal?))

;; Forcing a promise writes it: the runtime's promise memoises into
;; itself, so (force p) mutates p, and (force (vector-ref tab i)) mutates
;; tab. Left out of the write analysis, a promise reached through a
;; const capture or parameter went to force's const overload, which
;; forces a copy -- correct value, no memoisation, and a table of
;; promises silently exponential. The variable a force reaches is the
;; root of its argument's access path.
;;[ja] force の引数 e がたどるアクセス経路の根にある変数を返す。
;;[ja] vector-ref や car などを剥がして根の記号に至れなければ #f。
;;[ja] 実行時の promise は自分自身にメモ化するので force は書き込み扱い。
(define (forced-root e)
  (match e
    [(? symbol? v) v]
    [`(,(? (lambda (h) (memq h '(vector-ref list-ref car cdr))) _) ,x ,_ ...)
     (forced-root x)]
    [_ #f]))

;; The members of PARAMS that EXPR may write to.
;;[ja] 式 expr が書き込む可能性のある仮引数を params の中から集めて返す。
;;[ja] set! や vector-set! などの直接の書き込みに加え、summary 済みの
;;[ja] 関数や binding 宣言の mutates 節を介した間接の書き込みも数える。
;;[ja] 未知の呼び出し先には渡した引数すべてを書くと仮定する。
(define (expr-mutated-params expr params)
  (match expr
    [`(quote ,_) '()]
    [`(set! ,x ,e)
     (append (if (memq x params) (list x) '())
	     (expr-mutated-params e params))]
    [`(,(? (lambda (h) (memq h '(vector-set! set-car! set-cdr! hash-set!))) _) ,x ,es ...)
     (append (if (memq x params) (list x) '())
	     (append-map (lambda (e) (expr-mutated-params e params)) es))]
    [`(force ,e)
     (let ([r (forced-root e)])
       (append (if (and r (memq r params)) (list r) '())
	       (expr-mutated-params e params)))]
    [`(,(? symbol? f) ,args ...)
     (append
      (cond
       [(hash-ref mutation-summary f #f)
	=> (lambda (idxs)
	     (filter-map (lambda (i)
			   (and (< i (length args))
				(let ([a (list-ref args i)])
				  (and (symbol? a) (memq a params) a))))
			 idxs))]
       ;; A binding-declared operation writes exactly the argument
       ;; positions its mutates clause names; the gate is what backs the
       ;; declaration up.
       [(binding-op? f)
	(filter-map (lambda (i)
		      (and (< i (length args))
			   (let ([a (list-ref args i)])
			     (and (symbol? a) (memq a params) a))))
		    (binding-op-mutates f))]
       [(memq f non-mutating-heads) '()]
       ;; Unknown callee -- a closure held in a variable, say: assume it
       ;; writes every parameter it is handed.
       [else (filter (lambda (a) (and (symbol? a) (memq a params))) args)])
      (append-map (lambda (e) (expr-mutated-params e params)) args))]
    [(? list?) (append-map (lambda (e) (expr-mutated-params e params)) expr)]
    [_ '()]))

;;[ja] プログラム中の各トップレベル関数について、書き込む可能性のある
;;[ja] 仮引数の添字集合を mutation-summary に計算して入れる。空の表から
;;[ja] 始めて変化がなくなるまで繰り返す不動点計算で、集合は増えるだけ
;;[ja] なので必ず停止する。
(define (compute-mutation-summaries! prog)
  (hash-clear! mutation-summary)
  (let ([defs (filter (lambda (f) (match f [`(define (,_ ,_ ...) ,_ ...) #t] [_ #f]))
		      (match prog [`(begin ,forms ...) forms] [_ (list prog)]))])
    (for ([d defs])
      (match d [`(define (,f ,_ ...) ,_ ...) (hash-set! mutation-summary f '())]))
    (let fix ()
      (let ([changed #f])
	(for ([d defs])
	  (match d
	    [`(define (,f ,ps ...) ,body ...)
	     (let* ([m (remove-duplicates
			(append-map (lambda (e) (expr-mutated-params e ps)) body))]
		    [idxs (sort (filter-map (lambda (x) (index-of ps x)) m) <)])
	       (unless (equal? idxs (hash-ref mutation-summary f))
		 (set! changed #t)
		 (hash-set! mutation-summary f idxs)))]))
	(when changed (fix))))))

;;;; ---------------- parameter liveness ----------------
;;;;
;;;; mutation-summary says which parameters a function MAY WRITE; this pass
;;;; says which of those writes anyone can SEE. A written parameter whose
;;;; final contents no caller ever reads is not an output but a workspace
;;;; the caller happens to be allocating -- build-S's q and cs are the
;;;; standing examples -- and a rewrite is free to treat it as internal:
;;;; allocate it inside, drop the final restoration the derivation
;;;; performs for visibility, shrink the ABI. The --derive hook
;;;; (derive-source-maybe) consumes it: a scratch that is not an output
;;;; is left unrestored.
;;;;
;;;; The computation mirrors the mutation fixpoint, one level up: a write
;;;; is observable if, at some call site, the argument it lands in is
;;;; still wanted afterwards. "Wanted" is decided per call site, in the
;;;; caller:
;;;;
;;;;   * the argument variable occurs in a form that may still evaluate
;;;;     after the call -- computed against evaluation order, with every
;;;;     enclosing loop's whole body counted as after (the next iteration
;;;;     sees it, and a repeated call reads what the previous one wrote);
;;;;   * or the argument is a parameter of the caller whose own index is
;;;;     already observable -- the fixpoint step, sets only grow;
;;;;   * or the argument is neither a parameter nor locally bound, i.e. a
;;;;     global someone else can read;
;;;;   * or the variable is aliased: it occurs somewhere whose immediate
;;;;     parent is not a call to a known head, e.g. as a bare let-binding
;;;;     right-hand side, and from then on a second name can read it
;;;;     behind the ordered check's back.
;;;;
;;;; Roots: a program with a main is closed, and main is its one entry;
;;;; every written parameter of main is observable and everything else is
;;;;  reached from call sites. A file without a main is a library -- every
;;;; function is an entry point, every written parameter is an output, and
;;;; the analysis correctly reports nothing exploitable.

;;[ja] 関数名 → 書き込みが呼び出し側から「見える」仮引数の添字集合。
;;[ja] mutation-summary の部分集合。--derive の復元判定が使う。
(define param-observable (make-hasheq))

;; Heads whose plain arguments cannot smuggle a vector past the ordered
;; check: calls to translated functions (they appear in mutation-summary)
;; and primitives that read or write elements without retaining their
;; argument. cons and list retain; a binding pair is not a call at all;
;; both therefore fall through to the alias rule.
;;[ja] 頭部 h の直下に置かれた引数が別名を作らないと言えるかを返す。
;;[ja] 翻訳済み関数の呼び出しと、引数を保持しない基本操作だけを認める。
;;[ja] cons や list は引数を保持するので含めない。
(define (alias-benign-head? h)
  (or (hash-has-key? mutation-summary h)
      (memq h '(vector-ref vector-length vector-set! display write newline
                hash-ref hash-set! hash-has-key? hash-count
                let let* letrec do if cond when unless begin and or not else
                + - * / remainder quotient modulo max min abs expt sqrt
                sin cos tan exp log floor
                < > <= >= = zero? even? odd? negative? positive?
                eq? eqv? equal?))))

;; Symbols in BODY with at least one occurrence in a non-benign position.
;;[ja] body の中で、別名を作りうる位置に一度でも現れた記号の集合を
;;[ja] ハッシュ表として返す。そうした変数は順序に基づく生存判定を
;;[ja] すり抜けて別名から読まれうるので、常に観測可能とみなす。
(define (aliased-symbols body)
  (define acc (make-hasheq))
  ;;[ja] 式 f を走査し、benign? が偽の位置にある記号を acc に記録する。
  ;;[ja] 頭部が良性なら直下の引数は良性、そうでなければ非良性として下る。
  (define (walk f benign?)
    (cond [(symbol? f) (unless benign? (hash-set! acc f #t))]
          [(and (pair? f) (eq? (car f) 'quote)) (void)]
          [(pair? f)
           (let ([b (and (symbol? (car f)) (alias-benign-head? (car f)))])
             ;; the head position itself is a reference only for calls
             (for ([sub (cdr f)]) (walk sub b))
             (unless (symbol? (car f)) (walk (car f) #f)))]
          [else (void)]))
  (for ([f body]) (walk f #f))
  acc)

;; Symbols bound by let, let*, do or a named let anywhere in BODY.
;;[ja] body 内のどこかで let 系や do、名前付き let によって束縛される
;;[ja] 記号の集合をハッシュ表として返す。仮引数でも局所変数でもない
;;[ja] 記号を大域変数と判定するために使う。
(define (locally-bound-symbols body)
  (define acc (make-hasheq))
  ;;[ja] 束縛の組 b の変数名を acc に登録する。
  (define (bind! b) (when (and (pair? b) (symbol? (car b)))
                      (hash-set! acc (car b) #t)))
  ;;[ja] 式 f を再帰的にたどり、束縛形に出会うたびに bind! を呼ぶ。
  (define (walk f)
    (match f
      [`(quote ,_) (void)]
      [`(let ,(? symbol? nm) ,bs ,body ...)
       (hash-set! acc nm #t) (for-each bind! bs) (for-each walk (append (map cdr bs) body))]
      [`(,(or 'let 'let* 'letrec) ,bs ,body ...)
       (for-each bind! bs) (for-each walk (append (append-map cdr bs) body))]
      [`(do ,bs ,_ ,body ...)
       (for-each bind! bs) (for-each walk (append (append-map cdr bs) (cdr f)))]
      [(? list?) (for-each walk f)]
      [_ (void)]))
  (for ([f body]) (walk f))
  acc)

;; Every call to a translated function inside FORMS, in evaluation order,
;; each with the forms that may still evaluate after it. Loops contribute
;; their whole recurring part as "after" for everything inside them.
;;[ja] body 中にある翻訳済み関数への呼び出しを評価順に集め、それぞれに
;;[ja] 「その後にまだ評価されうる式の列」を添えたリストを返す。
;;[ja] ループの中では繰り返し部分全体を後続として数える。
(define (collect-call-sites body)
  (define out '())
  ;;[ja] 呼び出し call とその後続式 laters の組を結果に積む。
  (define (visit call laters) (set! out (cons (cons call laters) out)))
  ;;[ja] 式列 forms を順に処理する。各式の後続は列の残りと laters。
  (define (seq forms laters)
    (let loop ([fs forms])
      (unless (null? fs)
        (form (car fs) (append (cdr fs) laters))
        (loop (cdr fs)))))
  ;;[ja] 1 つの式 f を形ごとに分解し、部分式へ適切な後続 laters を
  ;;[ja] 付けて下る。翻訳済み関数の呼び出しに達したら visit する。
  (define (form f laters)
    (match f
      [`(quote ,_) (void)]
      [`(let ,(? symbol? _) ,bs ,body ...)
       ;; value-position loop: its whole body may run again
       (let ([cycle body])
         (seq (map cadr (filter pair? bs)) (append cycle laters))
         (for ([b body]) (form b (append cycle laters))))]
      [`(,(or 'let 'let* 'letrec) ,bs ,body ...)
       (seq (map cadr (filter (lambda (b) (and (pair? b) (pair? (cdr b)))) bs))
            (append body laters))
       (seq body laters)]
      [`(do ,bs (,test ,res ...) ,body ...)
       (let* ([inits (map cadr (filter (lambda (b) (and (pair? b) (pair? (cdr b)))) bs))]
              [steps (append-map cddr (filter pair? bs))]
              [cycle (append (list test) res body steps)])
         (seq inits (append cycle laters))
         (for ([c cycle]) (form c (append cycle laters))))]
      [`(if ,c ,t) (form c (cons t laters)) (form t laters)]
      [`(if ,c ,t ,e) (form c (list* t e laters)) (form t laters) (form e laters)]
      [`(,(or 'when 'unless) ,c ,body ...)
       (form c (append body laters)) (seq body laters)]
      [`(cond ,clauses ...)
       (let loop ([cs clauses])
         (unless (null? cs)
           (let* ([cl (car cs)] [rest (append-map (lambda (x) x) (cdr cs))])
             (when (pair? cl)
               (if (eq? (car cl) 'else)
                   (seq (cdr cl) laters)
                   (begin (form (car cl) (append (cdr cl) rest laters))
                          (seq (cdr cl) laters)))))
           (loop (cdr cs))))]
      [`(,(or 'begin 'and 'or) ,body ...) (seq body laters)]
      [`(,(? symbol? h) ,args ...)
       (seq args laters)
       (when (hash-has-key? mutation-summary h) (visit f laters))]
      [(? list?) (seq f laters)]
      [_ (void)]))
  (seq body '())
  out)

;;[ja] 各関数の書き込み仮引数のうち、どれかの呼び出し元から結果が
;;[ja] 読まれうるものの添字集合を param-observable に計算して入れる。
;;[ja] main があればそれだけを根とし、なければ全関数を入口とみなす。
;;[ja] 呼び出し地点ごとの生存判定を不動点として繰り返す。
(define (compute-param-liveness! prog)
  (compute-mutation-summaries! prog)
  (hash-clear! param-observable)
  (define forms (match prog [`(begin ,fs ...) fs] [_ (list prog)]))
  (define defs
    (filter (lambda (f) (match f [`(define (,_ ,_ ...) ,_ ...) #t] [_ #f])) forms))
  (define others
    (filter (lambda (f) (match f [`(define ,_ ...) #f] [_ #t])) forms))
  (define fnames
    (map (lambda (d) (match d [`(define (,f ,_ ...) ,_ ...) f])) defs))
  (for ([f fnames]) (hash-set! param-observable f '()))
  (for ([f (if (memq 'main fnames) '(main) fnames)])
    (hash-set! param-observable f (hash-ref mutation-summary f '())))
  ;; static per-function facts, computed once
  (define contexts
    (append
     (for/list ([d defs])
       (match d
         [`(define (,g ,ps ...) ,body ...)
          (list g ps (locally-bound-symbols body) (aliased-symbols body)
                (collect-call-sites body))]))
     ;; top-level expressions: a pseudo-caller with no parameters and no
     ;; locals, so every vector it hands over is global and observable
     (if (null? others)
         '()
         (list (list '#%top '() (make-hasheq) (make-hasheq)
                     (collect-call-sites others))))))
  (let fix ()
    (define changed #f)
    (for ([ctx contexts])
      (match-define (list g ps locals aliased sites) ctx)
      (define g-obs (hash-ref param-observable g '()))
      (for ([site sites])
        (match-define (cons call laters) site)
        (define callee (car call))
        (define written (hash-ref mutation-summary callee '()))
        (for ([i written])
          (define a (and (< i (length (cdr call))) (list-ref (cdr call) i)))
          (when (and (symbol? a)
                     (not (memq i (hash-ref param-observable callee '())))
                     (or (hash-ref aliased a #f)
                         (ormap (lambda (l) (sexp-occurs? a l)) laters)
                         (let ([j (index-of ps a)])
                           (if j
                               (and (memq j g-obs) #t)
                               (not (hash-ref locals a #f))))))
            (hash-set! param-observable callee
                       (sort (cons i (hash-ref param-observable callee '())) <))
            (set! changed #t)))))
    (when changed (fix))))

;;[ja] 関数 f が書き込みうる仮引数の添字リストを返す。
(define (function-written-params f) (hash-ref mutation-summary f '()))
;;[ja] 関数 f の書き込みのうち呼び出し元から観測される仮引数の添字を返す。
(define (function-output-params f)  (hash-ref param-observable f '()))
;;[ja] 関数 f が書き込むが誰にも読まれない、作業領域扱いの仮引数の
;;[ja] 添字を返す。書き込み集合から観測可能な集合を引いたもの。
(define (function-scratch-params f)
  (filter (lambda (i) (not (memq i (function-output-params f))))
          (function-written-params f)))
;;[ja] 書き込みのある全関数について (名前 出力添字 作業領域添字) を
;;[ja] 名前順に並べた連想リストを返す。外部から解析結果を見るための窓口。
(define (param-liveness-alist)
  (sort (for/list ([(f w) (in-hash mutation-summary)]
                   #:unless (null? w))
          (list f (function-output-params f) (function-scratch-params f)))
        symbol<? #:key car))

;; Does STMT possibly write V? The per-name direction of the same walk,
;; used to establish that V is write-free across a span of statements.
;;[ja] 文 stmt が変数 v を書き込む可能性があるかを返す。
;;[ja] expr-mutated-params と同じ走査を、変数 1 つに絞った向きで行う。
;;[ja] ある区間で v が書き込みなしであることを示すために使う。
(define (stmt-writes? stmt v)
  (match stmt
    [`(quote ,_) #f]
    [`(set! ,x ,e) (or (eq? x v) (stmt-writes? e v))]
    [`(,(? (lambda (h) (memq h '(vector-set! set-car! set-cdr! hash-set!))) _) ,x ,es ...)
     (or (eq? x v) (ormap (lambda (e) (stmt-writes? e v)) es))]
    [`(force ,e) (or (eq? (forced-root e) v) (stmt-writes? e v))]
    [`(,(? symbol? f) ,args ...)
     (or (cond
	  [(hash-ref mutation-summary f #f)
	   => (lambda (idxs)
		(ormap (lambda (i) (and (< i (length args)) (eq? (list-ref args i) v)))
		       idxs))]
	  [(binding-op? f)
	   (ormap (lambda (i) (and (< i (length args)) (eq? (list-ref args i) v)))
		  (binding-op-mutates f))]
	  [(memq f non-mutating-heads) #f]
	  [else (and (memq v args) #t)])
	 (ormap (lambda (e) (stmt-writes? e v)) args))]
    [(? list?) (ormap (lambda (e) (stmt-writes? e v)) stmt)]
    [_ #f]))

;;[ja] ============================================================
;;[ja] 翻訳の本体(このファイルの大半は この 1 関数の内部定義)。
;;[ja] expr-org(展開済み begin 式)を受け、ヘッダ用/本体用の 2 つの
;;[ja] ポートへ C++ を書き出す。おおまかな内部地図:
;;[ja]   ・pre-cexp/post-cexp — 「式の前後に置くべき文」のスコープ別
;;[ja]     スタック。C++ の式の中に文を書けないので、named let から
;;[ja]     作った struct 定義などを一旦ここへ積み、文境界で吐き出す。
;;[ja]   ・infer-type-from-org-expr — α 変換+依存解析+型推論の呼び口
;;[ja]     (type-infer-match.scm 側。HM / relational の分岐もそこ)
;;[ja]   ・ctype/cpptype/sexp->cpptype — 推論結果の型 → C++ 型文字列
;;[ja]   ・cexp — 式の翻訳(値になるもの)
;;[ja]   ・cstat/cstat-ret — 文の翻訳(値を捨てる/return を付ける)
;;[ja]   ・clambda — λ・named let をクロージャ struct へ
;;[ja]   ・cdefs/cdeffun — トップレベル define(署名・テンプレート判定・
;;[ja]     SCM2CPP_FN 付与・-M 用の capi-add! もここ)
;;[ja] ============================================================
(define (scm2cpp-match-port expr-org
			    port-h port-c
			    )
  ;;[ja] 略記: str-a = string-append、str-j = string-join。
  (define str-a string-append)
  (define str-j string-join)
  ;;[ja] 既定の出力先。本体用ポートに向ける。
  (define port-o port-c)
  ;;[ja] 文字列 str を既定の出力ポート port-o へ書く。
  (define (pout str) (display str port-o))
  ;;[ja] 文字列 str をヘッダ用ポート port-h へ書く。
  (define (hout str) (display str port-h))
  ;;[ja] 文字列 str を本体用ポート port-c へ書く。
  (define (cout str) (display str port-c))
  ;;[ja] str の末尾にセミコロンと改行を付けてヘッダ用ポートへ書く。
  (define (hout-semi str) (fprintf port-h "~a;~n" str))
  ;;[ja] スコープごとの「式の前に置く文」「後に置く文」のスタック。
  ;;[ja] 深さは scope-level と同期し、inc-lv / dec-lv で積み降ろす。
  (define pre-cexp  (list->stack (list "")))
  (define post-cexp (list->stack (list "")))
  ;;[ja] 「今の式の前に置くべき文」を、スコープスタック pre-cexp の
  ;;[ja] 深さ lv の段に文字列として追記する。
  (define (add-pre-cexp  str [lv 0])  (stack-set-apply! pre-cexp  lv (lambda (x) (str-a x str)))) ;; (set! pre-cexp (str-a pre-cexp str)))
  ;;[ja] add-pre-cexp のセミコロンと改行を付ける版。
  (define (add-pre-cexp-semi str [lv 0])  (add-pre-cexp  (format "~a;~n" str) lv))
  ;;[ja] 「今の式の後に置くべき文」を post-cexp の深さ lv の段に追記する。
  (define (add-post-cexp str [lv 0])  (stack-set-apply! post-cexp lv (lambda (x) (str-a x str))))
  ;;[ja] add-post-cexp のセミコロンと改行を付ける版。
  (define (add-post-cexp-semi str [lv 0]) (add-post-cexp (format "~a;~n" str) lv))
  ;;[ja] 今のスコープの深さ。pre-cexp / post-cexp の段数に一致する。
  (define scope-level 0)
  ;;[ja] スコープを 1 段深くし、pre-cexp と post-cexp に新しい段を積む。
  ;;[ja] str0 と str1 はその段の初期文字列。
  (define (inc-lv [str0 ""] [str1 ""])
    (set! scope-level (+ scope-level 1))
    (stack-push! str0 pre-cexp )
    (stack-push! str1 post-cexp))
  ;;[ja] スコープを 1 段抜け、その段に溜まった後置文と前置文を
  ;;[ja] この順の 2 値で返す。呼び出し側がそれを文境界に吐き出す。
  (define (dec-lv)
    (set! scope-level (+ scope-level 1))
    (values
     (stack-pop! post-cexp)
     (stack-pop! pre-cexp)))
  ;;[ja] inc-lv してから body を評価するマクロ。
  (define-macro (begin-inc-lv . body)
   `(begin 
      (inc-lv)
      ,@body))
  ;;[ja] body を評価した後に dec-lv を呼び、body の値を返すマクロ。
  (define-macro (begin-dec-lv . body)
   (let ((begin-dev-lv-last-ret (gensym)))
     `(let ((,begin-dev-lv-last-ret (begin ,@body)))
	(dec-lv)
	,begin-dev-lv-last-ret
	)))
  ;;[ja] inc-lv、body の評価、dec-lv をこの順で行い body の値を返すマクロ。
  (define-macro (begin-inc-dev-lv . body)
   (let ((begin-inc-dev-lv-last-ret (gensym)))
     `(let ((,begin-inc-dev-lv-last-ret (begin-inc-lv ,@body)))
	(dec-lv)
	,begin-inc-dev-lv-last-ret
	)))
  ;;;; Parallel back ends, selected through SCM2CPP_PARALLEL.
  ;;;;
  ;;;; Because a named let and a do loop are emitted as an ordinary for loop
  ;;;; rather than as a closure, a directive placed in front of it is enough to
  ;;;; hand the loop to OpenMP, to an offload target or to OpenACC.
  ;;;;
  ;;;; Which loop gets it is decided by the test below rather than by taking
  ;;;; the outermost one, which is a guess and not an analysis: on a
  ;;;; coordinate descent the outermost loop is the sweep, whose iterations
  ;;;; read what the one before wrote, and annotating it produces a data race
  ;;;; -- wrong answers that differ from run to run, with no diagnostic. The
  ;;;; test is conservative in one direction only. A loop is annotated only
  ;;;; when every write it makes provably lands somewhere no other iteration
  ;;;; of that loop touches; anything the analysis does not understand counts
  ;;;; as a dependence. So a loop that could have been parallel may be left
  ;;;; alone, but an unsafe one is not annotated.
  ;;;; in-parallel-loop records whether generation is already inside an
  ;;;; annotated loop, since nesting a second directive inside the first
  ;;;; oversubscribes rather than helps.
  ;;[ja] 既に並列指示を付けたループの内側を生成中なら #t(入れ子は付けない)。
  (define in-parallel-loop #f)

  ;;[ja] 記号 s が式 e のどこかに現れるかを返す。
  ;;[ja] ループ変数への言及を調べるための小さな走査。
  (define (sym-in? s e)
    (cond [(eq? s e) #t]
          [(pair? e) (or (sym-in? s (car e)) (sym-in? s (cdr e)))]
          [else #f]))

  ;; The bound of every counted loop inside E, as written: (do ((k 0 ...))
  ;; ((= k p)) ...) contributes p. Used to recognise a row-major index.
  ;;[ja] 式 e の中にある計数 do ループの上限式をすべて集めて返す。
  ;;[ja] 行優先の添字 i*S+j の S が内側ループの上限と一致するかの判定に使う。
  (define (inner-loop-bounds e)
    (cond
      [(not (pair? e)) '()]
      [(and (eq? (car e) 'do) (pair? (cdr e)) (pair? (cddr e)))
       (append (match (car (caddr e))
                 [`(= ,_ ,b) (list b)]
                 [_ '()])
               (inner-loop-bounds (cdr e)))]
      [else (append (inner-loop-bounds (car e)) (inner-loop-bounds (cdr e)))]))

  ;; Does IDX name a different element for every value of VAR? Two shapes are
  ;; recognised: the index is the variable itself, and the row-major
  ;; (+ (* VAR S) REST) where REST does not mention VAR and S is the extent
  ;; an inner loop runs to -- which is what makes the rows disjoint.
  ;;[ja] 添字式 idx がループ変数 var の値ごとに別々の要素を指すかを返す。
  ;;[ja] 認めるのは var そのものと、行優先の (+ (* var S) rest) で S が
  ;;[ja] 内側ループの上限 bounds に含まれ rest に var が出ない形だけ。
  (define (index-injective? idx var bounds)
    (match idx
      [(? symbol? s) (eq? s var)]
      [`(+ (* ,a ,b) ,rest)
       (and (not (sym-in? var rest))
            (or (and (eq? a var) (member b bounds))
                (and (eq? b var) (member a bounds)))
            #t)]
      [_ #f]))

  ;; Every (vector-set! V IDX _) and (set! X _) in E, with the scalars that
  ;; are bound inside E left out: those are private to one iteration.
  ;;[ja] 式 e 内の vector-set! と set! による書き込みを列挙して返す。
  ;;[ja] 各要素は (vec V IDX) か (scalar X 文) の形。e の内側で束縛された
  ;;[ja] スカラーは反復ごとに私有なので local に積んで除外する。
  (define (loop-writes e local)
    (match e
      [`(vector-set! ,v ,idx ,val)
       (append (list (list 'vec v idx)) (loop-writes val local))]
      [`(set! ,(? symbol? x) ,val)
       (append (if (memq x local) '() (list (list 'scalar x e)))
               (loop-writes val local))]
      [`(let ,(? list? bs) ,body ...)
       (let ([local* (append (filter-map (lambda (b) (and (pair? b) (car b))) bs) local)])
         (append (append-map (lambda (b) (if (pair? b) (loop-writes (cadr b) local) '())) bs)
                 (append-map (lambda (x) (loop-writes x local*)) body)))]
      [`(do ,(? list? bs) ,pred ,body ...)
       (let ([local* (append (filter-map (lambda (b) (and (pair? b) (car b))) bs) local)])
         (append-map (lambda (x) (loop-writes x local*)) body))]
      [(? list?) (append-map (lambda (x) (loop-writes x local)) e)]
      [_ '()]))

  ;; Every (vector-ref V IDX) in E.
  ;;[ja] 式 e 内の vector-ref をすべて (V IDX) の組として列挙して返す。
  (define (loop-reads e)
    (match e
      [`(vector-ref ,v ,idx) (cons (list v idx) (loop-reads idx))]
      [(? list?) (append-map loop-reads e)]
      [_ '()]))

  ;; Is X used anywhere other than as the accumulator of its own updates?
  ;; This is what separates a reduction from a scan. Both write the scalar
  ;; the same way; the scan also *reads* the running value -- (vector-set! s
  ;; i acc) -- and so needs the sum of the iterations before it, which a
  ;; reduction's per-thread partial is not. Annotating one as the other is
  ;; silent and wrong: a prefix sum came out as one thread's share.
  ;;[ja] スカラー x が、自分自身を更新する set! 以外の場所で読まれて
  ;;[ja] いるかを返す。読まれていればスキャンであって縮約ではないので、
  ;;[ja] reduction 節として扱ってはいけない。
  (define (used-outside-updates? x e)
    (cond
      [(and (pair? e) (eq? (car e) 'set!) (pair? (cdr e)) (eq? (cadr e) x))
       (match (caddr e)
         [`(,_ ,a ,b) (or (and (not (eq? a x)) (used-outside-updates? x a))
                          (and (not (eq? b x)) (used-outside-updates? x b)))]
         [other (used-outside-updates? x other)])]
      [(eq? e x) #t]
      [(pair? e) (or (used-outside-updates? x (car e))
                     (used-outside-updates? x (cdr e)))]
      [else #f]))

  ;; A scalar written only as (set! X (+ X E)), and never read apart from
  ;; that, is a sum reduction, and the directive can carry it instead of the
  ;; loop being rejected for it.
  ;;[ja] 書き込み一覧 writes の中でスカラー x への更新がすべて
  ;;[ja] (set! x (+ x E)) か (set! x (* x E)) の形で揃っていれば、
  ;;[ja] その演算子記号 + か * を返す。揃わなければ #f。
  (define (reduction-op writes x)
    (let ([ws (filter (lambda (w) (and (eq? (car w) 'scalar) (eq? (cadr w) x))) writes)])
      (and (pair? ws)
           (let ([ops (map (lambda (w)
                             (match (caddr w)
                               [`(set! ,_ (+ ,a ,_)) (and (eq? a x) '+)]
                               [`(set! ,_ (+ ,_ ,a)) (and (eq? a x) '+)]
                               [`(set! ,_ (* ,a ,_)) (and (eq? a x) '*)]
                               [`(set! ,_ (* ,_ ,a)) (and (eq? a x) '*)]
                               [_ #f]))
                           ws)])
             (and (andmap (lambda (o) (eq? o (car ops))) ops) (car ops))))))

  ;; Effects whose order is part of the answer even though no memory is
  ;; shared. Writing to a stream is the case here: a loop that prints one
  ;; line per iteration produces its lines interleaved when the iterations
  ;; run at once, which is wrong however sound the data dependences are.
  ;;[ja] 式 e が display や newline などの出力を含むかを返す。
  ;;[ja] 出力の順序は答えの一部なので、含むループは並列化しない。
  (define (does-io? e)
    (cond
      [(and (pair? e) (memq (car e) '(display write newline write-string print))) #t]
      [(pair? e) (or (does-io? (car e)) (does-io? (cdr e)))]
      [else #f]))

  ;; A call to a function that writes through a parameter can reach memory
  ;; this analysis never sees, so a loop containing one is left alone. The
  ;; mutation summary already records which parameters each function writes;
  ;; a name absent from it is a primitive, which writes nothing.
  ;;[ja] 式 e が、仮引数を通して書き込む翻訳済み関数の呼び出しを含むか
  ;;[ja] を返す。この解析の目に見えないメモリへ届きうるので、含む
  ;;[ja] ループは並列化の対象から外す。
  (define (calls-mutating-function? e)
    (cond
      [(and (pair? e) (symbol? (car e))
            (pair? (hash-ref mutation-summary (car e) '()))) #t]
      [(pair? e) (or (calls-mutating-function? (car e))
                     (calls-mutating-function? (cdr e)))]
      [else #f]))

  ;; Can the loop over VAR with body E run its iterations in any order?
  ;; Returns #f, or the list of reduction clauses needed (possibly empty).
  ;;[ja] ループ変数 var、本体 e のループの各反復を任意の順で実行できるか
  ;;[ja] を判定する。入出力や不明な書き込みがなく、書く要素が反復ごとに
  ;;[ja] 単射で、書いた配列を別添字で読まず、反復をまたぐスカラーが
  ;;[ja] 縮約に限られるとき、必要な reduction 節の文字列リストを返す。
  (define (loop-independent? var e)
    (let* ([bounds (inner-loop-bounds e)]
           [writes (loop-writes e '())]
           [vec-writes (filter (lambda (w) (eq? (car w) 'vec)) writes)]
           [scalar-names (remove-duplicates
                          (map cadr (filter (lambda (w) (eq? (car w) 'scalar)) writes)))]
           [reductions (map (lambda (x)
                              (cons x (and (not (used-outside-updates? x e))
                                           (reduction-op writes x))))
                            scalar-names)])
      (and
       ;; Order-observable effects, and writes this analysis cannot see.
       (not (does-io? e))
       (not (calls-mutating-function? e))
       ;; Every element written must belong to this iteration alone.
       (andmap (lambda (w) (index-injective? (caddr w) var bounds)) vec-writes)
       ;; And an array this loop writes must not be read at some other index,
       ;; which would be another iteration's element.
       (andmap (lambda (r)
                 (let ([v (car r)] [idx (cadr r)])
                   (andmap (lambda (w) (or (not (eq? (cadr w) v))
                                           (equal? (caddr w) idx)))
                           vec-writes)))
               (loop-reads e))
       ;; A scalar carried across iterations is a dependence unless it is a
       ;; reduction the directive can express.
       (andmap cdr reductions)
       (map (lambda (r) (format "reduction(~a:~a)" (cdr r) (cname (car r)))) reductions))))

  ;; How many iterations, as written, for the profitability guard. A loop
  ;; that does not start at zero counts as bound minus start.
  ;;[ja] do の束縛 bindings と終了条件 pred から、書かれた通りの反復回数
  ;;[ja] を表す式を返す。1 変数を 1 ずつ増やし = で止める形だけ認め、
  ;;[ja] それ以外は #f。並列化の採算判定に使う。
  (define (loop-trip-count bindings pred)
    (match (list bindings (car pred))
      [(list (list (list v start `(+ ,v2 1))) `(= ,v3 ,bound))
       (and (eq? v v2) (eq? v v3)
            (if (equal? start 0) bound `(- ,bound ,start)))]
      [_ #f]))

  ;; Threads are not free: spawning them costs microseconds and a short loop
  ;; is over in nanoseconds. When the count is a literal the decision is made
  ;; here; when it is a variable the pragma carries an if clause and the
  ;; runtime decides, which is the only way to serve one kernel called with
  ;; both a hundred and a hundred thousand columns.
  ;;[ja] 並列化する価値があるとみなす最小反復回数を返す。
  ;;[ja] 環境変数 SCM2CPP_OMP_MIN で上書きでき、既定は 1024。
  (define (omp-min-trip)
    (let ([s (getenv "SCM2CPP_OMP_MIN")])
      (or (and s (string->number s)) 1024)))

  ;;[ja] do ループの直前に置く並列化ディレクティブの文字列を返す。
  ;;[ja] SCM2CPP_PARALLEL が omp/gpu/acc のいずれかで、既に並列ループの
  ;;[ja] 内側でなく、loop-independent? が通り、反復回数が閾値以上のとき
  ;;[ja] だけ非空。回数が変数なら if 節を付けて実行時に判断させる。
  (define (parallel-pragma bindings pred body)
    (let ([m (getenv "SCM2CPP_PARALLEL")])
      (if (or in-parallel-loop (not m) (string=? m "thrust") (not (pair? bindings)))
          ""
          (let* ([var (car (car bindings))]
                 [carried (filter (lambda (b) (sym-in? (car b) (caddr b)))
                                  (cdr bindings))]
                 [clauses (and (null? carried) (loop-independent? var `(begin ,@body)))]
                 [trip (loop-trip-count bindings pred)])
            (cond
              [(not clauses) ""]
              [(and (number? trip) (< trip (omp-min-trip))) ""]
              [else
               (let* ([guard (if (or (not trip) (number? trip))
                                 ""
                                 (format " if(~a > ~a)" (cexp trip) (omp-min-trip)))]
                      [extra (if (null? clauses) "" (string-append " " (string-join clauses " ")))]
                      [dir (cond
                             [(string=? m "omp") "#pragma omp parallel for"]
                             [(string=? m "gpu") "#pragma omp target teams distribute parallel for"]
                             [(string=? m "acc") "#pragma acc parallel loop"]
                             [else #f])])
                 (if dir (format "~n~a~a~a~n" dir extra guard) ""))])))))
  ;;;; The Thrust back end does not annotate the loop but replaces it. Two
  ;;;; shapes are recognised, both written as an accumulator over a vector:
  ;;;; a running sum written back elementwise is a scan, and one that is not
  ;;;; written back is a reduction.
  ;;[ja] 環境変数 SCM2CPP_PARALLEL が thrust に設定されているかを返す。
  (define (thrust-mode?) (equal? (getenv "SCM2CPP_PARALLEL") "thrust"))
  ;;;; The integral-image rewrite, selected through SCM2CPP_INTEG.
  ;;;;
  ;;;; The value is either "auto", applying the rewrite wherever a box-sum
  ;;;; nest of any rank is recognised, or a space-separated list of NAME or
  ;;;; NAME:RANK tokens naming the arrays it may be applied to. NAME alone
  ;;;; matches at whichever rank the nest is actually found; NAME:RANK
  ;;;; additionally asserts what that rank ought to be, and is rejected if
  ;;;; the nest found does not match it. The names are hints: they may be
  ;;;; written by hand, or proposed by a language model (--llm-hints), and a
  ;;;; hint on an array whose loop nest does not match the shape is simply
  ;;;; never used. The rewrite is valid when every write to the array
  ;;;; precedes the nest, which the recogniser cannot see; that is what the
  ;;;; hint asserts.
  ;;[ja] 環境変数 SCM2CPP_INTEG を読んで積分画像化のヒントを返す。
  ;;[ja] 未設定なら空リスト、auto なら記号 auto、それ以外は
  ;;[ja] (配列名 . 階数か#f) の連想リスト。
  (define (integ-hints)
    (let ([m (getenv "SCM2CPP_INTEG")])
      (cond [(not m) '()]
	    [(string=? m "auto") 'auto]
	    [else (map (lambda (tok)
			 (let ([parts (string-split tok ":")])
			   (cons (string->symbol (car parts))
				 (and (pair? (cdr parts)) (string->number (cadr parts))))))
		       (string-split m))])))
  ;; The hint names arrays as they appear in the source, but by the time
  ;; the nest is matched alpha conversion may have renamed the symbol (a
  ;; local x alongside some function's parameter x, say), so compare on the
  ;; original name that orgn recovers.
  ;;[ja] 配列 v の階数 rank の入れ子に積分画像化を適用してよいかを返す。
  ;;[ja] auto なら常に真。名前指定なら α 変換前の元の名前でも照合し、
  ;;[ja] 階数が指定されていればそれも一致することを要求する。
  (define (integ-hinted? v rank)
    (let ([h (integ-hints)])
      (cond [(eq? h 'auto) #t]
	    [(list? h) (let ([e (or (assq v h) (assq (orgn v) h))])
			 (and e (or (not (cdr e)) (= (cdr e) rank))))]
	    [else #f])))
  ;; The element type for the template argument, taken from the literal that
  ;; initialises the accumulator: an exact zero accumulates ints, an inexact
  ;; one doubles.
  ;;[ja] 累積変数の初期リテラル z から表の要素型を決める。
  ;;[ja] 非正確な実数なら double、それ以外は int。
  (define (integ-elem-type z)
    (if (and (real? z) (inexact? z)) "double" "int"))
  ;; The rank-n box-sum-from-origin nest, generalising
  ;;   (do ((i 0 (+ i 1))) ((= i n))
  ;;     (do ((j 0 (+ j 1))) ((= j n))
  ;;       (let ((acc 0))
  ;;         (do ((a 0 (+ a 1))) ((= a (+ i 1)))
  ;;           (do ((b 0 (+ b 1))) ((= b (+ j 1)))
  ;;             (set! acc (+ acc (vector-ref v (+ (* a n) b))))))
  ;;         (vector-set! s (+ (* i n) j) acc))))
  ;; to n output loops (i, j, ...) and n matching accumulation loops (a, b,
  ;; ...), one pair per axis, each accumulation loop k bounded by (+ Ik 1)
  ;; where Ik is the output loop at the same position. n is discovered from
  ;; the nest itself, not told to the recogniser: peeling stops as soon as
  ;; the (let ((acc 0)) ...) at the centre is found. The two axes need not
  ;; share a size; only that v and s are indexed by the same row-major
  ;; flattening of the same n indices with the same per-axis sizes.
  ;;
  ;; Peel one output loop layer; returns (values I N body) or (values #f #f #f).
  ;;[ja] 出力側の do ループを 1 層剥がし、ループ変数・上限・本体の 3 値を
  ;;[ja] 返す。0 から 1 ずつ増やして = で止まる 1 変数の形だけを認める。
  (define (integ-peel-output expr)
    (match expr
      [`(do ((,I 0 (+ ,I2 1))) ((= ,I3 ,N)) ,B)
       #:when (and (eq? I I2) (eq? I I3))
       (values I N B)]
      [_ (values #f #f #f)]))
  ;; Peel one accumulation loop bounded by (+ IK 1); returns (values A body) or (values #f #f).
  ;;[ja] 累積側の do ループを 1 層剥がす。上限が対応する出力ループ変数
  ;;[ja] IK に 1 を足した形であることを要求し、ループ変数と本体を返す。
  (define (integ-peel-accum expr IK)
    (match expr
      [`(do ((,A 0 (+ ,A2 1))) ((= ,A3 (+ ,IK2 1))) ,B)
       #:when (and (eq? A A2) (eq? A A3) (eq? IK2 IK))
       (values A B)]
      [_ (values #f #f)]))
  ;; Peel one accumulation loop per entry of Is, in the same order; returns
  ;; (values (list A ...) final-form) or (values #f #f).
  ;;[ja] 出力ループ変数の列 Is と同じ順に累積ループを 1 層ずつ剥がし、
  ;;[ja] 累積ループ変数の列と最内の式を返す。途中で形が崩れれば #f #f。
  (define (integ-peel-accums body Is)
    (if (null? Is)
	(values '() body)
	(let-values ([(A rest) (integ-peel-accum body (car Is))])
	  (if (not A) (values #f #f)
	      (let-values ([(As final) (integ-peel-accums rest (cdr Is))])
		(if (not As) (values #f #f) (values (cons A As) final)))))))
  ;; The operator catalogue: which folds may take the table route at
  ;; all, what identity each demands at the centre, which C++ tag
  ;; carries it, and which class it falls in. + keeps the historical
  ;; integral_image emission; every other catalogued operator goes
  ;; through monoid_table, whose prefix read needs no inverse -- which
  ;; is exactly why the origin-anchored box form is answerable for any
  ;; of these, while inclusion-exclusion over arbitrary boxes would
  ;; demand the group and stays with +.
  ;;[ja] 表経路に乗せられる畳み込み演算子の目録。各行は
  ;;[ja] 演算子、初期値が単位元かを判定する述語、C++ 側のタグ、分類。
  ;;[ja] + だけは従来の integral_image、他は monoid_table で出力する。
  (define integ-op-catalog
    ;; op    identity-ok?                      C++ tag      class
    `((+    ,(lambda (z) (and (real? z) (zero? z)))          #f     group)
      (*    ,(lambda (z) (and (real? z) (= z 1)))            "mt_mul" monoid)
      (min  ,(lambda (z) (and (real? z) (infinite? z)
                              (positive? z)))                "mt_min" idempotent)
      (max  ,(lambda (z) (and (real? z) (infinite? z)
                              (negative? z)))                "mt_max" idempotent)))
  ;;[ja] 演算子 op の目録行を返す。載っていなければ #f。
  (define (integ-op-entry op) (assq op integ-op-catalog))
  ;; identity literal, printable in C++
  ;;[ja] 単位元リテラル z を C++ で書ける文字列にする。
  ;;[ja] 無限大は numeric_limits で表し、それ以外は数を文字列化する。
  (define (integ-id-cexp z)
    (cond [(and (real? z) (infinite? z))
           (if (positive? z)
               "(std::numeric_limits<double>::infinity())"
               "(-std::numeric_limits<double>::infinity())")]
          [else (number->string z)]))
  ;; Peel output loops until the (let ((acc 0)) accum-nest vector-set!) at
  ;; the centre is found; returns (values Is Ns acc-var zero-lit accum-nest
  ;; vector-set!-form) or six #f if the nest never bottoms out that way.
  ;;[ja] 出力ループを中心の (let ((acc 初期値)) 累積入れ子 vector-set!)
  ;;[ja] に当たるまで剥がし続け、階数を入れ子自身から発見する。
  ;;[ja] 出力変数列、上限列、累積変数、初期値、累積入れ子、書き込み形の
  ;;[ja] 6 値を返し、その形で底に着かなければ 6 つの #f を返す。
  (define (integ-discover expr)
    (let loop ([e expr] [Is '()] [Ns '()])
      (match e
	[`(let ((,ACC ,(? number? Z))) ,ACCNEST ,VSET)
	 ;; the seed literal is the fold's identity; which values are
	 ;; legitimate depends on the operator, checked in match-nest
	 ;; once the operator is known
	 #:when (and (real? Z) (pair? Is))
	 (values (reverse Is) (reverse Ns) ACC Z ACCNEST VSET)]
	[_
	 (let-values ([(I N body) (integ-peel-output e)])
	   (if (not I) (values #f #f #f #f #f #f)
	       (loop body (cons I Is) (cons N Ns))))])))
  ;; Row-major flattening of VARS over per-axis sizes DIMS, as an s-expression
  ;; matched against the source's own index expression: (v1*d2+v2)*d3+v3 ...
  ;;[ja] 添字変数列 vars と軸ごとの大きさ dims から、行優先の平坦化
  ;;[ja] 添字を S 式として組み立てる。原始プログラムの添字式と equal?
  ;;[ja] で照合するために使う。
  (define (integ-flatten vars dims)
    (let loop ([acc (car vars)] [vs (cdr vars)] [ds (cdr dims)])
      (if (null? vs) acc
	  (loop `(+ (* ,acc ,(car ds)) ,(car vs)) (cdr vs) (cdr ds)))))
  ;; The same flattening, rendered as C++ text over already-formatted operands.
  ;;[ja] integ-flatten と同じ平坦化を、整形済みの C++ 文字列に対して行う。
  (define (integ-cexp-flatten vars dims)
    (let loop ([acc (car vars)] [vs (cdr vars)] [ds (cdr dims)])
      (if (null? vs) acc
	  (loop (format "(~a*~a+~a)" acc (car ds) (car vs)) (cdr vs) (cdr ds)))))
  ;; Pure shape test: (values V S Is Ns Z OP) when EXPR is a box-fold
  ;; nest under a catalogued operator whose centre seed is that
  ;; operator's identity; six #f otherwise. No hint check and no include
  ;; emission, so the share planner below can probe statements without
  ;; side effects.
  ;;[ja] 式 expr が目録にある演算子による原点固定の箱畳み込み入れ子か
  ;;[ja] を副作用なしに判定する。入力配列 V、出力配列 S、出力変数列、
  ;;[ja] 上限列、初期値、演算子の 6 値を返し、違えば 6 つの #f を返す。
  ;;[ja] 入出力が同じ配列なら書き潰した要素を読むので対象外にする。
  (define (integ-match-nest expr)
    (let-values ([(Is Ns ACC Z ACCNEST VSET) (integ-discover expr)])
      (if (not Is)
	  (values #f #f #f #f #f #f)
	  (let-values ([(As final) (integ-peel-accums ACCNEST Is)])
	    (if (not As)
		(values #f #f #f #f #f #f)
		(match (list final VSET)
		  [(list `(set! ,ACC2 (,OP ,ACC3 (vector-ref ,V ,IDX)))
			 `(vector-set! ,S ,OIDX ,ACC4))
		   #:when (and (eq? ACC2 ACC) (eq? ACC3 ACC) (eq? ACC4 ACC)
			       (symbol? V) (symbol? S)
			       (symbol? OP)
			       ;; the operator must be catalogued and the
			       ;; seed must be ITS identity: a + fold
			       ;; seeded with 1.0 is a different program
			       (let ([e (integ-op-entry OP)])
				 (and e ((cadr e) Z)))
			       ;; With the same array as source and
			       ;; destination the nest reads cells it has
			       ;; already overwritten; a snapshot changes
			       ;; the meaning, so no rewrite.
			       (not (eq? V S))
			       (equal? IDX (integ-flatten As Ns))
			       (equal? OIDX (integ-flatten Is Ns)))
		   (values V S Is Ns Z OP)]
		  [_ (values #f #f #f #f #f #f)]))))))
  ;;;; Sharing one table among sibling nests. When several statements of one
  ;;;; sequence are box-sum nests over the same array with the same extents,
  ;;;; and the span from the first to the last is write-free for that array,
  ;;;; a single snapshot serves them all: the first nest declares and builds
  ;;;; the table, without braces so it lives to the end of the enclosing
  ;;;; scope, and the later nests only query it. integ-share-plan holds the
  ;;;; decision while the sequence is being emitted; entries are pushed on
  ;;;; entry to the sequence and popped on the way out, so nested sequences
  ;;;; shadow naturally, as do the identically named C++ declarations.
  ;;[ja] -I の表共有の決定。配列名 → (表名 階数 構築済みか)。列の
  ;;[ja] 出力に入るとき積み、出るとき降ろす。
  (define integ-share-plan '())  ; alist V -> (vector table-name rank built?)
  ;;[ja] 文の列 Es の中で同じ配列・同じ演算子・同じ大きさの箱畳み込み
  ;;[ja] 入れ子が 2 つ以上あり、最初から最後までの区間でその配列への
  ;;[ja] 書き込みがなければ、1 つの表を共有する計画を立てて返す。
  ;;[ja] 返り値は (配列 . 演算子) から (vector 表名 階数 構築済み?) への
  ;;[ja] 連想リスト。大きさが異なる要求が混じる配列は共有しない。
  (define (integ-plan-sequence Es)
    (let* ([nests (filter values
			  (for/list ([e Es] [i (in-naturals)])
			    (let-values ([(V S Is Ns Z OP) (integ-match-nest e)])
			      (and V (list i (list V (length Is) Ns OP))))))]
	   [keys (remove-duplicates (map cadr nests))]
	   [cands
	    (filter-map
	     (lambda (key)
	       (let* ([v (car key)] [rank (cadr key)] [op (cadddr key)]
		      [idxs (filter-map (lambda (n) (and (equal? (cadr n) key) (car n)))
					nests)])
		 (and (>= (length idxs) 2)
		      (integ-hinted? v rank)
		      (let ([lo (apply min idxs)] [hi (apply max idxs)])
			(for/and ([e Es] [i (in-naturals)])
			  (or (< i lo) (> i hi) (memq i idxs)
			      (not (stmt-writes? e v)))))
		      ;; two folds under different operators must not
		      ;; share one table, so the key and the C++ name
		      ;; both carry the operator
		      (cons (cons v op)
			    (vector (format "scm2cpp_ii_~a~a" (cname v)
					    (if (eq? op '+) ""
						(format "_~a" (cname op))))
				    rank #f)))))
	     keys)])
      ;; The same (array, operator) wanted at two different extents
      ;; cannot share one name; leave such an array to the per-nest path.
      (filter (lambda (c)
		(= 1 (length (filter (lambda (d) (equal? (car d) (car c))) cands))))
	      cands)))
  ;;[ja] 認識済みの箱畳み込み入れ子を、表の構築と問い合わせループの
  ;;[ja] C++ 文字列に変換して返す。+ なら integral_image の query、
  ;;[ja] 他の演算子なら monoid_table の prefix を使う。共有計画に
  ;;[ja] 載っていれば最初の入れ子だけ構築し、以後は問い合わせのみ出す。
  (define (integ-emit V S Is Ns Z OP)
    (let* ([n (length Is)]
	   [cis (map cname Is)] [cns (map cexp Ns)]
	   [cv (cname V)] [cs (cname S)] [et (integ-elem-type Z)]
	   [zeros (map (lambda (_) "0") cis)]
	   [loops (string-join
		   (map (lambda (ci cn) (format "for (int ~a = 0; ~a < ~a; ~a++)" ci ci cn ci))
			cis cns)
		   "\n")]
	   [share (assoc (cons V OP) integ-share-plan)]
	   [tname (if share (vector-ref (cdr share) 0) "scm2cpp_ii")]
	   [tag (caddr (integ-op-entry OP))]        ; C++ tag, #f for +
	   [queries
	    (if (eq? OP '+)
		(format (string-append
			 "~a {~n"
			 "const int scm2cpp_lo[~a] = { ~a };~n"
			 "const int scm2cpp_hi[~a] = { ~a };~n"
			 "~a[ ~a ] = ~a.query(scm2cpp_lo, scm2cpp_hi);~n"
			 "}")
			loops
			n (string-join zeros ", ") n (string-join cis ", ")
			cs (integ-cexp-flatten cis cns) tname)
		;; the origin-anchored fold is a single table read: no
		;; inverse, hence any catalogued monoid
		(format (string-append
			 "~a {~n"
			 "const int scm2cpp_hi[~a] = { ~a };~n"
			 "~a[ ~a ] = ~a.prefix(scm2cpp_hi);~n"
			 "}")
			loops
			n (string-join cis ", ")
			cs (integ-cexp-flatten cis cns) tname))]
	   [build
	    (if (eq? OP '+)
		(format (string-append
			 "scm2cpp::integral_image<~a,~a> ~a;~n"
			 "{ const int scm2cpp_dims[~a] = { ~a };~n"
			 "~a.build(~a, scm2cpp_dims); }~n")
			et n tname n (string-join cns ", ") tname cv)
		(format (string-append
			 "scm2cpp::monoid_table<~a,~a,scm2cpp::~a<~a>> ~a;~n"
			 "{ const int scm2cpp_dims[~a] = { ~a };~n"
			 "~a.build(~a, scm2cpp_dims, ~a); }~n")
			et n tag et tname
			n (string-join cns ", ")
			tname cv (integ-id-cexp Z)))])
      (cond
       [(and share (vector-ref (cdr share) 2))
	;; already built earlier in this write-free span; query only
	queries]
       [share
	(vector-set! (cdr share) 2 #t)
	(str-a build queries)]
       [else (str-a "{ " build queries " }")])))
  ;;[ja] 文 expr が箱畳み込み入れ子でヒントも許していれば、必要な
  ;;[ja] include を登録したうえで積分画像版の C++ 文字列を返す。
  ;;[ja] そうでなければ #f を返し、通常の for ループ出力に任せる。
  (define (integ-boxsum-nest expr)
    (let-values ([(V S Is Ns Z OP) (integ-match-nest expr)])
      (and V (integ-hinted? V (length Is))
	   (begin
	     (c-includes-adds (list "<vector>" "\"scm2cpp.hpp\""))
	     (integ-emit V S Is Ns Z OP)))))
  ;; (do ((i 0 (+ i 1))) ((= i N) _) (set! acc (+ acc (vector-ref v i)))
  ;;                                 (vector-set! sv i acc))
  ;;[ja] do ループが「累積和を要素ごとに書き戻す」スキャンの形なら
  ;;[ja] (入力配列 . 出力配列) を返し、違えば #f。
  (define (thrust-scan bindings pred E)
    (match (list bindings pred E)
      [(list (list (list i 0 `(+ ,i2 1)))
	     (list `(= ,i3 ,_) _ ...)
	     (list `(set! ,acc (+ ,acc2 (vector-ref ,v ,i4)))
		   `(vector-set! ,sv ,i5 ,acc3)))
       (and (eq? i i2) (eq? i i3) (eq? i i4) (eq? i i5)
	    (eq? acc acc2) (eq? acc acc3)
	    (cons v sv))]
      [_ #f]))
  ;; (do ((i 0 (+ i 1))) ((= i N) _) (set! acc (+ acc (vector-ref v i))))
  ;;[ja] do ループが配列の総和を取るだけの縮約の形なら
  ;;[ja] (入力配列 . 累積変数) を返し、違えば #f。
  (define (thrust-reduce bindings pred E)
    (match (list bindings pred E)
      [(list (list (list i 0 `(+ ,i2 1)))
	     (list `(= ,i3 ,_) _ ...)
	     (list `(set! ,acc (+ ,acc2 (vector-ref ,v ,i4)))))
       (and (eq? i i2) (eq? i i3) (eq? i i4) (eq? acc acc2)
	    (cons v acc))]
      [_ #f]))
  ;; Returns the replacement expression, or #f to fall through to a for loop.
  ;;[ja] thrust モードで do ループがスキャンか縮約に一致すれば、
  ;;[ja] 必要な include を登録して thrust の呼び出し文字列を返す。
  ;;[ja] 一致しなければ #f を返し、通常の for ループに落とす。
  (define (thrust-loop bindings pred E)
    (and (thrust-mode?)
	 (let ([sc (thrust-scan bindings pred E)])
	   (if sc
	       (begin
		 (c-includes-adds (list "<thrust/scan.h>" "<thrust/device_vector.h>"))
		 (format "thrust::inclusive_scan(~a.begin(),~a.end(),~a.begin())"
			 (cname (car sc)) (cname (car sc)) (cname (cdr sc))))
	       (let ([rd (thrust-reduce bindings pred E)])
		 (and rd
		      (begin
			(c-includes-adds (list "<thrust/reduce.h>" "<thrust/device_vector.h>"))
			(format "~a = thrust::reduce(~a.begin(),~a.end(),~a)"
				(cname (cdr rd)) (cname (car rd)) (cname (car rd))
				(cname (cdr rd))))))))))
  ;;[ja] 今の関数の前後に置く C++ 文字列(functor struct の定義など)。
  (define pre-cfun "")
  (define post-cfun "")
  ;;[ja] 今出力中の関数の直前に置くべき C++ 文字列 str を pre-cfun に
  ;;[ja] 追記する。関数の外に出す struct 定義などがここに溜まる。
  (define (add-pre-cfun str) (set! pre-cfun (str-a pre-cfun str)))
  ;;[ja] add-pre-cfun のセミコロンと改行を付ける版。
  (define (add-pre-cfun-semi str) (add-pre-cfun (format "~a;~n" str))) 
  ;;[ja] 今の関数のテンプレート仮引数の候補(未刈り込み)。
  (define current-template-vars '())  
  ;; current-template-vars holds unpruned candidates; this holds the
  ;; template parameter names the enclosing function actually declares,
  ;; which is what decides whether such a name is a type inside its body.
  ;;[ja] 今の関数が実際に宣言するテンプレート仮引数名。本体の中で
  ;;[ja] その名前が型かどうかを決めるのはこちら。
  (define current-template-names '())
  ;;[ja] 上の各名前に対応する型。
  (define current-template-types '())  
  ;;[ja] ヘッダ先頭に出す #include の一覧(c-includes-adds で追加)。
  (define c-includes '())
  ;; Forward declarations, emitted together at the head of the header so that
  ;; a function may call one defined later.
  ;;[ja] 前方宣言の一覧。後で定義される関数を先に呼べるようヘッダ先頭へ。
  (define c-fwd-decls '())
  ;;[ja] 前方宣言の文字列 str をヘッダ先頭にまとめて出す一覧に追加する。
  (define (c-fwd-decl-add str)
    (set! c-fwd-decls (append c-fwd-decls (list str))))
  ;;[ja] include 対象の文字列 str を重複なしで c-includes に追加する。
  (define (c-includes-add str)
    (set! c-includes (lset-union equal? c-includes (list str))))
  ;;[ja] c-includes-add のリスト版。複数の include をまとめて登録する。
  (define (c-includes-adds lst)
    (set! c-includes (lset-union equal? c-includes lst)))
  ;; (define-values (expr-alpha env-alpha env-free)  
  ;;   (alpha-conv (list 'begin expr-org)))
  ;; (define env-alpha-inv (envinvert env-alpha))
  ;; (define env-free-inv ( envinvert env-free))
  ;; (define env-init-type (alpha-free->type-env env-alpha-inv env-free-inv))
  ;; (define env-ret-type (%which (Env Ret) (%derive-type expr-alpha Ret env-init-type Env )))
  ;; (define env-type
  ;;   (if env-ret-type
  ;; 	(reduce-unknown-type (cdr (assq 'Env env-ret-type)))
  ;; 	#f))
  ;;[ja] 型推論の呼び口。大域の型環境、全体の返り値型、未知型の一覧、
  ;;[ja] α 変換済みの式、α 変換と自由変数の逆写像をまとめて受け取る。
  (define-values (env-type-global gloal-ret-type unknown-type-list expr-alpha env-alpha-inv env-free-inv)   (infer-type-from-org-expr expr-org ))
  ;;[ja] 局所の型環境。関数に入るたびに大域環境から派生させる。
  (define env-type-local env-type-global)

  ;;[ja] トップレベルで定義された大域変数の一覧。
  (define top-level-global-vars (expr-type->global-vars expr-alpha env-type-global))
  ;(define top-level-functions-undef-types-alist      (functions-undef-types-alist expr-alpha env-type-global unknown-type-list top-level-global-vars))
  ;;[ja] 各トップレベル関数について、その仮引数に束縛された未確定型と
  ;;[ja] 自由変数由来の未確定型を並べた連想リスト。関数適用時に
  ;;[ja] テンプレート実引数を明示するかどうかの判断に使う。
  (define function-free-type-variable-bind-free-alist (functions-undef-types-alist expr-alpha env-type-global unknown-type-list top-level-global-vars))
  ;;[ja] 上の連想リストに現れる未確定型をすべて平らに並べたもの。
  (define free-type-variables (flatten (map (lambda (kv) (append (cadr kv) (caddr kv)))    function-free-type-variable-bind-free-alist)))
  (display (list 'free-type-variables free-type-variables))(newline)

  ;; (define free-type-variables-template-name-alist (map (lambda (v) (display v)(cons v (var-name-to-template-type-name (cname v)))) free-type-variables))
  ;; (display (list 'free-type-variables-template-name-alist free-type-variables-template-name-alist))(newline)


  ;(display (list env-type-global gloal-ret-type unknown-type-list expr-alpha env-alpha-inv env-free-inv))(newline)

  ;;[ja] α 変換後の変数名 v を、原始プログラムでの元の名前に戻す。
  (define (orgn v) (env2-rename v env-alpha-inv env-free-inv))
  ;;[ja] 変数 v の元の名前を C++ の識別子として使える文字列にする。
  (define (cname v) (schlep-symbol-str (orgn v)))
  ;(define (vtype v) (var-env->type v env-type-local))
  ;;[ja] 変数 v の推論済みの直接型を現在の型環境から引く。
  (define (vtype v) (var-env->direct-type v env-type-local))



  ;;[ja] 変数 v の型が確定していない、つまりテンプレート仮引数になる
  ;;[ja] 型変数のままかを返す。
  (define (non-fix-type? v)  (var-non-fix-type? v env-type-local))
  ;;[ja] 式 expr-local の型を返す。記号なら型環境を引き、それ以外は
  ;;[ja] 現在の環境のもとで返り値型を手早く導出する。
  (define (expr->type expr-local)
    (cond 
     [(symbol? expr-local) (vtype expr-local)]
     [else (quick-derive-return-type expr-local env-type-local)
      ;; (let*-values
      ;; 	  (
      ;; 	   ;; [(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
      ;; 	   [(type1 ret1 unk1) (derive-type expr-local env-type-local)])
      ;;   ;(display (list "expr->type1" expr-local ret1))
      ;; 	ret1
      ;; 	)
      ]))
  ;; (define (expr->expand-type expr-local)  
  ;;   (cond
  ;;    [(symbol? expr-local)       
  ;;   ;(expand-type 
  ;;    (expr->type expr-local) env-type-local)
  ;; )
  
  ;; Template parameter names are derived from the variable name, so two
  ;; distinct type variables from different scopes could collide and be
  ;; conflated. Assign per type variable and disambiguate on collision.
  ;;[ja] 型変数 → テンプレート仮引数名、および使用済みの名前の集合。
  ;;[ja] 変数名由来の名前が別スコープで衝突したら番号で区別する。
  (define tvar-name-table (make-hasheq))
  (define tvar-name-used (make-hash))
  ;;[ja] 型変数 v に対応するテンプレート仮引数名を返す。変数名から
  ;;[ja] 作った基本名が既に別の型変数に使われていれば番号を付けて
  ;;[ja] 区別し、同じ型変数には常に同じ名前を返すよう表に記憶する。
  (define (tvar-name v)
    (hash-ref!
     tvar-name-table v
     (lambda ()
       (let ([base (var-name-to-template-type-name (cname v))])
	 (let loop ([n 1])
	   (let ([cand (if (= n 1) base (format "~a~a" base n))])
	     (if (hash-ref tvar-name-used cand #f)
		 (loop (+ n 1))
		 (begin (hash-set! tvar-name-used cand #t) cand))))))))
    ;;[ja] 変数 v の C++ 型名。型が確定していなければテンプレート仮引数名
  ;;[ja] (tvar-name)へ。直接型が union 等の複合なら cpptype に委ねる
  ;;[ja] (数値 union は最も広い数値型へ潰れる — C++ の算術変換と同じ)。
(define (ctype v)
    (if (non-fix-type? v)
	;; A variable can be non-fixed and still carry a compound direct
	;; type. The relational inference gives a named let's counter one:
	;; seeded from a parameter of unknown type and updated by
	;; arithmetic, it comes out as a union of that type variable with
	;; Int rather than as either alone. tvar-name names a template
	;; parameter and needs a symbol, so a compound type goes to
	;; cpptype instead, where a union of numeric types and type
	;; variables collapses to its widest numeric member -- which is
	;; what C++ arithmetic conversion would do to it anyway.
	(let ([t (vtype v)])
	  (if (symbol? t) (tvar-name t) (cpptype t)))
	(type->ctype (vtype v))
	))
  ;; number-type-order-list runs from narrow to wide; take the widest.
  ;;[ja] 数値型の集合 ts のうち、number-type-order-list で最も広い型を返す。
  (define (widest-number-type ts)
    (let loop ([rest number-type-order-list] [found #f])
      (cond [(null? rest) found]
	    [(memq (car rest) ts) (loop (cdr rest) (car rest))]
	    [else (loop (cdr rest) found)])))
  ;;[ja] m が既知の型記号ではない記号、つまり型変数かを返す。
  (define (type-variable? m) (and (symbol? m) (not (memq m type-symbols))))
  ;;[ja] union の要素列 E が数値型と型変数だけからなり、数値型を少なくとも
  ;;[ja] 1 つ含むかを返す。真なら最も広い数値型 1 つに潰せる。
  (define (numeric-collapsible-union? E)
    (and (pair? (filter number-type? E))
	 (andmap (lambda (m) (or (number-type? m) (type-variable? m))) E)))
  ;;[ja] union 型の要素列 E を C++ 型文字列にする。Void を含めば void、
  ;;[ja] 数値型と型変数だけなら最も広い数値型、未解決の型を含む要素が
  ;;[ja] あり別に素の型変数があればその型変数のテンプレート名、
  ;;[ja] それ以外は boost::variant を縮めた型にする。
  (define (cppuniontype E)
    ;; A union that includes a path yielding no value is used in statement
    ;; position; emit void.
    (if (memq Void E)
	(type->ctype Void)
    ;; A union of numeric types and type variables collapses to the widest
    ;; numeric type, which is what C++ arithmetic conversion does anyway.
    (if (numeric-collapsible-union? E)
	(cpptype (widest-number-type (filter number-type? E)))
	;; A member that still contains an unresolved type has no C++
	;; spelling at all, so a variant over it would not compile. If
	;; another member is a plain type variable, that one absorbs the
	;; union: a template parameter is precisely the statement that the
	;; type is settled by the call site rather than here.
	(let ([unresolved? (lambda (m) (ormap (lambda (x)
						(unknown-type? x unknown-type-list))
					      (flatten (list m))))]
	      [tv (findf type-variable? E)])
	  (if (and tv (ormap unresolved? E))
	      (tvar-name tv)
	      (begin
		(c-includes-add "\"scm2cpp.hpp\"" )
		(format
		 "typename scm2cpp::make_variant_shrink_over< boost::mpl::vector< ~a > >::type "
		 (string-join (map cpptype E) ","))))))))
  ;;[ja] 引数位置の型 t を C++ 型文字列にする。未知型と数値の union は
  ;;[ja] その型変数のテンプレート名にし、それ以外は cpptype に委ねる。
  (define (cpptype-arg t)
    (cond 
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [else (cpptype t) ]))
  ;;[ja] 型 S 式 → C++ 型文字列の本体。make-vector の長さがリテラルなら
  ;;[ja] std::array<T,N>、そうでなければ std::vector<T>。scm2cpp-stream は
  ;;[ja] scm2cpp::stream_cell<T>。union は cppuniontype で処理。
  (define (cpptype t);;type->cpptype
    ;(display (list "cpptype0 " t))(newline)
    (cond
     ;[(symbol? t) (ctype t)]
     [(member t unknown-type-list) (tvar-name t)]
     [(optional-union-type? t) => (lambda (x)
                                    (c-includes-add "<optional>")
                                    (format "std::optional<~a>" (cpptype x)  ))]
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [(symbol? t)  (type->ctype t)]
      
     ;[(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [else
      (match 
       t
     ;[(? symbol? X)  (ctype X)]
       [`(,(? union-symbol? U) ,E ...) 
	;(if  (pair? (lset-intersection eq? E unknown-type-list))
	(let* ([var-types (lset-intersection eq? E unknown-type-list)]
	       ;; vtype returns a symbol when the type is unresolved, but
	       ;; lset-union requires lists.
	       [var-type-lists (map (lambda (v) (let ([t (vtype v)]) (if (list? t) t (list t)))) var-types)]
	       [E-subtrected
	       (lset-difference equal? E
				(apply lset-union (cons eq? var-type-lists)))])
	  (if (pair? (lset-intersection eq? E-subtrected number-type-order-list))
	      (let  ([ts (lset-difference eq? E-subtrected (list Number))])
		(if ( = 1 (length ts))
		    (cpptype (car ts))		  
		    (cppuniontype ts)))
	      ;(cppuniontype E)
	      (cppuniontype (lset-difference eq?  E (list Number)) )
	      )
	  ;; (cppuniontype e))
	  )
       	]

     [`(lambda ,params ,ret)
      (c-includes-adds (list "<functional>" "<algorithm>"))
      ;; The return may itself be compound -- a promise of a vector gives
      ;; (lambda () (make-vector n T)) -- and ctype only knows scalar
      ;; symbols, so compounds go back through cpptype.
      ;;
      ;; Container parameters are references, matching how every emitted
      ;; function takes its containers; without the & here a real function
      ;; such as mset(vector<double>&,...) does not convert to the
      ;; boost::function type, and a converting wrapper would copy the
      ;; array and lose the writes.
      (format "std::function< ~a ( ~a ) >"
	      (if (pair? ret) (cpptype ret) (ctype ret))
	      (string-join (map (lambda (p)
				  (if (container-type? p)
				      (format "~a &" (cpptype p))
				      (cpptype p)))
				params)
			   ","))
      ]
     [`(make-vector ,(? number? N) ,V) 
      (c-includes-add "<array>" )
      (format "std::array<~a,~a>" (cpptype V) N  )]
     [`(make-vector ,N ,V) 
      (c-includes-add "<vector>" )
      (format "std::vector<~a>" (cpptype V)  )]
     [`(make-list ,(? number? N) ,V) 
      (c-includes-add "<array>" )
      (format "std::array<~a,~a>" (cpptype V) N  )]
     [`(make-list ,N ,V) 
      (c-includes-add "<vector>" )
      (format "std::vector<~a>" (cpptype V)  )]
     [`(vector ,params ... )
      (let ((tps (map cpptype params))) 
	(if (list-all-equal? tps)
	    (begin 
	      (c-includes-add "<array>")
	      (format "std::array<~a,~a>" (cpptype (car tps)) (length params))
	      )
	  (begin
	    (c-includes-add "<boost/fusion/include/vector.hpp>")
	    (format "boost::fusion::vector<~a>" (string-join tps ",")))))
      ]
     ;; The nominal recursive type; scm2cpp::stream_cell<T> in the runtime.
     [`(scm2cpp-stream ,T)
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::stream_cell< ~a >" (cpptype T))]
     ;; A hash table. unordered_map needs a std::hash for the key, which
     ;; the standard supplies for numbers and strings; a key that is
     ;; itself a container gets the ordered map, whose comparison the
     ;; containers already have.
     [`(hash ,K ,V)
      (if (container-type? K)
	  (begin (c-includes-add "<map>")
		 (format "std::map< ~a,~a >" (cpptype K) (cpptype V)))
	  (begin (c-includes-add "<unordered_map>")
		 (format "std::unordered_map< ~a,~a >" (cpptype K) (cpptype V))))]
     ;; The summed-area representation, for an array whose reads are box sums.
     [`(integral-image ,T ,(? number? R))
      (c-includes-adds (list "<vector>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::integral_image< ~a,~a >" (cpptype T) R)]
     ;; A type constructor a user binding declared: its C++ spelling, with
     ;; the declared header pulled into the include list.
     [`(,(? binding-type? BT) ,BTARGS ...)
      (c-includes-add (binding-type-header BT))
      (apply format (binding-type-cpp BT) (map cpptype BTARGS))]
     [`(list ,params ... )
      (if (list-all-equal? params)
	  (begin
	    (c-includes-add "<list>")
	    (format "std::list< ~a >" (cpptype (car params))))
	  (begin 
	    (c-includes-add "<boost/fusion/include/list.hpp>")
	    (format "boost::fusion::list< ~a >" (string-join (map cpptype params) ","))))
      ]
     ;; An unrecognised compound type whose head is an unknown type is treated
     ;; as a template parameter. Unknown types made on another path are not in
     ;; unknown-type-list, so match on the name.
     [(list (? (lambda (x)
		 (and (symbol? x)
		      (or (memq x unknown-type-list)
			  (regexp-match? #px"^Unknown-Type" (symbol->string x))))) U) _ ...)
      (tvar-name U)]
     [_ 
      ;; (let*-values
      ;; 	  (
      ;; 	   ;; [(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
      ;; 	   [(type1 ret1 unk1) (derive-type t env-type-local)])
	(ctype t ) ]
     ) ]))
  ;;[ja] 引数式 e の C++ 型文字列を返す。型が複合でその中に e 自身が
  ;;[ja] 要素として含まれていれば型変数扱いでテンプレート名を返し、
  ;;[ja] そうでなければ sexp->cpptype に委ねる。
  (define (sarg->cpptype e) 
    (let ([t (expr->type e)])
    ;(cpptype-arg (expr->type e))
      (display (list 'sarg->cpptype e t))(newline)
      (if (pair? t)
	(cond
	 [(member e t) (tvar-name e) ]
	 [else	(sexp->cpptype e t)]
	 )
	(sexp->cpptype e t))
    ))

  ;;[ja] 「式 e の型」を C++ 型文字列で。expr->type は非シンボルに対して
  ;;[ja] 関係的な quick-derive を走らせ得るので純粋な表引きではない点に注意。
  (define (sexp->cpptype e [t-ret NoType])
    ;(display (list 'sexp->cpptype e))(newline)
    (let ([t (if (eq? t-ret NoType)
		 (expr->type e) t-ret)])
      (display (list 'sexp->cpptype e t))(newline)
      (cond
       [(assoc t ctype-alist) => cdr]
       [(eq? t e) (cpptype-arg t)]
       ;; t is not necessarily a list; member requires one.
       [(and (list? t) (member e t)) (cpptype-arg t)]
       [else (cpptype t)];;(expand-type (expr->type e) env-type-local)
       )))
  ;; Scheme vectors, lists and the like are shared mutable objects: a
  ;; function that calls vector-set! on a parameter is expected, by Scheme's
  ;; own semantics, to mutate the very vector the caller passed in. Passing
  ;; such a parameter by C++ value instead copies it, so the mutation is
  ;; invisible to the caller -- silently, since the code still compiles and
  ;; runs, just computing nothing the caller can see. Container-typed
  ;; parameters are therefore always passed by reference, independently of
  ;; ref-flag, which still governs the unrelated case of a closure's
  ;; captured free variables.
  ;; Only the types actually written to via vector-set!/set-car!-style
  ;; mutation need reference passing. Streams and integral images are read
  ;; through car/cdr/query rather than mutated in place once built, are
  ;; sometimes passed as the temporary result of another call (stream_cdr's
  ;; return value, for instance), and a non-const reference parameter cannot
  ;; bind to a temporary; forcing one here broke exactly that call.
  ;;[ja] 型 t が参照渡しにすべきコンテナかを返す。vector、list、hash と
  ;;[ja] binding 宣言の型が該当し、stream や integral-image はわざと
  ;;[ja] 含めない。一時オブジェクトを非 const 参照に束縛できないため。
  (define (container-type? t)
    (and (pair? t)
	 (or (memq (car t) '(make-vector make-list vector list hash))
	     ;; A binding-declared type is a shared object like a vector: a
	     ;; function given one and told to write it must write the
	     ;; caller's, so it crosses by reference as well.
	     (binding-type? (car t)))))
  ;; The element type of a vector declared as (X (make-vector N V)). It is
  ;; derived from the fill V, except when V is a promise: the quick
  ;; derivation has no rule for make-promise and answered with a fresh
  ;; unknown name, while inference did settle X's type -- a promise of T
  ;; is a (lambda () T) there, spelled std::function<T()>, and a
  ;; std::function holding the runtime's promise still memoises as long
  ;; as it is forced in place, which the write analysis now ensures.
  ;;[ja] (X (make-vector N V)) と宣言された配列の要素型を C++ 文字列で
  ;;[ja] 返す。通常は初期値 V の型だが、V が make-promise のときは
  ;;[ja] 手早い導出が答えられないので、推論済みの X の型から要素型を取る。
  (define (vector-elem-cpptype X V)
    (match (list V (expr->type X))
      [`((make-promise ,_) (,(or 'make-vector 'make-list) ,_ ,T)) (cpptype T)]
      [_ (sexp->cpptype V)]))
  ;; Same computation as sarg->cpptype, but also reports whether the type is
  ;; a container, both read off the one expr->type call. expr->type re-runs
  ;; relational inference against whatever constraint state is current, so a
  ;; second, separate call for the same variable is not guaranteed to see
  ;; the same type as the first -- it is not a pure lookup.
  ;;[ja] sarg->cpptype と同じ計算に加え、その型がコンテナかどうかも
  ;;[ja] 2 値目で返す。binding 宣言の型なら記号 binding を返し、参照渡し
  ;;[ja] ではあるが span への書き換え対象からは外す。expr->type は純粋な
  ;;[ja] 表引きではないので、1 回の呼び出しから両方を読み取る。
  (define (sarg->cpptype/ref e)
    (let ([t (expr->type e)])
      (values
       (if (pair? t)
	   (cond [(member e t) (tvar-name e)]
		 [else (sexp->cpptype e t)])
	   (sexp->cpptype e t))
       ;; 'binding still counts as a container (truthy: crosses by
       ;; reference) but is exempt from the span rewrite below: a binding
       ;; type that happens to spell std::vector is the library's class,
       ;; not the translator's dynamic array, and a span view would not
       ;; have its operations.
       (if (and (pair? t) (binding-type? (car t)))
	   'binding
	   (container-type? t)))))
  ;; MUTATED, when given, lists the parameters the function may write to,
  ;; from the mutation summary; a container parameter not among them is
  ;; write-free for the whole call, which is the one case where the
  ;; region-local notion coincides with C++ const, so the keyword is
  ;; emitted. A const reference also accepts a temporary argument, which a
  ;; plain reference does not.
  ;; The most recent call's per-parameter information, for the C-API
  ;; collector in cdeffun: computed here, in the same expr->type pass that
  ;; decides the signature, so nothing is derived twice.
  ;;[ja] 直近に処理した呼び出しの仮引数ごとの情報。cdeffun の C-API
  ;;[ja] 収集が読む(署名を決めたのと同じ expr->type の通過で得る)。
  (define last-cargs-info '())
  ;; The C++ type of a function-valued variable, with each container
  ;; parameter's constness taken from what the function actually writes.
  ;; Falls back to the plain rendering when the summary has no entry.
  ;;[ja] 関数値を持つ変数 v の std::function 型文字列を返す。コンテナ引数
  ;;[ja] の const は mutation-summary に従って付ける。v の型が lambda 型
  ;;[ja] でなければ #f を返し、呼び出し側は通常の型に落とす。
  (define (funtype-cpp v)
    (let ([ft (vtype v)])
      (and (pair? ft) (eq? (car ft) 'lambda)
	   (let* ([idxs (hash-ref mutation-summary v #f)]
		  [ps (cadr ft)]
		  [rt (last ft)]
		  [pstr (string-join
			 (for/list ([pt ps] [i (in-naturals)])
			   (cond
			    [(not (container-type? pt)) (cpptype pt)]
			    [(and idxs (not (memq i idxs)))
			     (format "const ~a &" (cpptype pt))]
			    [else (format "~a &" (cpptype pt))]))
			 ",")])
	     (format "std::function< ~a ( ~a ) >"
		     (if (pair? rt) (cpptype rt) (ctype rt))
		     pstr)))))
  ;;[ja] 仮引数リスト → C++ 引数宣言文字列。コンテナ型は常に参照渡し
  ;;[ja] (Scheme の vector は共有可変なので、値渡しでは書き込みが
  ;;[ja] 呼び出し元に見えなくなる)。mutated に載らない引数は const。
  (define (svars->cargs vars ref-flag [mutated #f])
    ;(display (list "svars->cargs " vars ref-flag))(newline)
    (let*-values ([(ctypes refs)
		   (let loop ([vs vars] [cts '()] [rfs '()])
		     (if (null? vs)
			 (values (reverse cts) (reverse rfs))
			 (let-values ([(ct rf) (sarg->cpptype/ref (car vs))])
			   (loop (cdr vs) (cons ct cts) (cons rf rfs)))))]
		  [(cvars) (map cname vars)])
      ;; The type a parameter is actually declared with -- span for a
      ;; dynamic-extent array, the plain type otherwise -- decided once
      ;; and used both for the signature and for what the C ABI wrapper
      ;; is told, so the wrapper hands a view its pointer instead of
      ;; rebuilding a container around it.
      (let* ([decl-types
	      (map (lambda (t r orig)
		     (let* ([t (or (funtype-cpp orig) t)]
			    [sp (and (not (eq? r 'binding))
				     (regexp-match #px"^std::vector<(.+)>$" t))])
		       (cond
			[(and sp r mutated (not (memq orig mutated)))
			 (c-includes-add "\"scm2cpp.hpp\"")
			 (format "scm2cpp::cspan<~a>" (cadr sp))]
			[(and sp (or ref-flag r))
			 (c-includes-add "\"scm2cpp.hpp\"")
			 (format "scm2cpp::span<~a>" (cadr sp))]
			[else t])))
		   ctypes refs vars)])
	(set! last-cargs-info (map list cvars decl-types refs))
	(string-join
	 (map (lambda (t v r orig)
		(cond
		 [(regexp-match? #px"^scm2cpp::c?span<" t) (format " ~a ~a " t v)]
		 [(and r mutated (not (memq orig mutated)))
		  (format " const ~a & ~a " t v)]
		 [(or ref-flag r) (format " ~a & ~a " t v)]
		 [else (format " ~a  ~a " t v)]))
	      decl-types cvars refs vars)
	 " , "))))
  ;;[ja] 変数列 vars を C++ 名に直してコンマ区切りで並べた文字列を返す。
  ;;[ja] 呼び出しや初期化で実引数として渡すときに使う。
  (define (svars->crefs vars) (string-join (map cname vars) " , "))  
  ;;[ja] 変数列 vars をクロージャ struct のメンバ宣言の並びにして返す。
  ;;[ja] const と参照の付け方は svars->cargs と同じ規則で、コンストラクタ
  ;;[ja] 引数とメンバの型が常に一致するようにしている。
  (define (svars->cdefs vars ref-flag [mutated #f]) ;return str : int a; float b; ...
    ;; The same constness rule as svars->cargs, so a member and the
    ;; constructor argument that initialises it always agree: a container
    ;; the body never writes is held as a const reference, which accepts
    ;; the caller's const and non-const alike.
    (apply string-append
	   (map (lambda (v)
		  (let-values ([(t r) (sarg->cpptype/ref v)])
		    (let* ([t (or (funtype-cpp v) t)]
			   [sp (and (not (eq? r 'binding))
			            (regexp-match #px"^std::vector<(.+)>$" t))])
		      (cond
		       [(and sp r mutated (not (memq v mutated)))
			(format "scm2cpp::cspan<~a> ~a;~n" (cadr sp) (cname v))]
		       [(and sp (or ref-flag r))
			(format "scm2cpp::span<~a> ~a;~n" (cadr sp) (cname v))]
		       [(and r mutated (not (memq v mutated)))
			(format "const ~a & ~a;~n" t (cname v))]
		       [(or ref-flag r) (format "~a & ~a;~n" t (cname v))]
		       [else (format "~a  ~a;~n" t (cname v))]))))
		vars)))
  ;;[ja] 変数列 vars からコンストラクタのメンバ初期化子リスト
  ;;[ja] :a(a),b(b) の文字列を作る。空なら空文字列。
  (define (svars->cinit vars)
    (let* ((cvars (map cname vars)))
      (if (null? vars)
	  ""
	  (string-append ":" (string-join (map (lambda (v) (format "~a(~a) " v v )) cvars) ",")))))

  ;;[ja] types->ctemplatedef の別名。
  (define (svars->ctemplatedef vars)(types->ctemplatedef vars))
  ;;[ja] 型変数列 vars から template< typename A, ... > の前置文字列を
  ;;[ja] 作る。同じ名前が 2 度出ると C++ として不正なので重複を除く。
  (define (types->ctemplatedef vars)
    ;; A name appearing twice is not legal C++, so remove duplicates.
    (let ([names (delete-duplicates (map tvar-name vars))])
      (types->ctemplatedef-names names)))
  ;;[ja] テンプレート仮引数名の列 names から template< ... > の文字列を
  ;;[ja] 作る。空なら空文字列を返し、非テンプレート関数になる。
  (define (types->ctemplatedef-names names)
    (if (null? names) ""
	(format "template< ~a > "
		(str-j (map (lambda (n) (format "typename ~a" n)) names) ","))))
  ;; A parameter that does not occur in the signature cannot be deduced, and
  ;; the function cannot be called at all. Keep only those that are used.
  ;; The occurrence test needs pregexp: regexp does not interpret \\b.
  ;;[ja] 型変数列 vars のテンプレート名のうち、署名文字列 signature-str
  ;;[ja] に単語として現れるものだけを返す。署名に出ない仮引数は推論
  ;;[ja] できず、その関数を呼べなくなるため。
  (define (types->ctemplatedef-used-names vars signature-str)
    (let ([names (delete-duplicates (map tvar-name vars))])
      (filter (lambda (n) (regexp-match? (pregexp (string-append "\\b" (regexp-quote n) "\\b"))
					 signature-str))
	      names)))
  ;;[ja] 署名に実際に現れる型変数だけで template< ... > 前置文字列を作る。
  (define (types->ctemplatedef-used vars signature-str)
    (types->ctemplatedef-names (types->ctemplatedef-used-names vars signature-str)))
  ;;[ja] λ/named let → operator() を持つ struct。自由変数はメンバとして
  ;;[ja] 捕獲(参照 or 値は free-ref-flag)。再帰用に自分自身も参照で持つ。
  ;;[ja] 返り値型は前段推論の結果を使い、無ければここで導出。
  (define (clambda expr lambda-name lambda-obj-name free-ref-flag)
    ;; Only the lambda's return type is wanted here. When the functor has a
    ;; name -- every named let does -- the front-end inference already
    ;; typed that name, and re-deriving the whole body relationally is not
    ;; just wasted work: on a deeply nested loop body the relational
    ;; search does not come back (the 335-line QAP core sat in one such
    ;; call for over nine minutes). Look the name up first; derive only
    ;; for the anonymous shapes, whose bodies are the small wrappers.
    (let-values ([(type1 lambda-type1 unk1)
		  (let* ([known (and lambda-obj-name (vtype lambda-obj-name))]
			 ;; Only when the front end settled the return
			 ;; type. A loop whose result the program never
			 ;; uses can be left open there (fft's bit-reverse
			 ;; loop is one), and the relational pass is what
			 ;; resolves those -- skipping it would emit the
			 ;; unknown's name as a C++ type.
			 [settled?
			  (lambda (t)
			    (or (pair? t)
				(and (symbol? t)
				     (regexp-match?
				      #px"^(Double|Int|Bool|Void|Char|String|Number|Float)"
				      (symbol->string t)))))])
		    (cond
		      [(and (pair? known) (eq? (car known) 'lambda)
			    (settled? (last known)))
		       (values known known '())]
		      ;; An open return means the loop's value is never
		      ;; used -- the front end's statement-position if
		      ;; does not unify its branches, so nothing pinned
		      ;; it. Close it to void: the tails may be #f or a
		      ;; call to a void function, and only void accepts
		      ;; both once cexp-ret drops the value. The
		      ;; relational deriver is not consulted: on large
		      ;; bodies it does not come back, and what it
		      ;; leaves open it renders as unknown-type names.
		      [(and (pair? known) (eq? (car known) 'lambda))
		       (let ([closed (append (drop-right known 1) (list Void))])
			 (values closed closed '()))]
		      [else (derive-type expr env-type-local)]))])
      (let* ((freevars (sexp-free-var expr )) 
	     (lambda-ret-type (last lambda-type1)) 
	     ( cdef-lambda-obj "")
	     ;; A struct whose name equals the object's clashes with the member,
	     ;; which is not legal C++. lambda-obj-name is #f for anonymous ones.
	     ( c-lambda-name (let* ([n (cname lambda-name)]
				    [o (and lambda-obj-name (cname lambda-obj-name))])
			       (if (and o (string=? n o)) (string-append n "_fn") n)))
	     ;; Which captures the body writes; the rest may be const.
	     ( written-frees (filter (lambda (v) (stmt-writes? expr v)) freevars))
	     ( c-local-defs (svars->cdefs freevars free-ref-flag written-frees))
	     ( c-local-init-args '())
	     ( c-init-args (svars->cargs freevars free-ref-flag written-frees))
	     )
	;(newline)(display (list 'clambda lambda-obj-name freevars  expr ))(newline)
      (when 
       lambda-obj-name 
       (begin
	 ;; (set! freevars (lset-difference equal?  freevars (list lambda-obj-name))) 
	 (set! cdef-lambda-obj (format "~a(~a)" (cname lambda-obj-name) (svars->crefs freevars)))
	 (set! c-local-init-args
	       (map (lambda (x)
		      (let ([tstr (if (equal? x lambda-obj-name)
				      c-lambda-name
				      (sexp->cpptype x))])
			(cond
			  ;; A captured function arrives as a fresh
			  ;; boost::function temporary, and a temporary
			  ;; cannot bind to a non-const reference; hold
			  ;; those by value -- copying one is cheap. The
			  ;; parameter constness must mirror the real
			  ;; function's: a container it never writes is a
			  ;; const reference there, and the boost::function
			  ;; type has to say so or a const argument will
			  ;; not go through.
			  [(regexp-match? #px"^std::function" tstr)
			   (let* ([ft (vtype x)]
				  [idxs (hash-ref mutation-summary x #f)]
				  [ps (if (and (pair? ft) (eq? (car ft) 'lambda))
					  (cadr ft) '())]
				  [rt (if (and (pair? ft) (eq? (car ft) 'lambda))
					  (last ft) #f)]
				  [pstr
				   (string-join
				    (for/list ([pt ps] [i (in-naturals)])
				      (cond
					[(not (container-type? pt)) (cpptype pt)]
					[(and idxs (not (memq i idxs)))
					 (format "const ~a &" (cpptype pt))]
					[else (format "~a &" (cpptype pt))]))
				    ",")])
			     (if rt
				 (format "std::function< ~a ( ~a ) > ~a"
					 (if (pair? rt) (cpptype rt) (ctype rt))
					 pstr (cname x))
				 (format "~a ~a" tstr (cname x))))]
			  ;; A container the body never writes may well
			  ;; arrive as somebody's const reference; a
			  ;; const-qualified member accepts either.
			  [(and (not (equal? x lambda-obj-name))
				(container-type? (vtype x))
				(not (stmt-writes? expr x)))
			   (format "const ~a & ~a" tstr (cname x))]
			  [else (format "~a & ~a" tstr (cname x))])))
		    freevars))	      
	 (set! c-local-defs  (str-a  (str-j c-local-init-args (format ";~n")) (format ";~n")))
	 (set! c-init-args  (str-j c-local-init-args (format " , ")))
	 ))
	;(newline)(display (list 'clambda1 lambda-obj-name freevars  expr ))(newline)
      (match
       expr
       [`(lambda ,params ,E ... ) 
	;(display (list 'clambda expr E))(newline)
	(format "~n struct ~a { ~n ~a  ~a(~a)~a {} ~n ~a operator()(~a ) ~n { ~a } } ~a " 
		c-lambda-name
		;(svars->cdefs freevars free-ref-flag) 
		c-local-defs
		c-lambda-name c-init-args (svars->cinit freevars) 		
		;(sexp->cpptype lambda-ret-type)  
		(cpptype lambda-ret-type)  
		(svars->cargs params #false) 
		(begin-inc-dev-lv
		 (let ([was current-fn-ret-void])
		   (set! current-fn-ret-void (equal? (cpptype lambda-ret-type) "void"))
		   (let ([body (cstat-ret (cons 'begin E))])
		     (set! current-fn-ret-void was)
		     body))) cdef-lambda-obj )
	]
       ))))

  ;;[ja] cexp の補助で、局所的に α 変換して自由変数を求めてから訳す
  ;;[ja] 式の担当。値位置の cond と let はクロージャ struct にして前置文
  ;;[ja] に積み、lambda はヘッダか関数前置に出し、値を持つ名前付き let
  ;;[ja] は即時呼び出し lambda の中の while に、その他の名前付き let は
  ;;[ja] 自己参照する functor に、残りは関数適用として訳す。
  (define (cexp-with-local-analysis expr-local [t-ref NoType])
    (let*-values
	([(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
	 ;[(type1 ret1 unk1) (derive-type expr-local env-type-local)]
	 )
      (let* ((alpha1env  (envinvert env-alpha-loc)) 
	    (free1env (envinvert env-free-loc))
	    (vars1 (map car alpha1env))
	    (freevars1 (map car free1env)))
	;(display (list alpha1env type1))
	;(display (list "cexp-with-local-analysis " vars1 freevars1  expr-local))(newline)
	(match 
	 expr-local
	 [`(cond ,E ...)
	  (let ((lambda-name  (gensym 'cond) ))
	    (add-pre-cexp-semi
	     (clambda `(lambda () ,expr-local) lambda-name #false #true))
	    (str-a (cname lambda-name)
	 	   "(" (str-j (map cname freevars1) ",")")"
	 	   "()"))]
	 [`(let (,V ... ) ,E ...)
	  (let* ((lambda-name  (gensym 'let) )
		 (as-lambda (cons 'lambda (cons (map car V) E)))
		 ;; The constructor call must list exactly the captures the
		 ;; struct declares, and clambda derives those from the let
		 ;; recast as a lambda -- not from the enclosing expression's
		 ;; free variables, which can be a strict superset. With the
		 ;; superset the two disagreed and the constructor call had
		 ;; the wrong arity; every case that compiled before is one
		 ;; where the two computations coincided.
		 (own-frees (sexp-free-var as-lambda)))
	    (add-pre-cexp-semi
	     (clambda as-lambda lambda-name #false #true)
	     )
	    (str-a (cname lambda-name)
		   "(" (str-j (map cname own-frees) ",")")"
		   "(" (str-j (map cexp (map cadr V)) ",")")"))
	  ]
	 [`(let ((,L (lambda ,params ,E ... ))),L)
	  (let ((lambda-name L )
		(tvars (lset-intersection eq? current-template-vars  (append vars1 freevars1))) )
	    (if (null? current-template-vars)
		(hout-semi
		 (clambda expr-local lambda-name #false #false))
		(add-pre-cfun-semi
		 (str-a 
		  (svars->ctemplatedef tvars)
		  (clambda expr-local lambda-name #false #false))))
	    (str-a (cname lambda-name)
		   (if (null? tvars) "" (format "< ~a >" (str-j (map sexp->cpptype tvars) ",")))
		   "(" (str-j (map cname freevars1) ",")")"))]
	 [`(lambda ,params ,E ... ) 	  
	  (let ((lambda-name  (gensym 'lambda) )
		(tvars (lset-intersection eq? current-template-vars  (append vars1 freevars1))) )
	    (if (null? current-template-vars)
		(hout-semi
		 (clambda expr-local lambda-name #false #false))
		(add-pre-cfun-semi
		 (str-a 
		  (svars->ctemplatedef tvars)
		  (clambda expr-local lambda-name #false #false))))
	    (str-a (cname lambda-name)
		   (if (null? tvars) "" (format "< ~a >" (str-j (map sexp->cpptype tvars) ",")))
		   "(" (str-j (map cname freevars1) ",")")")
	    )
	  ]
	 ;; The accumulator loop, in whatever position:
	 ;;   (let NAME ((v init) ...) (if TEST (NAME step ...) FINAL))
	 ;; A while inside an immediately-invoked lambda gives it a value, so
	 ;; the result-carrying loops the statement-position do cannot take --
	 ;; every Sinkhorn-style reduction is one -- stop being recursive
	 ;; functors, where each iteration was a call. The steps land in
	 ;; temporaries first, so that each is computed against the old values
	 ;; exactly as the recursive call's arguments are; FINAL may be any
	 ;; expression free of NAME, including a call to an enclosing loop.
	 ;; When the loop's type is void -- FINAL there for its effect, an
	 ;; mset! ending a reduction -- FINAL is emitted as a statement, since
	 ;; return with a void operand is not C++.
	 [`(let ,(? symbol? NAME) ((,VS ,IS) ...) (if ,TEST ,CALL ,FINAL))
	  #:when (and (pair? VS)
		      (pair? CALL) (eq? (car CALL) NAME)
		      (= (length (cdr CALL)) (length VS))
		      (not (sexp-occurs? NAME TEST))
		      (not (ormap (lambda (e) (sexp-occurs? NAME e)) (cdr CALL)))
		      (not (sexp-occurs? NAME FINAL))
		      (andmap (lambda (v)
				(let ([t (vtype v)])
				  (or (pair? t)
				      (and (symbol? t)
					   (regexp-match? #px"^(Double|Int|Bool|Char|String|Number|Float)"
							  (symbol->string t))))))
			      VS))
	  (let* ([ret-t (let ([ft (vtype NAME)])
			  (if (and (pair? ft) (eq? (car ft) 'lambda)) (last ft) #f))]
		 [ret-c (if ret-t (sexp->cpptype ret-t) "double")]
		 [tmps (map (lambda (v) (gensym (string->symbol (format "~a_next" (cname v))))) VS)])
	    (string-append
	     (format "([&]() -> ~a { " ret-c)
	     (apply string-append
		    (map (lambda (v i) (format "~a ~a = ~a; " (sexp->cpptype v) (cname v) (cexp i)))
			 VS IS))
	     (format "while (~a) { " (cexp TEST))
	     (apply string-append
		    (map (lambda (tmp v stp) (format "~a ~a = ~a; " (sexp->cpptype v) (cname tmp) (cexp stp)))
			 tmps VS (cdr CALL)))
	     (apply string-append
		    (map (lambda (v tmp) (format "~a = ~a; " (cname v) (cname tmp))) VS tmps))
	     "} "
	     (if (equal? ret-c "void")
		 (format "~a ; })()" (cexp FINAL))
		 (format "return ~a; })()" (cexp FINAL)))))]
	 [`(let ,(? symbol? v) (,V ...) ,E ... )  ;;named let
	  ;(display (list 'cexp-named-let v V E))(newline)
	  (set! env-alpha-inv (alist-cons-update v v env-alpha-inv))
	  (let ((lambda-name (gensym v ))
		(lambda-obj-name  v )
		;;(varnexts (map (lambda (e) `(set! ,(car e) ,(caddr e)   )) V))
		)
	    (add-pre-cexp-semi
	     (clambda
	      (cons 'lambda (cons (map car V) E))
	      lambda-name lambda-obj-name #true)
	     )
            ;(display (list 'cexp-named-let1 v V E lambda-obj-name freevars1 ))(newline)
	    (str-a 
	     (cname lambda-obj-name)	     
		   ;; "(" (str-j (map cname 
		   ;; 		   ;(lset-difference equal?  freevars1 (list lambda-obj-name)) 
                   ;;                ;(remove lambda-obj-name freevars1)
                   ;;                 freevars1
                   ;;                ) ",")")"
		   "(" (str-j (map cexp (map cadr V)) ",")")"))
	  ]
	 [`(,E0 ,Es ...) 
	  ;(display (list 'cexp-funcall E0 Es (null? Es) ))(newline)
	  (display (list 'cexp-funcall E0 Es  ))(newline)

	  (if (and (symbol? E0) (assoc E0 function-free-type-variable-bind-free-alist) 
		   (or (pair? (cadr (assoc E0 function-free-type-variable-bind-free-alist)))
		       (pair? (caddr (assoc E0 function-free-type-variable-bind-free-alist)))) )
	      (let ([E0-cstr (if (symbol? E0) (cname E0) (cexp E0))]
		    [E0-type (expr->type E0)]
	  	    [env-type-local-old env-type-local]
	  	    [unknown-type-list-old unknown-type-list])
	  	(match 
	  	 E0-type
	  	 [`(lambda ,Params ,Ret)		     		  
	  	  (let*-values 
		      ([(Es-types) (map expr->type Es)]
		       [(e0-type-free) (assoc E0 function-free-type-variable-bind-free-alist)]
		       [(e0-a-type)  (cadr e0-type-free) ]
		       [(e0-f-type)  (caddr e0-type-free) ]
		       [(types-correspond env-type-local-new unknown-typed-list-total-new)
			(env-type-match-partial-specialization	Params Es-types env-type-local  unknown-type-list)]
		       [(E0-type-a-specialization) (map (lambda (v) (aif (assoc v types-correspond) (cdr it) #f))  e0-a-type)]
		       [(E0-type-f-specialization) (map (lambda (v) (aif (assoc v types-correspond) (cdr it) #f))  e0-f-type)])
		    (set! env-type-local env-type-local-new)
		    (set! unknown-type-list unknown-typed-list-total-new)
		    (let* ([a-resolved? (andmap string? E0-type-a-specialization)]
			   [f-resolved? (andmap string? E0-type-f-specialization)]
			   [E0-cstr1
			    ;; When an argument cannot be resolved, omit the explicit
			    ;; template argument list and let C++ deduce it from the call.
			    (cond
			     [(null? e0-f-type)
			      (if a-resolved?
				  (str-a E0-cstr "<" (str-j E0-type-a-specialization ",") ">")
				  E0-cstr)]
			     [(and a-resolved? f-resolved?)
			      (str-a E0-cstr "<" (str-j E0-type-f-specialization ",") ">().operator()<" (str-j E0-type-a-specialization ",") ">")]
			     [f-resolved?
			      (str-a E0-cstr "<" (str-j E0-type-f-specialization ",") ">().operator()")]
			     [else E0-cstr])]
			   [ret
			;(str-a E0-cstr1 "(" (str-j (map cexp-cond-cast Es Params) ",") ")")
			    (str-a E0-cstr1 "(" (str-j (map cexp Es) ",") ")")
			    ])
		      (set! env-type-local env-type-local-old)
		      (set! unknown-type-list unknown-type-list-old )
		      ret) )]
		 [ _  (str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")]
	  	 ))
	(let ([E0-cstr (if (symbol? E0) (cname E0) (cexp E0))])
	    (if (null? Es)
		(str-a E0-cstr  "()")
		;(str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")

		(let ([E0-type (expr->type E0)])
		  (match 
		   E0-type
		   [`(lambda ,Params ,Ret)		     
		    (str-a
		     E0-cstr
		     "("
		     (str-j 
		      (map cexp-cond-cast Es Params) 
		      ",") ")" )]
		   [ _ 
		    (str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")]
		   ))
		))
	)]
	  
	 [_ 
	  (error "unknown-expression in scm2cpp" expr-local)
	  (format " error_in_gen_cexp ~a " expr-local) ]
	 ))))

  ;;[ja] 式 expr-local を訳し、型 t-cast への変換で包んだ文字列を返す。
  ;;[ja] Number なら get_number、optional なら optional_attach、
  ;;[ja] それ以外は C++ の関数形式キャストを使う。
  (define (cexp-with-cast expr-local t-cast)
    (cond
     [(eq? t-cast Number)  (format "scm2cpp::get_number(~a)" (cexp expr-local))]
     [(optional-union-type? t-cast) => (lambda (X) (format "scm2cpp::optional_attach(~a)" (cexp expr-local)))]
     [ else (str-a (cpptype t-cast) "(" (cexp expr-local) ")" )]
     ))

  ;;[ja] 式 expr-local の型が期待される型 t-ref と一致すればそのまま訳し、
  ;;[ja] 違えば cexp-with-cast で変換を挟む。t-ref が Number で式が数値型
  ;;[ja] か数値になりうる未知型なら変換は不要とみなす。
  (define (cexp-cond-cast expr-local t-ref)
   (let ([te (expr->type expr-local)])
     (if (or (eq? te t-ref) (equal? te t-ref) 
	     ;(lset= equal? t-ref te) (lset= eq? t-ref te)
	     )
	 (cexp expr-local)
	 (if (and (eq? t-ref Number)
		  (or (number-type? te)
		      (type-unknown->number-any-union-type? te unknown-type-list))) 
	     (cexp expr-local)
	     (cexp-with-cast expr-local t-ref)))))

  ;;[ja] 数値として使われる式 e を訳す。変数なら Number への条件付き
  ;;[ja] 変換を通し、それ以外はそのまま cexp に渡す。
  (define (cexp-num e) 
    ;;(cexp e)
    (if (symbol? e)  
    	(cexp-cond-cast e Number)
    	(cexp e))
    )
    
  ;;[ja] 式の翻訳。match の巨大 cond。リテラル・変数・算術・vector-ref・
  ;;[ja] if(値位置)・let(束縛→ 先行文として積む)・関数適用など。
  ;;[ja] 「式の中に文が要る」場面は add-pre-cexp で外へ逃がす。
  (define (cexp expr [t-ref NoType])
    ;(display (list "cexp " expr )) (newline)   
    (match
     expr
     ;; An operation a user binding declared: emit its C++ template over the
     ;; translated operands. At the head of the match for the same reason as
     ;; the stream clauses below -- later clauses match calls first.
     [`(,(? binding-op? BOP) ,BARGS ...)
      (for ([h (binding-op-headers BOP)]) (c-includes-add h))
      (apply format (binding-op-cpp BOP) (map (lambda (a) (cexp a)) BARGS))]
     ;; (cons a (delay b)) is a stream; wrap b in a C++11 lambda so it stays
     ;; delayed. Alpha conversion wraps an anonymous lambda as
     ;; (let ((L (lambda () ...))) L), so accept that shape too. This must sit
     ;; at the head of the match: a local-analysis variant and the function
     ;; name table both match cons first.
     [`(cons ,A (let ((,L (lambda () ,B ...))) ,L2))
      #:when (eq? L L2)
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::make_stream(~a,[=]() { return ~a; })"
	      (cexp A)
	      (cexp (if (= 1 (length B)) (car B) (cons 'begin B))))]
     [`(cons ,A (lambda () ,B ...))
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::make_stream(~a,[=]() { return ~a; })"
	      (cexp A)
	      (cexp (if (= 1 (length B)) (car B) (cons 'begin B))))]
     [(? boolean? X) (if (equal? X #t) "true" "false" ) ]
     ;; Scheme prints infinities as +inf.0/-inf.0, which C++ cannot
     ;; read back; NaN likewise. Every other number keeps its printed
     ;; form.
     [(? number? X)
      (cond [(and (real? X) (infinite? X))
             (if (positive? X)
                 "(std::numeric_limits<double>::infinity())"
                 "(-std::numeric_limits<double>::infinity())")]
            [(and (real? X) (nan? X))
             "(std::numeric_limits<double>::quiet_NaN())"]
            [else (number->string X)]) ]
     [(? string? X) (string-append "\"" X  "\"") ]
     [(? char? X)   (string-append "'" (string expr)  "'") ]   

     [(? symbol? X)  (cname X)]
      ;; (if (eq? t-ref NoType)  (cname X)
      ;; 	  (let ([tx (vtype X)])	
      ;; 	    (if (equal? t-ref tx) (cname X)
      ;; 		(str-a (cpptyp t-ref) "(" (cname X) ")"))))]


     ;; Parenthesised, unlike the arithmetic default below: an operand
     ;; embedded in a further expression (e.g. (* 1.0 (remainder x n))) needs
     ;; its own precedence protected, since % and * bind at the same level
     ;; and are left-associative in C++, so an unparenthesised "a % b" folds
     ;; into a surrounding "c*a % b" as (c*a) % b rather than c*(a % b).
     [`(quotient ,N ,M) (format "(~a / ~a)"  (cexp-num  N) (cexp-num  M))  ]
     ;; remainder had no rule and fell through to the binary default.
     [`(remainder ,N ,M) (format "(~a % ~a)" (cexp-num  N) (cexp-num  M))  ]
     [`(modulo ,N ,M) (format "(~a % ~a)" (cexp-num  N) (cexp-num  M))  ]
     [`(atan ,X ,Y) (c-includes-add "<math.h>") (format "atan2(~a , ~a)"  (cexp-num  X) (cexp-num Y))  ]
     [`(abs ,X) (c-includes-add "<cmath>") (format "std::abs(~a)" (cexp-num  X)) ]
     [`(floor ,X) (c-includes-add "<cmath>") (format "std::floor(~a)" (cexp-num X)) ]
     ;; Truncation toward zero matches R5RS only for non-negative values,
     ;; which is what (inexact->exact (floor x)) feeds it.
     [`(inexact->exact ,X) (format "int(~a)" (cexp-num X)) ]
     ;; C++ containers copy by value; the copy IS the expression.
     [`(vector-copy ,X) (format "(~a)" (cexp X)) ]
     [`(max ,X ,Y) (format "std::max( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [`(min ,X ,Y) (format "std::min( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [ (list (? op-float->float? Op) X) (c-includes-add "<math.h>") (format "~a(~a)" Op (cexp X ))  ]
     [`(not ,X) (format "!(~a)" (cexp X)) ]
     ;; and and or become the C++ short-circuit operators, so the operands are
     ;; evaluated in the same order and only as far as needed.  With no operand
     ;; Scheme gives #t and #f respectively.
     [`(and) "true"]
     [`(or)  "false"]
     [`(and ,E ...) (format "(~a)" (string-join (map cexp E) " && "))]
     [`(or  ,E ...) (format "(~a)" (string-join (map cexp E) " || "))]
     [`(zero? ,X) (format "(~a == 0 )" (cexp-num  X)) ]
     ;; One argument is a separate case.  The variadic clause below joins the
     ;; operands with the operator, and string-join emits no separator when the
     ;; list holds a single element, so (- x) came out as (x): the negation was
     ;; dropped and no error was reported.  A one-argument + or * is indeed the
     ;; argument itself, but - negates and / takes the reciprocal.
     [`(- ,X) (format "(-(~a))" (cexp-num X))]
     [`(/ ,X) (format "(1.0/(~a))" (cexp-num X))]
     [`( ,(? op-num-num-num? Op) ,V-list ...)
      (string-append "(" (string-join (map cexp-num V-list) (symbol->string Op)) ")")]
     [`( ,(? op-num-num-bool? Op) ,X ,Y) 
      (when (equal? Op '=) (set! Op '==))
      (format "~a ~a ~a" (cexp X) Op (cexp Y))]
     ;; [`(lambda ,params ,E ... ) 
     ;;  (clambda expr (gensym 'lambda) #false #false) ]
     [`(set! ,X ,Y) (format "~a = ~a" (cexp X) (cexp Y) )]
     [`(display ,X)  (c-includes-add "<iostream>") (format "std::cout << ~a" (cexp X))]
     ['(newline)  (c-includes-add "<iostream>") (format "std::cout << std::endl") ]
     [`(vector-ref ,X ,N) (format "~a[~a]"  (cexp X) (cexp N))] 
     [`(vector-set! ,X ,N ,V)(format "~a[ ~a ] = ~a " (cexp X)(cexp N)(cexp V))]
     [`(vector-length ,X)
      (let ((x (
		;expr->expand-type
		expr->type
		X)))
	;(display (list 'vec-len-cexp X x))(newline)
	(match 
	 x
	 [`(make-vector ,N ,V) (format "~a" (if (number? N) N (cexp N)))]
	 [`(vector ,E ...) (format "~a" (length E))]
	 [ _ (format "vector_length(~a)" (cexp X))  ]))]	    
     ;; [`(make-vector ,N1 ,V1)]
     ;; [`(make-vector ,N ,V)  `(make-vector ,N ,(inf V)  )]
     [`(if ,E1 ,E2 ,E3)	(format "( ( ~a ) ? (~a) : (~a) )" (cexp E1) (cexp E2) (cexp E3)) ]
     [`(cond (,X ,E) ...)
      ;(display (list 'cond-cexp X E))(newline)
     	(format 
     	 "( ~a )"
     	 (str-j 
     	  (append
     	   (map
     	    (lambda (x y)(format "( ~a ) ? ( ~a )" (cexp x)(cexp y))) 
     	    (drop-right X 1) (drop-right E 1) )
     	   (list (apply str-a
     	    (cons (format "( ~a )" (cexp (last E)))
     		  (make-list (- (length E) 1) ")")))))
     	  " : ( "))]
     [(or `(define ,(? symbol? X) (make-vector ,(? number? N) ,V))
	  `(define ,(? symbol? X) (make-list ,(? number? N) ,V)))
      ;;(display (list "def make vec " X N V expr)) (newline)(display (list (cpptype (expr->type V) ) (cpptype (expand-type X env-type-local) ))) (newline)
      ;; The vector representation follows the back end. Thrust needs the data
      ;; in device memory, and offloading a boost::array is not portable, so
      ;; under gpu a plain array is emitted and filled by a loop.
      (cond
       [(equal? (getenv "SCM2CPP_PARALLEL") "thrust")
	(c-includes-add "<thrust/device_vector.h>")
	(format "thrust::device_vector<~a> ~a(~a,~a)"
		(vector-elem-cpptype X V) (cexp X) N (cexp V))]
       [(equal? (getenv "SCM2CPP_PARALLEL") "gpu")
	(format "~a ~a[~a]; for(int scm2cpp_i=0;scm2cpp_i<~a;scm2cpp_i++) ~a[scm2cpp_i]=~a"
		(vector-elem-cpptype X V) (cexp X) N N (cexp X) (cexp V))]
       [else
	(c-includes-adds (list "<array>" "\"scm2cpp.hpp\""))
	(format "std::array<~a,~a> ~a = scm2cpp::filled_array<~a,~a>(~a)"
		(vector-elem-cpptype X V) N (cexp X)
		(vector-elem-cpptype X V) N (cexp V) )])
      ]
     [(or 
       `(define ,(? symbol? X) (make-vector ,N ,V))
       `(define ,(? symbol? X) (make-list ,N ,V)))
      (c-includes-add "<vector>")
      ;; N is an expression here, not a literal, and must be translated;
      ;; it reached the output as a raw s-expression before.
      (format "std::vector<~a> ~a(~a,~a)" (vector-elem-cpptype X V) (cexp X) (cexp N) (cexp V))]
     [(or `(make-vector ,(? number? N) ,V)
	  `(make-list ,(? number? N) ,V))
      (c-includes-adds (list "<array>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::filled_array<~a,~a>(~a)"  (sexp->cpptype V) N (cexp V) )]
     [(or
       `(make-vector ,N ,V)
       `(make-list ,N ,V))
      (c-includes-add "<vector>")
      ;; The extent is an expression -- (* n n) reaches here from a
      ;; make-vector in return position -- so it must go through cexp;
      ;; written raw it comes out as prefix Scheme inside the C++.
      (format "std::vector<~a>(~a,~a)" (sexp->cpptype V) (cexp N) (cexp V))]
     ;; A (vector e ...) literal. Inference already types it as a
     ;; fixed-extent array of the first element's type; the runtime's
     ;; make_array builds that boost::array in one expression, casting
     ;; the later elements to the first one's type. Before this clause
     ;; the literal fell through to the call path and came out as the
     ;; undefined function vector(...).
     [`(vector ,E1 ,Es ...)
      (c-includes-adds (list "<boost/array.hpp>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::make_array(~a)"
	      (string-join (map cexp (cons E1 Es)) ","))]
     ;; Build a (list e ...) value. std::list rather than std::vector, because
     ;; uniform_sequence_to_boost_ptr_sequence_view maps a vector to
     ;; ptr_vector, which has no push_front, so cons would not compile.
     [`(list ,params ...)
      (let ([ts (map (lambda (p) (sexp->cpptype p)) params)])
	(cond
	 [(null? params)
	  (c-includes-add "<list>")
	  "std::list<int>()"]
	 [(list-all-equal? ts)
	  (c-includes-add "<list>")
	  (format "std::list<~a>{~a}" (car ts) (str-j (map cexp params) ","))]
	 [else
	  (c-includes-add "<boost/fusion/include/list.hpp>")
	  (format "boost::fusion::make_list(~a)" (str-j (map cexp params) ","))]))]
     ;; Hash tables. A table is declared empty from its inferred type;
     ;; (make-hash) has no type of its own, so it only appears as an
     ;; initialiser. hash-ref with no default is .at(), which throws
     ;; where Racket raises; with a default it is a count() test, one
     ;; lookup more than a find() would cost but readable.
     [`(define ,(? symbol? X) (make-hash))
      (format "~a ~a" (sexp->cpptype X) (cexp X))]
     [`(hash-ref ,H ,K) (format "~a.at(~a)" (cexp H) (cexp K))]
     [`(hash-ref ,H ,K ,D)
      (format "( ~a.count(~a) ? ~a.at(~a) : (~a) )" (cexp H) (cexp K) (cexp H) (cexp K) (cexp D))]
     [`(hash-set! ,H ,K ,V) (format "~a[ ~a ] = ~a " (cexp H) (cexp K) (cexp V))]
     [`(hash-has-key? ,H ,K) (format "( ~a.count(~a) > 0 )" (cexp H) (cexp K))]
     [`(hash-count ,H) (format "(int)~a.size()" (cexp H))]
     [`(define ,(? symbol? X) ,E)
      ;; A local whose type the inference did not settle has no name to be
      ;; declared with: the type is either an unknown that never got
      ;; resolved, or a template parameter belonging to some other
      ;; function and not in scope here. The initializer knows, so let it
      ;; say -- auto rather than decltype(auto), because this is a value
      ;; declaration and decltype(auto) would bind a reference wherever
      ;; the initializer happens to be an lvalue, aliasing what the
      ;; current emission copies.
      (let* ([t (sexp->cpptype X)]
	     ;; Template parameter names are the variable's own name with
	     ;; Type appended, so a bare one of that shape which the
	     ;; enclosing function does not declare belongs to another
	     ;; function and is not a type here. A rendering that still
	     ;; carries an unresolved type is not a type anywhere.
	     [in-scope current-template-names]
	     [unresolved?
	      (and (string? t)
		   (or (regexp-match? #px"\\bUnknown" t)
		       (and (regexp-match? #px"^[A-Za-z_][A-Za-z0-9_]*Type[0-9]*$"
					   (string-trim t))
			    (not (member (string-trim t) in-scope)))))])
	(format "~a ~a = ~a" (if unresolved? "auto" t) (cexp X) (cexp E))) ]
     [`(quote ,(? symbol? X) ) (format  "string_to_symbol(\"~a\") " X) ]

     [`( ,(? cpp-function-name-correspond-alist? f) ,E ... )
      ;(display (list f E))(newline) 
      (format "~a (~a)" 
	      (cpp-function-name-in-correspond-alist f)
	      (string-join (map cexp E) " , "))
     	      ;(map cexp E)
      ]

     [_ (cexp-with-local-analysis expr t-ref)]
     ))
  ;; Does the body ever make V name a different object than its initialiser?
  ;; (set! V INIT) is the redundant self-assignment the FFT benchmark writes
  ;; and leaves V an alias; (set! V SOMETHING-ELSE) would not.
  ;;[ja] 本体 expr の中に、変数 v を初期化子 init 以外のものに付け替える
  ;;[ja] set! があるかを返す。(set! v init) という自己代入は別名関係を
  ;;[ja] 保つので数えない。参照束縛にしてよいかの判定に使う。
  (define (set!-repoints? expr v init)
    (cond
      [(and (pair? expr) (eq? (car expr) 'set!)
	    (pair? (cdr expr)) (eq? (cadr expr) v))
       (not (and (pair? (cddr expr)) (eq? (caddr expr) init)))]
      [(pair? expr) (or (set!-repoints? (car expr) v init)
			(set!-repoints? (cdr expr) v init))]
      [else #f]))

  ;; A let binding whose initialiser is another container variable is an alias
  ;; in Scheme: after (let ((ar areal)) ...) the two names denote one vector,
  ;; so a vector-set! through ar is visible through areal and to the caller.
  ;; Declaring a fresh container and copying loses every such write -- the FFT
  ;; benchmark transformed a copy and returned its input untouched. Bind a
  ;; reference instead. That is sound while the name is never re-pointed:
  ;; Scheme's set! would rebind the name, where assignment through a reference
  ;; would overwrite the aliased object, so that case keeps the copy.
  ;; The copy that case falls back to is not what Scheme means either: after
  ;; (set! v w) a write through v hits w's vector, where the copy keeps them
  ;; apart. Faithful emission would need a pointer, since a C++ reference
  ;; cannot be re-pointed, and every use of the name would have to
  ;; dereference. Until that exists, say so rather than emit a silent
  ;; divergence -- the FFT benchmark spent years passing while returning its
  ;; input, which is what silence costs.
  ;;[ja] let の束縛 1 つを C++ の宣言文字列にする。初期化子が別のコンテナ
  ;;[ja] 変数で、本体中で付け替えられないなら参照として束縛し、Scheme の
  ;;[ja] 別名の意味を保つ。付け替えがある場合はコピーになるので警告を
  ;;[ja] 出してから通常の define として訳す。
  (define (clet-binding v init body)
    (cond
      [(and (symbol? init)
	    (container-type? (vtype v))
	    (not (set!-repoints? body v init)))
       (format "~a & ~a = ~a" (sexp->cpptype v) (cname v) (cexp init))]
      [else
       (when (and (symbol? init) (container-type? (vtype v)))
	 (eprintf "warning: ~a is bound to the container ~a and then re-pointed by set!; C++ assignment copies contents where Scheme rebinds the name, so writes through ~a after the set! will not be seen through the other name~n"
		  (cname v) (cexp init) (cname v)))
       (cexp `(define ,v ,init))]))

  ;;[ja] 文の翻訳。display/newline/set!/vector-set!/do ループ・
  ;;[ja] 文位置の if などはここ。cexp と違い値を作らない形を許す。
  (define (cstat expr
		 [cterm-stat cstat-semi]  ;cstat-ret
		 [cterm-exp cexp] ;cexp-ret
		 )
    ;(display (list "cstat "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (match 	 
     expr
     [(or `(cond ,E ...) `(begin (cond ,E ...))) 
      (let* ((clauses (drop-right E 1))
	     (last-clause  (last E))
	     (cond-cexp-fn (lambda (x) (cexp (car x))))
	     (cconds (map cond-cexp-fn clauses))	     
	     (clast 
	      (match 
	       last-clause
	       [`(else ,E1 ... ) 
		(begin-inc-lv
		 (str-a "{"(cterm-stat `(begin . ,E1)) "}"))]
	       [ _ (format "if(~a){~a}" (cexp (car last-clause))
			   (begin-inc-lv
			    (cterm-stat `(begin . ,(cdr last-clause)))
			    )
			   )
		   ])))
	(begin-dec-lv
	 ;(display (list "cstat-cond " cconds ))(newline)
	 (str-j 
	  (append
	   (map (lambda (c x)(format "if(~a){~a}" c (cterm-stat `(begin . ,(cdr x))))) cconds clauses)
	   (list clast))
	  " else ")))]
     [(or `(if ,E1 ,E2 ,E3) `(begin (if ,E1 ,E2 ,E3)))	
      (format "if( ~a ) { ~a } else { ~a }" 
	      (cexp E1) (begin-inc-dev-lv (cterm-stat E2))  (begin-inc-dev-lv (cterm-stat E3)) )]
     [(or `(if ,E1 ,E2)  `(begin (if ,E1 ,E2)) `(when ,E1 ,E2) `(begin (when ,E1 ,E2)))
      (format "if( ~a ){~a}" (cexp E1) (begin-inc-dev-lv (cterm-stat E2)) ) ]
     [(or `(unless ,E1 ,E2) `(begin (unless ,E1 ,E2)))
      (format "if( ~a ){}else{~a}" (cexp E1) (begin-inc-dev-lv (cterm-stat E2) )) ]
     [`(begin ,E ...)
      ;(begin-inc-dev-lv
      (let* ([saved integ-share-plan]
	     [plan (integ-plan-sequence E)])
	(set! integ-share-plan (append plan saved))
	(let ([r (str-a
		  (apply str-a (map cstat-semi (drop-right E 1)))
		  ;; (cexp-ret (last E))
		  (cterm-stat (last E)))])
	  (set! integ-share-plan saved)
	  r))]
     ;; [`(begin ,E ...) (cstat-semi expr)]
     [`(define (,F ,params ...) ,E ... ) 
      (clambda 
       (cons 'lambda (cons params E))
       F F #false)]
     [`(let ((,L (lambda ,params ,E ... ))),L)
      (cexp-with-local-analysis expr)]
     [`(let (,V ... ) ,E ...)
      (let* ((cvarsinit (map (lambda (e) (clet-binding (car e) (cadr e) E)) V)))
	(str-a (str-j cvarsinit ";") ";"
	       (begin-inc-dev-lv 	       
		(cterm-stat `(begin . ,E)))))]
     [`(do  ,bindings ,pred ,E ... )
      ;(display (list 'do-cpp bindings pred E))(newline)	(format "for( ~a ;;~a )" (str-j cvarsinit ",") (str-j cvarsnext ","))
      (let* ((ii (integ-boxsum-nest expr))
	    (thr (and (not ii) (thrust-loop bindings pred E)))
	    (prag (parallel-pragma bindings pred E))
	    (cvarsinit (map (lambda (e) (cexp `(define ,(car e) ,(cadr e)))) bindings))
	    (cvarsnext (map (lambda (e) (cexp `(set! ,(car e) ,(caddr e)))) bindings))
	    (cend (match (car pred)
			 [`(not ,X) (cexp X)]
			 [_ (str-a "!(" (cexp (car pred)) ")")]))
	    (cret (if ( >  (length pred) 1)
		      (cexp (cadr pred)) ""))
	    (outer in-parallel-loop)
	    ;; The body is generated with the flag set only if this loop was
	    ;; actually annotated, so that a nested loop does not get a second
	    ;; directive -- but does get its chance when this one was rejected.
	    (cb (begin
		  (set! in-parallel-loop (or outer (not (equal? prag ""))))
		  (let ([r (if (null? E) ""
			       (begin-inc-dev-lv
				(str-a "{" (cstat-semi `(begin . ,E)) "}")))])
		    (set! in-parallel-loop outer)
		    r))))
	(if ii ii
	(if thr thr
	(if (or (equal? cterm-stat cstat-semi) ( <  (length pred) 2))
	    (str-a prag
		   (format "for( ~a ; ~a ; ~a )" (str-j cvarsinit ",") cend (str-j cvarsnext ","))  cb)
	    (str-a 
	     (format "for( ~a ;; ~a )" (str-j cvarsinit ",") (str-j cvarsnext ","))
	     (format "if( ~a ){ ~a }else{ ~a }  " (cexp (car pred)) (cterm-stat (cadr pred)) (begin-inc-dev-lv (cstat-semi `(begin . ,E)))))))))]
     [_ (cterm-exp  expr)]
     ))
  ;; Set around each function body: a void function must not return a
  ;; value, so its tail expression is emitted as a bare statement.
  ;;[ja] 今の関数が void なら #t。末尾の式を return にせず素の文で出す。
  (define current-fn-ret-void #f)
  ;;[ja] 関数本体の末尾の式 expr を訳し、溜まっていた前置文を前に付けて
  ;;[ja] return 文にする。void 関数のときは return を付けず素の文にする。
  ;;[ja] 前置文を吐いた後は pre-cexp の最上段を空に戻す。
  (define (cexp-ret expr)
    ;(display (list "cexp-ret "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (let* ((o (cexp expr))
	   (o2 (if current-fn-ret-void
		   (format "~a ~a ;" (stack-top pre-cexp) o)
		   (format "~a return ~a ;" (stack-top pre-cexp) o))))
      (stack-set! pre-cexp 0 "") 
      o2))
  ;;[ja] 式 expr を文として訳し、前置文を前に付けてセミコロンと改行で
  ;;[ja] 閉じる。begin は各文を順に処理し、その列に対して積分画像の表
  ;;[ja] 共有計画を立ててから訳す。前置文は吐いた後に空に戻す。
  (define (cstat-semi expr)
    ;(display (list "cstat-semi "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (match 
     expr
     [`(begin ,E ...)
      (let* ([saved integ-share-plan]
	     [plan (integ-plan-sequence E)])
	(set! integ-share-plan (append plan saved))
	(let ([r (apply string-append (map cstat-semi E))])
	  (set! integ-share-plan saved)
	  r))]
     [ _
       (let* ((o (cstat expr))
	      (o2 (format "~a ~a " (stack-top pre-cexp) o)))
	 (stack-set! pre-cexp 0 "")
	 ;(set! pre-cexp "")
	 (format "~a ;~n" o2)
	  )]))
  ;;[ja] 関数本体の末尾に置く文として expr を訳す。cstat に終端処理
  ;;[ja] として cstat-ret と cexp-ret を渡し、最後に評価される式に
  ;;[ja] return が付くようにする。前置文を前に付けてから空に戻す。
  (define (cstat-ret expr)
    ;(display (list "cstat-ret "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (let* ((o (cstat expr cstat-ret cexp-ret))
	   (o2 (format "~a ~a" (stack-top pre-cexp) o)))
      (stack-set! pre-cexp 0 "")
      o2))

      ;(cstat expr cstat-ret cexp-ret))
  ;;[ja] トップレベル形の振り分け: (define (f ...) ...) → cdeffun、
  ;;[ja] (define x e) → 大域変数宣言、それ以外 → 文として main 相当へ。
  (define (cdefs expr)
    ;(display (list "cdefs " expr))(newline)
    (match 
     expr	 
     [`(define (,params ...) ,E ... ) (cdeffun expr)]
     ;; Global definitions must precede the function bodies, which go to the
     ;; header; writing them to the source file inverts the declaration order.
     [`(define ,(? symbol? X) ,E)
      (set! port-o port-h)
      (pout (cstat-semi expr))]
     [_
      ;(display (list "cdefs last " expr))(newline)
      (set! port-o port-c)
      (pout (cstat-semi expr))]))
  ;;[ja] 関数定義の翻訳の要所。流れ:
  ;;[ja]   1. 返り値型 lambda-ret-type を環境から取得
  ;;[ja]   2. current-template-vars/-types — 未確定型 → テンプレート仮引数
  ;;[ja]      候補。署名文字列に実際に現れた名前だけが template<...> に残る
  ;;[ja]   3. 返り値が未確定で引数から推論不能なら decltype(auto)
  ;;[ja]      (再帰関数には効かないのでその場合はテンプレートのまま)
  ;;[ja]   4. 非テンプレートなら inline を付けヘッダへ、capi-add! で
  ;;[ja]      -M ラッパ候補に登録。デバイス安全な本体なら SCM2CPP_FN
  ;;[ja]      (nvcc 下で __host__ __device__)を前置
  ;;[ja]   5. 本体は cstat-ret(最後の式に return を付ける)
  (define (cdeffun expr)
    (display (list "cdeffun0 " expr))(newline)
    (hout (format "~n"))     (cout (format "~n"))
    ;(display (list 'cdeffun1  expr (function-name expr) (vtype (function-name expr) )))(newline)
    (let-values ([(expr1 alpha1 free1)  (alpha-conv expr)])
      ;(display (list 'cdeffun2  expr1 alpha1 free1 ))(newline)
      (let* ((free1inv ( envinvert free1))
	     (alpha1inv ( envinvert alpha1))
	     (freevars (map car free1inv))
	     (vars1  (map car alpha1inv))
	     (t-vars1  (filter non-fix-type? vars1))	     
	     (lambda-ret-type
	      (last (cdr (vtype (function-name expr) ))))
	     [all-vars-return2 (append 	vars1 freevars (list lambda-ret-type))]
	     [all-vars-return1 (append 	vars1          (list lambda-ret-type))]
	     )
	;(display (list 'cdeffun3 t-vars1))(newline)
	(display (list 'all-vars-return1 all-vars-return1))(newline)
	(set! current-template-vars	       
		(remove-duplicates
		 (if (non-fix-type? lambda-ret-type)
		     (append (list lambda-ret-type )  t-vars1)
		     t-vars1))
		)
	(set! current-template-types
	      (vars-typeenv-unknown->unknown-types all-vars-return1 env-type-local unknown-type-list))

	;(display (list 'cdeffun2 lambda-ret-type ))(newline)
	;(display (list 'cdeffun2 lambda-ret-type  (sexp->cpptype lambda-ret-type)))(newline)
	(match
      	 expr
      	 [`(define (,F ,params ...) ,E ... )
          ;(display (list "def params0 " F  params lambda-ret-type E))
	  ;(display (list "def params "  params lambda-ret-type (sexp->cpptype lambda-ret-type)))
	  (if (null?  current-template-vars) (set! port-o port-c) (set! port-o port-h))
	  (let* ((mutated-params
		  ;; The parameters this function may write, by name; the
		  ;; summary stores indices so that alpha renaming cannot
		  ;; desynchronise it. A function absent from the summary
		  ;; (renamed, say) yields #f -- no const information --
		  ;; rather than an empty list, which would claim that
		  ;; nothing is written.
		  (let ([idxs (hash-ref mutation-summary F #f)])
		    (and idxs
			 (filter-map (lambda (i) (and (< i (length params)) (list-ref params i)))
				     idxs))))
		 (cargs-cstr (svars->cargs params #false mutated-params))
		 ;; A return type the inference did not settle used to become
		 ;; a template parameter like any other unsettled type. In
		 ;; return position that does not work: the parameter appears
		 ;; nowhere in the arguments, so the call site cannot deduce
		 ;; it and cannot name it either -- the emitted caller wrote a
		 ;; type that is not in scope there. C++ has the right feature
		 ;; for this position, so use it: decltype(auto) lets the body
		 ;; settle the type, and preserves the value category exactly
		 ;; where a plain auto would strip a reference and copy.
		 ;; Deducible cases -- the return type also appears among the
		 ;; parameters -- keep the template parameter, which works.
		 (ret-cstr
		  (let ([r (cpptype lambda-ret-type)])
		    (if (and (non-fix-type? lambda-ret-type)
			     (not (equal? (cname F) "main"))
			     (string? r)
			     (not (regexp-match?
				   (pregexp (string-append "\\b" (regexp-quote (string-trim r)) "\\b"))
				   cargs-cstr)))
			"decltype(auto)"
			r)))
		 (func-def-cstr (format "~a \n ~a(~a)"  ret-cstr (cname F) cargs-cstr))
		 ;; Whether the function is a template is decided by the same
		 ;; string the output uses: current-template-vars still holds
		 ;; unpruned candidates at this point.
		 (ctemplatedef (types->ctemplatedef-used current-template-types func-def-cstr))
		 ;; Recorded before the body is emitted, which is what reads it.
		 (template-names-here
		  (set! current-template-names
			(types->ctemplatedef-used-names current-template-types func-def-cstr)))
		 ;; A function whose return type the body settles has no
		 ;; spelling to put in a C header, so it stays out of the C
		 ;; API rather than being exported under a wrong one.
		 (capi-entry
		  (when (and (string=? "" (string-trim ctemplatedef))
			     (not (equal? ret-cstr "decltype(auto)"))
			     (not (equal? (cname F) "main")))
		    (capi-add! (list (cname F) (cpptype lambda-ret-type) last-cargs-info))))
		 ;; A non-template function is defined in the header, so it
		 ;; needs inline: without it the definition has external
		 ;; linkage and including the header from a second translation
		 ;; unit is a duplicate symbol, and the compiler is also less
		 ;; willing to expand the call. A small helper called once per
		 ;; array element cost three times the loop it was helping when
		 ;; it was not expanded. main is exempt -- it may not be inline.
		 (inline-kw (if (and (string=? "" (string-trim ctemplatedef))
				     (not (equal? (cname F) "main")))
				"inline " ""))
		 (body-cstr
		  (begin
		    (inc-lv)
		    (set! current-fn-ret-void (equal? (cpptype lambda-ret-type) "void"))
		    (let ([body (cstat-ret (cons 'begin E))]) ;;func body
		      (set! current-fn-ret-void #f)
		      body)))
		 ;; A function whose signature and body stay inside the
		 ;; device-safe subset -- no streams, no containers, no
		 ;; closures, no runtime tables backed by std::vector --
		 ;; is marked SCM2CPP_FN: __host__ __device__ under nvcc,
		 ;; nothing anywhere else.  main and templates are never
		 ;; marked.
		 (device-kw
		  (if (and (string=? "" (string-trim ctemplatedef))
			   (not (equal? (cname F) "main"))
			   (not (regexp-match?
				 #px"std::cout|std::cerr|std::endl|std::vector|std::string|std::list|std::map|std::function|make_promise|integral_image|monoid_table|\\bnew\\b|\\bdelete\\b"
				 (string-append func-def-cstr body-cstr))))
		      "SCM2CPP_FN " ""))
		 (cfunstr	    
		  (format 
		   "\n ~a \n ~a~a~a \n {~a}" 
		   ctemplatedef
		   device-kw
		   inline-kw
		   func-def-cstr 
		   body-cstr))
		 (cfunstr2 (str-a pre-cfun cfunstr)))
	    ;(display (list "cdeffun3"  current-template-vars))(newline)
	    (dec-lv)
	    (c-fwd-decl-add
	     (format "~a~a~a;~n"
		     (types->ctemplatedef-used current-template-types func-def-cstr)
		     device-kw
		     func-def-cstr))
	    (set! pre-cfun "")
	    (pout cfunstr2)
	    )	
	  ]
	 [_ 
	  ;; (error "unknown-expression in scm2cpp-def" expr)
	  (cstat-semi expr)
	  ;(format " error_in_gen_cexp-def ~a " expr) 
	  ]
	 )))
    )

  (c-includes-add "\"scm2cpp.hpp\"" )


					;(cstat expr-alpha)
  ;(display (list 'expr-alpha expr-alpha)) (newline)
  ;; (display env-alpha-inv)
  ;; (display env-free-inv)
  ;; (display env-init-type )
  ;(display env-type) (newline)
  ;; (define (tmpf a b)  (display env-type-local) (+ a b))
  ;; (display (tmpf 1 10)) 
  ;; (cexp-with-local-analysis  '(let ((z (lambda (x127 y128) (+ x127 y128)))) (lambda (u v) x (+ u v))))

  ;;(cdeffun expr-alpha)
  ;; (cdeffun (cadr expr-alpha))  
  ;; (when env-ret-type 
  
  ;; A user binding, if SCM2CPP_BINDING names one -- loaded before the
  ;; mutation summaries, which consult the ops' mutates declarations.
  (load-binding!)

  ;; Which function may write which parameter, needed both for the const
  ;; parameters below and for the write-free spans the sharing of
  ;; summed-area tables depends on; the liveness pass recomputes those
  ;; summaries and then classifies each written parameter as output or
  ;; scratch. Nothing downstream consumes the classification yet.
  (compute-param-liveness! expr-org)

  (capi-reset!)

  (map
   cdefs (cdr expr-alpha))

  ;(string-append 
  (string-append
   (apply string-append
	  (map (lambda (x)
		 (list->string (append (string->list "#include" ) '(#\tab) (string->list  x ) '(#\newline))))
	       c-includes))
   (format "~n")
   (apply string-append c-fwd-decls))
           
  )




					;(display 
					;(declare-names  (call-with-input-file "scm2c.typ" read))
					; ) 

;(define scmcode '(define (f x) y ))

;;[ja] 展開済みの S 式 scmcode を scm2cpp-match-port に渡し、ヘッダと
;;[ja] 本体の C++ を文字列として受け取って 2 値で返す。生成された文字列が
;;[ja] 最小ランタイムの範囲に収まると判定できたときだけ、boost の include
;;[ja] を落として SCM2CPP_MINIMAL を定義した include 部を先頭に付ける。
(define (scm2cpp-match-values scmcode)
  (let* ((cppcode "")
         (hppcode "")
	 (includes "")
	 )
    (set! 
     hppcode 
     (call-with-output-string 
      (lambda (port-h)
	(set! cppcode
	      (call-with-output-string       
	       (lambda (port-c)
		 (set! includes
		 (scm2cpp-match-port scmcode port-h port-c))))))))
    ;; A program gets the minimal runtime -- boost includes dropped,
    ;; scm2cpp.hpp gated down to what a numeric kernel touches, which
    ;; is what still compiles where boost cannot follow, CUDA first
    ;; among them -- only when the generated text provably stays
    ;; inside that section: no boost token, no list machinery, and
    ;; every scm2cpp:: reference on the minimal whitelist.
    ;;[ja] 最小ランタイムの範囲内で使ってよい scm2cpp:: 名の許可一覧。
    (define minimal-names
      '("make_array" "filled_array" "integral_image" "monoid_table"
        "mt_add" "mt_mul" "mt_min" "mt_max" "span" "cspan"))
    ;;[ja] 生成テキスト txt が最小ランタイムだけで足りるかを返す。
    ;;[ja] boost、list や map、std::function、make_promise が出ず、
    ;;[ja] scm2cpp:: の参照がすべて許可一覧に載っていれば真。
    (define (minimal-text? txt)
      (and (not (regexp-match? #rx"boost" txt))
           ;; closures and promises call into the full runtime without
           ;; a scm2cpp:: prefix, so their type and builder are
           ;; disqualifiers in their own right
           (not (regexp-match? #rx"std::list|std::map|std::function|make_promise"
                               txt))
           (for/and ([m (regexp-match* #rx"scm2cpp::([A-Za-z_]+)" txt
                                       #:match-select cadr)])
             (member m minimal-names))))
    (when (and (minimal-text? hppcode) (minimal-text? cppcode))
      (set! includes
            (string-append
             "#define SCM2CPP_MINIMAL
"
             (string-join
              (filter (lambda (l) (not (regexp-match? #rx"boost" l)))
                      (string-split includes "
"))
              "
")
             "
")))
    (set! hppcode  (string-append includes hppcode ))
  (values hppcode cppcode)))

;;[ja] C++ 文字列 cppcode-str を astyle で整形して返す。呼び出しごとに
;;[ja] 一時ファイルを作るので、翻訳が並行して走っても互いの出力を
;;[ja] 読み違えない。
(define (cpp-code-string-indent cppcode-str)
  ;; A fixed shared path here meant concurrent translations (as when
  ;; run-tests.sh and a manual invocation overlap) could each overwrite the
  ;; other's file mid-astyle-run, so one process could read back the other's
  ;; program. A fresh temporary file per call avoids that.
  (let ([tmp (make-temporary-file "scm2cpp-indent~a.cpp")])
    (display-to-file cppcode-str tmp #:exists 'replace)
    (port->string (car (process (format "astyle ~a" tmp))))
    (let ([result (file->string tmp)])
      (delete-file tmp)
      result)))

;; (define tmp-cppstr
;; "
;; template< typename XType >  double f( XType  x  ,  double  y ) {
;;  struct let127 { 
;;  double  &  y;
;;   let127( double  &  y ):y(y)  {} 
;;  double operator()( int  v  ,  double  u  ) 
;;  {  u = 20  ;
;;     v =  \"aaaaa\"
;;  return (u+y) ; } }  ;
;;  return (10+let127(y)(3,10)) ;}
;; ")
;; (display (cpp-code-string-indent tmp-cppstr))



;;[ja] ============================================================
;;[ja] 外部入口。ソース文字列と型注釈文字列を受け、
;;[ja] (ヘッダ文字列 本体文字列 "") を返す。パイプラインは:
;;[ja]   1. declare-names        — 型注釈(.typ)を環境に登録
;;[ja]   1b. derive-source-maybe (--derive 時)— 配列代数による導出
;;[ja]   2. macro-expand         — ユーザ define-macro と配列マクロを展開
;;[ja]   3. rewrite-named-let    — 末尾再帰の名前付き let → do ループ形へ
;;[ja]   4. scm2cpp-match-values — 下の巨大関数で型推論+ C++ 生成
;;[ja]   5. astyle 整形(cpp-code-string-indent)
;;[ja] ============================================================
;;[ja] --save-scm の実装。SCM2CPP_SAVE_SCM にパスが入っていれば、
;;[ja] 「導出 + マクロ展開 + named-let 書き換え」を通った直後の
;;[ja] プログラム — C++ になる直前の Scheme — をそこへ書き出す。
;; With SCM2CPP_SAVE_SCM=<path>, the program is written there as Scheme
;; at the moment it is about to become C++: user and array macros
;; expanded, tail-recursive named lets already loops, the derivation
;; (when enabled) applied. What the file holds is a program the
;; translator itself accepts again, so a derived kernel can be read,
;; kept, edited, and re-translated -- the paper's re-express-as-Scheme
;; workflow, mechanised. The identity is the point: translating the
;; saved file must give the same C++ as the run that saved it.
(define (save-scm-maybe expr)
  (let ([path (getenv "SCM2CPP_SAVE_SCM")])
    (when (and path (non-empty-string? path))
      (call-with-output-file path #:exists 'replace
	(lambda (out)
	  (fprintf out ";; scm2cpp --save-scm: the program after macro~n")
	  (fprintf out ";; expansion and rewriting, before C++ emission.~n")
	  (for ([form (if (and (pair? expr) (eq? (car expr) 'begin))
			  (cdr expr) (list expr))])
	    (pretty-write form out)
	    (newline out)))))
    expr))

;;[ja] --derive の実装。SCM2CPP_DERIVE=1 のとき、マクロ展開前のソース
;;[ja] 文字列を読み直し、各関数の with-arrays 宣言から配列の形を取って
;;[ja] 座標降下の残差更新を差分化(rewrite-derive.scm)し、導出後の
;;[ja] プログラムを文字列に戻す。どの仮引数が出力かは展開後の
;;[ja] プログラムに生存解析(compute-param-liveness!)をかけて決める:
;;[ja] 出力である作業ベクトルは最後に復元され、そうでなければ省く。
;;[ja] 何かが導出された関数ごとに "derive: f: raise differencing" を
;;[ja] 標準エラーに報告する。無効時はソース文字列をそのまま返す。
;; With --derive the source is read before macro expansion -- that is
;; where the with-arrays declarations still stand -- and each function
;; that declares its shapes is offered to the derivation.  Which of its
;; parameters are outputs comes from the liveness pass over the
;; expanded program, so a residual the caller reads is restored and one
;; nobody reads is not.  The derived program then takes the ordinary
;; road: expansion lowers the array forms the derivation wrote.
(define (derive-source-maybe src)
  (cond
    [(not (derive-enabled?)) src]
    [else
     (define forms
       (call-with-input-string src
         (lambda (p) (let loop ([acc '()])
                       (let ([f (read p)])
                         (if (eof-object? f) (reverse acc) (loop (cons f acc))))))))
     (cond
       ;; nothing declares a shape: the source goes on untouched (not
       ;; even re-printed, so the plain translation is byte-identical)
       [(not (memq 'with-arrays (flatten forms))) src]
       [else
        (compute-param-liveness!
         (rewrite-named-let
          (call-with-input-string
           (string-append "(begin " (scheme-code-string-macro-expand src) ")")
           (lambda (p) (read p)))))
        (define (outputs g ps)
          (for/list ([i (function-output-params g)] #:when (< i (length ps)))
            (list-ref ps i)))
        (define derived (derive-forms forms outputs))
        (for ([entry (derive-log)])
          (eprintf "derive: ~a: ~a\n" (car entry)
                   (string-join (map symbol->string (cdr entry)) " ")))
        (call-with-output-string
         (lambda (out)
           (for ([f derived]) (pretty-write f out) (newline out))))])]))

;;[ja] 翻訳の外部入口。上の [ja] の段階 1 から 5 をこの順に実行し、
;;[ja] 整形済みのヘッダ文字列と本体文字列と空文字列のリストを返す。
;;[ja] 呼ぶたびに宣言表と未知型リストを空にしてから始める。
(define (scm2cpp-match-list scmcode-pre-expand-macro-str declarationstr )
  ;;(display (scheme-code-string-macro-expand scmcode-pre-expand-macro-str))
  (set!declarations '())
  (set!unknown-type-list '())
   ;(declare-names declarationstr)
  (declare-names 
   (call-with-input-string 
    declarationstr
    (lambda (p) (read p)))) 
  (call-with-values 
      (lambda ()
	(scm2cpp-match-values
	 (save-scm-maybe
	 (rewrite-named-let
	  (call-with-input-string 
	  (string-append 
	   "(begin "
	   ;;scmcodestr
	   ;;scmcode-pre-expand-macro-str	   
	   (scheme-code-string-macro-expand
	    (derive-source-maybe scmcode-pre-expand-macro-str))
	  ")")
	   (lambda (p) (read p)))))))
    (lambda (h c)
      (list 
       (cpp-code-string-indent h)
       (cpp-code-string-indent c) "")
      ))
  )



;;[ja] 対話的な確認用。S 式 scmcode を begin で包んで翻訳し、
;;[ja] ヘッダと本体をそのまま標準出力に表示する。
(define (scm2cpp-match-display scmcode)
  (call-with-values 
      (lambda ()(scm2cpp-match-values `(begin ,scmcode))) 
    (lambda (h c) 
      (display h) (newline) 
      (display c) (newline)))
  )



;; ;(define tmp-exp (s-read "fft.sc"))
;; (define tmp-exp (s-read "fft-sub1.scm"))
;; ;(set! tmp-exp (cons 'begin tmp-exp))


;; (define tmp-exp-str (with-output-to-string  (lambda () (map display tmp-exp))))
;; ;;(display tmp-exp-str) (newline)


;; (define tmp-exp-str
;; (cond ((not (= n (let loop ((i m) (p 1)) ;Qobi
;; 		    (if (zero? i) p (loop (- i 1) (* 2 p))))))
;; 	 (display 'aaaa)
;; 	 (newline)))
;; )

;; (define tmp-exp-str
;; "
;; (define (f)
;;     (set! x 2)
;;     (cond
;;      ( 
;;       (not 
;;        (= n 
;; 	  (let loop ((i m) (p 1)) 
;; 	    (if (zero? i) p (loop (- i 1) (* 2 p))))
;;        ))
;;     x)
;;      )
;; )
;; "
;; ;; "(define (f x y) 
;; ;;     (if (> x y) 100 3))"
;; )

;; (define tmp-exp-str
;;   "(if z x y)"
;; )


;; ;; ;(define tmp-exp-str  "(+ x 3)")
;; ;(define tmp-exp-str  "(define (f x) x)")
;; (define tmp-exp-str  "(define (f x) (+ 1 x))")
;; ;(define tmp-exp-str  "(define (f x y) (+ y x))")


;; (map display
;; (scm2cpp-match-list 
;; tmp-exp-str
;;  "(
;;  (\"*int\" int) 
;;  (\"main\" int) 
;; )"
;; )
;; )



;;[ja] 手動試験用の Scheme ソース文字列。平方根をニュートン法で求める
;;[ja] 小さなプログラムで、下のコメントアウトされた呼び出しから使う。
;;[ja] 中の define 群は文字列の一部であり、この翻訳器の関数ではない。
(define tmp-exp-str
"
(define (sqrt-double x)
  (sqrt-iter-double 1.0 x))


(define (sqrt-iter-double guess x)
  (if (good-enough? guess x)
      guess
      (sqrt-iter-double (improve guess x)
                 x)))


(define (good-enough? guess x)
  (< (abs (- (square guess) x)) 0.001))


(define (improve guess x)
  (average guess (/ x guess)))


(define (average x y)
  (/ (+ x y) 2.0))


(define (square x) (* x x))


(display (sqrt-double 9.0) )

;; (define (main )
;;    (display (sqrt-double 9) )
;;    ;(display (sqrt-double 8) )
;;    (newline)
;;    0
;; )

")


;; (map display
;; (scm2cpp-match-list 
;; tmp-exp-str
;;  "()"
;; )
;; )










;; ;; "(define (f x y) 
;; ;;     (if (> x y) #t #f)) "


;; ;; "(define (f x y) 
;; ;;     (+ 10 (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1))))"

;; ;; "(define (f x y) 
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1)))"

;; ;; "(define (f) 
;; ;;   (define v (make-vector 3 12.0))
;; ;;   )"

;; ;; "(define (f) 
;; ;;   (make-vector 3 12.0))
;; ;;   "


;; ;; "(define (f) 
;; ;;   (define v (make-vector 3 12.0))
;; ;;   (vector-set! v 2 2.0)
;; ;;   (vector-ref v 3)  
;; ;;   v
;; ;; )"


;; ;; "(define (f x y)
;; ;;    (define (h u v) (* u v))
;; ;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;; ;;       (set! u 20)  
;; ;;       (+ x y))
;; ;;     )
;; ;;     (if (> x y) x y)
;; ;;     (+ 10 (if (> x y) x y))
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)) 
;; ;;     (+ 20 (cond 
;; ;;      ((> x y) 3) 
;; ;;      ((< x y) 10)
;; ;;      (else 1)))
;; ;;     (+ (f 3 5) (h x y) (g x y) )
;; ;;  )
;; ;; (define (g x y)       (+ x y))
;; ;; (define (main)(f 1 2)  0)
;; ;; "

;; ;;" (define (f x y) 
;; ;;    (define (h u v) (* u v))
;; ;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;; ;;       (set! u 20)  
;; ;;       (+ x y))
;; ;;     )
;; ;;     (if (> x y) x y)
;; ;;     (+ 10 (if (> x y) x y))
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)) 
;; ;;     (+ 20 (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1)))
;; ;;     (+ (f 3 5) (h x y) (g x y) )
;; ;;  )
;; ;; (define (g x y)       (+ x y))
;; ;; (define (main)(f 1 2)  0)
;; ;; "
;;  "
;; (
;;  (\"*int\" int) 
;;  (\"main\" int) 
;; )
;; "
;; )
;; )

					;(curry scm2cpp-match-values '(define (f x) (+ x y)))

;; (scm2cpp-match-display '(define (f x y) (set! u 20)  (+ x y)))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;;       (set! u 20)  
;;       (+ x y))
;;     )
;;  ))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+ 10 (let ( (v 3) (u 10)) 
;;       (set! u 20)  
;;       (+ u y))
;;     )
;;  ))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+  10 lambda (x y) (+ x y)) 13)  
;;     )
;;  )

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (let ((z (lambda (x y) (+ x y))) )
;;       (lambda (u v) x (+ u v))
;;     ;0
;;     )))





;; (scm2cpp-match-display '(define (f x) (set! y 10) (+ y x )))

					;(display (scm2cpp-match '(let ((x u)(y 2))(set! z 19) (+ v 29 ))))
					;(scm2cpp-match '(let ((x 20)(y 2))(set! x 19)) )

					;(alpha-free->type-env '((a-int . a-int )) '((b-int . b-int ))) 
					;(scm2cpp-match 'x)
					;(scm2cpp-match '(+ x-int y-int 10 ))
					;(scm2cpp-match '(> x-int y-int ))
					;(scm2cpp-match '(set! v (+ x-int y-int 10 )))
					;(scm2cpp-match '(if (> x y ) (set! x 20 ) (set! y 30)))
					;(display (scm2cpp-match '(if (> x y ) (begin (set! x 20 ) (set! y 30) )  (set! y 1 )))) 
					;(display (scm2cpp-match '(begin (set! x 20 ) (set! y 30))))

					;(scm2cpp-match '(lambda (x) (+ x 10)))
					;(display (scm2cpp-match '(lambda (x) (+ x y))))
					;(display (scm2cpp-match '(define (f x) (+ x y))))
					;(display (scm2cpp-match '(define (f) (+ x y))))

					;(display "aa")
					;(newline)
					;(string-join '("one" "two" "three" "four") " potato ")







					;(scm2cpp-match '(define (f x-int y-int ) (display x) (display y) (+ x-int y-int )) )






;; (define %cpp-expression 
;;   (%rel 
;;    ( Exp O  O1  O2 Op OOp
;;      Pre Post S1 S2 S3 
;;      Clauses Body 
;;      X Y Z A B A-list V-list F
;;      XX YY 
;;      Tmp
;;      )
;;    [( X Y) (%string? X)  (%is Y (string-append "\"" X  "\"")) ] 
;;    [( X Y) (%number? X) (%is Y (number->string X)) ] 
;;    [( X Z) (%char? X) (%is Y (string X)) (%cpp-expression Y Z) ]
;;    [( X O) (%symbol? X)  (%is O (symbol->string X))  ]

;;    [( `(,Op ,X ,Y )  O) 
;;     (%member Op op-num-num-num) 
;;     (%cpp-expression X XX)
;;     (%cpp-expression Y YY)
;;     (%cpp-expression Op OOp)
;;     (%is O (string-append "(" XX OOp YY ")")) 
;;     ]

;;    ;; [( `(,Op . ( ,X . ( ,Y . ,Z )))  O) 
;;    ;;  (%member Op op-num-num-num) 
;;    ;;  (%cpp-expression    )
;;    ;;  (%cpp-expression Y YY)
;;    ;;  (%cpp-expression Op OOp)
;;    ;;  (%is O (string-append "(" XX OOp YY ")")) 
;;    ;;  ]

;;    ))

;; (%which (O) ( %cpp-expression "aaaa"    O))
;; (%which (O) ( %cpp-expression #\newline O))
;; (%which (O) ( %cpp-expression 12        O))
;; (%which (O) ( %cpp-expression 'a        O))
;; (%which (O) ( %cpp-expression '(+ a (* b 6 ))        O))


;; (define (cpp-expr expr)
;;   (match
;;    expr
;;    [(? number? X) (number->string X) ]
;;    [(? string? X) (string-append "\"" X  "\"") ]
;;    [(? char? X)   (string-append "'" (string expr)  "'") ]   
;;    [(? symbol? X) (symbol->string X)  ]
;;    [`( ,(? op-num-num-num? Op) ,V-list ...) 
;;     (string-append 
;;      "("
;;      (string-join (map cpp-expr V-list) (symbol->string Op))
;;      ")")
;;     ]

;;    ;; [_ ('else expr)]
;;    )
;; )

;; ;; ;(constant? 12)
;; ;; (cpp-expr "aaaa")
;; ;; (cpp-expr 'a)
;; ;; (cpp-expr 12)
;; ;; (number? 12)
;; ;; (char? #\newline)
;; ;; (cpp-expr  #\newline )
;; ;; (cpp-expr  (string #\newline ))
;; ;; (cpp-expr '(+ a (* b 6 )) ) 



;; ;; (define %scm2cpp-str
;; ;;   (%rel 
;; ;;    ( Exp Alpha Free Type Out
;; ;;      Pre Post S1 S2 S3 
;; ;;      Clauses Body 
;; ;;      X Y Z A B A-list V-list F
;; ;;      Tmp
;; ;;      )
;; ;;    [( X Alpha Free Type Y) (%string? X)  (%is Y (string-append "\"" X  "\"")) ] 
;; ;;    [( X Alpha Free Type Y) (%number? X) (%is Y (number->string X)) ] 
;; ;;    [( X Alpha Free Type Z) (%char? X) (%is Y (string X)) (%scm2cpp-str Y Alpha Free Type Z) ]
;; ;;    ))

;; ;; (%which (O) ( %scm2cpp-str "aaaa"    null null null O))
;; ;; (%which (O) ( %scm2cpp-str #\newline null null null O))
;; ;; (%which (O) ( %scm2cpp-str 12        null null null O))




;; (define (cpp-stat expr)
;;   (match 
;;    expr
;;    [ `(set ,X ,Y)  (format "~a = ~a " X (cpp-expr Y))]

;;    ))

;; (cpp-stat '(set x (+ a 12 (* 2 b))))

;; (let* (
;;        (lambda-name (gensym 'lambda))
;;        (lambda-obj-name (gensym lambda-name))
;;        )

;;   (format 
;; "struct ~a{ ~a{} void operator()(){
;; return x
;; }   
;; }~a
;; " lambda-name lambda-name lambda-obj-name)
;; )







