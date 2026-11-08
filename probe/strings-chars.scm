;; Characters, strings and conversions: string-length, string-ref,
;; substring, string=?, string<?, string-append, string-upcase,
;; char->integer, char-upcase, char-alphabetic?, number->string and
;; string->number, over char and std::string (scm2cpp.hpp's
;; string_length and the rest).  A parameter seen only through one of
;; them is given the type the C++ signature takes.  Strings are values
;; here (a function receives a copy), so string-set! is not provided.
(define (count-alpha s)
  (let ((n 0))
    (do ((i 0 (+ i 1))) ((= i (string-length s)))
      (when (char-alphabetic? (string-ref s i)) (set! n (+ n 1))))
    n))

(define (shift-char c k)
  (if (char-alphabetic? c)
      (integer->char (+ 97 (remainder (+ (- (char->integer (char-downcase c)) 97) k) 26)))
      c))

(define (main)
  (let ((s "Hello, Scheme 42"))
    (display (string-length s)) (newline)
    (display (count-alpha s)) (newline)
    (display (string-ref s 7)) (display (char-upcase (string-ref s 8))) (newline)
    (display (substring s 7 13)) (newline)
    (display (string=? "Scheme" (substring s 7 13))) (display " ") (display (string<? "abc" "abd")) (newline)
    (display (string-upcase (substring s 0 5))) (newline)
    (display (string-append "n=" (number->string 7) " half=" (number->string (/ (string->number "21") 2.0))))
    (newline)
    (display (char->integer #\A)) (display (shift-char #\Y 3)) (display (shift-char #\, 3)) (newline)
    0))
