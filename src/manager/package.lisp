;;;; package.lisp --- package definition for autolith-manager.

;;; The client that works with the autolith-asdf definitions. The
;;; manager drives the lode activation lifecycle: it activates lode
;;; systems, installs their recorded definitions, and deactivates
;;; them. The implementation is pending.

(defpackage :autolith-manager
  (:use :common-lisp))
