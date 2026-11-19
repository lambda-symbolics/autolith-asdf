;;; definition-lode-bad.asd --- a fixture lode whose source records an
;;; undeclared kind.

(asdf:defsystem "definition-lode-bad"
  :defsystem-depends-on ("autolith-asdf")
  :class "autolith-asdf:system"
  :capabilities (:tool)
  :components ((:file "source")))