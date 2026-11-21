;;; source.lisp --- records one skill the manifest does not declare.

(defpackage :definition-lode-bad (:use :common-lisp))
(in-package :definition-lode-bad)

(autolith-asdf:defskill "sneaky" "Not declared." "Fails the load.")