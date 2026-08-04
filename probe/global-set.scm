(define seed 12345)
(define (next-rand)
  ;; Small constants on purpose: Scheme integers are unbounded, C++ ints are
  ;; not, so a multiplier that overflows 32 bits would make the translation
  ;; disagree with the source. 75*65536 stays well inside the range.
  (set! seed (remainder (+ (* seed 75) 74) 65537))
  seed)
(define (main) (display (next-rand)) (newline) 0)
