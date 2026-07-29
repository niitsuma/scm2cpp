# scm2cpp 作業コピーの変更点

2013年8月時点の実装(v0.8.1 相当)を複製し、現行 Racket 8.10 で動くように修正した。
元のツリーには手を加えていない。

## 動かすための前提

- 従来の関係論理型推論を使う場合のみ cKanren が要る。その親ディレクトリを
  `PLTCOLLECTS` に末尾コロン付きで指定する。`~/.local/share/racket/*/collects` に
  置くと raco setup が走って権限エラーになる。
- 整形に `astyle` を使う。未インストールだと生成コードが 1 行に潰れる。
- コンパイルは `g++ -std=c++11 -include boost/operators.hpp -include boost/optional.hpp`。

回帰テストは `./run-tests.sh` で実行する。

## 修正した内容

### 1. コマンドラインからの利用に一本化
元の実装はブラウザから呼び出す形を取っており、それに属するモジュール群を外した。
翻訳エンジンは `scm2cpp-file.scm`(CLI)から直接使う。

### 2. モジュール読み込み時の自己テストを停止
`scm2cpp-match.scm` 末尾の `(map display (scm2cpp-match-list tmp-exp-str "()"))` は
読み込みのたびに実行され、例外で全体を止めていたためコメントアウトした。

### 3. テンプレート実引数が解決できない場合の扱い(`scm2cpp-match.scm`)
`E0-type-a-specialization` が `#f` を含むと `string-join` が落ちていた。
解決できないときは `<...>` を出力せず、C++ 側の実引数からの型推論に任せる。

### 4. 数値のみの共用体型を最も広い数値型へ畳む
`cppuniontype` に `numeric-collapsible-union?` を追加。数値型と型変数だけから成る
共用体は `boost::mpl::vector` の variant ではなく `double` などに畳む。
C++ の算術変換と同じ意味になり、生成コードが読みやすくテンプレート推論も通る。

### 5. テンプレート引数の重複除去と未使用引数の削除
`types->ctemplatedef` で名前の重複を除去(重複は不正な C++ になる)。
`types->ctemplatedef-used` を追加し、署名に現れない型引数を落とす。
署名に出ない型引数は実引数から推論できず、呼び出せない関数になっていた。
判定の正規表現は `regexp` では `\b` が効かないため `pregexp` を使う。

### 6. `abs` の修飾
修飾なしの `abs` は `<cstdlib>` の int 版に解決され、実数計算で桁落ちしていた
(SICP sqrt が 3.02353 になった)。`std::abs` を出力し `<cmath>` を include する。
修正後は Racket と同じ 3.00009 になる。

### 7. 名前付き let を do ループへ書き換え(可読性の主目的)
`rewrite-named-let` を追加し、変換前のソースを書き換える。対象は引数なしで
末尾自己再帰のみの形(`if`/`when`/`cond` の末尾に `(NAME)`)。
クロージャ構造体 `struct loopNNN { ... }` ではなく素の `for` ループになる。
値を返す名前付き let は式の位置に現れうるため対象外(従来どおり)。
`do` の終了節は alpha 変換が 2 要素しか受け付けないため `((not TEST) 0)` の形で出す。

### 8. do ループの二重否定を解消
終了条件が `(not X)` のとき `!(!(X))` ではなく `X` を出力する。

### 9. インクルードガードの正規化(`scm2cpp-file.scm`)
ファイル名をそのまま大文字化していたため、ハイフンを含むと不正なマクロ名になった。
英数字以外を `_` に置換し、末尾に `_HPP` を付ける。

### 10. 型変数名の一意化(`scm2cpp-match.scm`)
テンプレート型引数名は変数名から機械的に作られるため、別スコープの同名変数に由来する
相異なる型変数が同じ名前になっていた。`template<typename XType, typename XType>` という
不正な C++ になるだけでなく、本来別の型であるべき引数が同一型に潰れていた。
型変数(gensym)をキーにした記憶表 `tvar-name` を導入し、衝突時のみ連番を付けて一意化する。

### 11. remainder / modulo の生成規則
`quotient` はあるのに `remainder` の規則が無く、二項演算の既定経路で `a remainder b` と
中置出力されて不正な C++ になっていた。`a % b` を出力する規則を追加。

### 12. 大域変数の出力先(`cdefs`)
関数本体はヘッダに出るのに大域変数の定義はソース側に出ていたため、宣言順序が逆転して
参照できなかった(FFT で手修正が必要だった問題)。大域変数もヘッダ側へ出す。

