#lang info

(define collection "sciencelogo")
(define version "0.1")
(define deps '("base"))
(define build-deps '("rackunit-lib" "scribble-lib" "net-lib" "yaml"))
(define scribblings '(("scribblings/sciencelogo.scrbl" (multi-page))))
(define source-omit-files '(".agents" ".aws" ".codex"))
(define license 'MIT)
