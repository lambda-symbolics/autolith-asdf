;;;; autolith-asdf.asd --- system definition of the manifest schema
;;;; library for lode systems.
;;;
;;; The library defines one ASDF system class, AUTOLITH-ASDF:SYSTEM,
;;; and the slot schema a defsystem declaration uses. It depends only
;;; on ASDF. The manifest schema version is this library's version.

(asdf:defsystem "autolith-asdf"
  :description "Manifest schema library for lode systems."
  :version "0.1.0"
  :depends-on ("asdf")
    :components ((:file "src/package")
                 (:file "src/schema")
                 (:file "src/parse")
                 (:file "src/system"))
  :in-order-to ((test-op (load-op "autolith-asdf/test"))))

(asdf:defsystem "autolith-asdf/test"
  :description "Shape checks for the autolith-asdf manifest schema."
  :depends-on ("autolith-asdf")
  :pathname "test/"
  :components ((:file "test"))
  :perform (asdf:test-op (operation component)
             (uiop:symbol-call :autolith-asdf-test :run-all-tests)))
