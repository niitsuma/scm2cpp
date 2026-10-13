# ファイル一覧: 各ファイルの役割と依存関係

これから木に手を入れる人のための地図。パイプラインそのものは
`CLAUDE.md`(Architecture)と `README.md` に書いてあり、このファイルは
目録です: チェックインされた全ソースファイルについて役割を 1〜2 行で、
Racket モジュール間の `require` グラフとともに示し、変更を置く場所と
影響範囲を手を入れる前に見られるようにします。パイプラインの順に、
段階ごとにまとめています。依存関係の列は、このファイルを最後に触った
コミット時点の `require` です(`grep -n require *.scm *.rkt` で再生成
できます)。英語版は `FILES.md`。

## 1. 翻訳器: 入口とパイプライン

```
scm2cpp-file.scm                          コマンドライン
  |-- scm-include.rkt                     (include "f.scm") の差し込み; read-source-forms
  `-- scm2cpp-match.scm                   scm2cpp-match-list: パイプラインと出力器
        |-- scheme-macro-parser.rkt       define-macro 展開 (array-macros.scm を種として)
        |-- rewrite-derive.scm            --derive: ループ -> 配列代数 -> Gram 形 -> matmul
        |     |-- rewrite-raise.scm         R1-R7、素朴なループを代数へ持ち上げる
        |     |-- rewrite-driver.scm        改善規則の不動点
        |     |     |-- rewrite-incremental.scm   有限差分 (導出の本体)
        |     |     |-- rewrite-normalize.scm     畳み込みを露出させるコスト中立の書き換え
        |     |     |-- rewrite-precompute.scm    ループ不変な畳み込みの持ち上げ; 畳み込みの畳み込み
        |     |     |-- rewrite-lagsum.scm        スライス積和のラグ添字 prefix 表
        |     |     |-- rewrite-contract.scm      ユーザ一時配列の縮約
        |     |     |-- rewrite-cost.scm          規則の門が共有する多項式コストモデル
        |     |     `-- rewrite-raise.scm
        |     `-- rewrite-incremental.scm
        |-- rewrite-blas.scm              --blas/--cublas: matmul 形 -> binding の演算
        |-- custom-binding.scm            --binding と bindings/ のファイル
        |-- type-infer-match.scm          型推論の前段 (既定は HM)
        |     |-- type-infer-hm.scm         アルゴリズム W
        |     |-- type-infer-rel-bridge.scm SCM2CPP_RELATIONAL=1: relational 経路
        |     |     `-- type-infer-rel.scm    relational 推論器 (rkanren)
        |     |-- depend-analysis.scm       各定義が使う大域変数/関数
        |     `-- (下記ユーティリティ)
        |-- scm2cpp-function.scm          関数署名: テンプレート引数、戻り型
        |-- schlep-name.scm / schlep-base.scm   名前の変換と宣言 (Schlep 由来)
        `-- alpha-conv.scm, type-symbols.scm, type-infer-util.scm, depend-analysis.scm,
            onlisp.scm, slib-plt.scm, list-util.scm, cl-util.scm, alist-util.scm
```

