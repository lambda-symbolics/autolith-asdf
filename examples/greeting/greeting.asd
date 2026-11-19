(asdf:defsystem "greeting"
  :defsystem-depends-on ("autolith-asdf")
  :class "autolith-asdf:system"
  :capabilities (:skill :tool :context)
  :components ((:file "greeting")))