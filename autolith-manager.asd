;;;; autolith-manager.asd --- system definition of the client that
;;;; works with the autolith-asdf definitions.
;;;
;;; The manager drives the lode activation lifecycle: it activates
;;; lode systems, installs their recorded definitions, and
;;; deactivates them. It depends on the manifest schema library.
;;; The manager implementation is pending; this definition prepares
;;; the separate system.

(asdf:defsystem "autolith-manager"
  :description "Client for autolith-asdf: the lode manager."
  :version "0.1.0"
  :depends-on ("autolith-asdf")
  :components ((:file "manager/package")))
