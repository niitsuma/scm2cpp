# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml)

*[English version](README.md)*

Scm2Cpp は Scheme の部分集合を、人が読んで編集できる C++ へ翻訳します。

機械のためだけの C を吐く従来の Scheme コンパイラと違い、Scm2Cpp は Scheme
の値に実行時表現を与えません。整数は `int` に、ベクタは
`std::array<double,1025>` に、`(car x)` は `car(x)` になります。型は
プログラム全体の推論から決まり、推論で確定できなかったものが C++ の
テンプレート引数になります。

```scheme
(define (square x) (* x x))
(define (average x y) (/ (+ x y) 2.0))
(define (improve guess x) (average guess (/ x guess)))
```

は次のようになります。

```cpp
double square( double x )                 { return (x*x) ; }
double average( double x, double y )      { return ((x+y)/2.0) ; }
double improve( double guess, double x )  { return average(guess,double((x/guess))) ; }
```

## 例: 速い lasso — Scheme から pip、そして GPU へ

このリポジトリの看板製品は lasso ソルバです。素の Scheme
(`examples/kernel-only/lasso-cov.scm`) で書かれ、C++ へ翻訳され、
pip 用に包装され、CUDA にバッチで載ります — どの段階でも同じ生成関数です。

```console
$ pip install scm2cpp-lasso      # C++17 コンパイラが必要。Racket は不要
```

この 1 行はいま実際に動きます。パッケージは
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/) として PyPI に
あり、入るのはこのリポジトリが Scheme から生成した C++ です。導入先に
Racket は要りません。

100 本の候補列のうち信号を担うのは 3 本。どれかをソルバに尋ねると、
その 3 本だけを答えます:

```python
import numpy as np
from scm2cpp_lasso import CovLasso

rng = np.random.default_rng(0)
X = rng.standard_normal((500, 100))          # 500 行、候補 100 列
beta = np.zeros(100)
beta[[7, 23, 61]] = [2.0, -1.5, 0.8]         # 効くのはこの 3 本だけ
y = X @ beta + 0.1 * rng.standard_normal(500)

model = CovLasso(X, y)                       # Gram 行列は一度だけ作る
path = model.fit_path(model.lambda_grid())   # 100 個の lambda、暖かい開始

fit = path[60]
for j in np.flatnonzero(np.abs(fit) > 1e-6):
    print(f"  x{j:<3} {fit[j]:+.3f}")
```

```console
  x7   +1.965
  x23  -1.474
  x61  +0.770
```

残る 97 本は厳密にゼロです — 罰則はそのためにあります — 係数は植えた値が
罰則の分だけゼロ側に縮んだものです。残りのインタフェースは 2 行です:

```python
grid = model.fit_path_batch(lambdas)         # すべての lambda をゼロから。GPU があれば並列
betas = model.bootstrap(lam, n_boot=500)     # 再標本をまとめて 1 バッチで当てはめ直す
```

下の数字は `bench/lasso-table.py` が RTX 4090 と i9-10900X で出すものです。
普通の密な設計行列、p=200 列、n=1800 行、4096 個の lambda の格子、すべての
lambda をゼロから — 暖かい開始が使えない交差検証格子の形です。両者とも同じ
設計行列から始めるので、Gram 行列を組む時間は翻訳カーネルの側に入っており、
BLAS は 1 スレッドに固定してあるので CPU の行は 1 コア対 1 コアです。翻訳
カーネルには tol=1e-8 を、sklearn には既定の 1e-4 を課しているので、この
比較は控えめです。厳しいほうの許容誤差まで解いた側が翻訳カーネルで、GPU と
CPU の答えは 1.3e-15 まで一致します:

| ソルバ | 時間 |
|---|---|
| sklearn `Lasso.fit` を lambda ごとに、冷たく | 31.9 秒 |
| 翻訳した cov カーネル、CPU 1 コア、冷たく | 1.3 秒 |
| 翻訳した cov カーネル、GPU、lambda 1 つにスレッド 1 本 | 0.2 秒 |

