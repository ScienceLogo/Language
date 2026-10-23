#lang racket/base

(require rackunit racket/file racket/string "../scribblings/citation-data.rkt")

(define metadata
  (string-append
   "cff-version: 1.2.0\nmessage: Cite this example.\ntype: software\n"
   "title: >-\n  A readable language\n  for workflows\n"
   "authors:\n  - given-names: John\n    family-names: Example\n"
   "    orcid: https://orcid.org/0000-0000-0000-0000\n"
   "  - name: Example contributors\n"
   "repository-code: https://example.org/project\nlicense: MIT\n"
   "# Add a DOI after archival: doi: 10.1234/comment-only\n"))

(define (from-text text)
  (define file (make-temporary-file "sciencelogo-citation~a.cff"))
  (dynamic-wind
    (lambda () (display-to-file text file #:exists 'truncate))
    (lambda () (read-citation file))
    (lambda () (delete-file file))))

(module+ test
  (define unpublished (from-text metadata))
  (check-false (citation-doi-url unpublished))
  (check-equal? (citation-text unpublished)
                (string-append "John Example; Example contributors. "
                               "A readable language for workflows [Software]. https://example.org/project"))
  (check-equal? (citation-author-name (car (hash-ref unpublished "authors"))) "John Example")
  (check-false (string-contains? (citation-text unpublished) "comment-only"))
  ;; A DOI and release fields added to the same metadata become the citation;
  ;; no copy in the manual needs to be edited. Bare YAML dates are supported.
  (define released
    (from-text (string-append metadata "doi: 10.1234/example\nversion: \"1.2.0\"\ndate-released: 2026-10-23\n")))
  (check-equal? (citation-doi-url released) "https://doi.org/10.1234/example")
  (check-equal? (citation-text released)
                (string-append "John Example; Example contributors. (2026). "
                               "A readable language for workflows (version 1.2.0) [Software]. "
                               "https://doi.org/10.1234/example"))
  (define quoted-date
    (from-text (string-append metadata "doi: https://doi.org/10.1234/example\ndate-released: \"2026-10-23\"\n")))
  (check-equal? (citation-doi-url quoted-date) "https://doi.org/10.1234/example")
  (check-true (string-contains? (citation-text quoted-date) "(2026)."))
  (check-false (string-contains? (citation-text quoted-date) "(version")))