| ファイル | 役割 | requires |
|---|---|---|
| `scm2cpp-file.scm` | コマンドライン。旗(`-t`, `-M`, `-I`, `-P`, `--derive`, `--blas`, `--cublas`, `--binding`, `--llm-hints`, `-S`, `-N`, `--inference`)を解釈して環境変数(`SCM2CPP_*`)に変え、`scm2cpp-match-list` を 1 回呼び、`<base>.hpp` / `<base>.cpp` を書き、`-M` なら `<base>_capi.cpp` と `<base>.py` も書く。ここでは書き換えをしない: 最適化はすべて `scm2cpp-match-list` の中で走り、環境変数で選ばれる。 | `scm2cpp-match.scm`, `scm-include.rkt` |
| `scm2cpp-match.scm` | パイプラインと出力器、1 つの大きなスコープ。`scm2cpp-match-list` = derive-source-maybe -> lower-blas-maybe -> マクロ展開 -> `rewrite-named-let`(pre-pass)-> save-scm-maybe -> `scm2cpp-match-values`(推論、次にトップレベル形式ごとの C++ 化: `cdeffun`, `clambda`, `cstat`, `cexp`)。変更要約(const 性)、積分画像化(`-I`)、並列バックエンド(`-P`)、最小ランタイムの判定、`module+ test`(suite の `match-unit`)もここ。 | `alist-util`, `cl-util`, `list-util`, `onlisp`, `schlep-name`, `alpha-conv`, `type-infer-util`, `depend-analysis`, `rewrite-derive`, `rewrite-blas`, `custom-binding`, `type-symbols`, `type-infer-match`, `scm2cpp-function`, `scheme-macro-parser.rkt` |
| `scm-include.rkt` | `read-source-forms` / `read-source-string`: ソースプログラムの唯一の読み手。トップレベルの `(include "file.scm")` を、書かれたファイルからの相対で、プログラムごとに 1 度だけ差し込む。プログラムの全消費者(翻訳器、oracle、relational の門、提案器、テスト)がここを通る。 | -- |
| `scheme-macro-parser.rkt` | プログラム自身の `define-macro`(と組み込みの `array-macros.scm` 層)を、小さな Racket プログラムを書いて走らせることで展開する。展開はテキストなので oracle と翻訳器が同じ形式を見る。 | -- |
| `array-macros.scm` | 配列と畳み込みの層: 4 つの `define-macro`(`range-for`, `range-fold`, `range-sum`, `with-arrays`)。最後のものが本体内の代数の全形式を展開する: `array-ref`/`array-set!`/`array-inc!`/`array-dec!`/`array-mul!`/`array-div!`(セル単位と要素ごと; `*=` と `/=` はスカラでも)、`array-sum`/`array-reduce`/`array-dot`、`box` と `sub`(prefix 和と超直方体和)、`row`, `slice`, `scale`, `row-inc!`/`row-dec!`, `array-gather!`/`array-permute!`、そして配列全体の積 `matmul`/`transpose`(Gram は上三角 + 鏡映に展開)。全展開と oracle に種として入る。先頭コメントが仕様。 | --(データ; マクロパーサが展開) |
| `scm2cpp-function.scm` | 推論済み関数署名の補助: 引数名と型、戻り型、テンプレートか(開いた型があるか)、テンプレート引数文字列。 | `schlep-name.scm` |
| `schlep-name.scm` | 名前の変換、宣言(`declare-names` が `-t` の型ファイルを読む)、pragma。Aubrey Jaffer の Schlep `scm2c` 由来。 | `schlep-base`, `alpha-conv`, `alist-util`, `slib-plt`, `type-symbols`, `list-util`, `cl-util` |
| `schlep-base.scm` | Schlep の大域(入出力名、現在の手続き、出力行カウンタ、`report`)。 | -- |
| `scm2c.typ` | `-t` で渡す型宣言ファイル: 名前パターン -> C 型、Schlep の書式。 | -- |

### 型推論

| ファイル | 役割 | requires |
|---|---|---|
| `type-infer-match.scm` | 前段: α 変換、依存解析、次に HM か relational 橋。結果を出力器が読む環境に変換(`var-env->type`, `type->ctype`)。 | `rel-util`, `type-infer-rel-bridge`, `alist-util`, `cl-util`, `list-util`, `onlisp`, `schlep-name`, `alpha-conv`, `type-symbols`, `type-infer-util`, `type-infer-hm`, `type-rel-util`, `depend-analysis` |
| `type-infer-hm.scm` | Hindley-Milner(アルゴリズム W)、`derive-type-hm`: relational の `derive-type` と同じ契約、`--inference hm` 以降の既定。 | `type-symbols`, `type-infer-util`, `custom-binding` |
| `type-infer-rel-bridge.scm` | `SCM2CPP_RELATIONAL=1`: 読んだままのプログラムに `type-infer-rel.scm` を走らせ(ソースファイルを読み直す、だから `SCM2CPP_SOURCE_FILE`)、答えを出力器の語彙に変換。 | `type-infer-rel`, `type-symbols`, `scm-include.rkt` |
| `type-infer-rel.scm` | relational 型推論器: rkanren 上の `conde` 節の山、前向き(項から型)にも後ろ向き(型から項)にも走る。数値塔は 1 つの `number` 型(先頭コメント参照)。 | rkanren (vendor) |
| `type-infer-util.scm` | 両推論器が共有する環境機構: 未知型変数、環境更新、単一化の補助。唯一の PLaneT 依存(`amb.plt`)もここ。 | `alist-util`, `list-util`, `alpha-conv`, `type-symbols`, `type-rel-util`, `schlep-name`, `rel-util`, `onlisp`, `cl-util`、および PLaneT の amb.plt |
| `type-rel-util.scm` | 数値型順序上の relational 補助(`number-typeo`)。 | `type-symbols`, `rel-util` |
| `type-symbols.scm` | 型の語彙: 型記号、数値順序、C 型名(`ctype-alist`)、演算子表、コンパイラタグ。 | `alist-util`, `alpha-conv` |
| `depend-analysis.scm` | 各トップレベル定義が使う大域変数と関数; 推論の順序付けと、型が開いたままの関数の発見。 | `alist-util`, `list-util`, `alpha-conv`, `type-symbols`, `rel-util`, `cl-util`, `type-infer-util` |
| `alpha-conv.scm` | プログラムの α 変換と基本演算子の署名(`op-num-num->num` など)。 | `list-util`, `cl-util` |
| `custom-binding.scm` | C++ テンプレートのユーザ binding(`--binding`、および `--blas`/`--cublas` の `bindings/`): 推論用の型構成子、出力器用の演算表、演算ごとの Scheme モデル、テストプログラム。宣言はデータ。 | `type-symbols` |

