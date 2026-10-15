;;;; DBSCAN by brute-force neighbourhoods, the products as matrix
;;;; multiplications: scikit-learn's DBSCAN(algorithm="brute") on the
;;;; Euclidean metric, with the same labels, and no neighbourhood ever
;;;; stored.
;;;;
;;;; Points i and j are neighbours when |x_i|^2 + |x_j|^2 - 2 x_i.x_j
;;;; <= EPS^2 -- the squared distance as scikit-learn's brute search
;;;; computes it -- and every point is its own neighbour; the test is
;;;; kept as x_i.x_j - h_j >= h_i - EPS^2/2 with h = |x|^2/2, a
;;;; comparison against a constant per row that the compiler vectorises.  The dot
;;;; products come a BS x BC tile at a time, (matmul xb (transpose xc)),
;;;; the one product --blas and --cublas hand to a gemm; the tile is
;;;; small enough to stay in cache while the test reads it (a tile as
;;;; wide as all n points goes out to memory and back, and the product
;;;; then costs most of the time).  Three passes over row blocks:
;;;;
;;;;   1  every point: its neighbour count; a point with at least
;;;;      MINPTS is a core point;
;;;;   2  the core points: core neighbours are joined in a union-find
;;;;      whose root is always the smaller index, so a component's root
;;;;      is its smallest core point;
;;;;   3  the other points: each takes the component with the smallest
;;;;      root among its core neighbours, or none (noise, -1).
;;;;
;;;; Components are numbered by their roots in increasing order.  This
;;;; is scikit-learn's labelling: dbscan_inner starts a cluster at each
;;;; unlabelled core point in index order and expands it completely
;;;; before the next, so cluster k is the component of the k-th smallest
;;;; root, and a border point reached from several clusters keeps the
;;;; first, the one with the smallest root.
;;;;
;;;; X is n rows of p (x[i*p+j]).  LABELS gets the cluster of each point
;;;; (-1 for noise) and CORE 1.0 for the core points.  Returns the
;;;; number of clusters.  BS and BC are the tile's rows and columns.
;;;;
;;;;[ja] 総当たりの近傍で DBSCAN(内積は行列積)。scikit-learn の
;;;;[ja] DBSCAN(algorithm="brute")、ユークリッド距離と同じラベルを、近傍の
;;;;[ja] リストを持たずに出す。距離の 2 乗 |x_i|^2 + |x_j|^2 - 2 x_i.x_j <= EPS^2 で
;;;;[ja] 近傍(自分自身も含む)。内積は BS 行ずつの行列積(--blas / --cublas で
;;;;[ja] gemm)。3 回の区画の走査: 1 全点の近傍数(MINPTS 以上が core)、2 core
;;;;[ja] 点どうしを union-find(根は常に小さい番号 = 成分の最小 core 点)、3 残りの
;;;;[ja] 点は近傍の core 点の成分のうち根が最小のものに入る(なければ -1)。成分は
;;;;[ja] 根の小さい順に番号を振る。これは scikit-learn の dbscan_inner の番号付けと
;;;;[ja] 同じ(番号順に core 点からクラスタを作り、作り終えてから次へ進むので、
;;;;[ja] 境界点は根が最小のクラスタに入る)。

;; the rows ROWS[s0 .. s0+M) gathered into XB (BS rows, the ones past M
;; zero)
(define (gather-rows x xb rows s0 m bs p)
  (do ((r 0 (+ r 1))) ((= r bs))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! xb (+ (* r p) j)
                   (if (< r m)
                       (vector-ref x (+ (* (vector-ref rows (+ s0 r)) p) j))
                       0.0))))
  0)

;; tile[r, c] = xb[r] . x[c0 + c] for the MC points from C0 (the columns
;; past MC zero): one product, BS by BC, small enough to stay in cache
;; while the test reads it
(define (col-tile x xb xc tile c0 mc bs bc n p)
  (with-arrays ((xb (bs p)) (xc (bc p)) (tile (bs bc)))
    (do ((c 0 (+ c 1))) ((= c bc))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! xc (+ (* c p) j)
                     (if (< c mc) (vector-ref x (+ (* (+ c0 c) p) j)) 0.0))))
    (array-set! tile (matmul xb (transpose xc)))
    0))

;; the root of I, halving the path on the way
(define (uf-find parent i)
  (let ((r i))
    (do () ((= (vector-ref parent r) r))
      (vector-set! parent r (vector-ref parent (vector-ref parent r)))
      (set! r (vector-ref parent r)))
    r))

