# 翻訳器

*[English](translator.md)* · [README](../README.ja.md)

翻訳器そのものの導入と使い方です。必要なもの、コマンドラインとオプション、受け付ける Scheme の部分集合、テストスイート、Typed Racket による検査、ランタイムヘッダを扱います。Python パッケージだけを使うならどれも要りません。

## インストール

ここは翻訳器の導入です(Python パッケージだけならどれも要りません。README の
「インストール(Python パッケージ)」を参照)。必要なもの:

- [Racket](https://racket-lang.org/) 8.x
- [Boost](https://www.boost.org/) のヘッダ
- [astyle](http://astyle.sourceforge.net/) — 生成コードの字下げはこの外部
  プログラムが行います。無い場合、出力は 1 行にまとめて出ます
- 生成コードをコンパイルする C++17 コンパイラ。回帰スイートは C++17 で
  コンパイルします (ランタイムヘッダが取り込む Boost.Math が Boost 1.82
  以降 C++14 を要求するため)。`CXXSTD=c++20 ./run-tests.sh` も通ります
- 任意: CUDA ツールキット (`-P gpu` と `-P thrust` 用)
- 任意: numpy 入りの Python 3 (`-M` の出力を使う場合)

翻訳器が乗る miniKanren は**別途用意する必要はありません**。
`vendor/rkanren` として同梱されており、下記 2 番目のコマンドで登録され
ます。中身は「同梱 rkanren について」を参照してください。

```console
$ sudo apt-get install racket astyle libboost-all-dev g++
$ git clone https://github.com/niitsuma/scm2cpp.git
$ cd scm2cpp
$ raco link --user vendor/rkanren        # 一度だけ。PLTCOLLECTS は不要
$ ./run-tests.sh                         # PASS=194 FAIL=0 と出れば成功 (CUDA なしなら 172、cblas.h もなければ 146)
```

コレクションを登録したくない場合は `raco link` の代わりに `PLTCOLLECTS`
を設定します。末尾のコロンが必要です。

```console
$ export PLTCOLLECTS=$PWD/vendor:
```

### 同梱 rkanren について

翻訳器のユーティリティモジュールのいくつかは関係型で書かれており、
Hindley-Milner 経路でも miniKanren を読み込むため、どの翻訳にも
miniKanren が必要です — ただし `raco pkg install cKanren` で入るもの
ではありません。あのパッケージのモジュールは制約コアだけを再輸出して
おり、このコードが呼ぶ層 (`nullo`、`never-pairo` など) を含みません。
`vendor/rkanren` はその cKanren — Alvis, Willcock, Carter, Byrd,
Friedman の制約枠組み。MIT 表示はディレクトリ内に保存 — の核を
recursive miniKanren のものに交換したものです: walk と出現検査は循環
安全、単一化は等再帰的で、自己参照的な束縛は拒否せず `(==> x t)` と
注釈されます (Niitsuma, Computacion y Sistemas 22(4), 2018)。核の周りの
枠組みは無改変で、原本の無改変ライブラリはツリーではなく git 履歴
(コミット 3c945f9) に保管してあります。`vendor/mk-recursive` は同じ
変更を素の miniKanren に施したもので、関係型の型推論はそちらに乗ります。

## 使い方

```console
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++17 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o sample sample.cpp
$ ./sample
```

`scm2cpp-file.scm` は `sample.hpp` と `sample.cpp` を書き出します。

### オプション

| オプション | 意味 |
|---|---|
| `-t FILE` | 型注釈ファイル (`scm2c.typ` 参照) |
| `-P omp` | 反復が独立と示せた最も外側のループに `#pragma omp parallel for` を出す (「ディレクティブが付く位置」参照) |
| `-P gpu` | OpenMP のターゲットオフロード指示を出す。配列は素の配列になる |
| `-P acc` | OpenACC 指示を出す |
| `-P thrust` | 認識できたループを Thrust アルゴリズムに書き換える。配列は `thrust::device_vector` になる |
| `-I NAMES` | 指定した配列に対する「原点からの箱和」ループ入れ子を、面積和テーブル (summed-area table) への問い合わせに書き換える。NAMES は空白区切りで、各要素は `NAME` か `NAME:RANK`、あるいは `auto`。階数 (走査和なら 1、画像なら 2、以下同様) は入れ子自身から発見されるので、`:RANK` は「そうであるはず」という主張であり、食い違えば書き換えを拒否します |
| `--cost OBJ` | 導出 driver が何を最適化するか: `speed`(既定)か `memory`。`memory` では確保セル数が先に判定し、時間コストは同点の決着にだけ使われます。表 1 本とループを交換する候補は時計には得でも損と判定され、見送られます |
| `--blas` | 縮約(`contract`、numpy の einsum: 導出が外へ出す Gram・メモ・復元と、手書きカーネルが `matmul` で書く積)を CBLAS 呼び出し — それぞれ `dgemm`・`dgemv`・`dsyrk` 1 回、転置フラグは和を取る添字が各オペランドのどこにあるかから読む、スラブのバッチは `dgemm` のループ(`--cublas` では `cublasDgemmStridedBatched` 1 回)— として、binding `bindings/cblas-binding.scm` 経由で出す。利用者自身の C++ と同じ custom-binding 機構なので、3 つの演算は他と同じく宣言・モデル化・検査される。生成ヘッダは `scm2cpp-blas.hpp` を include し、`-lopenblas`(または手元の CBLAS)でリンクする。指定しなければ積は従来どおりループ入れ子で、頼まない限りプログラムは BLAS に依存しない。式のオペランドは先に実体化され、和を取る添字がオペランドの途中にある縮約は展開のまま |
| `--cuda` | 依存解析で並列にできると分かったループ(各反復が自分の要素だけを書き、持ち越すスカラーは和だけ)のうち、本体がスカラーと配列要素だけを計算するものを CUDA カーネルとして出す(1 反復 1 スレッド、和は atomic add)。反復回数が `SCM2CPP_CUDA_MIN`(既定 4096)以上で起動し、それ未満はホストのループ。積はデバイス上の配列に対する cuBLAS(`bindings/cuda-binding.scm`)。配列は文をまたいでデバイスに置き、デバイスの文は足りないものだけ送り、ホストの文は足りないものだけ戻してから書いたものを記録する(`scm2cpp-cuda.hpp`)。反復のホスト側が小さな配列しか触らなければ、大きな配列は動かない。`nvcc -x cu` でコンパイルし `-lcublas` をリンク。`-M` のラッパは各 view の長さを受け取り、戻る前に呼び出し側の配列を戻す |
| `--cublas` | 同じ積を `bindings/cublas-binding.scm` 経由で cuBLAS 呼び出しに出す。関数が読むだけの行列は `with-arrays` スコープの先頭で一度アップロードされ(`dmat-upload`)、書く行列は呼び出しごとにコピー、各演算はデバイスで走って結果を戻します。ヘッダは `scm2cpp-cublas.hpp` を include。CUDA の include パスを付けて `-lcublas -lcudart` をリンク(ホストコンパイラで足ります。カーネルは何もありません)。積が支配的なときだけ得 — コピーが代金です |
| `--derive` | 関数が宣言した配列の形(本体先頭の `with-arrays`: 階数 2 は行列、階数 1 はベクトル)から座標降下の covariance 形を導出する。残差の掃引を配列代数へ持ち上げ、作業ベクトルの更新(減らす側でも増やす側でも)を差分化して、外へ出した Gram 行列で保守するメモに置き換え、呼び出し元が残差を読むなら最後に復元します(生存解析が決める)。導出後の本体は `(if (< p n) ..)` の下で走り(p と n は作業ベクトルを行または列で更新する行列の宣言の形から読む)、else 側は書かれたままの掃引: scikit-learn の `precompute='auto'` の規則です。作業領域はベクタでも、行や列ごとに更新する行列でも、fiber ごとに更新するテンソルでも構いません(テンソルの積は他の軸を平坦化した行列の上に書かれます)。設計行列の向きはどちらでも構いません: p 行 n 列(`x[j*n+i]`、掃引は行を歩く)でも n 行 p 列(`x[i*p+j]`、numpy の C 順、掃引は列 `(col x j)` を歩く)でも、積は転置が反対側に付いた形(`x' x`、`x' r`、`r -= x d`)で出て、同じ BLAS 呼び出しに下ります。その前に、ループが書かない配列の積 -- そのような X からループが集めた列の `(matmul (transpose xk) xk)`、`xk[i,c] = x[i, idx[c]]` -- を X'X として一度だけ作り、添字で引くようにします(ログに `invariant`、後述)。宣言のない関数には触れず、宣言のないプログラムはバイト単位で同じ翻訳になります。標準エラーの `derive: NAME: raise differencing` が発火を報告し、`-S` で導出後のプログラムを Scheme として保存できます |
| `--binding FILE` | 宣言された演算を FILE に従いユーザ提供の C++ ヘッダへ対応づける。`examples/custom-template/` を参照 |
| `-M` | 実行ファイル用のソースに加えて `NAME_capi.cpp` (extern "C" ラッパ) と `NAME.py` (ctypes ローダ) を出し、翻訳された関数を Python から numpy 配列に対して呼べるようにする |
| `--llm-hints CMD` | ソースを標準入力として CMD を実行し、その標準出力を `-I` 用の空白区切り配列名として使う。指定しない限り無効。CMD は Scm2Cpp の一部ではなく、通常はローカルに立てたモデルへのラッパです |

環境変数:

| 変数 | 意味 |
|---|---|
| `SCM2CPP_RELATIONAL=1` | 関係型の型推論 (`--inference relational` と同義): recursive miniKanren の型付け関係を門として使い、型付けできたかを stderr に出す。型そのものはどちらでも Hindley-Milner が実現する(門の予算は `SCM2CPP_REL_BUDGET` 秒、既定 60) |
| `SCM2CPP_INTEG` | `-I` と同じ |
| `SCM2CPP_LLM_HINTS` | `--llm-hints` と同じ |
| `PLTCOLLECTS` | rkanren の在り処 |

### ディレクティブが付く位置

`-P omp`、`-P gpu`、`-P acc` は単に最外ループに注釈を付けるわけではありません。
候補は外側から順にループ運搬依存の有無を検査され、最初に通ったループに
ディレクティブが付きます。どれも通らなければその関数は逐次のままです。
検査は片側に保守的で、そのループのどの反復も触らない場所へ書き込むことが
証明できた場合にのみ注釈を付けます。したがって並列化できたはずのループが
そのまま残ることはありますが、できないループに注釈が付くことはありません。

何をもって証明とするか:

- すべての `vector-set!` の添字がループ変数について単射であること。添字が
  変数そのものであるか、行優先の `(+ (* i S) rest)` の形で `rest` が `i` を
  含まず `S` が内側ループの回数であること (これが行同士を素にします)
- ループが書き込む配列が、別の添字で読まれていないこと (それは他の反復の
  要素だからです)
- ループ内で代入されるスカラーが、ループ内で束縛されていて私的であるか、
  あるいは `(set! acc (+ acc E))` の形でのみ更新されること。後者では
  ループを拒否する代わりにディレクティブが `reduction(+:acc)` を伴います

たとえば座標降下では、掃引ループは前の掃引が書いたものを読むので拒否され、
座標ループは `c` 全体を書いてその 1 要素を読むので拒否され、ディレクティブは
最内の更新に付きます。`cs[i]` を読んで `cs[i+1]` を書く prefix sum は
どの階層でも拒否され、逐次のままです。

スレッドは無料ではないので、注釈が付いたループには番人も付きます:
`#pragma omp parallel for if(p > 1024)`。反復回数がリテラルで閾値未満の
ループには、そもそも注釈を付けません。閾値は `SCM2CPP_OMP_MIN` (既定 1024)
です。実行時に決める意味は、1 つの翻訳済みカーネルが 100 列でも 10 万列でも
呼ばれうるところにあります。

`./run-tests-omp.sh` は、`run-tests.sh` が逐次出力を検査するのと同じやり方で
これを検査します。`-P omp` で翻訳し、`-fopenmp` でコンパイルし、Racket と
結果を比べます。競合は毎回顕在化するとは限らないので、1 事例につき複数回
走らせます。

### 積分画像の書き換えと `--llm-hints`

`-I` は、各軸について配列自身の広がりまでのすべての添字 `i1,...,ik` に対し、
原点 `(0,...,0)` からその添字までの箱にわたる和を計算するループ入れ子 —
階数 `k` に対して O(n^(2k)) の計算 — を、1 回 O(n^k) の面積和テーブル構築と
O(n^k) 回の問い合わせに書き換えます。階数は与えるものではなく、入れ子が実際に
持つ軸数から発見されるので、同じオプションが素の列に対する走査和 (`k=1`)、
2 次元画像 (`k=2`)、3 次元体積、と正方でも長方形でも同じように働きます。
書き換えはその形が正確に認識されたときだけ発火するので、違う配列を挙げても、
入れ子が合致しない配列を挙げても、コードは変わりません。実際に見つかった
階数と食い違う階数を指定した場合 (3 軸の入れ子に `v:2`) も同様です。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -I v sample.scm       # 手で示唆
$ racket scm2cpp-file.scm -t scm2c.typ -I "v w" sample.scm   # 複数
$ racket scm2cpp-file.scm -t scm2c.typ -I v:2 sample.scm     # 階数を主張
$ racket scm2cpp-file.scm -t scm2c.typ -I auto sample.scm    # 全配列を試す
```

`--llm-hints` は `-I` の引数を手で与える代わりに提案させます。CMD は
プログラムのソースを標準入力として実行され、原点からの箱和でしか読まれないと
判断した配列の名前を空白区切り (必要なら `NAME:RANK`) で標準出力に印字すること、
あるいは何も出さないことが期待されます。CMD はその約束を守る任意のコマンドで、
Scm2Cpp は同梱しません。OpenAI 互換エンドポイントへの 1 行ラッパで十分です。

```python
#!/usr/bin/env python3
# llm-hint-cmd -- 標準入力からソースを読み、配列名を標準出力に印字する
import sys
from openai import OpenAI

client = OpenAI(base_url="http://localhost:4000/v1", api_key="...")
resp = client.chat.completions.create(
    model="qwen3.6",
    messages=[
        {"role": "system", "content":
         "Some arrays are written first and afterwards only read inside a "
         "loop nest that sums, for every index up to the array's own extent "
         "on each axis, every element from the origin to that index -- a "
         "box sum from the origin, of whatever rank the array has. Reply "
         "with ONLY the space-separated names of those arrays, or nothing."},
        {"role": "user", "content": sys.stdin.read()},
    ],
    max_tokens=100,
)
print(resp.choices[0].message.content)
```

```console
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints ./llm-hint-cmd sample.scm
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints "ask-local -n 100" sample.scm
```

1 つの列の複数の文が同じ配列に対する箱和の入れ子であり、その間の区間が
その配列について書き込み無しだと解析が示せるとき (`set!` なし、
`vector-set!` なし、ある関数が書き込む引数を通じてそこに届く呼び出しもなし)、
最初の入れ子で 1 つのテーブルを作り、残りが共有します。間に書き込みがあれば
入れ子は単に分かれ、それぞれが自分のテーブルを持ちます。同じ関数単位の書き込み
解析は、関数が決して書かないコンテナ引数を、生成される署名で `const ... &` と
印づけるのにも使われます。

CMD が見つからない場合や、使える出力を出さなかった場合、翻訳は
`--llm-hints` が与えられなかったかのように進みます。いずれにせよ提案は
あくまで示唆です。名指しされた配列も、箱和の形が実際に認識されたときだけ
書き換えられるので、誤った提案は何も変えません。そして結果は他のビルドと
同様に検査されることが前提です — `./run-tests.sh` は、どのオプションで
生成されたかに関わらず、すべての回帰事例を翻訳し、コンパイルし、実行します。

### 何を保存するかの提案: `repeat-scan.rkt` と `memo-propose.rkt`

`repeat-scan.rkt` は、厳密にできる部分を担います。副作用のない部分式は
その自由変数の関数なので、それらの変数が一致すれば 2 つの出現も一致します
(ループ添字も含めて)。このツールは、繰り返される副作用のない部分式を、
何に依存しているかとともに列挙し、反復ごとに変わる変数とそうでない変数を
分けて示し、`-c CMD` を与えるとどれをテーブルにする価値があるかをモデルに
尋ねます。繰り返しを見つけるのは機械的な作業ですが、どれを保存すべきかは
ループの入れ子構造とテーブルの大きさに依存し、そここそ尋ねる価値のある
判断です。移動平均に対する lasso について尋ねたところ、ローカルモデルは
すべての候補を却下し、30x600 のテーブルは埋めるほうが省く算術より高くつくと
理由づけました — 実測が既に裏づけていた通りです。限界はその作業階層に
あります。素朴な二次の prefix sum には繰り返される部分式が 1 つもありません。
そこでの無駄は繰り返された式ではなく重なった範囲だからです。

`memo-propose.rkt` は別の問いを立てます。「この形を書き換えよ」ではなく
「繰り返しの作業を共有するには何を保存すべきか」です。会話を段階に分けて
進め (何を保持するか、次にプログラム自身の構造がそれを保持可能にするか、
最後に書き換え後のプログラム)、答えを 2 つの関門にかけます。1 つ目は
お馴染みのもの、元と同じものを印字すること。2 つ目は複数のサイズで時間を
計り、コストの伸びが明らかに緩やかであることを要求します。ここでの提案は
完全に正しくてまったく速くならないことがあり、それを見分けられるのは
計時の関門だけだからです。

```console
$ racket memo-propose.rkt -c "ask-local -n 900" -s "400=400,1600,3200" \
    -o faster.scm kernel.scm
  original: (1.0 5.6 38.5)  (grew 37.4-fold)
  proposed: (0.4 0.4 0.5)   (grew 1.2-fold)
memo-propose: accepted -> faster.scm
```

`-s NAME=A,B,C` は、変化させるプログラム中のリテラルを指定します。2 つ目の
関門は働きに見合います。すべての部分和を律儀にテーブルへ保存しておきながら
結局再計算する書き換えは、答えの検査は通り、ここで「コストの伸びが元と同じ
ままだ」と告げられて拒否されます。

### 生成コードのコンパイル

| 設定 | コンパイラ起動 |
|---|---|
| 既定 | `g++ -std=c++17 -include boost/operators.hpp -include boost/optional.hpp` |
| `-P omp` | `-fopenmp` を追加 |
| `-P gpu` | `-fopenmp -foffload=nvptx-none -fcf-protection=none -fno-stack-protector` を追加 |
| `-P thrust` | `nvcc -O2` でコンパイル |

## 対応している部分集合

`define`、`lambda`、`let`、名前付き `let`、`letrec`、`if`、`cond`、`when`、
`unless`、`begin`、`do`、`set!`、`define-macro`、`define-syntax`、
`vector-ref`、`vector-set!`、`vector-length`、`make-vector`、`list`、
`make-list`、`list-ref`、`car`、`cdr`、`cons`、`display`、`newline`、
`string-append`、`not`、`zero?`、数値演算子と比較、通常の初等超越関数、
`delay`/`force` と遅延ストリーム、`make-hash`、`hash-ref`、`hash-set!`、
`hash-has-key?`、`hash-count`。

非対応: 継続、一般の末尾呼び出し除去、提供されるリスト型・ストリーム型を
超える任意のヒープ確保再帰データ、および上記以外の R7RS。

promise はメモ化する呼び出し可能オブジェクトで、promise のベクタは遅延表に
なります。`(make-vector n (delay 0))` に、他のセルを force する `(delay ..)`
を詰めれば、依存順に埋まる動的計画法で、各本体は 1 回だけ走ります
(`probe/promise-table.scm`)。force は const 解析で書き込みとして扱われ
(`const` 参照越しに force した promise は毎回計算し直す)、promise の表は
可変参照で捕獲されます。

ハッシュ表は鍵型と値型を 1 つずつ持ち、どちらも使われ方から推論されます。
`(make-hash)` は `std::unordered_map<K,V>` に、鍵自体がコンテナなら
`std::map<K,V>` になります。既定値付き `hash-ref` は `count ? at : 既定値`、
`hash-has-key?` は `count > 0`、`hash-count` は `size` です。表はベクタと
同じく関数呼び出しを参照で越え、`hash-set!` は書き込みとして数えられます。
これが、引数が小さな整数添字でない関数のメモ化です。表は実際に呼ばれた
分だけ育ちます(`probe/hash-memo.scm` は疎な引数にわたる Collatz の
ステップ数をメモ化し、文字列鍵の集計も行います)。`define-memo` マクロは
普通の `define-macro` ソース `probe/define-memo.scm` で、include で取り
込みます。メモ化する本体の文は文の位置に置く必要があります。`let` に
束縛された `(begin ..)` は C++ の式にならなければならないからです。
`probe/fib.scm` は誰もが知る 1 つの関数の上に 2 つのイディオムを並べた
ものです — ハッシュ表による `fib-memo` と promise のベクタによる
`fib-lazy` で、fib(40) に対しどちらも本体が 41 回走ることを Racket と
C++ の両方で示します。どちらも書き換えが見つけるものではありません。
木構造の再帰を表埋めループにしていた規則は規則探索とともに消え、代わり
にサブセットが用意するのがこの 2 つの形です。

トップレベルの `(include "file.scm")` は Racket の `include` と同じく、
そのファイルのフォーム群の代わりです。パスは書かれたファイルからの相対で、
含まれたファイルがさらに include してもかまいません。差し込みはテキスト
上で、何かがプログラムを読む前に行われるので、翻訳器・オラクル・提案
ツール・`-S` はどれも 1 つのプログラムを見ます。`-M` の Python ローダと
生成される C++ に違いは現れません。`examples/` の lasso カーネル群は
`soft-threshold` をコピーではなくこの形で共有しています
(`examples/kernel-only/soft-threshold.scm`)。1 つのファイルは 1 つの
プログラムに 1 度だけ差し込まれます。直接でも別の include 経由でも、
2 度目の include は何も足しません。そのため `soft-threshold.scm` を
それぞれ include する 2 つのカーネルを並べて include できます
(`examples/kernel-only/lasso-auto.scm` が `lasso-kernel.scm` と
`lasso-cov.scm` を取り込みます)。

Scheme の値は定まった型の C++ オブジェクトへ対応づけられます。その帰結を
1 つ明記しておきます。名前をベクタに束縛すると別名になります — 2 つの名前は
1 つのベクタを指し、翻訳器はどちらを通じた書き込みも両方から見えるように
参照を出します。この対応が破れるのは、そうした名前を `set!` で指し直すときです。
C++ の参照は指し直せないので、翻訳器はコピーに退避し、警告します。
`(set! v w)` の後、両言語は食い違います。Scheme は `v` を通じて `w` の
ベクタへ書きますが、C++ はコピーへ書きます。名前を指し直すのではなく、
要素を通じて代入するか、意図したベクタを渡してください。

### 配列と fold の層

すべての翻訳単位には組み込みの `define-macro` 群が種として与えられます
— 正典は `array-macros.scm` で、同名マクロを定義するファイルは組み込みを
上書きできます。格納は配列 1 つにつきフラットなベクタ 1 本、添字は常に
1 つのアフィン式なので、生成される C++ は手書きのフラットカーネルと同じ
ループネストになり、更新形式は導出(`--derive`)が持ち上げるちょうどの形に
展開されます — この層で書いた掃引が導出から代数を隠すことはありません。

| 形式 | 意味 |
|---|---|
| `(range-for (i n) body ...)` / `(range-for (i a b) body ...)` | ループ `i = 0..n-1` / `a..b-1` |
| `(range-fold ((acc init) (i n)) e)` | fold。`e` が次の `acc` を与える |
| `(range-sum (i n) e)` | `e` の総和(名前なしの fold) |
| `(with-arrays ((a (d0 d1 ...)) ...) body ...)` | 形状つきフラット配列の宣言 |
| `(array-ref a i j)` / `(array-set! a i j v)` | 行優先の添字。値は最後(SRFI 25 と同じ) |
| `(array-inc! a i j e)` / `(array-dec! a i j e)` | `a[i,j] += e` / `-= e` |
| `(array-inc! y e)` / `(array-dec! y e)` | ベクタ式 `e` の要素ごと `y += e` / `-= e` |
| `(array-mul! a i j e)` / `(array-div! a i j e)` | `a[i,j] *= e` / `/= e` |
| `(array-mul! y e)` / `(array-div! y e)` | ベクタ式またはスカラ `e` の要素ごと `y *= e` / `/= e`(2 次元 `y` と行列式またはスカラも同様)。`(matmul a b)` なら積を `y` と同形の一時配列に作ってから掛け、`--blas` / `--cublas` はその積を `array-set!` のものと同じく下ろす |
| `(array-sum e)` | ベクタ式の総和 |
| `(array-reduce op id e)` | `+` `*` `min` `max` と単位元 `id` による同じ fold |
| `(array-set! s i j (array-sum (box v i j)))` | 前置 box 和: `s[i,j]` に `[0,i]×[0,j]` 上の fold |
| `(array-sum (sub a lo1 hi1 ...))` | 超矩形上の和 — numpy の `a[lo1:hi1, ...].sum()` |
| `(array-dot u v)` | `(array-sum (* u v))` |
| `(array-gather! dst src idx)` | `dst[i] = src[idx[i]]` — numpy の `dst = src[idx]`。反復が独立なので `-P omp` で並列化 |
| `(array-permute! a idx)` | 一時コピー経由の `a = a[idx]` |
| `(row-inc! a i e)` / `(row-dec! a i e)` | 2 次元 `a` の行 `i` に `+= e` / `-= e`。添字を増やせば `(row-dec! a i j e)` は 3 階 `a` の fiber `a[i,j,:]` |
| `(col-inc! a j e)` / `(col-dec! a j e)` | 2 次元 `a` の列 `j` に `+= e` / `-= e`(stride 付き)。`(col-dec! a j k e)` は fiber `a[:,j,k]` |
| `(array-set! y e)` | ベクタ式 `e` の `y = e`。2 次元 `y` と行列式 `e` なら行列全体(`array-inc!`/`array-dec!` も同様) |
| `(array-set! g (matmul x (transpose x)))` | 2 次元 `x` の行どうしの Gram `g = x x'`、numpy の `x @ x.T`。展開は上三角とその写し。一般の積は `(matmul a (transpose b))` と `(matmul a b)` |
| `(array-set! c (matmul x v))` | ベクタ `v` に対する `c = x v` — 各行の内積 |
| `(array-dec! r (matmul (transpose x) d))` | ベクタ `d` に対する `r -= x' d`、スカラ倍した行の和(`array-inc!`/`array-set!` も同様)。`d` が行列式なら行ごとの `r -= d' x` |
| `(array-set! g (matmul (transpose x) x))` | *列*の Gram `g = x' x`。`(n p)` と宣言した `x`、つまり設計行列を n 行 p 列(numpy の C 順)で持つとき。`(array-dec! r (matmul x d))` が対になる `r -= x d`。`d` はベクタでも行列式でもよい(n 行 T 列で持つ行列残差) |
| `(array-set! y (contract (k ..) (i ..) (a la ..) (b lb ..)))` | 縮約、numpy の einsum: `y[i ..] = k .. について a * b の和`。各オペランドの軸に添字を順に名前で載せる(`(x k i)` は和を取る添字が第 1 軸の `x`)。`a`、`b` は任意階数の宣言済み名か、同形の名前の上の式。`array-inc!` / `array-dec!` で `+=` / `-=`。上の `matmul` はどれも添字 2 つの縮約で、`--derive` が書くのはこの形: `(contract (i) (k1 k2) (x k1 i) (x k2 i))` が Gram、オペランドの切り方も階数も問わない。両オペランドと `y` の先頭にあって和を取らない添字はバッチ(`(contract (k) (l i j) (e l i k) (e l j k))`: スラブ `l` ごとに積 1 つ) |

**ベクタ式**とは: 宣言済みの 1 次元名、`(row a j)`(展開時の
array-curry)または `(col a j)`(列、stride 付き)— 添字を増やした `(row a i j)` / `(col a j k)` は 3 階配列の最後の軸 / 最初の軸に沿った fiber —、`(slice u lo hi)` / `(slice u lo hi step)`(numpy の
`u[lo:hi:step]`、半開区間)、スカラをブロードキャストするベクタ式上の
`(+ - *)`、そして `(scale c v)`(名前を持ったスカラ倍)。**行列式**は
宣言済みの 2 次元名と、その上の `(+ - *)` / `(scale c m)`。式の木は展開まで
見えたままなので、導出は代数に対して働けます: `y -= coef*u` は
`(array-dec! y (scale coef u))` であり、構造を隠す融合プリミティブでは
ありません。`matmul` の各形は導出が外へ出す積をそのまま書いたもので、
`--blas` / `--cublas` はそれぞれをライブラリ呼び出し一回に置き換えます
(意味はループ入れ子、呼び出しは同じ積をライブラリから)。

### 部分集合が期待する作法

- union 型なし: 「ベクタまたは `#f`」は翻訳できない。事前確保バッファ +
  0/1 フラグを使う。
- 異種 pair の返却なし: 結果としての `(cons vec num)` は翻訳できない。
  出力引数 + スカラ返却を使う。
- ループは `do` か名前付き `let`。ループの非再帰末尾は慣例として `#f`。
- 素の配列はフラット + 明示的な添字算術(`(+ (* i n) j)`)— または上の
  配列層(同じものに展開される)。
- 他に制約がないとき引数を浮動小数に強制するイディオムは `n` でなく
  `(* 1.0 n)` を掛けること。
- C++ の予約語と同じ名前(`new`、`case`、`int` など)は接尾辞 `_scm` を
  付けて出力する: `new` は `new_scm` になる。

## テスト

```console
$ raco link --user vendor/rkanren    # まだなら一度だけ
$ ./run-tests.sh                     # PASS=194 FAIL=0 と報告 (cuBLAS や cblas.h がなければ少なくなる)。失敗があれば非ゼロ終了
$ TIMEOUT=600 ./run-tests.sh /tmp/result.txt      # 制限時間を延ばし、ログ先を指定
```

スイートの 194 の検査は、`CASES=` に並ぶ 37 本のプログラム、`probe/` のプログラムを
`--derive`、`--blas`、`--cublas`、`--cuda` で訳し直した回、`CASES=` のプログラムを関係的な推論で
訳し直した回、そして単体テストです。
各プログラムは翻訳され、コンパイルされ、実行され、そして
**その出力が、同じプログラムを Racket で走らせた結果と比較されます**。
4 段階すべてが成功しなければなりません。最初の 3 つは処理系がまだ動くことを
示すだけで、翻訳が今も Scheme の意味を保っていることを示すのは比較です。

仕様は Scheme そのものなので、古びていく期待出力ファイルはありません。
`test-oracle.rkt` が両側を供給し、単体でも使えます。

```console
$ racket test-oracle.rkt run bench/sqrttest.scm        # Racket が印字するもの
$ racket test-oracle.rkt diff racket.out cpp.out       # 2 つの出力を比較
```

このオラクルはプログラムを `#lang racket/base` としてではなく、翻訳器の
前処理と同じように読みます。`define-macro` は展開され、片腕の `(if c t)` は
合法で、`force` は裸のサンクを受け取り、`make-promise` はサンクを取って
`scm2cpp.hpp` と同じように記憶化します。数値は相対許容誤差
(`SCM2CPP_TOL`、既定 `1e-5`) で比較されます。C++ は有効数字 6 桁で印字し、
Racket はすべて印字するからです — `2.0` と `2`、`3.00009155413138` と
`3.00009` は一致とみなし、それ以外は厳密に一致しなければなりません。
大きなトークンに埋め込まれた数 (`beta_hat=0.000436075`) は数として比較され、
周囲の文字は文字通り照合されます。

同じスイートは GitHub Actions (`.github/workflows/tests.yml`) 上で、
上記のインストール手順を経て、push と pull request のたびに走ります。
手順が壊れれば、読者の最初の 10 分ではなくそちらで露見します。

`main` が何も印字しない事例は `FAIL(no output)` として失敗します。比較する
ものが無くなり、何とでも一致してしまう事例こそ、この段階が塞ぐべき穴だからです。

新しい事例を書くときに知っておく価値のある帰結が 2 つあります。Scheme の
整数は無限精度で C++ の `int` はそうではないので、32 ビットを溢れる算術は
両辺を食い違わせます — これは設計通りで、スイートは黙って通す代わりに
そう告げるようになりました (サンプル生成器が小さな乗数を使うのはこのためです)。
また、実行時間が長いベンチマークループに支配されるプログラムは、オラクルが
プログラム全体を実行するため、インタプリタ上では遅くなります。

### ユーザの C++ テンプレートの結合 (`--binding`)

結合ファイルは、ユーザ自身のヘッダが Scheme からどう見えるかを宣言します。
推論のための型構成子、コード生成器のための演算 1 つにつき 1 項目、各演算の
純 Scheme モデル、そしてテストです。これにより `(mat-ref m r j)` は
`m.at(r,j)` に翻訳され、`m` は `foo::Matrix< double >` と型付けされ、
ヘッダは include に加わります。Scheme プログラムが C++ に言及することは
ありません。結合の読み込みは何も実行しません — 宣言はデータであり、モデルが
走るのは検査の関門の中だけです。

```console
$ racket binding-check.rkt -I examples/custom-template \
    examples/custom-template/foo-binding.scm
```

これはすべての `binding-test` を 2 回走らせます。一度は Racket でモデルに
対して、もう一度は実際のヘッダに対して翻訳・コンパイル・実行し、出力を
比べます。モデルがヘッダについて主張することは、こうして両方を走らせる
ことで検査されます — 導出に課すのと同じ基準です。モデルが行優先だと
言うのにヘッダが列優先で格納していれば、印字された食い違いとして捕まります。
`examples/custom-template/` に完全な作業例があります。

### 翻訳された関数を Python から呼ぶ (`-M`)

`-M` は通常の 2 つに加えてさらに 2 つの成果物を出します。翻訳された非
テンプレート関数すべてに対する `extern "C"` ラッパ `NAME_capi.cpp` (スカラーは
そのまま通り、配列参照は要素ポインタになります) と、各 numpy 配列の dtype と
サイズを宣言された署名と照合してから渡す ctypes ローダ `NAME.py` です。
関数が書き換える配列はその場で書き換えられるので、ソルバが書いた係数は
呼び出し側の配列に入ります。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M kernel.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libkernel.so kernel_capi.cpp
$ python3 -c 'import kernel; kernel.lasso(x, beta, resid, xnorm, 0.02, 20000, 360, 40)'
```

どの呼び出し側も広がりを確定しない引数は `std::vector<double>` として出て、
ポインタと長さの組で渡ります。呼び出し側が `make-vector` で作る引数は
`std::array<double,N>` のままで、ポインタだけで渡ります。したがって外から
呼ばれるために書かれた、自分の `main` を持たないカーネルは、注釈なしで
公開できます — `examples/kernel-only/` を参照してください。署名が C ABI を
渡れない関数 (共用体、クロージャ、リスト) は、黙ってではなくコメントで
名指しした上で飛ばされます。作業例では、この方法で呼んだカーネルが
scikit-learn の Lasso と 5e-11 まで一致しました。

## 推論を Typed Racket に対して検証する

Hindley-Milner のパスとコード生成器は 1 つの実装であり、そこにバグがあれば
独立した証人のないまま誤った C++ が出ます。`verify-tr.rkt` は推論された型を
Typed Racket の注釈に変え、プログラムを `typed/racket` モジュールとして
書き出し、2 つ目の無関係な型検査器に読ませます。

```console
$ racket verify-tr.rkt prog.scm
OK: Typed Racket agrees (Real level)
```

検査は意図的に数値の塔の Real の水準で走ります。Typed Racket は
`(* 2.5 i)` を `Flonum` ではなく `Real` と型付けし、それは正しいのです。
Racket の厳密なゼロは浮動小数点との乗算を生き延びるので、Flonum の水準は
本当にこのプログラムの Racket 意味論を記述していません。検証されるのは
構造です — 何が関数で何を取るか、何がベクタで何のベクタか、どこで値が
捨てられるか — であり、int か double かの判断は推論パスに残ります。C++ が
それを必要とするからです。束縛の対を適用と読み違える、引数リストの長さが
違う、ベクタのはずの場所にスカラーがある。Typed Racket はこれらをすべて
即座に拒否します。それはかつてすり抜けた前段バグの種類そのものです。

スイートの `CASES=` に並ぶ 37 本のうち 36 本が、どちらの推論(既定の Hindley-Milner、
または `SCM2CPP_RELATIONAL=1`。後者でも型は Hindley-Milner が実現します)でも検査を通ります。
通らない 1 本は遅延ストリームを使っており、ここでは基礎となる Typed Racket 表現を持たないため
対象外と宣言しています
(`--keep` で生成モジュールをソースの隣に残せます)。ハッシュ表は `Mutable-HashTable` として
書き出し(`hash-ref` の既定値は thunk に包んで渡します。Typed Racket が型付けする既定値は
thunk だけだからです)、`memo-call` / `memo-range` には補助定義があります(表の鍵は
文字列で、C++ が鍵の値のバイト列で引くのに対応します)。

## ランタイムヘッダ

`scm2cpp.hpp` は翻訳器なしで単体でも使えます。通常の C++ コンテナに対する
Lisp 演算子を与えるので、`car`、`cdr`、`cons`、`list-ref` が

    std::vector    std::list    std::array    boost::fusion::list

に適用でき、`std::pair` はコンスセルとして扱われます。`eq?`、`eqv?`、
`equal?`、`quote` と記号演算も提供されます。`eq?` はアドレス比較です。

```cpp
template<typename T>
bool is_eq(T & x, T & y) { return (&x)==(&y); }
```

一様な列に対する `cons` と `cdr` は `std::list` のコピーを返します。それが
Scheme の意図する持続的な意味論だからです。以前の版は呼び出し側の記憶領域を
共有する `boost::ptr_container` のビューを返していましたが、その依存は
なくなりました。

数値プログラムにはさらに小さなヘッダが与えられます。生成された本文が数値
部分集合の内側に収まっているとき — クロージャなし、リストなし、プロミス
なし — 翻訳器は `SCM2CPP_MINIMAL` を定義し、ヘッダは std だけになり、
boost の include を 1 つも伴わずにコンパイルできます。これが nvcc に
通せる理由です。

作業例は `usage.cpp`、`list-test.cpp`、`equal-test.cpp` を参照してください。