### 導出(`--derive`)と積(`--blas` / `--cublas`)

| ファイル | 役割 | requires |
|---|---|---|
| `rewrite-derive.scm` | `derive-forms`: `with-arrays` 宣言を持つ関数ごとに、ループを持ち上げ、スクラッチベクタを見つけ、driver を走らせ、次に `fold-matmul` でセル単位の積を `(matmul ...)` 形に畳み、導出後の本体を元の本体と `(if (< p n) ..)` で分岐させる(`guard-by-shape`); 発火した規則をログ。 | `rewrite-driver`, `rewrite-raise`, `rewrite-incremental` |
| `rewrite-raise.scm` | ループ持ち上げ R1-R7: マクロ展開の逆で、展開がそこに立つ形と正確に一致する所だけ(`do` -> `range-for`、宣言幅が合う平板添字 -> `array-ref`、累積 -> `array-sum`、自己更新 -> `array-dec!`/`row-dec!`)。 | `rewrite-incremental`, `rewrite-normalize` |
| `rewrite-driver.scm` | `derive-fixpoint`: 改善規則を文列に対し発火しなくなるまで交互適用; 生存解析後のスクラッチ復元; `lower-replacement`。 | `rewrite-incremental`, `rewrite-precompute`, `rewrite-normalize`, `rewrite-lagsum`, `rewrite-contract`, `rewrite-cost`, `rewrite-raise` |
| `rewrite-incremental.scm` | 配列代数上の有限差分: スクラッチベクタの各読みの周りに式を育て、更新を持ち上げた Gram 行列上のメモに差分化(`incrementalize`, `degree`, `walk-collect`, `pure?`, `subst`)。 | -- |
| `rewrite-normalize.scm` | 他の規則のために畳み込みを露出させるコスト中立の書き換え(純粋な fill のインライン化、`elem->vexpr`)。 | `rewrite-incremental` |
| `rewrite-precompute.scm` | 汎用の 2 規則: ループ不変な純粋畳み込みを表に持ち上げる; 畳み込みの畳み込み。 | `rewrite-incremental` |
| `rewrite-lagsum.scm` | スライス積の和を、ラグを添字とする 1 つの prefix 表から答える。 | `rewrite-incremental` |
| `rewrite-contract.scm` | 1 つの構文規律のもとで生成・消費されるユーザ一時配列の縮約。 | `rewrite-incremental` |
| `rewrite-cost.scm` | 規則の門が比較する多項式コストモデル(`--cost speed` / `memory`)。 | `rewrite-incremental` |
| `rewrite-blas.scm` | `lower-blas-forms`: 各 `matmul` 形を binding 演算 1 呼び出しに(`blas-gram!`, `blas-gemv!`, `blas-gemv-t-add!`, `blas-gemm-nt!`, `blas-gemm-nn!`, `blas-gemm-tn-add!`); cuBLAS では読むだけの行列をスコープ入口で 1 度アップロード。binding ファイル自体は翻訳時に custom-binding の機構が読み込み、ここでは require しない。 | -- |
| `bindings/cblas-binding.scm` | 上の演算を `<cblas.h>` 向けに Scheme モデル付きで宣言; C++ は `scm2cpp-blas.hpp`。 | -- |
| `bindings/cublas-binding.scm` | 同じ演算、行列オペランドをデバイス上に(`dmat-upload`); C++ は `scm2cpp-cublas.hpp`。 | -- |
| `scratch-internalize.scm` | 生存解析の消費者: スクラッチ引数(書くが後で誰も読まない)を署名から外し関数内で確保。`test-internalize.rkt` が検査; 既定経路上にはない。 | `scm2cpp-match.scm` |
| `block-equiv.scm` | 書き込みのない 2 つのブロックは同じ値を計算するか。`repeat-scan.rkt` が使う。 | `custom-binding.scm` |

