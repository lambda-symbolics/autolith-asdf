
;;; Format

(asdf:defsystem "autolith-asdf"
  :description "Manifest schema library for lode systems."
  :version "0.1.0"
  :depends-on ("asdf")
    :components ((:file "package")
                 (:file "schema")
                 (:file "parse")
                 (:file "system")
                 (:file "definitions"))
  :in-order-to ((test-op (load-op "autolith-asdf/test")))
  :perform (asdf:test-op (operation component)
             (uiop:symbol-call :autolith-asdf-test :run-all-tests)))

(asdf:defsystem "autolith-asdf/test"
  :description "Shape and recording checks for the autolith-asdf manifest schema."
  :depends-on ("autolith-asdf" "autolith-test")
  :pathname "test/"
  :components ((:file "test")))



