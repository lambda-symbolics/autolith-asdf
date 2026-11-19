
(asdf:defsystem "autolith-asdf"
  :description "Manifest schema library for lode systems."
  :version "0.1.0"
  :depends-on ("asdf")
    :components ((:file "src/asdf/package")
                 (:file "src/asdf/schema")
                 (:file "src/asdf/parse")
                   (:file "src/asdf/system")
                   (:file "src/asdf/definitions"))
  :in-order-to ((test-op (load-op "autolith-asdf/test")))
  :perform (asdf:test-op (operation component)
             (uiop:symbol-call :autolith-asdf-test :run-all-tests)))

(asdf:defsystem "autolith-asdf/test"
  :description "Shape and recording checks for the autolith-asdf manifest schema."
  :depends-on ("autolith-asdf")
  :pathname "test/"
  :components ((:file "test")))