### ユーティリティ(翻訳ロジックなし)

| ファイル | 役割 | requires |
|---|---|---|
| `list-util.scm` | 木とリストの補助(`map-tree`, `flatten-tree`, `filter-tree` など)。 | -- |
| `alist-util.scm` | 連想リストと小さな集合の更新(`alist-cons-update`, `vset-union` など)。 | -- |
| `cl-util.scm` | Common Lisp の名前(`cl:nth`, `cl:subst`, `cl:some` など)。 | -- |
| `rel-util.scm` | rkanren 上の relational リスト補助(`listo`, `memo`, `reverseo` など)。 | `alist-util`, `cl-util`, `list-util` |
| `onlisp.scm` | Paul Graham の On Lisp のユーティリティの Racket 版。 | `list-util`, `cl-util` |
| `slib-plt.scm` | SLIB の `defmacro` / `macroexpand` の Racket 版(Aubrey Jaffer)。 | -- |

## 2. ランタイムヘッダ(生成コードが include するもの)

| ファイル | 役割 |
|---|---|
| `scm2cpp.hpp` | 唯一のランタイムヘッダ: ストリーム(`stream_cell<T>`)、メモ化 promise(`promise<F,T>`, `make_promise`, 参照渡しの `force`)、`integral_image<T,N>`、`make_array`、`span`。`SCM2CPP_MINIMAL`(数値カーネル)では std だけになり nvcc が通す。 |
| `scm2cpp-blas.hpp` | binding 演算の cblas 版(`blas_gram` = dsyrk + 鏡映、dgemv、dgemm); 行優先 p x n を列優先 n x p として読むので転置は一切しない。 |
| `scm2cpp-cublas.hpp` | 同じ演算の cuBLAS 版、1 度アップロードした `device_matrix` 上で。 |
| `usage.cpp`, `list-test.cpp`, `equal-test.cpp` | ランタイムヘッダの手書き例。 |
| `ideal/stream-ideal-new.cpp` | 遅延ストリームの生成コードのあるべき形、手書き。 |

## 3. テスト

`run-tests.sh` が suite(`./run-tests.sh`、期待は `PASS=85 FAIL=0`;
CUDA デバイスなしで 66、`cblas.h` もなければ 60)。順序:

1. 解析の単体検査、コンパイラ不要: `test-liveness.rkt`,
   `test-incremental.rkt`, `test-internalize.rkt`,
   `test-precompute.rkt`, `test-normalize.rkt`, `test-lagsum.rkt`,
   `test-derive.rkt`, `test-contract.rkt`, `test-cost.rkt`,
   `test-raise.rkt`, `test-rel-infer.rkt`(それぞれ名前のモジュールを
   require、上のグラフ参照)、`test-files-doc.rkt`(この目録と木の
   突き合わせ); `match-unit`(`raco test
   scm2cpp-match.scm`); `doc-unit`(`raco scribble
   scribblings/scm2cpp.scrbl`、その `eval:check` 例が走る)。
2. `CASES=` のプログラム: それぞれ翻訳、コンパイル、実行し、出力を
   `test-oracle.rkt` が同じプログラムの Racket 実行と diff(数値は許容差
   付き)。include 先はケースの横に同じ相対パスでコピーされる。
3. `probe/derive-{lasso,enet,mt}.scm`, `probe/matmul.scm`,
   `probe/auto-lasso.scm` の導出ラウンド: 素、`--derive`、`--derive
   --blas`(`cblas.h` がある所)、`--derive --cublas`(nvcc、cuBLAS、
   デバイスがある所); `matmul` と `auto-lasso` は決して derive しない。
4. `pymodule-lasso`: 移動平均 covariance カーネルを `-M` で、boost なしで
   ラッパをビルド、`examples/kernel-only/tfs-fast-lasso.py` が sklearn の
   許容差内に入ること(numpy がある所)。
