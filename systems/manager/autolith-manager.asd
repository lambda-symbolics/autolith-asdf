;;; Manager

(asdf:defsystem "autolith-manager"
  :description "Client for autolith-asdf: the lode manager."
  :version "0.1.0"
  :depends-on ("autolith-asdf")
  :components ((:file "package")
               (:file "run")
               (:file "manager"))
  :in-order-to ((test-op (load-op "autolith-manager/test")))
  :perform (asdf:test-op (operation component)
             (uiop:symbol-call :autolith-manager-test :run-all-tests)))

(asdf:defsystem "autolith-manager/test"
  :description "Activation lifecycle checks for the autolith manager."
  :depends-on ("autolith-manager" "autolith-test")
  :pathname "test/"
  :components ((:file "manager")))
