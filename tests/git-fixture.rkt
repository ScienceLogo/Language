#lang racket/base

(require racket/system)

(provide with-git-fixture)

;; The package-build service does not provide Git. Keep each fixture's cleanup
;; and all surrounding tests active when its external tool is unavailable.
(define (with-git-fixture before body after)
  (dynamic-wind
    before
    (lambda ()
      (if (find-executable-path "git")
          (body)
          (displayln "Skipping Git integration fixture: git is not available on PATH.")))
    after))