5. CUDA ケース: kernel-only の covariance lasso を nvcc と
   `cuda/batch-lasso.cu` で(デバイスがある所)。
6. チェックイン済みの全 binding に `binding-check.rkt`
   (`examples/custom-template/foo-binding.scm`,
   `examples/std-binding/vec-binding.scm`、ライブラリがあれば
   `bindings/` の 2 つ)。

| ファイル | 役割 | requires |
|---|---|---|
| `run-tests.sh` | 上記の suite。 | すべて |
| `run-tests-omp.sh` | 同じプログラムを `-P omp` で翻訳し `-fopenmp` でコンパイル、各数回実行; 全実行が oracle と一致すること。OpenMP コンパイラが要り時間が倍になるので別立て。 | |
| `test-oracle.rkt` | `run PROG.scm` は pre-pass が読むとおりにプログラムを評価(`racket/base` 名前空間、組み込みマクロを種として); `diff A B` は数値許容差付きで出力比較。 | `scm-include.rkt` |
| `test-liveness.rkt` | 出力器の引数生存解析。 | `scm2cpp-match.scm` |
| `test-incremental.rkt` | 固定入力での有限差分。 | `rewrite-incremental.scm` |
| `test-internalize.rkt` | スクラッチの内部化。 | `scratch-internalize.scm` |
| `test-precompute.rkt` | precompute の 2 規則。 | `rewrite-precompute.scm` |
| `test-normalize.rkt` | 正規化の書き換え。 | `rewrite-normalize.scm`, `rewrite-incremental.scm` |
| `test-lagsum.rkt` | 正規化済み入力上のラグ和の表。 | `rewrite-normalize.scm`, `rewrite-lagsum.scm` |
| `test-contract.rkt` | driver 経由の配列縮約。 | `rewrite-contract.scm`, `rewrite-driver.scm` |
| `test-cost.rkt` | driver 経由のコストモデルと目的。 | `rewrite-cost.scm`, `rewrite-driver.scm` |
| `test-files-doc.rkt` | このファイルと `FILES.md` を木と突き合わせる: 全モジュールに行があり、各行の requires 列がモジュールの実際の `require` と一致する(ファイル名で比較; 木のモジュールでない名前は注釈として無視)。 | -- |
| `test-derive.rkt` | lasso の形での driver の端から端まで。 | `rewrite-driver.scm` |
| `test-raise.rkt` | ループ持ち上げ、および持ち上げてから導出 vs 層から導出。 | `rewrite-raise`, `rewrite-driver`, `rewrite-derive`, `rewrite-incremental`, `scm-include.rkt` |
| `test-rel-infer.rkt` | relational 推論器の前向きと後ろ向き。 | `type-infer-rel.scm`, `scm-include.rkt` |
| `binding-check.rkt` | 各 binding-test プログラムを、Scheme モデルの下と実ヘッダに対し翻訳して、2 回走らせ比較。 | `custom-binding.scm` |
| `verify-tr.rkt` | 推論した型を Typed Racket の注釈に変えてそこで型検査: HM pass の独立な証人。 | `type-infer-match`, `scheme-macro-parser.rkt`, `scm-include.rkt` |
| `.github/workflows/tests.yml` | CI: Racket、Boost ヘッダ、astyle、g++; 同梱 rkanren を link; `./run-tests.sh`(CUDA も cblas もないので PASS=67)。 | |
| `makefile` | 第 2 節の手書き C++ 例をビルド。 | |

### テストプログラム(すべて suite が読む)

