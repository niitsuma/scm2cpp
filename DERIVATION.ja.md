# DerivedLasso の導出

[English](DERIVATION.md)

`scm2cpp-lasso` パッケージの `DerivedLasso` が動かす C++ は、Gram
行列の水準では誰も書いていません。入力は
[`examples/kernel-only/lasso-design.scm`][src] で、残差形の素朴な座標
降下です。X を numpy の持ち方(n 行 p 列、`x[i*p+j]`)で歩く平坦な
ループだけでできていて、Gram 行列も BLAS も出てきません。共分散
(Gram)形は翻訳器が自分で作ります。scikit-learn の `precompute='auto'`
と同じ分岐と、BLAS 呼び出し 3 つも翻訳器が出します:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M --derive --cublas lasso_design.scm
derive: lasso-design: raise differencing merge matmul guard
```

この文書は、このログ行に出る規則を発火順にすべて取り上げます。
規則ごとに、コードへのリンクと、そのコードがこのカーネルに何をするか
の解説を付けます。リンクはすべてコミット [`ae3d69a`][commit] に固定
しています。パッケージに入っている 3 変種(`--cublas`、`--blas`、
どちらもなし)は `python/scm2cpp-lasso/regenerate.sh` が上のコマンド
で作ります。

[commit]: https://github.com/niitsuma/scm2cpp/tree/ae3d69a041a59cd41d659a0c37602a25baf29fc7
[src]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/examples/kernel-only/lasso-design.scm

## 0. 適用順の一覧

| # | 段階 | 規則 | コード | lasso-design への効果 |
|---|---|---|---|---|
| 0 | 入口 | `--derive`、`--blas`/`--cublas` | [scm2cpp-file.scm L92-105][flags]、[scm2cpp-match.scm L3178-3179][hook] | `SCM2CPP_DERIVE` / `SCM2CPP_BLAS` を立てる。ソース文字列は `derive-source-maybe`、`lower-blas-maybe`、マクロ展開の順に通る |
| 1 | 準備 | 形と生存解析 | [derive-source-maybe][dsm]、[find-with-arrays][fwa]、[compute-param-liveness!][live] | `(with-arrays ((x (n p)) ..))` から形を取る。`resid` は出力なので最後に復元する |
| 2 | ドライバ | **raise**(R1-R7) | [rewrite-raise.scm][raise] | `do` → `range-for`、`x[i*p+j]` → `(col x j)`、内積ループ → `(array-sum ..)`、残差更新ループ → `(array-dec! resid (scale d (col x j)))` |
| 3 | 準備 | 作業ベクトル候補 | [scratch-candidates][sc] | 組 (`resid` . `beta`) |
| 4 | ドライバ | **differencing**(差分化) | [try-differencing][td] → [incrementalize][inc] | メモ `c = X'r`、Gram `G = X'X`、更新 `c -= d G[j,:]`、足し込み `b0[j] += d`、復元 `r -= X b0` |
| 5 | ドライバ | **merge**(表の併合) | [try-merge][tm] → [table-subset-plan][tsp]、[apply-table-merge][atm] | `xnorm[j]` の読みを `G[j,j]` に置き換え、`xnorm` を作るループを消す |
| 6 | ドライバ | (precompute、lower、contract、dead-fill) | [derive-fixpoint/log][dfl] | 毎周回すべて試すが、ここでは 1 つも発火しない。何も発火しない周回が不動点 |
| 7 | 後処理 | **matmul**(縮約への畳み込み) | [fold-matmul][fm] | Gram・メモ・復元のループの入れ子がそれぞれ `(contract ..)` 1 つになる |
| 8 | 後処理 | **guard** | [guard-by-shape][gbs] | `(if (< p n) 導出版 元のまま)` |
| 9 | 下降 | 縮約 → BLAS | [lower-contract][lc] | `blas-syrk!`(Gram)、`blas-gemv!`(メモ)、`blas-gemv!`(復元) |
| 10 | 出力 | 束縛演算 → C++ | [cblas-binding.scm][cbind]、[scm2cpp-blas.hpp][hpp] | `cblas_dsyrk`、`cblas_dgemv`(または cuBLAS の対応関数) |

2、4、5、6 は 1 つの不動点ループです。それ以外は表の順に 1 回ずつ
走ります。

[flags]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-file.scm#L92-L105
[hook]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-match.scm#L3178-L3179
[dsm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-match.scm#L3102-L3130
[live]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-match.scm#L610-L664
[fwa]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L93-L104
[sc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L63-L86
[raise]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L47-L235
[td]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L72-L99
[inc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L271-L591
[tm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L112-L139
[tsp]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-precompute.scm#L177-L198
[atm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-precompute.scm#L203-L217
[dfl]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L267-L287
[fm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L139-L237
[gbs]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L290-L295
[lc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L175-L273
[cbind]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/bindings/cblas-binding.scm#L18-L37
[hpp]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-blas.hpp#L27-L63

## 1. 入力

`lasso-design.scm` の要点(コメントは除いています):

```scheme
(define (lasso-design x y resid xnorm beta lams betas iters tol n p nlam)
  (with-arrays ((x (n p)) (y (n)) (resid (n)) (xnorm (p)) (beta (p))
                (lams (nlam)) (betas (nlam p)))
  (do ((i 0 (+ i 1))) ((= i n)) (vector-set! resid i (vector-ref y i)))
  (do ((j 0 (+ j 1))) ((= j p))                         ; xnorm[j] = |x_j|^2
    (let ((acc 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j)) (vector-ref x (+ (* i p) j))))))
      (vector-set! xnorm j acc)))
  (do ((l 0 (+ l 1))) ((= l nlam))                      ; 正則化パス
    ... (do ((j 0 (+ j 1))) ((= j p))                   ; 1 掃引
          (let ((rho 0.0) (old (vector-ref beta j)))
            (do ((i 0 (+ i 1))) ((= i n))               ; rho = x_j . r
              (set! rho (+ rho (* (vector-ref x (+ (* i p) j)) (vector-ref resid i)))))
            (set! rho (+ rho (* old (vector-ref xnorm j))))
            (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n))) (vector-ref xnorm j))))
              (vector-set! beta j bnew)
              (if (not (= bnew old))
                  (begin ...maxmove...
                    (do ((i 0 (+ i 1))) ((= i n))       ; r -= (bnew-old) x_j
                      (vector-set! resid i (- (vector-ref resid i)
                                              (* (vector-ref x (+ (* i p) j)) (- bnew old))))))
                  #f)))) ...)))
```

導出のために書き手が足すのは `with-arrays` だけです。普通の翻訳では
何も変えません。`--derive` には「`x` は n×p 行列」と伝え、
`x[i*p+j]` を (i, j) 要素として読めるようにします。

## 2. 入口と準備

**フラグ**([scm2cpp-file.scm L92-105][flags])。`--derive` は
`SCM2CPP_DERIVE=1` を、`--blas` / `--cublas` は `SCM2CPP_BLAS` を
立てます。[`scm2cpp-match-list`][hook] はマクロ展開の前のソース文字列
に `(lower-blas-maybe (derive-source-maybe src))` をかけます。マクロを
展開すると `with-arrays` も代数の形も消えてしまうので、2 つともこの
段階で走らせる必要があります。

**`derive-source-maybe`**([scm2cpp-match.scm L3102-3130][dsm])。
フォームを読み、使い捨ての展開版に
[`compute-param-liveness!`][live] をかけて、呼び出し側から見える仮引数
を調べます。そのうえで読んだままのフォームに `derive-forms`
([rewrite-derive.scm L302-315][dfo])をかけ、標準エラーに
`derive: f: ...` を出します。ここでは `resid` は書き込まれる仮引数
なので出力扱いになり、最後に正しい中身を持っていなければなりません。
§4 の復元はこの判定から出てきます。

**`derive-body`**([rewrite-derive.scm L242-265][db])は関数ごとの
ドライバです。最初の `with-arrays` を見つけ
([`find-with-arrays`][fwa])、宣言を dims(階数 2 以上:`x (n p)`、
`betas (nlam p)`)と extents(階数 1)に分けます。候補を見つけるために
本体を 1 度 raise します。それから候補の組ごとに不動点ループを回し、
`raise` 以外の規則が発火した最初の組を採ります。最後に積を畳み込み
(§7)、ガードを付けます(§8)。

[dfo]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L302-L315
[db]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L242-L265

## 3. raise:ループを配列代数へ

[rewrite-raise.scm][raise]。各規則は、配列マクロが行う展開の逆です。
規則が発火するのは、その展開結果とまったく同じ形がコードにある場所
だけです。そのため raise した後のプログラムを展開すると、同じループが
同じ順で、ビット単位で同じに戻ります。規則は下から上へ、何も変わら
なくなるまで適用します([`raise-loops`、L230-235][rl])。

| 規則 | コード | パターン → 結果 | lasso-design での適用箇所 |
|---|---|---|---|
| R1 | [L70-72][r1] | `(do ((i 0 (+ i 1))) ((= i N)) body)` → `(range-for (i N) body)` | すべての数え上げループ |
| R2 | [L74-97][r2] | N が a の宣言された行幅なら `(vector-ref a (+ (* w N) i))` → `(array-ref a w i)`。階数 3 以上では次の軸に対してさらに分ける | `x[i*p+j]` → `(array-ref x i j)`、`betas[l*p+j]` → `(array-set! betas l j ..)` |
| R3 | [L100-111][r3] | `(range-for (i N) (set! acc (+ acc term)))` → `(set! acc (+ acc (array-sum V)))`。V は term の要素ビュー | ノルムのループと `rho` のループ |
| R4 | [L113-194][r4] | `(range-for (i N) (vector-set! a i (- (vector-ref a i) t)))` → `(array-dec! a V)`。`+` なら `array-inc!`。行列の作業領域には行・列の形もある | 残差の更新 |
| R5 | [L198-208][r5] | `(let ((acc 0.0)) (set! acc (+ acc S)) ..)` → `(let ((acc S)) ..)` | `xnorm` の累積変数、`rho` の初期値 |
| R6 | [L210-216][r6] | 包んでいる代入から 1 回だけ読まれる let 束縛を代入式に埋め込む | `xnorm[j] = (array-sum ..)` |
| R7 | [L218-221][r7] | ベクトルの宣言長全体のスライス → ベクトルそのもの | `(slice resid 0 n)` → `resid` |

R3 と R4 が使う「要素 → ビュー」の変換は
[`elem->vexpr`][e2v](rewrite-normalize.scm L88-114)です。ループ添字
i についての要素式を、ベクトル全体の式に変えます。`(array-ref x i j)`
のように *先頭* の添字が i で、他の添字が動かないものは列ビュー
`(col x j)` になります([L103-105][e2vcol] の節)。
`(array-ref v js.. i)` は `(row v js..)` に、スカラー倍は
`(scale s ..)` になります。X が n 行 p 列で格納されているので、内積は
列を歩きます:

```scheme
(let ((rho (array-sum (* (col x j) resid))) (old (vector-ref beta j))) ...)
...
(array-dec! resid (scale (- bnew old) (col x j)))
```

[rl]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L230-L235
[r1]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L70-L72
[r2]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L74-L97
[r3]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L100-L111
[r4]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L113-L194
[r5]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L198-L208
[r6]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L210-L216
[r7]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-raise.scm#L218-L221
[e2v]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-normalize.scm#L88-L114
[e2vcol]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-normalize.scm#L103-L105

**作業ベクトル候補**([`scratch-candidates`、rewrite-derive.scm
L63-86][sc])。raise した本体で「スケールしたビューで更新される対象」
`(array-dec! V (scale _ (col X J)))` を作業ベクトルとし、同じ座標 J で
書かれるベクトル `(vector-set! B J _)` を係数とします。ここでは組
(`resid` . `beta`) が 1 つだけ見つかります。どれが残差でどれが係数か
を翻訳器に教えるものは何もなく、コードの形から読み取っています。

## 4. differencing:メモと Gram

[`try-differencing`][td](rewrite-driver.scm L72-99)は、掃引の形を
した文(先頭が `range-for` か `do` の文。`let` と `begin` の中にも
入ります)を順に [`incrementalize`][inc](rewrite-incremental.scm
L268-580)へ渡し、最初に受理されたものを採ります。復元するかどうかも
ここで決めます。出力である作業ベクトルは必ず復元し、局所的なものは
後の文が読むときだけ復元します。中身は配列代数の上の有限差分法
(Paige と Koenig)で、内積を名指しで探すパターンはどこにもありません。

**文脈:作業ベクトルから外へ育てる。**
[`maximal-contexts`][mc](L200-221)は `resid` の出現それぞれから出発
し、[`admissible?`][adm](L179-196)が成り立つ限り、囲む式を外側へ
広げていきます。条件は次の 3 つです:

- *純粋*:書き込みをしない(使える演算子は `pure-heads`、L100-110);
- *線形*:`resid` についての [`degree`][deg](L114-172)がちょうど 1。
  これで `C[r - d u] = C[r] - d C[u]` が成り立つ;
- *不変*:他の自由変数は、掃引中に変わらないか、ループ座標である
  (ループ座標はメモの添字になる)。ループ座標とは、`range-for` だけが
  束縛し、その長さがすべて同じで、掃引中に書き換わらない名前です
  ([L274-299][coord])。別のループのカウンタと同じ名前の、let で束縛
  した `i` は座標になりません。

[coord]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L274-L299

このカーネルでは `(array-sum (* (col x j) resid))` で成長が止まり
ます。その外側は `rho` の let 束縛で、毎反復で束縛し直される `old` は
メモの添字になれないからです。こうしてメモは `c[j] = x_j · r` に
なります。

**更新**(L310-333)。`(array-dec! resid (scale (- bnew old) (col x j)))`
は `(site vec d x j () - col)` として記録されます。ベクトルの作業領域、
係数 `d = bnew - old`、方向 `(col x j)`、減算、列ビュー、という意味
です。出現数の検査(L349-371)で、`resid` のすべての出現が文脈か更新
のどちらかに収まっていることを確かめます。1 つでも余れば、規則は
適用を拒否します。

**出力**(L533-591)。`P = p` です:

| 部分 | コード | lasso-design での結果 |
|---|---|---|
| 座標を穴にして族にまとめる | [L384-404][holed] | 族は `(array-sum (* (col x ?H0) resid))` の 1 つ |
| 外に出すカーネル:文脈に更新方向を代入したもの | [L539-552][gram] | `G[k1,k2] = (array-sum (* (col x k1) (col x k2)))`、つまり `X'X` |
| メモの構築 | [L553-564][memo] | `c[k] = (array-sum (* (col x k) resid))`、つまり `X'r` |
| 方向ごとの総移動量 | [L492-501][b0] | 更新のたびに `b0[j] += (bnew - old)` |
| 読み → メモの読み | [L475-480][rd] | `rho` の初期値が `(array-ref c j)` になる |
| 更新 → メモの更新 | [L486-530][upd] | k2 < p について `c[k2] -= G[j,k2] * (bnew - old)`。O(n) が O(p) になる |
| 対称性 | [L466-474][sym] | G の定義式そのものから対称性を証明する。そのため更新は G の列 j ではなく、連続した行 j を読む |
| 復元 | [L570-590][rst] | jj について `resid -= b0[jj] * (col x jj)` |

掃引の間、作業ベクトルにはもう触りません。最後に 1 回だけ、方向ごとの
総移動量から作り直します。`b0[j]` は掃引の中で更新の係数 `d` を足し込んだ
もので、`d` が何でできていても復元は正しくなります(ここでは
`bnew - old`。SVM では `(anew - old) y_i` で、係数の変化から復元すると
これを間違えます)。変化なしのときに更新を飛ばす `(if (not (= bnew old)) ..)`
はソースに書いてあるもので、そのまま引き継がれます。

[mc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L200-L221
[adm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L179-L196
[deg]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L114-L172
[holed]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L384-L404
[gram]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L539-L552
[memo]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L553-L564
[b0]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L492-L501
[rd]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L475-L480
[upd]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L486-L530
[sym]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L466-L474
[rst]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-incremental.scm#L570-L590

## 5. merge:列ノルムは Gram の対角

[`try-merge`][tm](rewrite-driver.scm L112-139)は、表を埋めるループ
`name[idx..] = expr` をすべて集め(`collect-fill-defs`)、比較のため
だけにそれぞれを正規化します(`defs3`)。そのうえで
[`table-subset-plan`][tsp](rewrite-precompute.scm L177-198)に、ある表
の定義が別の表の定義の添字を制限したものになっていないかを調べさせ
ます。大きい表の添字から小さい表の添字への写像をすべて試します:

```
xnorm[j]   = (array-sum (* (col x j)  (col x j)))
G[k1,k2]   = (array-sum (* (col x k1) (col x k2)))     k1 -> j, k2 -> j
```

得られる計画は `((xnorm G ((k1 . j) (k2 . j))))` です。
[`apply-table-merge`][atm](L203-217)が `(vector-ref xnorm j)` を
すべて `(array-ref G j j)` に書き換え、`drop-fills` が `xnorm` を作る
ループを `0` に置き換えます。こうして導出版ではノルムをまったく計算
しなくなります。この規則は表を消すことしかしないので、ループに陥る
ことはありません。

## 6. 不動点ループの残り

[`derive-fixpoint/log`][dfl](rewrite-driver.scm L267-287)は、毎周回、
決まった順に規則を試します:raise、differencing、merge、precompute
([L147-152][pc])、lower([L215-252][lo])、contract-axis、
dead-fill([L256-258][df])。どの規則も発火しなかった最初の周回で
止まります。lasso-design では、merge の次の周回で何も発火しません:

- differencing の出力は `let` で、`let` そのものは掃引として渡され
  ないので、differencing は再発火しない;
- Gram はもう外に出ているので、precompute が見つける「ループ内の定数
  畳み込み」は残っていない;
- `resid` は出力で、併合された表を作るループもすでに消えているので、
  dead-fill が集めるものはない。

そのためログは `raise differencing merge` になります。
(`try-precompute` は手書きの Gram を外に出すための規則です。この
カーネルでは differencing がもうその仕事をしています。)

[pc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L147-L152
[lo]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L215-L252
[df]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-driver.scm#L256-L258

## 7. matmul:3 つの入れ子が 3 つの縮約になる

[`fold-matmul`][fm](rewrite-derive.scm L139-237)は規則 1 つです。
1 文だけを持つ `range-for` の入れ子を剥がし([`peel`、L158-162][peel])、
中身が 2 つのビューの内積なら
`(contract (k) (i..) (a la..) (b lb..))` にします。これは numpy の
einsum で、どの添字もそれが走る軸に名前を付けて書きます。軸の割り当て
は [`labels`][lab](L167-176)が決めます:`(row a js..)` は
`(a js.. k)`、`(col a js..)` は `(a k js..)`、裸のベクトルは `(a k)`
です。

| 入れ子(§4 の出力) | 下位規則 | 縮約 |
|---|---|---|
| Gram:`G[k1,k2] = Σ (col x k1)(col x k2)` | [`memo-fold` L182-191][mf] | `(array-set! G (contract (k) (k1 k2) (x k k1) (x k k2)))` |
| メモ:`c[k] = Σ (col x k) resid` | `memo-fold` | `(array-set! c (contract (k) (k') (x k k') (resid k)))` |
| 復元:`resid -= Σ_j b0[j] (col x j)` | [`restore-fold` L194-217][rf] | `(array-dec! resid (contract (j) (i) (b0 j) (x i j)))` |

掃引の中のメモ更新は、G の 1 行を回る `range-for` 1 つだけで内積を
含まないので、ループのまま残ります。1 座標あたり O(p) なので、BLAS
を呼ぶ価値はありません。代数としては何も変わりません。積を本来の
階数で書き直すだけで、そうしておくと次のパスがどの呼び出しになるか
を読み取れます。

[peel]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L158-L162
[lab]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L167-L176
[mf]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L182-L191
[rf]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L194-L217

## 8. guard:scikit-learn の precompute='auto' を導出する

[`guard-by-shape`][gbs](rewrite-derive.scm L290-295)。行列とビューは
[`update-matrix`][um](L270-279)が渡します。差分化は、長さ n の作業
ベクトルを、長さ p のメモと 1 度だけ作る p×p の Gram に取り替えます。
これが得になるのは p < n のときだけです。p も n も実行時の値なので、
導出版にはガードを付けます:

```scheme
(if (< p n) (begin 導出版...) (begin 元のまま...))
```

宣言のどちらの長さが p になるかはビューで決まります。`(n p)` 行列の
`col` は長さ n で p 本あるので、条件は `(< p n)` です。`(p n)` 行列の
`row` でも同じ条件になります。X が横長なら、掃引は書いたとおりに走り
ます。`examples/kernel-only/lasso-auto.scm` が手で書いている分岐、
scikit-learn が `precompute='auto'` で選んでいる分岐と同じものです。

[um]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-derive.scm#L270-L279

§3-8 を通った後のプログラム(抜粋、gensym の番号は省いています):

```scheme
(if (< p n)
  (begin
    (range-for (i n) (vector-set! resid i (vector-ref y i)))
    0                                                   ; xnorm を作るループ(併合で消えた)
    (let ((b0 (make-vector p 0.0)) (g (make-vector (* p p) 0.0)) (c (make-vector p 0.0)))
      (with-arrays ((g (p p)) (c (p)) (b0 (p)))
        (array-set! g (contract (k) (k1 k2) (x k k1) (x k k2)))    ; G = X'X
        (array-set! c (contract (k) (k3) (x k k3) (resid k)))      ; c = X'r
        (range-for (l nlam) ...
          (range-for (j p)
            (let ((rho (array-ref c j)) (old (vector-ref beta j)))
              (set! rho (+ rho (* old (array-ref g j j))))
              (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n))) (array-ref g j j))))
                (vector-set! beta j bnew)
                (if (not (= bnew old))
                    (begin ...maxmove...
                      (vector-set! b0 j (+ (vector-ref b0 j) (- bnew old)))
                      (range-for (k2 p) (array-dec! c k2 (* (array-ref g j k2) (- bnew old)))))
                    #f)))) ...)
        (array-dec! resid (contract (j) (i) (b0 j) (x i j)))           ; r -= X b0
        0)))
  (begin ...元のループ、手を付けない...))
```

## 9. 縮約 → BLAS

`lower-blas-maybe`([scm2cpp-match.scm][lbm])は
`bindings/cblas-binding.scm` か `bindings/cublas-binding.scm` を読み
込み、[`lower-blas-forms`][lbf](rewrite-blas.scm L95-)を走らせます。
縮約は 1 つずつ [`lower-contract`][lc](L175-273)を通ります。`kpos` は、
和を取るラベルが各オペランドの軸の並びの先頭にあるか末尾にあるかを
返します。行優先の格納では、先頭にあればそのオペランドを転置して
読むことになります。左オペランドは、y の中で自由ラベルが先に現れる
方です。そのうえで:

| 縮約 | 場合 | 呼び出し |
|---|---|---|
| `(contract (k) (k1 k2) (x k k1) (x k k2))` | [Gram、L243-247][syrk]:両辺が同じ名前で、和のラベルも同じ位置 | `(blas-syrk! g x 1.0 0.0 1 p n)` |
| `(contract (k) (k3) (x k k3) (resid k))` | [右がベクトル、L259-265][gemv]:x が左オペランドで、和のラベルが先頭 | `(blas-gemv! c x resid 1.0 0.0 1 p n)` |
| `(array-dec! resid (contract (j) (i) (b0 j) (x i j)))` | [左がベクトル、L248-258][gemvl]:`b0` は名前なので実体化は要らない。`array-dec!` なので alpha -1、beta 1 | `(blas-gemv! resid x b0 -1.0 1.0 0 n p)` |

積の形ごとの専用コードはありません。転置フラグは、和のラベルがどこ
にあるかだけで決まります。`--cublas` では、`x` はそのスコープで読む
だけなので、[`operand`][opd] がスコープの入口で 1 回だけ転送します
(`dmat-upload`)。ベクトルはホストに置いたままです。

[lbm]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/scm2cpp-match.scm#L3141-L3156
[lbf]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L95-L301
[syrk]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L243-L247
[gemv]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L259-L265
[gemvl]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L248-L258
[opd]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/rewrite-blas.scm#L150-L159

## 10. C++ の出力

BLAS 演算は普通のカスタム束縛の演算です
([cblas-binding.scm L18-37][cbind])。シグネチャ、C++ の書式文字列、
`(mutates 0)`、ヘッダを持ちます。型推論、変更の要約、出力器はこれを
他の宣言済みの演算と同じに扱います。どの演算にも Racket のモデルが
付いていて、`binding-check.rkt` がそれを実際の C++ と照合します。
呼び出しは [scm2cpp-blas.hpp][hpp] に着地します:`blas_syrk` は
上三角を `cblas_dsyrk` で作って残りを鏡写しにするループを足したもの、
`blas_gemv` は `ta` で転置を選ぶ `cblas_dgemv` です。デバイス版は
`scm2cpp-cublas.hpp` にあります。

`--blas` を付けなければ、同じ縮約を [array-macros.scm L418-482][amc]
がループの入れ子に展開します(Gram は上三角と鏡写し)。これが
パッケージの `derived_loops` 変種です。

[amc]: https://github.com/niitsuma/scm2cpp/blob/ae3d69a041a59cd41d659a0c37602a25baf29fc7/array-macros.scm#L418-L482

## 11. 検査

- `run-tests.sh` は `probe/derive-lasso-design.scm` を、そのまま、
  `--derive`、`--derive --blas`、(デバイスがあれば)`--derive --cublas`
  で翻訳し、すべてを同じオラクル出力と比べます。テストデータは 2 進
  で割り切れる値なので、どの変種も同じ桁を出力します。
- `test-raise.rkt` は同じ規則を兄弟カーネルで検査します:
  `lasso-kernel.scm`(X を p 行 n 列で格納、行ビュー)と
  `probe/derive-lasso-col.scm`(ここと同じ列ビュー)です。それぞれ
  について、発火ログ、`(< p n)` のガード、Gram・メモ・
  復元が縮約になっていることを確かめます。
- `python/scm2cpp-lasso/check-derived.py` は、縦長と横長の設計行列で
  `DerivedLasso` を `CovLasso` と scikit-learn に 1e-8 まで照合します。

各段階を自分で見るには、`racket scm2cpp-file.scm -t scm2c.typ -S
--derive --blas lasso_design.scm` を実行します。
`lasso_design.expanded.scm`(C++ になる直前のプログラム)が書き出され、
標準エラーの行が発火ログです。
