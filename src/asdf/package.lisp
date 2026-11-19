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
     ;; Recorded lode definitions and their accessors.
     #:definition
     #:definition-lode
     #:definition-name
     #:definition-description
     #:definition-related
     #:skill-definition
     #:skill-instructions
     #:tool-definition
     #:tool-usage
     #:tool-handler
     #:context-definition
     #:record-skill
     #:record-tool
     #:record-context
     #:lode-definitions
     #:find-definition
     ;; Definition forms the lode author writes.
     #:defskill
     #:defcommand
     #:defcontext
     ;; Load-time definition failures.
     #:definition-error
     #:definition-error-lode
     #:definition-error-name
     #:definition-error-reason
   ;; Definition-time shape errors.
   #:shape-error
   #:shape-error-form
   #:shape-error-reason))
