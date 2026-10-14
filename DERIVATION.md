# How DerivedLasso is derived

[Japanese](DERIVATION.ja.md)

`DerivedLasso` in the `scm2cpp-lasso` package runs C++ that nobody
wrote at the Gram level. The input is
[`examples/kernel-only/lasso-design.scm`][src], plain residual-form
coordinate descent: flat loops over X stored the numpy way (n rows of
p, `x[i*p+j]`), with no Gram matrix and no BLAS anywhere in it. The
translator produces the covariance (Gram) form itself, with
scikit-learn's `precompute='auto'` branch and three BLAS calls:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M --derive --cublas lasso_design.scm
derive: lasso-design: raise differencing merge matmul guard
```

This document goes through every rule on that log line in the order
it fires. For each rule it gives a link to the code and an
explanation of what the code does on this kernel. All links point to
commit [`1f9d710`][commit]. `python/scm2cpp-lasso/regenerate.sh` runs
the command above for the three committed variants (`--cublas`,
`--blas`, neither).

[commit]: https://github.com/niitsuma/scm2cpp/tree/1f9d710d4c5bb17797d8cd91eff2ad2569514290
[src]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/examples/kernel-only/lasso-design.scm

## 0. The order at a glance

| # | stage | rule | code | effect on lasso-design |
|---|---|---|---|---|
| 0 | entry | `--derive`, `--blas`/`--cublas` | [scm2cpp-file.scm L92-105][flags], [scm2cpp-match.scm L3178-3179][hook] | set `SCM2CPP_DERIVE` / `SCM2CPP_BLAS`; the source string goes through `derive-source-maybe`, then `lower-blas-maybe`, then macro expansion |
| 1 | setup | shapes and liveness | [derive-source-maybe][dsm], [find-with-arrays][fwa], [compute-param-liveness!][live] | `(with-arrays ((x (n p)) ..))` gives the shapes; `resid` is an output, so it will be restored |
| 2 | driver | **raise** (R1-R7) | [rewrite-raise.scm][raise] | `do` -> `range-for`, `x[i*p+j]` -> `(col x j)`, dot loop -> `(array-sum ..)`, residual loop -> `(array-dec! resid (scale d (col x j)))` |
| 3 | setup | scratch candidates | [scratch-candidates][sc] | the pair (`resid` . `beta`) |
| 4 | driver | **differencing** | [try-differencing][td] -> [incrementalize][inc] | memo `c = X'r`, Gram `G = X'X`, update `c -= d G[j,:]`, copy `b0 = beta`, restore `r -= X (beta - b0)` |
| 5 | driver | **merge** | [try-merge][tm] -> [table-subset-plan][tsp], [apply-table-merge][atm] | `xnorm[j]` reads become `G[j,j]`, and the `xnorm` fill is dropped |
| 6 | driver | (precompute, lower, contract, dead-fill) | [derive-fixpoint/log][dfl] | offered every round; none fires here, and a round where nothing fires is the fixpoint |
| 7 | post | **matmul** (fold to contractions) | [fold-matmul][fm] | the Gram, memo and restore nests each become one `(contract ..)` |
| 8 | post | **guard** | [guard-by-shape][gbs] | `(if (< p n) DERIVED ORIGINAL)` |
| 9 | lowering | contraction -> BLAS | [lower-contract][lc] | `blas-syrk!` (Gram), `blas-gemv!` (memo), `blas-gemv!` (restore) |
| 10 | emission | binding ops -> C++ | [cblas-binding.scm][cbind], [scm2cpp-blas.hpp][hpp] | `cblas_dsyrk`, `cblas_dgemv` (or the cuBLAS equivalents) |

Steps 2, 4, 5 and 6 are one fixpoint loop. The rest run once, in the
order given.

[flags]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-file.scm#L92-L105
[hook]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-match.scm#L3178-L3179
[dsm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-match.scm#L3102-L3130
[live]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-match.scm#L610-L664
[fwa]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L93-L104
[sc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L63-L86
[raise]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L47-L235
[td]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L72-L99
[inc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L268-L580
[tm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L112-L139
[tsp]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-precompute.scm#L177-L198
[atm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-precompute.scm#L203-L217
[dfl]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L267-L287
[fm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L139-L237
[gbs]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L290-L295
[lc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L175-L273
[cbind]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/bindings/cblas-binding.scm#L18-L37
[hpp]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-blas.hpp#L27-L63

## 1. The input

The part of `lasso-design.scm` that matters, with the comments
removed:

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
  (do ((l 0 (+ l 1))) ((= l nlam))                      ; the path
    ... (do ((j 0 (+ j 1))) ((= j p))                   ; one sweep
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

The `with-arrays` form is the only thing the author adds for the
derivation. In the plain translation it changes nothing. For
`--derive` it says that `x` is an nxp matrix, so `x[i*p+j]` can be
read as element (i, j).

## 2. Entry and setup

**Flags** ([scm2cpp-file.scm L92-105][flags]). `--derive` sets
`SCM2CPP_DERIVE=1`, and `--blas` / `--cublas` set `SCM2CPP_BLAS`.
[`scm2cpp-match-list`][hook] runs
`(lower-blas-maybe (derive-source-maybe src))` on the source string
before macro expansion. Both passes must run that early, because
`with-arrays` and the algebra forms are gone once the macros expand.

**`derive-source-maybe`** ([scm2cpp-match.scm L3102-3130][dsm]). It
reads the forms. It expands a throwaway copy and runs
[`compute-param-liveness!`][live] on it to learn which parameters a
caller can observe. It then calls `derive-forms`
([rewrite-derive.scm L302-315][dfo]) on the forms as read and prints
the `derive: f: ...` line on stderr. Here `resid` is written and is a
parameter, so it is an output and its contents must be correct at the
end. That decision is what produces the restore step in section 4.

**`derive-body`** ([rewrite-derive.scm L242-265][db]) is the
per-function driver. It finds the first `with-arrays`
([`find-with-arrays`][fwa]) and splits the declarations into dims
(rank >= 2: `x (n p)`, `betas (nlam p)`) and extents (rank 1). It
raises the body once to find candidates. Then, for each candidate
pair, it runs the fixpoint and keeps the first one where something
other than `raise` fired. Finally it folds the products (section 7) and
guards the result (section 8).

[dfo]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L302-L315
[db]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L242-L265

## 3. raise: from loops to the array algebra

[rewrite-raise.scm][raise]. Each rule is the inverse of an expansion
that the array macros perform. A rule fires only where that expansion
is exactly what the code contains, so the raised program expands back
to the same loops in the same order, bit for bit. The rules apply
bottom-up until nothing changes ([`raise-loops`, L230-235][rl]).

| rule | code | pattern -> result | on lasso-design |
|---|---|---|---|
| R1 | [L70-72][r1] | `(do ((i 0 (+ i 1))) ((= i N)) body)` -> `(range-for (i N) body)` | every counting loop |
| R2 | [L74-97][r2] | `(vector-ref a (+ (* w N) i))` -> `(array-ref a w i)` when N is a's declared row width; at rank >= 3 it splits again against the next axis | `x[i*p+j]` -> `(array-ref x i j)`, `betas[l*p+j]` -> `(array-set! betas l j ..)` |
| R3 | [L100-111][r3] | `(range-for (i N) (set! acc (+ acc term)))` -> `(set! acc (+ acc (array-sum V)))`, with V the element view of term | the norm loop and the `rho` loop |
| R4 | [L113-194][r4] | `(range-for (i N) (vector-set! a i (- (vector-ref a i) t)))` -> `(array-dec! a V)`; the `+` form gives `array-inc!`; row and column shapes for matrix scratches | the residual update |
| R5 | [L198-208][r5] | `(let ((acc 0.0)) (set! acc (+ acc S)) ..)` -> `(let ((acc S)) ..)` | `xnorm`'s accumulator; `rho`'s seed |
| R6 | [L210-216][r6] | a let binding read once by the fill it wraps is substituted in | `xnorm[j] = (array-sum ..)` |
| R7 | [L218-221][r7] | a slice covering a vector's whole declared extent -> the vector | `(slice resid 0 n)` -> `resid` |

The element-to-view step that R3 and R4 rely on is
[`elem->vexpr`][e2v] (rewrite-normalize.scm L88-114). It turns an
element expression in the loop index i into a whole-vector
expression. An `(array-ref x i j)` whose *first* index is i and whose
other indices do not move becomes the column view `(col x j)` (the
[L103-105][e2vcol] clause). An `(array-ref v js.. i)` becomes
`(row v js..)`. A scalar factor becomes `(scale s ..)`. Because X is
stored n rows of p, the dot product walks a column:

```scheme
(let ((rho (array-sum (* (col x j) resid))) (old (vector-ref beta j))) ...)
...
(array-dec! resid (scale (- bnew old) (col x j)))
```

[rl]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L230-L235
[r1]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L70-L72
[r2]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L74-L97
[r3]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L100-L111
[r4]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L113-L194
[r5]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L198-L208
[r6]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L210-L216
[r7]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-raise.scm#L218-L221
[e2v]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-normalize.scm#L88-L114
[e2vcol]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-normalize.scm#L103-L105

**Scratch candidates** ([`scratch-candidates`, rewrite-derive.scm
L63-86][sc]). On the raised body, a *scratch* is the target of an
update by a scaled view, `(array-dec! V (scale _ (col X J)))`. Its
partner is a vector written at the same coordinate J,
`(vector-set! B J _)`. Here that gives the single pair
(`resid` . `beta`). Nothing names the residual or the coefficients
for the translator; they are read off the code's shape.

## 4. differencing: the memo and the Gram

[`try-differencing`][td] (rewrite-driver.scm L72-99) offers each
sweep-shaped statement (a `range-for` or `do` at the head, entering
`let` and `begin` bodies) to [`incrementalize`][inc]
(rewrite-incremental.scm L268-580) and keeps the first that it
accepts. It also decides the restore: an output scratch is always
restored, and a local one is restored only if a later statement reads
it. This is finite differencing (Paige and Koenig) over the array
algebra. Nothing in it matches a dot product.

**Contexts: growing outward from the scratch.**
[`maximal-contexts`][mc] (L197-218) starts at each occurrence of
`resid` and grows the enclosing expression outward for as long as
[`admissible?`][adm] (L176-193) holds:

- *pure*: no writes (heads from `pure-heads`, L97-107);
- *linear*: [`degree`][deg] (L111-169) in `resid` is exactly 1, so
  `C[r - d u] = C[r] - d C[u]`;
- *invariant*: every other free variable is either untouched by the
  sweep or is a loop coordinate, which becomes an index of the memo.

On this kernel the growth stops at `(array-sum (* (col x j) resid))`.
The next enclosing form is the `let` binding of `rho`, and `old`,
which is rebound every iteration, cannot become a memo index. The
memo is therefore `c[j] = x_j . r`.

**Updates** (L282-305). `(array-dec! resid (scale (- bnew old) (col x j)))`
is recorded as `(site vec d x j () - col)`: a vector scratch,
coefficient `d = bnew - old`, direction `(col x j)`, decrement,
column view. An occurrence count (L321-343) checks that every
occurrence of `resid` is in a context or an update. If any is left
over, the rule refuses.

**What it emits** (L515-580), with `P = p`:

| piece | code | result on lasso-design |
|---|---|---|
| hole the coordinate, group families | [L360-380][holed] | one family `(array-sum (* (col x ?H0) resid))` |
| hoisted kernel: the context applied to the direction | [L525-534][gram] | `G[k1,k2] = (array-sum (* (col x k1) (col x k2)))`, i.e. `X'X` |
| memo build | [L536-546][memo] | `c[k] = (array-sum (* (col x k) resid))`, i.e. `X'r` |
| coefficient snapshot | [L547-551][b0] | `b0[k] = beta[k]` |
| reads -> memo reads | [L467-472][rd] | `rho` starts from `(array-ref c j)` |
| update -> memo update | [L478-512][upd] | `c[k2] -= G[j,k2] * (bnew - old)` for k2 < p, O(p) instead of O(n) |
| symmetry | [L458-466][sym] | G is proven symmetric from its own expression, so the update reads row j of G, which is contiguous, instead of column j |
| restore | [L571-578][rst] | `resid -= (beta[jj] - b0[jj]) * (col x jj)` over jj |

