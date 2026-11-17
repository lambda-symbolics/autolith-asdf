;;;; package.lisp --- package definition for autolith-asdf.

(defpackage :autolith-asdf
  (:use :common-lisp)
  (:export
   ;; The lode system class and its schema slots.
   #:system
   #:activation
   #:capabilities
   #:activation-depends-on
   #:dependencies
   ;; Parsed dependency records and their accessors.
   #:dependency
   #:dependency-name
   #:dependency-form
   #:dependency-manifest
   #:dependency-min-version
   #:dependency-source-kind
   #:dependency-location
   #:dependency-ref
   #:dependency-pin
   #:ref
   #:ref-kind
   #:ref-designator
   #:pin
   #:pin-kind
   #:pin-value
   ;; Definition-time shape errors.
   #:shape-error
   #:shape-error-form
   #:shape-error-reason))
