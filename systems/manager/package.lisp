;;;; package.lisp --- package definition for autolith-manager.

;;; The client that works with the autolith-asdf definitions. The
;;; manager drives the lode activation lifecycle: it activates lode
;;; systems, installs their recorded definitions, and deactivates them.

(defpackage :autolith-manager
  (:use :common-lisp)
  (:export
   ;; The manager and one activation run.
   #:manager
   #:activate
   #:deactivate
   #:activation-run
   #:run-system
   #:run-status
   #:run-registrations
   #:run-handle
   #:run-entry-error
   #:run-failures
   ;; The runtime context one activation receives.
   #:runtime-context
   #:context-manager
   #:context-run
   #:context-lode
   #:context-data
   ;; The registration primitive.
   #:register
   #:registration
   #:registration-run
   #:registration-position
   #:registration-kind
   #:registration-unwind-action
   #:registration-drain
   #:cleanup-handle
   #:handle-run
   ;; Refusals the consumer can program against.
   #:activation-refused
   #:activation-refused-lode
   #:activation-refused-reason
   #:deactivation-refused
   #:deactivation-refused-run
   #:deactivation-refused-dependents
   #:registration-refused
   #:registration-refused-run
   #:registration-refused-reason
   ;; The manager's installed definition index.
   #:manager-runs
   #:manager-installed-definitions))
