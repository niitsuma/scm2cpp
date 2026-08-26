;; Sliding-window minimum and maximum in O(n) per window, by the
;; monotone deque.  A window's minimum changes only when an element
;; enters that is smaller than something remembered, or when the
;; remembered minimum falls out of the window; the deque Q keeps the
;; indices of elements that could still matter, in increasing order of
;; value, so the front is always the answer.  Each index enters Q once
;; and leaves once, which is where O(n) comes from -- against the
;; O(n w) of re-scanning every window.
;;
;; Q is an integer scratch of N entries.  OUT receives the N - W + 1
;; complete windows: OUT[i] is the statistic over X[i .. i+W-1].  The
;; caller pads the incomplete head if it wants pandas' shape.  The
;; inner pop loop is written as a flag-driven do so that the generated
;; C++ is a loop, not a recursion: the amortized bound survives any
;; spelling, but a hundred-thousand-deep call stack would not.

(define (rolling-min x q out n w)
  (let ((head 0) (tail 0))
    (do ((i 0 (+ i 1)))
        ((= i n))
      (let ((xi (vector-ref x i))
            (run 1))
        (do ((z 0 0))
            ((= run 0))
          (if (> tail head)
              (if (>= (vector-ref x (vector-ref q (- tail 1))) xi)
                  (set! tail (- tail 1))
                  (set! run 0))
              (set! run 0)))
        (vector-set! q tail i)
        (set! tail (+ tail 1))
        (if (<= (vector-ref q head) (- i w))
            (set! head (+ head 1))
            0)
        (if (>= i (- w 1))
            (vector-set! out (- i (- w 1))
                         (vector-ref x (vector-ref q head)))
            0))))
  0)

(define (rolling-max x q out n w)
  (let ((head 0) (tail 0))
    (do ((i 0 (+ i 1)))
        ((= i n))
      (let ((xi (vector-ref x i))
            (run 1))
        (do ((z 0 0))
            ((= run 0))
          (if (> tail head)
              (if (<= (vector-ref x (vector-ref q (- tail 1))) xi)
                  (set! tail (- tail 1))
                  (set! run 0))
              (set! run 0)))
        (vector-set! q tail i)
        (set! tail (+ tail 1))
        (if (<= (vector-ref q head) (- i w))
            (set! head (+ head 1))
            0)
        (if (>= i (- w 1))
            (vector-set! out (- i (- w 1))
                         (vector-ref x (vector-ref q head)))
            0))))
  0)