### 13. letrec の対応
`(letrec ((F (lambda (p ...) BODY))) (F arg ...))` は名前付き let と等価なので、
`letrec->named-let` で書き換える。名前付き let は自己参照するクロージャ構造体として
既に生成できるため、既存の仕組みをそのまま使える。

### 14. クロージャ構造体名の衝突回避
構造体名と変数名が同じになるとメンバ名と衝突して不正な C++ になる。同名の場合は
接尾辞 `_fn` を付ける。

### 15. lambda 型の戻り値の扱い(検討したが差し戻した)
`boost::function< ~a ( ~a ) >` の戻り値側が `ctype`(変数用)を呼んでおり、共用体型が
来ると `symbol->string` で落ちていた。引数側と同じく `cpptype` にすると無限再帰に
陥ったため差し戻し、`ctype` のままとした。共用体型の側で対処すべき問題である。

### 16. sqrt の追加(`alpha-conv.scm`)
`op-float->float` の一覧に `sqrt` が無く、戻り値型が未確定のまま
`Unknown-Type24412` という不正な識別子として出力されていた。

### 17. 型推論を Hindley-Milner に差し替え(`type-infer-hm.scm` を新規追加)
従来の関係論理(cKanren)による推論は `run*` で解を全列挙するため、同型の再帰関数が
並ぶ入力(`comp-test.scm`)で組合せ爆発を起こし、CPU 時間 4 時間を超えても停止しなかった。
algorithm W に基づく推論を新規に実装し、`derive-type` と同じ引数・戻り値で差し替えた。
既定を HM とし、従来の関係論理版は環境変数 `SCM2CPP_RELATIONAL=1` で選ぶ。

実装上の要点:
- 型変数は `HMVarN`。残ったものは既存の慣習に合わせ `Unknown-Type` 記号へ写し、
  `unknown-type-list` に載せてテンプレート型引数として出力させる。
- 数値型は単一化の際に C++ の算術変換と同じく広い方へ寄せる。型変数が既に数値へ
  束縛されている場合も、より広い数値と出会えば張り替える。
- 推論を 3 回繰り返す。単一化は単調なので、後方の呼び出し地点の情報が前方へ伝播して
  収束する。`(square x)` の `x` が後の `(square guess)` から double と判明する場合に効く。
- 生成側は関数引数や局所変数の型も環境から引くため、束縛はすべて記録して出力する。

### 18. 関数の前方宣言をまとめて出力
定義順に依存して呼び出せない問題(`factorial` が後方の `fact_iter` を呼ぶ)があった。
テンプレートの有無にかかわらず前方宣言を集約し、include の直後に出す。

### 19. リスト対応
`(list 1 2 3)` が `list(1,2,3)` という未定義の識別子になっていた。生成規則を追加し
`std::list<int>{1,2,3}` を出す。std::vector ではなく std::list にするのは、
`uniform_sequence_to_boost_ptr_sequence_view` が vector を ptr_vector に写し
push_front が無いため cons が通らないから。list なら ptr_list になり README の
「cons(T, std::list<T>) は boost::ptr_list<T> になる」という設計どおりに動く。
あわせて実行時側に const 参照版の `car` を追加(一時オブジェクトを受けるため。
戻り値型は ptr_list で value_type が T* になるので iterator::value_type を使う)、
`list-ref` を `scm2cpp::list_ref` に対応づけた。

### 20. 遅延ストリームの名前付き再帰型(`scm2cpp.hpp` と `type-infer-hm.scm`)
`(cons a (delay b))` の型は自分自身を含むため、構造的に扱うと無限型になり
出現検査で弾かれていた(2011年の `test-cpp-code/stream-ideal.hpp` でも `decltype` で
自分の戻り値型を求めようとして書けずに中断している)。
実行時側に `std::function` で再帰を型消去した `stream_cell<T>` と `make_stream` を追加し、
推論側では `(scm2cpp-stream 要素型)` という 1 引数の型構成子として扱う。
単一化は要素型の照合だけで 1 段で終わり、無限展開が起きない。

この結果、型推論は完全に成功するようになった:
  integers-starting-from : (Int) -> (scm2cpp-stream Int)
  stream-car : ((scm2cpp-stream Int)) -> Int
  stream-cdr : ((scm2cpp-stream Int)) -> (scm2cpp-stream Int)