The scratch is no longer touched during the sweep. It is rebuilt once
at the end from how far the coefficients moved in total, which is why
`b0` is kept. The null-update guard `(if (not (= bnew old)) ..)` is in
the source and is carried through unchanged.

[mc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L197-L218
[adm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L176-L193
[deg]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L111-L169
[holed]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L360-L380
[gram]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L525-L534
[memo]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L536-L546
[b0]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L547-L551
[rd]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L467-L472
[upd]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L478-L512
[sym]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L458-L466
[rst]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-incremental.scm#L571-L578

## 5. merge: the column norms are the Gram diagonal

[`try-merge`][tm] (rewrite-driver.scm L112-139) collects every fill
`name[idx..] = expr` (`collect-fill-defs`), normalises each one for
comparison only (`defs3`), and asks [`table-subset-plan`][tsp]
(rewrite-precompute.scm L177-198) whether one table's definition is
another's at restricted indices. It tries every map from the big
table's indices onto the small one's:

```
xnorm[j]   = (array-sum (* (col x j)  (col x j)))
G[k1,k2]   = (array-sum (* (col x k1) (col x k2)))     with k1 -> j, k2 -> j
```

The plan is `((xnorm G ((k1 . j) (k2 . j))))`.
[`apply-table-merge`][atm] (L203-217) rewrites every
`(vector-ref xnorm j)` as `(array-ref G j j)`, and `drop-fills`
replaces the `xnorm` fill with `0`. The derived branch therefore no
longer computes the norms at all. The rule can only delete a table,
so it cannot loop.

## 6. The rest of the fixpoint

[`derive-fixpoint/log`][dfl] (rewrite-driver.scm L267-287) offers the
rules in a fixed order every round: raise, differencing, merge,
precompute ([L147-152][pc]), lower ([L215-252][lo]), contract-axis,
and dead-fill ([L256-258][df]). It stops after the first round in
which nothing fires. On lasso-design, the round after the merge fires
nothing:

- differencing does not fire again because its output is a `let`,
  which is never offered as a sweep;
- precompute finds no constant fold left inside a loop, because the
  Gram is already hoisted;
- dead-fill has nothing to collect, because `resid` is an output and
  the merged fill is already gone.

The log line therefore reads `raise differencing merge`.
(`try-precompute` is what hoists a Gram written by hand; on this
kernel differencing has already done it.)

[pc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L147-L152
[lo]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L215-L252
[df]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-driver.scm#L256-L258

## 7. matmul: three nests become three contractions

[`fold-matmul`][fm] (rewrite-derive.scm L139-237) is a single rule.
It peels a nest of single-statement `range-for`s ([`peel`, L158-162][peel]).
If what is inside is a dot product of two views, it becomes
`(contract (k) (i..) (a la..) (b lb..))`, numpy's einsum with every
index named on the axis it runs over.
[`labels`][lab] (L167-176) gives the axes: `(row a js..)` is
`(a js.. k)`, `(col a js..)` is `(a k js..)`, and a bare vector is
`(a k)`.

| nest (from section 4) | sub-rule | contraction |
|---|---|---|
| Gram: `G[k1,k2] = sum (col x k1)(col x k2)` | [`memo-fold` L182-191][mf] | `(array-set! G (contract (k) (k1 k2) (x k k1) (x k k2)))` |
| memo: `c[k] = sum (col x k) resid` | `memo-fold` | `(array-set! c (contract (k) (k') (x k k') (resid k)))` |
| restore: `resid -= sum_j (beta-b0)[j] (col x j)` | [`restore-fold` L194-217][rf] | `(array-dec! resid (contract (j) (i) ((- beta b0) j) (x i j)))` |

The memo update inside the sweep is a single `range-for` over a row
of G with no dot product in it, so it stays a loop. That is O(p) per
coordinate and is not worth a BLAS call. Under `--blas` the
algebra does not change; the products are only written at their real
rank so that the next pass can read off which call each one is.

[peel]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L158-L162
[lab]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L167-L176
[mf]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L182-L191
[rf]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L194-L217

## 8. guard: scikit-learn's precompute='auto', derived

[`guard-by-shape`][gbs] (rewrite-derive.scm L290-295), with
[`update-matrix`][um] (L270-279) supplying the matrix and view. The
differencing trades a scratch of length n for a memo of length p plus
a pxp Gram built once, which pays only when p < n. Both are run-time
values, so the derived body is guarded:

```scheme
(if (< p n) (begin DERIVED...) (begin ORIGINAL...))
```

Which declared extent counts as p depends on the view. A `col` of an
`(n p)` matrix is n long and there are p of them, so the test is
`(< p n)`. A `row` of a `(p n)` matrix gives the same test. When X is
wide, the sweep runs exactly as written. This is the rule that
`examples/kernel-only/lasso-auto.scm` writes by hand, and that
scikit-learn applies as `precompute='auto'`.

[um]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-derive.scm#L270-L279

The derived program after sections 3-8, abridged (gensym suffixes dropped):

```scheme
(if (< p n)
  (begin
    (range-for (i n) (vector-set! resid i (vector-ref y i)))
    0                                                   ; the xnorm fill, merged away
    (let ((b0 (make-vector p 0.0)) (g (make-vector (* p p) 0.0)) (c (make-vector p 0.0)))
      (with-arrays ((g (p p)) (c (p)) (b0 (p)))
        (array-set! g (contract (k) (k1 k2) (x k k1) (x k k2)))    ; G = X'X
        (array-set! c (contract (k) (k3) (x k k3) (resid k)))      ; c = X'r
        (range-for (k1 p) (vector-set! b0 k1 (vector-ref beta k1)))
        (range-for (l nlam) ...
          (range-for (j p)
            (let ((rho (array-ref c j)) (old (vector-ref beta j)))
              (set! rho (+ rho (* old (array-ref g j j))))
              (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n))) (array-ref g j j))))
                (vector-set! beta j bnew)
                (if (not (= bnew old))
                    (begin ...maxmove...
                      (range-for (k2 p) (array-dec! c k2 (* (array-ref g j k2) (- bnew old)))))
                    #f)))) ...)
        (array-dec! resid (contract (j) (i) ((- beta b0) j) (x i j)))   ; r -= X (beta - b0)
        0)))
  (begin ...the original loops, untouched...))
```

## 9. Contraction -> BLAS

`lower-blas-maybe` ([scm2cpp-match.scm][lbm]) loads
`bindings/cblas-binding.scm` or `bindings/cublas-binding.scm` and runs
[`lower-blas-forms`][lbf] (rewrite-blas.scm L95-). Each contraction
goes through [`lower-contract`][lc] (L175-273). `kpos` reports
whether the summed labels sit at the front or the back of each
operand's axis list. With row-major storage, front means the operand
is read transposed. The left operand is the one whose free labels
come first in y. Then:

| contraction | case | call |
|---|---|---|
| `(contract (k) (k1 k2) (x k k1) (x k k2))` | [the Gram, L243-247][syrk]: same name on both sides, summed label in the same place | `(blas-syrk! g x 1.0 0.0 1 p n)` |
| `(contract (k) (k3) (x k k3) (resid k))` | [vector on the right, L259-265][gemv]: x is the left operand, summed label in front | `(blas-gemv! c x resid 1.0 0.0 1 p n)` |
| `(array-dec! resid (contract (j) (i) ((- beta b0) j) (x i j)))` | [vector on the left, L248-258][gemvl]: `beta - b0` is materialised into a temporary `d`; alpha -1 and beta 1 from `array-dec!` | `(blas-gemv! resid x d -1.0 1.0 0 n p)` |

No product shape has code of its own: the transposition flags come
only from where the summed labels sit. Under `--cublas`, `x` is only
read in its scope, so [`operand`][opd] uploads it once at scope entry
(`dmat-upload`), and vectors stay on the host.

[lbm]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/scm2cpp-match.scm#L3141-L3156
[lbf]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L95-L301
[syrk]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L243-L247
[gemv]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L259-L265
[gemvl]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L248-L258
[opd]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/rewrite-blas.scm#L150-L159

## 10. Emission

The BLAS ops are ordinary custom-binding operations
([cblas-binding.scm L18-37][cbind]): a signature, a C++ format string,
`(mutates 0)` and a header. Type inference, the mutation summaries and
the emitter treat them like any other declared op. Each one also
carries a Racket model that `binding-check.rkt` compares against the
real C++. The calls land in [scm2cpp-blas.hpp][hpp]:
`blas_syrk` is `cblas_dsyrk` on the upper triangle plus a mirror
loop, and `blas_gemv` is `cblas_dgemv` with the transposition chosen
by `ta`. `scm2cpp-cublas.hpp` is the device version.

Without `--blas`, the same contractions are expanded by
[array-macros.scm L418-482][amc] into loop nests (the Gram as the
upper triangle plus its mirror). That is the `derived_loops` variant
of the package.

[amc]: https://github.com/niitsuma/scm2cpp/blob/1f9d710d4c5bb17797d8cd91eff2ad2569514290/array-macros.scm#L418-L482

## 11. How it is checked

- `run-tests.sh` translates `probe/derive-lasso-design.scm` plainly,
  with `--derive`, with `--derive --blas` and (with a device) with
  `--derive --cublas`, and compares all of them against the same
  oracle output. The test data is dyadic, so every variant prints
  identical digits.
- `test-raise.rkt` checks the same rules on the sibling kernels:
  `lasso-kernel.scm` (X stored p rows of n, row view) and
  `probe/derive-lasso-col.scm` (the column view, as here). For each it
  checks the firing log, the `(< p n)` guard, and
  that the Gram, the memo and the restore are contractions.
- `python/scm2cpp-lasso/check-derived.py` compares `DerivedLasso`
  against `CovLasso` and scikit-learn to 1e-8 on a tall and a wide
  design.

To see each stage yourself: `racket scm2cpp-file.scm -t scm2c.typ -S
--derive --blas lasso_design.scm` writes `lasso_design.expanded.scm`
(the program just before C++), and the stderr line is the firing log.
