#lang racket

;;usgae 
;;racket scm2c-fileio [-t scm2c.typ]fname 


;;[ja] ============================================================
;;[ja] scm2cpp-file.scm — 翻訳器のコマンドライン入口。
;;[ja] 役割は 4 つだけ:
;;[ja]   1. フラグを読んで環境変数に落とす(翻訳器本体は環境変数を見る)
;;[ja]   2. --llm-hints があればモデルに -I の候補配列名を尋ねる
;;[ja]   3. scm2cpp-match-list を呼んで (ヘッダ文字列, 本体文字列) を得る
;;[ja]   4. .hpp/.cpp に書き出す。-M ならさらに C ラッパと Python ローダ
;;[ja] 翻訳の中身はすべて scm2cpp-match.scm 側にある。
;;[ja] ============================================================
(require racket/cmdline)

;; read-file and write-file used to come from 2htdp/batch-io, which loads the
;; HtDP GUI stack: requiring it initialises GTK, so the translator refused to
;; start on a machine with no display -- a container, a CI runner, a server
;; over ssh -- with "Gtk initialization failed". These two are all that was
;; used of it. write-file returns the path it wrote, as the original did, so
;; the module still reports the two files it produced.
;;[ja] もとは 2htdp/batch-io の read-file/write-file を使っていたが、
;;[ja] それは GUI スタック(GTK)ごと初期化するため、ディスプレイの無い
;;[ja] CI やサーバで起動自体が失敗した。必要だった 2 関数だけ自前定義。
(define (read-file path) (file->string path))
(define (write-file path content)
  (display-to-file content path #:exists 'replace)
  path)

;(require "scm2c.scm")
(require "scm2cpp-match.scm")


(define verbose-mode (make-parameter #f))
(define profiling-on (make-parameter #f))
(define optimize-level (make-parameter 0))
(define link-flags (make-parameter null))

;;[ja] 型注釈ファイル(Schlep 由来の形式)。-t で差し替え可能。
;;[ja] 推論が決められない外部関数などの型をここから与える。
(define type-fname (make-parameter "scm2c.typ"))
;; Parallel back ends. The selected mode is passed to the code generator
;; through the environment, which emits a directive in front of each
;; outermost for loop, or rewrites the loop entirely.
;;   omp    : #pragma omp parallel for                             (CPU cores)
;;   gpu    : #pragma omp target teams distribute parallel for     (offload)
;;   acc    : #pragma acc parallel loop                            (OpenACC)
;;   thrust : rewrite recognised loops as Thrust algorithms
 
(define file-to-compile
  (command-line
   #:program "compiler"
   #:once-each
   [("-v" "--verbose") "Compile with verbose messages"
                       (verbose-mode #t)]
   [("-p" "--profile") "Compile with profiling"
                       (profiling-on #t)]
   #:once-any
   [("-o" "--optimize-1") "Compile with optimization level 1"
                          (optimize-level 1)]
   ["--optimize-2"        (; show help on separate lines
                           "Compile with optimization level 2,"
                           "which includes all of level 1")
                          (optimize-level 2)]
   #:multi
   [("-l" "--link-flags") lf ; flag takes one argument
                          "Add a flag <lf> for the linker"
                          (link-flags (cons lf (link-flags)))]
   [("-t" "--type-file") tf ;type fname
                          "Add a type filename  <tf> "
                          ( type-fname tf)]
   ;;[ja] 並列バックエンド選択。値は環境変数 SCM2CPP_PARALLEL 経由で
   ;;[ja] 出力器に届き、最外ループの前に対応する #pragma を挿す
   ;;[ja] (thrust だけはループ自体を書き換える)。
   [("-P" "--parallel") mode ; omp / gpu / acc / thrust
                          "Emit parallel code: omp, gpu, acc or thrust"
                          (putenv "SCM2CPP_PARALLEL" mode)]
   ;;[ja] -I: 名指しした配列の「原点からの箱和」読みを積分画像
   ;;[ja] (summed-area table)表現へ書き換える。"auto" なら自動検出。
   [("-I" "--integral-image") names ; "auto", or space-separated NAME/NAME:RANK tokens
                          "Rewrite box-sum nests over the named arrays (or: auto)"
                          (putenv "SCM2CPP_INTEG" names)]
   ;;[ja] -R: 翻訳前に書き換え規則探索(rewrite-search.scm)を通す。
   ;;[ja] --rules で外部規則ファイル追加、--apply-rule はコストモデルを
   ;;[ja] 無視して指名規則を強制適用(照合と自己テストは依然関門)。
   [("-R" "--rewrite-search") "Rewrite loop nests by rule search before translation"
                          (putenv "SCM2CPP_REWRITE" "1")]
   [("--rules") rfile     ; extra rewrite rules, self-tested before use
                          "Load extra rewrite rules from <rfile> (implies -R)"
                          (putenv "SCM2CPP_RULES" rfile)]
   [("--apply-rule") rname ; user asserts profitability; match and self-test still gate
                          "Apply the named rule wherever it matches, ignoring the cost model"
                          (putenv "SCM2CPP_FORCE_RULE" rname)]
   [("--binding") bfile   ; a user's custom C++ template binding
                          "Map declared ops onto a user C++ header per <bfile>"
                          (putenv "SCM2CPP_BINDING" bfile)]
   ;;[ja] -M: extern "C" ラッパと ctypes ローダも生成(このファイル末尾)。
   ;;[ja] pip パッケージ scm2cpp-lasso / scm2cpp-tfs はこの出力を同梱。
   [("-M" "--pymodule")   "Also emit an extern C wrapper and a ctypes loader"
                          (putenv "SCM2CPP_PYMODULE" "1")]
   [("--llm-hints") cmd    ; e.g. --llm-hints "ask-local -n 100"
                          "Run CMD with the source on stdin to propose -I hints"
                          (putenv "SCM2CPP_LLM_HINTS" cmd)]
   ;;[ja] -S/--save-scm: 最適化書き換え後・C++ 化前の Scheme を
   ;;[ja] <base>.expanded.scm に保存(実装は scm2cpp-match の
   ;;[ja] save-scm-maybe。保存物は再翻訳可能)。
   [("-S" "--save-scm")   "Also write the rewritten program as <base>.expanded.scm"
                          (putenv "SCM2CPP_SAVE_SCM" "1")]
   ;;[ja] -N/--plain: 最適化を一切かけない素の翻訳。個々の最適化は
   ;;[ja] もともと opt-in だが、これは「確実に全部切る」ための旗
   ;;[ja] (後段で関連環境変数を空にする)。読みやすさ主張の基準点。
   ;; The plainest reading of the program: translate it and nothing else.
   ;; Every optimisation here is opt-in already, so this flag is not needed
   ;; to get one -- it is needed to be sure of not getting one, whatever
   ;; else is on the command line or in the environment. That is what the
   ;; readability claim is about, and what to reach for when comparing the
   ;; output against the source or reporting a translation bug.
   [("-N" "--plain")      "Translate only: no rewriting, no offloading, no hints"
                          (putenv "SCM2CPP_PLAIN" "1")]
   ;; Which inference decides the types. The relational one is the original
   ;; implementation, kept because it runs as a relation rather than as a
   ;; function; it settles fewer programs than algorithm W and is slower
   ;; where both succeed. SCM2CPP_RELATIONAL=1 still selects it.
   ;;[ja] --inference: hm(既定、アルゴリズム W)か relational。
   ;;[ja] relational は SCM2CPP_RELATIONAL=1 と同義で、type-infer-match の
   ;;[ja] 分岐から橋(type-infer-rel-bridge)→門→HM 幅実現の経路に入る。
   [("--inference") which  ; hm | relational
                          "Type inference: hm (default) or relational"
                          (cond [(member which '("relational" "rel"))
                                 (putenv "SCM2CPP_RELATIONAL" "1")]
                                [(member which '("hm" "hindley-milner"))
                                 (putenv "SCM2CPP_RELATIONAL" "")]
                                [else
                                 (eprintf "scm2cpp: unknown inference ~a; use hm or relational\n"
                                          which)
                                 (exit 2)])]
   #:args (filename) ; expect one command-line argument: <filename>
   ; return the argument as a filename to compile
   filename))
 


;(display file-to-compile )

;; --plain wins over anything that asked for a rewrite, whichever order the
;; flags came in and whether the request came from the command line or from
;; the environment. It leaves -t, -M and --binding alone: those say what the
;; program means, not how hard to work on it.
;;[ja] --plain の実装: 書き換え系の環境変数を全部空へ。フラグの順序や
;;[ja] 呼び出し元 shell の設定に関係なく「何も最適化しない」を保証する。
;;[ja] -t / -M / --binding は「プログラムの意味」の側なので触らない。
(when (getenv "SCM2CPP_PLAIN")
  (for-each (lambda (v) (putenv v ""))
            '("SCM2CPP_INTEG" "SCM2CPP_REWRITE" "SCM2CPP_RULES"
              "SCM2CPP_FORCE_RULE" "SCM2CPP_PARALLEL" "SCM2CPP_LLM_HINTS")))

;; The relational gate reads the source as written -- vector forms
;; unexpanded -- so it needs to know which file that is.
;;[ja] relational の門は展開前のソースをファイルから読み直すので、
;;[ja] どのファイルかをここで教えておく(bridge の source-forms が読む)。
(putenv "SCM2CPP_SOURCE_FILE" file-to-compile)


(define file-to-compile-base-name  (substring file-to-compile 0 (- (string-length file-to-compile) 4)))
(define cpp-fname (string-append file-to-compile-base-name ".cpp"))
;; -S asked for the pre-emission Scheme; now that the base name is known,
;; turn the flag into the concrete path the dump goes to.
(when (equal? (getenv "SCM2CPP_SAVE_SCM") "1")
  (putenv "SCM2CPP_SAVE_SCM"
	  (string-append file-to-compile-base-name ".expanded.scm")))
(define hpp-fname (string-append file-to-compile-base-name ".hpp"))

(define base-name (last (regexp-split #rx"/" file-to-compile-base-name)))
;; A hyphen in the file name produced an illegal macro name.
(define header-flag-name
  (string-append
   (regexp-replace* #px"[^A-Za-z0-9_]" (string-upcase base-name) "_")
   "_HPP"))


;; With --llm-hints CMD, CMD is run with the program on its standard input
;; and is expected to print, on standard output, the space-separated names
;; of arrays that -I should be given -- or nothing, if it proposes none.
;; CMD is not part of Scm2Cpp; it is whatever the user points at, typically
;; a wrapper around a locally hosted model. This is entirely optional:
;; without the flag no command is run, and if CMD is missing, not found, or
;; prints nothing, the translation proceeds unhinted. The proposal is only
;; a hint -- an array it names is still rewritten only when the box-sum
;; nest is actually recognised, and the result is expected to be checked
;; by the regression suite like any other build.
;;[ja] --llm-hints CMD: ソース全文をプロンプトに付けて CMD(例: ask-local)
;;[ja] を standard input 経由で呼び、-I に渡すべき配列名の提案を得る。
;;[ja] 提案は「ヒント」でしかない — 実際に箱和の入れ子が認識された配列
;;[ja] だけが書き換わるので、モデルの誤りは無害化される。CMD 不在や
;;[ja] 空返答なら黙ってヒント無しで続行。正規表現で識別子形だけ通す。
(when (and (getenv "SCM2CPP_LLM_HINTS") (not (getenv "SCM2CPP_INTEG")))
  (let* ([prompt (string-append
                  "Below is a Scheme program. Some arrays are written first"
                  " and afterwards only read inside a loop nest that sums,"
                  " for every index i1,...,ik up to the array's own extent"
                  " on each axis, every element from the origin (0,...,0) to"
                  " (i1,...,ik) -- a box sum from the origin, of whatever"
                  " rank k the array has (k=1 for a running total over a"
                  " plain sequence, k=2 for a 2D image, and so on). Reply"
                  " with ONLY the space-separated names of those arrays, or"
                  " an empty reply if there are none. You may optionally"
                  " write NAME:RANK instead of NAME if you are confident of"
                  " the rank. No prose.\n\n"
                  (file->string file-to-compile))]
         [words (string-split (getenv "SCM2CPP_LLM_HINTS"))]
         [exe (and (pair? words) (find-executable-path (car words)))]
         [out (if exe
                  (with-output-to-string
                    (lambda ()
                      (parameterize ([current-input-port (open-input-string prompt)])
                        (apply system* exe (cdr words)))))
                  "")]
         [names (filter (lambda (s) (regexp-match? #px"^[a-zA-Z][a-zA-Z0-9!?*<>=+-]*(:[0-9]+)?$" s))
                        (string-split out))])
    (unless exe (eprintf "llm-hints: ~a not found; proceeding unhinted~n" (if (pair? words) (car words) (getenv "SCM2CPP_LLM_HINTS"))))
    (unless (null? names)
      (eprintf "llm-hints: ~a~n" (string-join names " "))
      (putenv "SCM2CPP_INTEG" (string-join names " ")))))

;;[ja] ここが本体呼び出し。scm2cpp-match-list はソース文字列と型注釈
;;[ja] 文字列を受け取り、(ヘッダ部 本体部) の 2 文字列を返す。
;;[ja] 内部の流れ(scm2cpp-match.scm): マクロ展開 → α 変換 → 依存解析
;;[ja] → 型推論(HM / relational 門)→ 文・式の C++ 化(cdeffun/cstat/cexp)。
(define result-codes
  (
   ;scmcode2codelist
   scm2cpp-match-list
   (read-file file-to-compile)
   (read-file (type-fname))
   )
)

;#ifndef BOOST_MPI_HPP
;#define BOOST_MPI_HPP
;#endif // BOOST_MPI_HPP

;(display result-codes)

;;[ja] インクルードガード付きでヘッダを書く。ガード名はファイル名を
;;[ja] 大文字化して非英数字を _ に置換(ハイフンが不正マクロ名になる
;;[ja] 事故があった)。
(write-file 
 hpp-fname 
 (string-append "
#ifndef " header-flag-name "
#define " header-flag-name "
"
(car result-codes)
"
#endif // " header-flag-name  "
"
)
)

(write-file 
 cpp-fname
 (string-append "
#include \"" base-name ".hpp\"
// #include \"scm2cpp.hpp\"
"
(cadr result-codes))
)

;; With -M, two more artifacts: an extern "C" wrapper over every collected
;; non-template function whose signature crosses the C ABI -- scalars pass
;; through, boost::array references become element pointers -- and a Python
;; loader that checks shapes and dtypes before handing numpy arrays in.
;; Functions whose signature does not cross (unions, closures, lists) are
;; skipped with a comment, not silently.
;;[ja] -M の実装。capi-functions(出力器が翻訳中に集めた非テンプレート
;;[ja] 関数の一覧)から、C ABI を越えられる署名だけを選んで
;;[ja]   1. extern "C" scm2cpp_<名前>(...) ラッパ(<base>_capi.cpp)
;;[ja]   2. numpy 配列の形と dtype を検査して渡す ctypes ローダ(<base>.py)
;;[ja] を生成する。越えられないもの(union・クロージャ・リスト)は
;;[ja] 黙殺せずコメントで「飛ばした」と書き残す。
(when (getenv "SCM2CPP_PYMODULE")
  (define (scalar-ctype? t) (member t '("int" "double" "bool" "void" "float")))
  ;; std::array<double,14400> -> (double 14400 #f); std::vector<double>
  ;; -> (double #f #f), an array whose length the caller supplies rather
  ;; than the type; scm2cpp::span<double> -> (double #f #t), a view the
  ;; wrapper hands the caller's pointer to directly.  All three are
  ;; contiguous, so all three arrive as an element pointer.
  ;;[ja] C++ 型文字列 → (要素型 長さ ビューか?) の 3 つ組。
  ;;[ja]   std::array<double,N> → ("double" N #f)   固定長: 要素ポインタ渡し
  ;;[ja]   std::vector<double>  → ("double" #f #f)  可変長: 長さ引数を追加し
  ;;[ja]                                            呼び出し前後でコピー
  ;;[ja]   scm2cpp::span<double>→ ("double" #f #t)  ビュー: ポインタ直渡し
  (define (parse-array t)
    (cond
      [(regexp-match #px"^std::array<\\s*([a-z]+)\\s*,\\s*([0-9]+)\\s*>$" t)
       => (lambda (m) (list (cadr m) (string->number (caddr m)) #f))]
      [(regexp-match #px"^scm2cpp::c?span<\\s*([a-z]+)\\s*>$" t)
       => (lambda (m) (list (cadr m) #f #t))]
      [(regexp-match #px"^std::vector<\\s*([a-z]+)\\s*>$" t)
       => (lambda (m) (list (cadr m) #f #f))]
      [else #f]))
  (define (np-dtype ct) (case ct [("double") "np.float64"] [("float") "np.float32"]
                              [("int") "np.int32"] [("bool") "np.bool_"] [else #f]))
  (define (ctypes-scalar ct) (case ct [("double") "ctypes.c_double"] [("float") "ctypes.c_float"]
                               [("int") "ctypes.c_int"] [("bool") "ctypes.c_bool"] [else #f]))
  (define entries (capi-functions))
  (define lib-name (format "lib~a.so" base-name))
  (define-values (wrappers pyfuncs skipped)
    (for/fold ([ws '()] [ps '()] [sk '()]) ([e entries])
      (let* ([fname (car e)] [ret (cadr e)] [args (caddr e)]
             [kinds (for/list ([a args])
                      (let ([ct (regexp-replace #px"^const\\s+" (string-trim (cadr a)) "")])
                        (cond [(scalar-ctype? ct) (list 'scalar (car a) ct)]
                              [(parse-array ct)
                               => (lambda (et)
                                    (list 'array (car a) (car et) (cadr et) (caddr et)))]
                              [else (list 'other (car a) ct)])))])
        (cond
         [(or (not (scalar-ctype? (string-trim ret)))
              (ormap (lambda (k) (eq? (car k) 'other)) kinds))
          (values ws ps (cons fname sk))]
         [else
          (let* ([cargs (string-join
                         (for/list ([k kinds])
                           (match k
                             [`(scalar ,n ,ct) (format "~a ~a" ct n)]
                             [`(array ,n ,et ,sz ,view)
                              (if (or sz view) (format "~a* ~a" et n)
                                  (format "~a* ~a, int ~a_len" et n n))]))
                         ", ")]
                 ;; A std::vector parameter is rebuilt from the caller's
                 ;; buffer and copied back afterwards, so a function that
                 ;; writes it still writes what the caller passed.
                 ;; a view parameter takes the caller's pointer as it is;
                 ;; only a by-value container needs the copy in and out
                 [dynamic (filter (lambda (k) (and (eq? (car k) 'array)
                                                   (not (cadddr k))
                                                   (not (list-ref k 4))))
                                  kinds)]
                 [pre (apply string-append
                             (for/list ([k dynamic])
                               (match k
                                 [`(array ,n ,et ,_ ,view)
                                  (format "  std::vector<~a> ~a_v(~a, ~a + ~a_len);\n" et n n n n)])))]
                 [post (apply string-append
                              (for/list ([k dynamic])
                                (match k
                                  [`(array ,n ,et ,_ ,view)
                                   (format "  std::copy(~a_v.begin(), ~a_v.end(), ~a);\n" n n n)])))]
                 [call (string-join
                        (for/list ([k kinds])
                          (match k
                            [`(scalar ,n ,_) n]
                            [`(array ,n ,et ,sz ,view)
                             (cond [view n]
                                   [sz (format "*reinterpret_cast<std::array<~a,~a>*>(~a)" et sz n)]
                                   [else (format "~a_v" n)])]))
                        ", ")]
                 [w (if (null? dynamic)
                        (format "extern \"C\" ~a scm2cpp_~a(~a) {\n  ~a~a(~a);\n}\n"
                                (string-trim ret) fname cargs
                                (if (equal? (string-trim ret) "void") "" "return ")
                                fname call)
                        (format "extern \"C\" ~a scm2cpp_~a(~a) {\n~a  ~a~a(~a);\n~a~a}\n"
                                (string-trim ret) fname cargs pre
                                (if (equal? (string-trim ret) "void") "" (format "~a scm2cpp_r = " (string-trim ret)))
                                fname call post
                                (if (equal? (string-trim ret) "void") "" "  return scm2cpp_r;\n")))]
                 [pyargs (string-join (map cadr kinds) ", ")]
                 [checks (apply string-append
                                (for/list ([k kinds])
                                  (match k
                                    [`(array ,n ,et ,sz ,view)
                                     (if sz
                                         (format "    ~a = np.ascontiguousarray(~a, dtype=~a)\n    assert ~a.size == ~a, \"~a: expected ~a elements\"\n"
                                                 n n (np-dtype et) n sz n sz)
                                         (format "    ~a = np.ascontiguousarray(~a, dtype=~a)\n"
                                                 n n (np-dtype et)))]
                                    [_ ""])))]
                 [callargs (string-join
                            (for/list ([k kinds])
                              (match k
                                [`(scalar ,n ,_) n]
                                [`(array ,n ,et ,sz ,view)
                                 (if (or sz view)
                                     (format "~a.ctypes.data_as(ctypes.POINTER(~a))" n (ctypes-scalar et))
                                     (format "~a.ctypes.data_as(ctypes.POINTER(~a)), ~a.size" n (ctypes-scalar et) n))]))
                            ", ")]
                 [argtypes (string-join
                            (for/list ([k kinds])
                              (match k
                                [`(scalar ,_ ,ct) (ctypes-scalar ct)]
                                [`(array ,_ ,et ,sz ,view)
                                 (if (or sz view) (format "ctypes.POINTER(~a)" (ctypes-scalar et))
                                     (format "ctypes.POINTER(~a), ctypes.c_int" (ctypes-scalar et)))]))
                            ", ")]
                 [pf (format "_lib.scm2cpp_~a.restype = ~a\n_lib.scm2cpp_~a.argtypes = [~a]\ndef ~a(~a):\n~a    return _lib.scm2cpp_~a(~a)\n\n"
                             fname (if (equal? (string-trim ret) "void") "None" (ctypes-scalar (string-trim ret)))
                             fname argtypes
                             fname pyargs checks fname callargs)])
            (values (cons w ws) (cons pf ps) sk))]))))
  (write-file
   (string-append file-to-compile-base-name "_capi.cpp")
   (string-append
    "// extern \"C\" wrappers over the translated functions, for Python and\n"
    "// any other caller that speaks the C ABI. Array parameters arrive as\n"
    "// element pointers: a view parameter takes the pointer as it is, so\n"
    "// the caller's buffer is read and written in place with no copy; a\n"
    "// fixed-extent one is reinterpreted as the std::array the function\n"
    "// expects. The caller guarantees the length either way.\n"
    "// Build (boost includes only if the generated header asks for them,\n"
    "// which a numeric kernel's does not):\n"
    "//   g++ -O2 -std=c++17 -shared -fPIC -I. -o " lib-name " " base-name "_capi.cpp\n"
    "#include \"" base-name ".hpp\"\n#include <vector>\n#include <algorithm>\n\n"
    (apply string-append (reverse wrappers))
    (if (null? skipped) ""
        (format "// not exposed (signature does not cross the C ABI): ~a\n"
                (string-join (reverse skipped) ", ")))))
  ;; The loader is meant to be imported, so its file name has to be a
  ;; legal module name: lasso-cov.scm gives lasso_cov.py, not
  ;; lasso-cov.py, which no import statement can name.
  (write-file
   (let-values ([(dir name _) (split-path
                               (string->path file-to-compile-base-name))])
     (let ([mod (string-append
                 (regexp-replace* #px"-" (path->string name) "_") ".py")])
       (if (path? dir) (path->string (build-path dir mod)) mod)))
   (string-append
    "# ctypes loader for " lib-name ", generated alongside it.\n"
    "# Arrays are numpy arrays of the declared dtype; they are made\n"
    "# contiguous on the way in and mutated in place where the translated\n"
    "# function mutates them.\n"
    "import ctypes\nimport numpy as np\nfrom pathlib import Path\n\n"
    "_lib = ctypes.CDLL(str(Path(__file__).resolve().parent / \"" lib-name "\"))\n\n"
    (apply string-append (reverse pyfuncs))))
  (eprintf "pymodule: ~a function(s) exposed~a~n"
           (length wrappers)
           (if (null? skipped) "" (format ", ~a skipped" (length skipped)))))