未解決の型変数はゼロ。生成される署名も `scm2cpp::stream_cell<int>` になる。
型構成子名を `stream` ではなく `scm2cpp-stream` にしたのは、`stream` という名前の
変数と衝突して `sarg->cpptype` の `(member e t)` が誤判定するため。

目標とする出力形は `ideal/stream-ideal-new.cpp` に手書きしてあり、コンパイル・実行
できる(11 を出力)。2011年に解けなかった形が名前付き再帰型で書けることの確認。

### 21. 無名ラムダでの構造体名衝突回避の修正
14 で入れた衝突回避が `lambda-obj-name` が `#f` の無名ラムダを考慮しておらず、
`symbol->string` で落ちていた。

### 22. 遅延ストリームのコード生成
`(cons a (delay b))` の遅延部分がクロージャ構造体を経由し、構造体の定義と呼び出しで
引数の数が食い違ってコンパイルできなかった。`scm2cpp::make_stream(a, [=](){ return b; })`
という C++11 のラムダを直接出すようにした。

規則の置き場所が要点だった。alpha 変換で無名ラムダは `(let ((L (lambda () ...))) L)` に
包まれるため、その形も受ける。さらに `cexp` の match の**先頭**に置く必要がある。
`cexp-with-local-analysis` や関数名対応表(`cpp-function-name-correspond-alist`)の節が
先に一致してしまい、後ろに置いても発火しなかった。

### 23. make-promise / delay の型
`(make-promise f)` の型が未知で `Unknown_type...Type` が宣言に漏れていた。
`make-promise` は引数の型をそのまま返す(C++ 側では `boost::function` に収まる)。

### 24. 並列化オプション `-P`(`scm2cpp-file.scm` と `scm2cpp-match.scm`)
名前付き let が素の for ループになったことで、ループが指示文を置ける場所になった。
`-P omp` / `-P gpu` / `-P acc` で最外の do ループの直前に指示文を出す。内側には
出さない(全段に付けると過剰な並列化になる)。GPU 指定時は配列生成を boost から
素の配列に切り替える(Boost はデバイス向けにコンパイルできない)。

実測(積分画像 素朴版 O(n^4), n=200): 逐次    s -> OpenMP 20コア    s(   倍)。
GPU    s。
【計測値は未確定。条件を揃えて計測しなおしたうえで記入すること。】
なお `scm2cpp.hpp` をデバイス向けにコンパイルできず、GPU 経路では include を
外す必要があった。GPU 用の最小ランタイム分離が今後の前提。コンパイルには
`-fcf-protection=none -fno-stack-protector` が要る。

### 25. Thrust への変換 `-P thrust`
指示文は逐次依存のあるループ(prefix-sum など)を並列化できない。do ループの形を
見て、累算を配列に書き戻す形は `thrust::inclusive_scan`、累算のみは `thrust::reduce`
に置き換える。該当しない形は通常の for ループに落ちるので既存動作は不変。
配列は `thrust::device_vector` にする。

実測: 1000万要素の inclusive scan は Thrust    ms 対 逐次    ms(   倍)。
【計測値は未確定。条件を揃えて計測しなおしたうえで記入すること。】
要素数を大きくすると通常経路は `boost::array<int,N>` がスタック上に載るため
実行できないのに対し、Thrust 経路は完走する。既定の配列生成も `std::vector` に
すべきという課題が判明した。

## 結果

回帰テスト: 変更前 PASS 6 / FAIL 5 → 変更後 PASS 7 / FAIL 4。
SICP sqrt が変換・コンパイル・実行まで通り、数値も Racket と一致する。

## 残っている問題

- `delay-test` と `stream-test`: `sexp->cpptype` で対・引用シンボルの型が扱えない。
  ランタイム側(`scm2cpp.hpp`)には cons/car/cdr があるので型側の配線のみ不足。
- `comp-test` と `def-def`: 型推論(cKanren の単一化)が終わらずタイムアウトする。
  機能ではなく性能の問題。`type-infer-match.scm` 系への切り替えが回避策になりうる。
- 大域変数の定義が `.cpp` に、関数本体が `.hpp` に出るため宣言順序が逆転する
  (FFT で手修正が必要だった)。宣言を `.hpp`、定義を `.cpp` に分けるのが本来の形。
- 値を返す名前付き let はまだクロージャ構造体になる。