| ディレクトリ | 内容 |
|---|---|
| `test-scm-code/` | 元々の小さなケース: `car-test`, `comp-test`, `delay-test`, `stream-test`(ストリームと promise)、`def-def`(`CASES` 外)。 |
| `test-scm2cpp/fact.scm` | 階乗。 |
| `long2/defdef{,2,3}.scm` | 入れ子の define; 2 と 3 がケース。 |
| `bench/*.scm` | README の計時プログラムを兼ねるケース: `psumnaive`/`psumfast`、`integnaive`/`integfast`/`integdata`/`integrect`/`integ3d`/`prefixsum1d`(箱和、rank 1-3 の `-I` の形)、`sqrttest`(Newton)、`nlet`(named let)、`fft`/`fftrun`、`listtest`、`constest`、`collide`(ケース外)。 |
| `probe/` | subset の機能 1 つに 1 ケース(各ファイルの先頭コメント参照): `letrec`, `higher-order`, `thunk-arg`, `global-set`, `unary-ops`, `vector-literal`, `promise-vector`, `promise-table`, `hash-memo` + `define-memo`(include される)、`fib`, `alias-binding`, `capture-const`, `inner-define`(ケース外)、`array-fold`(マクロ層)、`matmul`(全積形)、`auto-lasso`, `derive-lasso`/`derive-lasso-wide`(p > n: 導出の guard の else 側)/`derive-lasso-inc`(作業ベクトルを増やす側)/`derive-lasso-col`(設計行列を n 行 p 列で持つ: 列 view)/`derive-enet`/`derive-mt`(`examples/kernel-only/` のカーネルを include)。 |
| `examples/tfs-lasso.scm` | ケース: 合成系列での temporal feature selection; `kernel-only/soft-threshold.scm` を include。 |

## 4. 例とカーネル

| ファイル | 役割 |
|---|---|
| `examples/README.md` | 例の案内。 |
| `examples/bitrev-permute.scm` | ビット反転置換の 2 通り。 |
| `examples/tfs-lasso-reference.py` | TFS 検査の numpy 参照実装。 |
| `examples/kernel-only/README.md` | `main` のないカーネル、C++/Python から呼ぶためのもの。 |
| `kernel-only/soft-threshold.scm` | soft-thresholding 演算子、全 lasso カーネルが include(プログラムごとに 1 度)。 |
| `kernel-only/lasso-kernel.scm` | 残差形の lasso 座標降下、`with-arrays` の形付き; `--derive` の入力。`lasso-kernel.expanded.scm` はその `-S` 出力。 |
| `kernel-only/enet-kernel.scm`, `mt-kernel.scm` | 残差形の elastic net と multi-task lasso; 残り 2 つの導出入力。 |
| `kernel-only/lasso-cov.scm` | 与えられた Gram 行列上の covariance 更新による座標降下、手書き(`cov-descend`); `python/scm2cpp-lasso` の `CovLasso` の裏のカーネル。 |
| `kernel-only/derived-check.py` | 導出した `lasso-kernel.scm` を素の翻訳と `-M` ラッパ越しに突き合わせる(suite の `pymodule-derived`)。 |
| `kernel-only/lasso-auto.scm` | scikit-learn の `precompute='auto'` の選択を手で: n > p なら Gram 経路、それ以外は残差経路、積は `matmul` 形で記述; `--derive` が今出す同じ分岐の参照; `--blas`/`--cublas` で翻訳し `--derive` はかけない。 |
| `kernel-only/tfs-lasso-cov.scm`, `tfs-lasso-cov-multi.scm`, `tfs-lasso-cov-arrays.scm`, `tfs-lasso-fused.scm`, `tfs-predict.scm` | 設計行列を作らない(prefix 和)移動平均特徴上の lasso; 単系列、複数系列、配列層での記述、融合版、予測。`python/scm2cpp-tfs` が同梱。 |
| `kernel-only/autocov.scm`, `levinson.scm`, `rolling-minmax.scm` | 自己共分散、Levinson-Durbin、sliding min/max; これも `scm2cpp-tfs` が同梱。 |
| `kernel-only/tfs-fast-lasso.py`, `tfs-lasso-cov-check.py`, `tfs-lasso-cov-multi-check.py` | `-M` ラッパ上の Python ドライバ; 最初のものが suite の `pymodule-lasso`。 |
| `examples/custom-template/` | `foo.hpp`(ユーザの行列クラス)、`foo-binding.scm`(Scheme からどう見えるか、モデルとテスト付き)、`matdemo.scm`。 |
| `examples/std-binding/` | `vec-binding.scm`(`binding-propose.rkt` から採用した `std::vector` binding)、`vecdemo.scm`。 |

## 5. 執筆支援ツール(翻訳の一部ではない)

| ファイル | 役割 | requires |
|---|---|---|
| `memo-propose.rkt` | 何を保持すべきか(メモ、prefix 和、Gram)をモデルに問い、出力一致と増加率の計時で提案を門番する。 | `scm-include.rkt` |
| `repeat-scan.rkt` | 2 回以上計算される副作用なしの部分式を、依存と到達回数付きで列挙。 | `block-equiv.scm` |
| `clause-propose.rkt` | 欠けている relational 推論節(素の署名)をモデルに問い、門番する。 | `type-infer-rel.scm`, `scm-include.rkt` |
| `binding-propose.rkt` | カーネルの未知演算を std/boost クラスに写す binding 丸ごとをモデルに問い、`binding-check` にかける。 | `type-infer-rel.scm`, `scm-include.rkt` |
| `--llm-hints CMD`(`scm2cpp-file.scm` 内) | 翻訳器内唯一のモデルフック: `-I` の配列名を提案; 誤った名前は無害。 | |

