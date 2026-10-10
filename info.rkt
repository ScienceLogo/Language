#lang info

(define collection "sciencelogo")
(define deps '("base"))
(define build-deps '("rackunit-lib" "scribble-lib"))
(define scribblings '(("scribblings/sciencelogo.scrbl" (multi-page))))
(define source-omit-files '(".agents" ".aws" ".codex"))
(define license 'MIT)