逐次の単一パス、つまり両者とも暖かい開始が使える仕事では互角です。400 個の
lambda のパスで、sklearn の既定である 1e-4 なら 0.058 秒対 0.078 秒、両者に
1e-8 を要求すると 0.101 秒対 0.090 秒で、係数は 7e-9 まで一致します。差が
開くのは仕事が逐次でないときで、それを測ったのが上の表です。

### pip で入る他の lasso との比較

`bench/lasso-compare.py` は、この環境で `pip install` できる lasso 全部 —
scikit-learn 1.9.0、celer 0.7.4、skglm 0.5、RAPIDS cuML 26.8 — に同じ
冷たい格子を解かせます。各ソルバは自身の既定許容誤差で走り、計測前に
1 回の計測外フィット(numba のコンパイルを時計から外すため)、cuML は
計測開始前にデータをデバイスへ置いた状態です。最終列は最小 lambda に
おける各ソルバの目的関数と当方の差 — 速いが緩い答えはここに現れます:

| ソルバ | 時間 | 目的関数の差 |
|---|---|---|
| scm2cpp-lasso、CPU 1 コア (tol 1e-8) | 0.9 秒 | 0 |
| scm2cpp-lasso、GPU、lambda 1 つに 1 スレッド | 0.2 秒 | 0 |
| sklearn `Lasso.fit` を lambda ごと | 12.5 秒 | +1.6e-09 |
| celer を lambda ごと | 17.3 秒 | 0 |
| skglm を lambda ごと | 16.4 秒 | +2.8e-17 |
| cuML を lambda ごと、GPU | 57.5 秒 | +9.1e-07 |

正直な注記を 2 つ。celer と skglm は別の領域 — 非常に大きく疎な設計
行列 — のために作られており、そこではスクリーニング規則が支配します。
p=200 の密行列ではフィットごとの準備代だけ払って本領に届きません。
cuML は 1 回のフィットの**内側**を並列化するので、1 フィットが大きい
ときに勝ちます。この規模ではフィットごとの起動オーバーヘッドが支配し、
当方の GPU 行は **lambda を跨いで**並列化します — 罰則 1 つに CUDA
スレッド 1 本。交差検証格子が実際に差し出す並列軸はこちらです。
R の glmnet はこのアルゴリズム族の祖先ですが、現行 Python でビルド
できる移植が存在せず、族そのもので代表されています。