## 6. ベンチマーク(`bench/`、Python と CUDA)

| ファイル | 供給先 |
|---|---|
| `bench/lasso-table.py` | README 表 1(n=1800, p=200, 4096 lambda): 残差カーネル、covariance カーネル warm/cold、GPU、sklearn。 |
| `bench/lasso-compare.py` | sklearn/celer/skglm/cuML との cold 格子、warm path、`CovLassoCV` 行(`--cv-only`)。 |
| `bench/multitask-compare.py` | multi-task 表(`--cv` で CV の組)。 |
| `bench/cv-grid-designs.py` | CV 格子の GPU 設計を並べて(問題ごとブロックのカーネルの根拠となった比較)。 |
| `bench/lasso-memory-compare.py` | Gram 経路と残差経路のピークメモリ; `bench/resid-cd.cu`(GPU 上の残差形降下)と `_generated` カーネルを使う。 |
| `bench/cv-hints-experiment.py` | 言語モデルは CV の最適化を再発見するか。 |
| `cuda/batch-lasso.cu` | 翻訳した covariance カーネル上の独立したバッチ lasso path、lambda 1 つに 1 スレッド(suite の CUDA ケース)。`cuda/compare-sklearn.py` が sklearn と計時比較。 |

## 7. Python パッケージ(`python/`)

| ファイル | 役割 |
|---|---|
| `python/README.md`, `README.ja.md` | 2 つのパッケージが何か。 |
| `python/PACKAGING.md`, `PACKAGING.ja.md` | Scheme のカーネルから `pip install` まで: `-M` 向けの書き方、写すべきパッケージ配置、suite への組み込み、公開。 |
| `scm2cpp-lasso/src/scm2cpp_lasso/__init__.py` | `CovLasso`, `CovLassoCV`, `CovRidge`, `CovLogistic`, `CovGroupLasso`, `CovMultiTaskLasso`, `CovMultiTaskLassoCV`: 翻訳した `cov_descend`/`enet_descend`/`mt_descend` 上の covariance 経路推定器; `fit_path_batch`、`bootstrap`、CV 格子は `_grid_descend` 経由で GPU へ。 `DerivedLasso`: X と y を渡すと導出カーネル(`lasso-kernel.scm --derive --blas`)が残りを全部やる。 |
| `scm2cpp-lasso/src/scm2cpp_lasso/batch_capi.cu` | CUDA カーネル: `scm2cpp_cv_descend`(問題 1 つにブロック 1 つ、fold 索引 Gram; スレッド版フォールバック)、`scm2cpp_batch_descend`(問題 1 つにスレッド 1 本、比較用に残置)。 |
| `scm2cpp-lasso/src/scm2cpp_lasso/_generated/` | `lasso-cov.scm` の翻訳出力(`lasso_cov.cpp/.hpp`, `_capi.cpp`, `_loader.py`)、`lasso-kernel.scm` の `--derive --blas`(`derived_blas/`)と `--derive` だけ(`derived_loops/`、`_loader_derived.py`)の翻訳出力、`scm2cpp.hpp` と `scm2cpp-blas.hpp` の写し; pip に Racket が要らないようコミット済み。`regenerate.sh` が更新。 |
| `scm2cpp-lasso/src/scm2cpp_lasso/_libfind.py` | ビルド済み共有ライブラリを探し C の入口を名前で束縛; `derived_backend()` がどちらの導出版が入ったかを返す。 |
| `scm2cpp-lasso/setup.py`, `pyproject.toml` | C++(導出カーネルは、CBLAS がコンパイル・リンクできれば BLAS 版、なければループ版)と、nvcc が PATH にあれば `batch_capi.cu` をビルド。 |
| `scm2cpp-lasso/check-gpu.py` | 全 GPU 経路をその CPU 経路と突き合わせ、1e-12 での一致を期待。 |
| `scm2cpp-lasso/check-derived.py` | `DerivedLasso` を `CovLasso` と sklearn に、縦長と横長の設計で突き合わせ、呼び出し全体の時間も出す。 |
| `scm2cpp-lasso/README.md`, `README.ja.md` | パッケージ自身の文書と表。 |
| `scm2cpp-tfs/` | 移動平均(TFS)カーネル用の同じ配置: `_generated/` 下に `autocov`, `levinson`, `rolling_minmax`, `tfs_predict`, `lasso_cov`; `__init__.py` に `TemporalLasso`(`bootstrap_windows` 付き)、`TemporalRidge`, `TemporalAR`, `TemporalLogistic`, `TemporalGroupLasso` とその土台の `CovRidge`/`CovGroupLasso`; `examples/pandas_demo.py`。 |