(define (dbscan x labels core eps minpts bs bc n p)
  (let ((h (make-vector n 0.0))
        (count (make-vector n 0))
        (parent (make-vector n 0))
        (best (make-vector n 0))
        (rows (make-vector n 0))
        (id (make-vector n 0))
        (xb (make-vector (* bs p) 0.0))
        (xc (make-vector (* bc p) 0.0))
        (tile (make-vector (* bs bc) 0.0))
        (half (* 0.5 (* eps eps)))
        (nrows 0)
        (nclusters 0))
    ;; h = |x|^2 / 2: i and j are neighbours when x_i.x_j - h_j >= h_i - eps^2/2
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((acc 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (set! acc (+ acc (* (vector-ref x (+ (* i p) j)) (vector-ref x (+ (* i p) j))))))
        (vector-set! h i (* 0.5 acc)))
      (vector-set! parent i i)
      (vector-set! best i n)
      (vector-set! rows i i))
    ;; pass 1: neighbour counts, every point
    (do ((s0 0 (+ s0 bs))) ((>= s0 n))
      (let ((m (if (< (+ s0 bs) n) bs (- n s0))))
        (gather-rows x xb rows s0 m bs p)
        (do ((c0 0 (+ c0 bc))) ((>= c0 n))
          (let ((mc (if (< (+ c0 bc) n) bc (- n c0))))
            (col-tile x xb xc tile c0 mc bs bc n p)
            (do ((r 0 (+ r 1))) ((= r m))
              (let ((i (vector-ref rows (+ s0 r))) (c 0))
                (let ((ci (- (vector-ref h i) half)))
                  (do ((t 0 (+ t 1))) ((= t mc))
                    (set! c (+ c (if (>= (- (vector-ref tile (+ (* r bc) t)) (vector-ref h (+ c0 t))) ci) 1 0)))))
                (vector-set! count i (+ (vector-ref count i) c))))))))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! core i (if (>= (vector-ref count i) minpts) 1.0 0.0)))
    ;; pass 2: the core points, joined
    (set! nrows 0)
    (do ((i 0 (+ i 1))) ((= i n))
      (if (= (vector-ref core i) 1.0)
          (begin (vector-set! rows nrows i) (set! nrows (+ nrows 1)))
          0))
    (do ((s0 0 (+ s0 bs))) ((>= s0 nrows))
      (let ((m (if (< (+ s0 bs) nrows) bs (- nrows s0))))
        (gather-rows x xb rows s0 m bs p)
        (do ((c0 0 (+ c0 bc))) ((>= c0 n))
          (let ((mc (if (< (+ c0 bc) n) bc (- n c0))))
            (col-tile x xb xc tile c0 mc bs bc n p)
            (do ((r 0 (+ r 1))) ((= r m))
              (let ((i (vector-ref rows (+ s0 r))))
                ;; RI tracks the root of i's component as the row joins
                ;; it: one find per neighbour, the smaller root kept
                (let ((ri (uf-find parent i))
                      (ci (- (vector-ref h i) half)))
                  (do ((t 0 (+ t 1))) ((= t mc))
                    (let ((j (+ c0 t)))
                      (if (and (= (vector-ref core j) 1.0)
                               (>= (- (vector-ref tile (+ (* r bc) t)) (vector-ref h j)) ci))
                          (let ((rj (uf-find parent j)))
                            (if (< ri rj)
                                (vector-set! parent rj ri)
                                (if (< rj ri)
                                    (begin (vector-set! parent ri rj) (set! ri rj))
                                    0)))
                          0))))))))))
    ;; the clusters, numbered by their roots in increasing order
    (do ((i 0 (+ i 1))) ((= i n))
      (if (and (= (vector-ref core i) 1.0) (= (uf-find parent i) i))
          (begin (vector-set! id i nclusters) (set! nclusters (+ nclusters 1)))
          0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! labels i (if (= (vector-ref core i) 1.0)
                                (* 1.0 (vector-ref id (uf-find parent i)))
                                -1.0)))
    ;; pass 3: the other points, to the cluster with the smallest root
    ;; among their core neighbours
    (set! nrows 0)
    (do ((i 0 (+ i 1))) ((= i n))
      (if (= (vector-ref core i) 0.0)
          (begin (vector-set! rows nrows i) (set! nrows (+ nrows 1)))
          0))
    (do ((s0 0 (+ s0 bs))) ((>= s0 nrows))
      (let ((m (if (< (+ s0 bs) nrows) bs (- nrows s0))))
        (gather-rows x xb rows s0 m bs p)
        (do ((c0 0 (+ c0 bc))) ((>= c0 n))
          (let ((mc (if (< (+ c0 bc) n) bc (- n c0))))
            (col-tile x xb xc tile c0 mc bs bc n p)
            (do ((r 0 (+ r 1))) ((= r m))
              (let ((i (vector-ref rows (+ s0 r))))
                (let ((ci (- (vector-ref h i) half)))
                  (do ((t 0 (+ t 1))) ((= t mc))
                    (let ((j (+ c0 t)))
                      (if (and (= (vector-ref core j) 1.0)
                               (>= (- (vector-ref tile (+ (* r bc) t)) (vector-ref h j)) ci))
                          (let ((rj (uf-find parent j)))
                            (if (< rj (vector-ref best i)) (vector-set! best i rj) 0))
                          0))))))))))
    (do ((i 0 (+ i 1))) ((= i n))
      (if (and (= (vector-ref core i) 0.0) (< (vector-ref best i) n))
          (vector-set! labels i (* 1.0 (vector-ref id (vector-ref best i))))
          0))
    nclusters))