`CovLassoCV` はこの機構の上の scikit-learn `LassoCV` です — 同じ格子
構成、同じ連続 fold、同じ平均 MSE 最小の選択。構造的な節約が 2 つ
あります。fold の訓練 Gram は**引き算**(Gram は行について加法的なので
G − Xf'Xf は fold 1 個分の費用)であり、Gram ができた後は**下流が
n 行に二度と触れない** — 差が n とともに開くのはこのためです。GPU では
全 fold × 全 alpha を単一起動の 1 スレッドずつにできますが、その起動は
fold の Gram を alpha ごとに複製するため、既定では複製サイズで側を選び
ます — 512 MB 以下なら CUDA、超えたら CPU の warm パス(`force_cpu` /
`force_gpu` で上書き可)。cv=5、alpha 100 個、CPU 1 コア、
sklearn 1.9.0、3 回実行の最良値:

| n | p | CPU | CUDA(強制) | sklearn `LassoCV` |
|---|---|---|---|---|
| 1,800 | 200 | 0.13 秒 | 0.20 秒 | 0.09 秒 |
| 5,000 | 1000 | 1.4 秒 | 6.0 秒 | 1.0 秒 |
| 100,000 | 200 | 0.39 秒 | 0.40 秒 | 2.1 秒 |
| 100,000 | 500 | 1.2 秒 | 1.6 秒 | 5.5 秒 |

CUDA 列は CV が GPU に差し出せるものを正直に示しています: cv × 100 =
500 個の独立問題は、複製が小さい領域で warm CPU パスと同着、複製が
GB 級になる領域で敗北します — `fit_path_batch` の数千 lambda と違い
500 スレッドではデバイスが埋まらないので、CV の勝ちは構造的節約
(Gram の引き算と warm パス)のものであって GPU のものではなく、既定が
6.0 秒のセルを踏むことはありません(ヒューリスティックがそこでは既に
CPU 側にいます)。機構が効くのは大きい n です: Gram の下流は 100,000 行
に二度と触れません。n=5,000, p=1000 では sklearn の生 X 上の降下の方が
当方の Gram 経由より本当に速い。CPU と CUDA の選ぶ alpha は全サイズで
同一(係数 1e-14 一致)。sklearn とは n=5,000 で完全一致、それ以外は
準同点上で 1 格子点差(平均 MSE の相対差は高々 2.6e-4)で、sklearn の
tol=1e-10 なら全サイズで当方の alpha を選びます。

各部分の仕組みは後述します。Python 包装は「PyPI からソルバを入れる」、
境界コピーなしの `-M` インタフェースは「速い lasso を Python から呼ぶ」、
CUDA プロファイルは「GPU 上での実行」を参照してください。

## インストール

必要なもの:

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
$ ./run-tests.sh                         # PASS=44 FAIL=0 と出れば成功
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
| `-R` | 翻訳前に規則探索でループ入れ子と再帰を書き換える。下記の prefix-sum、separable-box-sum、tabulation の各規則 |
| `--rules FILE` | FILE から追加の書き換え規則を読む (`-R` を含意)。各規則は使用前に自己テストされます |
| `--apply-rule NAME` | 名前で指定した規則を、コストモデルを無視して合致箇所すべてに適用する。一度払って以降を安くする類の書き換え — 残差を持ち回る座標降下を Gram 行列の covariance update に変える `cd-covariance-update` が代表例 — では静的モデルが償却を見通せないため、採算は呼び出し側が主張します。構造的な合致と規則の自己テストは依然として関門です |
| `--binding FILE` | 宣言された演算を FILE に従いユーザ提供の C++ ヘッダへ対応づける。`examples/custom-template/` を参照 |
| `-M` | 実行ファイル用のソースに加えて `NAME_capi.cpp` (extern "C" ラッパ) と `NAME.py` (ctypes ローダ) を出し、翻訳された関数を Python から numpy 配列に対して呼べるようにする |
| `--llm-hints CMD` | ソースを標準入力として CMD を実行し、その標準出力を `-I` 用の空白区切り配列名として使う。指定しない限り無効。CMD は Scm2Cpp の一部ではなく、通常はローカルに立てたモデルへのラッパです |

環境変数:

| 変数 | 意味 |
|---|---|
| `SCM2CPP_RELATIONAL=1` | 関係型の型推論 (`--inference relational` と同義): recursive miniKanren の型付け関係で、旧関係型導出が後退先 |
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

### 規則探索 (`-R`)

`-R` は翻訳の前にソース間書き換えを走らせます。規則は値です — 左辺パターン、
右辺テンプレート、副条件 — そして 1 つの汎用エンジンが単一化によってすべての
部分項に照合し、静的コストを下げる書き換えを採用します。したがって規則を
書く順序は問いません。4 つの規則が同梱されています。

| 規則 | 書き換え | コスト |
|---|---|---|
| `scan-lemma-1d` | 配列のすべての接頭辞を再度足し上げる処理が、1 回の走査累積になる | O(n^2) から O(n) |
| `boxsum-2d-separable` | 正方配列のすべての箱を再度足し上げる処理が、行方向の prefix 走査と列方向の in-place prefix 走査になる | O(n^4) から O(n^2) |
| `tabulate-recursion` | `(- n k)` に対する純粋な単項の木再帰が、下から順のテーブル充填になり、自己呼び出しがテーブル読みになる | 指数から O(n) |
| `cd-covariance-update` | 残差を持ち回る座標降下が Gram 行列の covariance update になる。Gram 行列を一度作り、`c = X'r` をそれを通じて維持し、最後の 1 パスで残差を現在値に戻す | 掃引あたり O(np) が、一度の O(np^2) の後は掃引あたり O(p^2) |

`cd-covariance-update` は探索だけでは決して発火しません。静的コストモデルは
どのループも一様に数えるので、一度きりの Gram 構築が、それが償う掃引と同じだけ
高くつくように見えます。実際に償却されるかは掃引回数と行列の再利用回数に
依存し、それはソースに書かれていない事実です。そこで名前で
`--apply-rule cd-covariance-update` と適用します。この規則は `xnorm` 引数に
ついて何も仮定せず (`c` の維持は Gram 行列だけで行われるので、呼び出し側が
何を渡していても両辺は一致します)、収縮作用素は抽象のままにし (両辺が同じ順で
等しい引数を渡すため)、罰則式が残差を読む場合は照合を拒否します。残差は
掃引の途中で両辺の食い違いを許している唯一の状態だからです。算術上の注意:
結果は厳密には等しく、浮動小数点では丸めの範囲でのみ一致します。残差更新の
結合順序が変わるためです。

規則は、自身に埋め込まれたテストを通ってはじめて使われます。小さなプログラム
対の両辺を実行して出力を比べ、失敗した規則はメッセージとともに捨てられます。

`--rules FILE` はファイルから規則を追加します。手で書いても、言語モデルに
提案させても構いません。外部規則は組み込み規則よりも意図的に表現力が低く
(右辺は手続きではなくテンプレート、副条件は固定語彙
`(distinct ?a ?b)`、`(symbol ?x)`、`(number ?x)`、`(zero ?x)` から選ぶ)、
規則ファイルを読むことがそのファイルの言うことを実行することにはなりません。
埋め込みテストは必須で、これが関門です。自分自身のテストで両辺が食い違う
提案規則は、どのプログラムに触れる前に捨てられます。

```scheme
(rule gauss-sum
  (lhs (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
         (set! ?ACC (+ ?ACC ?I))))
  (rhs (set! ?ACC (+ ?ACC (quotient (* ?N (- ?N 1)) 2))))
  (when (distinct ?I ?ACC) (symbol ?ACC))
  (test (define (main)
          (let ((n 25) (acc 7))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc i)))
            (display acc) (newline)))
        (main)))
```

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

`rule-propose.rkt` はモデルが書く規則について輪を閉じます。コマンドに規則を
求め、関門にかけ、失敗したら証拠を返して — 「あなた自身のテストで、元は 30 と
印字しますが書き換え後は 20 と印字します」— 再挑戦させます (既定 3 回)。
受理された規則は査読のために規則ファイルへ追記されるだけで、直接適用される
ことはありません。この繰り返しは翻訳器ではなくこの著述ツール側にあるので、
翻訳そのものは決定的なままです。

```console
$ racket rule-propose.rkt -o my-rules.scm "ask-local -n 800" \
    "Rewrite the loop summing 0..n-1 into its closed form."
$ racket scm2cpp-file.scm -t scm2c.typ --rules my-rules.scm sample.scm
```

`-R` と `-I` は箱和の形について重なりますが同じものではありません。`-I` は
任意の階数と長方形の広がりを扱え、1 つのテーブルを複数の入れ子で共有できます。
一方 `-R` は再帰も扱い、その出力は素の Scheme なので実行時支援を必要とせず、
後段のすべてと組み合わせられます。

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
`delay`/`force` と遅延ストリーム。

非対応: 継続、一般の末尾呼び出し除去、提供されるリスト型・ストリーム型を
超える任意のヒープ確保再帰データ、および上記以外の R7RS。

Scheme の値は定まった型の C++ オブジェクトへ対応づけられます。その帰結を
1 つ明記しておきます。名前をベクタに束縛すると別名になります — 2 つの名前は
1 つのベクタを指し、翻訳器はどちらを通じた書き込みも両方から見えるように
参照を出します。この対応が破れるのは、そうした名前を `set!` で指し直すときです。
C++ の参照は指し直せないので、翻訳器はコピーに退避し、警告します。
`(set! v w)` の後、両言語は食い違います。Scheme は `v` を通じて `w` の
ベクタへ書きますが、C++ はコピーへ書きます。名前を指し直すのではなく、
要素を通じて代入するか、意図したベクタを渡してください。

## テスト

```console
$ raco link --user vendor/rkanren    # まだなら一度だけ
$ ./run-tests.sh                     # PASS=43 FAIL=0 と報告。失敗があれば非ゼロ終了
$ TIMEOUT=600 ./run-tests.sh /tmp/result.txt      # 制限時間を延ばし、ログ先を指定
```

31 本のプログラムはそれぞれ翻訳され、コンパイルされ、実行され、そして
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
そう告げるようになりました (試料生成器が小さな乗数を使うのはこのためです)。
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
ことで検査されます — 書き換え規則に課すのと同じ基準です。モデルが行優先だと
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

## PyPI からソルバを入れる

ソルバには専用のパッケージがあるので、Python の利用者は Racket も
このリポジトリも必要としません。

```console
$ pip install scm2cpp-lasso     # Gram 行列に対する lasso、設計行列は任意
$ pip install scm2cpp-tfs       # 移動平均による特徴選択
```

両方とも公開済みです —
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/) と
[scm2cpp-tfs](https://pypi.org/project/scm2cpp-tfs/)。このファイルの
冒頭の例は公開版に対してそのまま動きます。

```python
from scm2cpp_lasso import CovLasso
model = CovLasso(X, y)
path = model.fit_path(model.lambda_grid())

from scm2cpp_tfs import TemporalLasso
model = TemporalLasso(series, wmax=200, nobs=1800)
path = model.fit_path(y, model.lambda_grid(y))
yhat = model.predict(path[-1])           # 設計行列は最後まで作らない
```

各パッケージがコンパイルする C++ は `python/` 以下にコミットされており、
`examples/kernel-only/` からそのパッケージの `regenerate.sh` が生成します。
つまりインストールに必要なのは C++17 コンパイラだけで、翻訳器が要るのは
再生成のときだけです。インストール時に `nvcc` があれば、CUDA スレッド 1 本が
lambda 1 つを担当するバッチ GPU 経路も併せてビルドされます。無ければ
パッケージは同じように入って同じように動き、そのメソッドだけが欠けます。
こうしたパッケージは `python/` に 1 ディレクトリずつ置かれ、違いは
`python/README.md` (日本語版は `python/README.ja.md`) が説明します。

## 速い lasso を Python から呼ぶ

`-M` はライブラリの隣に `extern "C"` ラッパと ctypes ローダを出すので、
翻訳されたカーネルはそのまま import できます。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/lasso-cov.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o liblasso-cov.so lasso-cov_capi.cpp
```

boost の include は不要です。数値カーネルには最小ランタイムが与えられます。
配列引数は呼び出し側の numpy バッファへのポインタとして渡されます — 引数は
`scm2cpp::span` ビューです — ので、カーネルはその場で読み書きし、境界で
何もコピーされません。

`examples/kernel-only/fast-lasso.py` は生成された 4 つの関数を小さなクラスに
まとめます。設計行列は作られません。`build_S` が元系列をラグ和に変え、
`build_P` が目的変数との相互積に変え、`build_G` が Gram 行列を組み立て、
以降 `cov_descend` は座標あたり O(n) ではなく O(p) で済みます。降下は
止まった場所から正確に再開できるので、正則化パス全体を暖かいまま歩けます。
各 lambda は前の解から始まります。

```python
model = TemporalLasso(series, wmax=200, nobs=1800)   # Gram は一度だけ
path = model.fit_path(y, lambdas)                    # lambda 1 つにつき 1 行
```

```console
$ python3 examples/kernel-only/fast-lasso.py
strongest windows at the end of the path: [1, 2, 4, 5, 20]  (the target was built from 5 and 20)
scm2cpp path of 400 lambdas: 0.107s
sklearn lasso_path (same grid, warm):  0.095s
objective gap vs sklearn: max +1.67e-16 (negative means ours is lower)
```

暖かい者同士なら両者は互角で、解は丸めの範囲で一致します。差が開くのは
仕事が逐次でないところ — 各分割が冷たく始まる交差検証の格子 — であり、
それが次節の GPU が測るものです。

## GPU 上での実行と、sklearn との比較

生成コードの本文が数値部分集合の内側に収まっていれば、最小ランタイム
(`SCM2CPP_MINIMAL`) が与えられます。boost ヘッダなし、C++17、そして
デバイスで安全な関数には nvcc の下で `__host__ __device__` が付きます。
配列引数は `scm2cpp::span` ビュー — ポインタ 1 本で、ホストでは
`std::vector` や `std::array` から、カーネルでは生のデバイスポインタから
暗黙に作られます — なので、同じ翻訳済み関数が g++ でも nvcc でもそのまま
コンパイルできます。

`cuda/batch-lasso.cu` は、翻訳された covariance-update lasso
(`examples/kernel-only/lasso-cov.scm`) をバッチ正則化パスとして走らせます。
CUDA スレッド 1 本が lambda 1 つを担い、座標降下は各問題の内部では逐次で、
各スレッドは自分の係数の最大移動量が許容誤差を下回るまで塊ごとに掃引します。
`cuda/compare-sklearn.py` は同じ問題を numpy で組み直し、同じ格子で
scikit-learn を計時します。壁時計だけを信じるのではなく、目的関数の値で
解を照合します。

数値はこの README 冒頭の例にあります。冷たい者同士では翻訳カーネルが
1 コアで sklearn の約 22 倍、GPU バッチはさらに約 10 倍で、目的関数は
同等です。sklearn の冷たい行は 256 回の当てはめからの推定です。
nvcc とデバイスがある環境で `run-tests.sh` が走らせる検査は、同じ
プログラムの小さな事例です。

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

回帰スイートの 31 本のうち 30 本が検査を通ります。通らない 1 本は遅延
ストリームを使っており、ここでは基礎となる Typed Racket 表現を持たないため
対象外と宣言しています (`--keep` で生成モジュールをソースの隣に残せます)。

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
Scheme の意図する持続的な意味論だからです。以前の版は呼び出し側の記憶を
共有する `boost::ptr_container` のビューを返していましたが、その依存は
なくなりました。

数値プログラムにはさらに小さなヘッダが与えられます。生成された本文が数値
部分集合の内側に収まっているとき — クロージャなし、リストなし、プロミス
なし — 翻訳器は `SCM2CPP_MINIMAL` を定義し、ヘッダは std だけになり、
boost の include を 1 つも伴わずにコンパイルできます。これが nvcc に
通せる理由です。

作業例は `usage.cpp`、`list-test.cpp`、`equal-test.cpp` を参照してください。

## 文書

- `CHANGES.ja.md` — 歴史あるコードベースへの修正の記録と、それぞれの理由
- `ideal/stream-ideal-new.cpp` — 遅延ストリームについて生成コードが取るべき
  形を手で書いたもの

## 貢献

`CONTRIBUTING.md` を参照してください。

## ライセンス

MIT ライセンス。`LICENSE` を参照してください。そこには MIT の条項だけが
あります。

いくつかのファイルは Aubrey Jaffer の Schlep と SLIB、および Paul Graham の
*On Lisp* で公表されたユーティリティに由来します。`vendor/rkanren` は同梱の
第三者ライブラリです。これらはそれぞれ独自の寛容なライセンスの下にあり、
その全文が各ファイルの冒頭に再掲されています。これらの条件は MIT の条項に
**追加される**もので、由来と派生の度合いの実測とともに `NOTICE` に記録して
あります — `LICENSE` に混ぜないのは、ライセンスファイルが素の MIT だと
一目で分かるようにするためです。再配布者は MIT の条項に加えてこれらも
守る必要があります。

## 引用

設計を記述した論文を準備中ですが、まだこのリポジトリにはありません。
公開されるまでは、リポジトリと使用したコミットを引用してください。
機械可読なメタデータは `CITATION.cff` にあります。