## 8. 文書とメタデータ

| ファイル | 役割 |
|---|---|
| `README.md`, `README.ja.md` | プロジェクト: 何をするか、表、旗、subset。 |
| `CLAUDE.md` | パイプラインの順序、コミットの規則、翻訳向け Scheme を書くときの subset。公開。 |
| `CHANGES.ja.md` | 番号付き変更記録(日本語; `*.ja.md` 以外で唯一の非 ASCII ファイル)。 |
| `CONTRIBUTING.md` | 翻訳失敗の報告の仕方; 貢献に必要なもの。 |
| `scribblings/scm2cpp.scrbl` | Racket インターフェースの手引き; 例はビルド時に走る(`doc-unit`)。 |
| `joss/paper.md`, `paper.ja.md`, `paper.bib` | JOSS 論文草稿。 |
| `CITATION.cff`, `LICENSE`, `NOTICE` | 引用メタデータ、ライセンス、第三者表示(Schlep、SLIB、On Lisp、rkanren)。 |
| `.gitignore` | ソース横の生成 `*.cpp/*.hpp`、ビルド産物、venv。 |

## 9. 同梱および外部依存

| 何 | どこ | なぜ |
|---|---|---|
| rkanren | `vendor/rkanren/` | 再帰的 miniKanren 核上の cKanren 制約枠組; relational 推論器と `rel-util.scm` が `nullo`/`never-pairo` を要り、カタログの `cKanren` にはない。`raco link --user vendor/rkanren` か `PLTCOLLECTS=$PWD/vendor:`。 |
| `amb.plt` | PLaneT(`type-infer-util.scm` の `(planet "amb.scm" ("wmfarr" "amb.plt" 1 0))`) | 推論ユーティリティの非決定的選択; 初回使用時に PLaneT が取得。 |
| Boost | システム | 完全ランタイムの `boost::function`, `boost::optional`, `boost::array`; 最小ランタイムは不要。 |
| astyle | システム、任意 | 生成コードの整形; なければ 1 行だがコンパイルは通る。 |
| cblas / OpenBLAS、CUDA + cuBLAS | システム、任意 | `--blas` / `--cublas` と対応する suite ラウンド。 |
| numpy, scikit-learn(celer, skglm, cuML は任意) | Python venv | パッケージとベンチマーク; sklearn が参照。 |

## 10. 変更はどこに置くか

- 新しい subset 機能: `probe/` にケース、`CASES=` に 1 行、
  `scm2cpp-match.scm` に出力、`type-infer-hm.scm` に型付け(relational
  経路も追従させるなら `type-infer-rel.scm` に節)。
- 新しい書き換え: `scm2cpp-match.scm` の `derive-source-maybe` の隣に
  `-maybe` 関数、`scm2cpp-file.scm` に環境変数を立てる旗、`--plain` の
  消去リストにその変数、`run-tests.sh` に載せる `test-*.rkt` 単体検査。
- BLAS の新しい積形: `array-macros.scm` にマクロ節、導出が書くなら
  `rewrite-derive.scm` に fold パターン、両 `bindings/` に `defop` +
  モデル、`probe/matmul.scm` にケース。
- Python 向けの新カーネル: `examples/kernel-only/` に `.scm`、
  `regenerate.sh` 経由でパッケージの `_generated/` に `-M` 出力、
  `__init__.py` に推定器、GPU 経路があれば `check-gpu.py` に 1 行。
- provide された Racket 関数の変更: `scribblings/scm2cpp.scrbl` の
  `@defproc` 例。
- モジュールの追加・改名、`require` の変更: ここと `FILES.md` の行
  (`test-files-doc.rkt` が落ちる)。
