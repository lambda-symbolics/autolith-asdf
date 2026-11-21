;;; definition-lode.asd --- a well-formed fixture lode.

(asdf:defsystem "definition-lode"
  :defsystem-depends-on ("autolith-asdf")
  :class "autolith-asdf:system"
  :capabilities (:skill :tool :context)
  :components ((:file "source")))