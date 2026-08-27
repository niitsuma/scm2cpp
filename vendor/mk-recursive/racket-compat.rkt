#lang racket

;;(provide exists list-sort remp my-sort datum->string  call-with-string-output-port find)
(provide (all-defined-out))

(require racket/port)

(define (remp p ls) (filter (compose not p) ls))

(define (my-sort comp ls)
  (sort ls comp))

;(define datum->string ~a)
(define (datum->string x) (format "~a" x))


;;;http://www.scheme.com/csug7/control.html#./control:s6

(define (exists proc list1 ) ;;list2 ...
  (for/or ((i list1))
  (proc i)))

;;;http://www.scheme.com/tspl4/objects.html#./objects:s62
(define (list-sort predicate lst)
  (sort lst predicate)
  )


;;rnrs/io/ports-6
;;;;;http://www.scheme.com/tspl4/io.html#./io:s39
(define (call-with-string-output-port proc)
  (call-with-output-string proc)
  ;;(with-output-to-string proc)
  )


;;; http://www.scheme.com/csug7/objects.html
(define (find proc lst)
  (let ((l (filter proc lst)))
    (if (null? l)
	#f
	(car l)))
  )


;; http://www.scheme.com/tspl4/control.html#./control:s37
;;(for-all procedure list1 list2 ...)
(define (for-all procedure list1)
  (and (map procedure list1))
  )
