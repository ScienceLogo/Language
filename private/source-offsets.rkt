#lang racket/base

(provide make-character-offset)

;; A string port's file position counts UTF-8 bytes. Its source position
;; counts characters but treats CRLF as one position. Neither can directly
;; index source text. Map byte boundaries to actual string character indices.
(define (make-character-offset text input)
  (define byte-count (for/sum ([c (in-string text)]) (char-utf-8-length c)))
  (define offsets (make-vector (add1 byte-count) #f))
  (for/fold ([byte 0]) ([c (in-string text)] [index (in-naturals)])
    (vector-set! offsets byte index)
    (+ byte (char-utf-8-length c)))
  (vector-set! offsets byte-count (string-length text))
  (lambda () (vector-ref offsets (file-position input))))
