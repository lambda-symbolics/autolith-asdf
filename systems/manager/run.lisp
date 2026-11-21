;;;; run.lisp --- activation runs, tracked registrations, cleanup handles.
;;;
;;; One activation attempt of one lode system (spec: entity
;;; ActivationRun). The manager creates a run when activation starts;
;;; each retry is a new run. Registrations track in registration order
;;; (spec: entity Registration). The cleanup handle records the
;;; function the activation entry point returned (spec: entity
;;; CleanupHandle).

(in-package :autolith-manager)

;;; The lifecycle states of one run (spec: ActivationRun.status):
;;;
;;;   running -> active      the activation entry point succeeded
;;;   running -> unwinding    the entry point signaled a failure
;;;   unwinding -> failed     the reverse unwind finished
;;;   active -> draining      deactivation started
;;;   draining -> done        drain, definition removal, cleanup finished

(defclass activation-run ()
  ((system :initarg :system :reader run-system
           :documentation "The lode system this run activates.")
   (status :initform :running :reader run-status)
   (registrations :initform nil)
   (handle :initform nil :reader run-handle)
   (entry-error :initform nil :reader run-entry-error)
   (failures :initform nil))
  (:documentation
   "One activation attempt of one lode system. FAILED and DONE are
terminal; the lode stays loaded and inactive after a failed run, and a
retry is a new run."))

(defun run-registrations (run)
  "The registrations RUN tracked, in registration order."
  (nreverse (copy-list (slot-value run 'registrations))))

(defun run-failures (run)
  "The cleanup failures RUN collected, in collection order."
  (nreverse (copy-list (slot-value run 'failures))))

(defclass registration ()
  ((run :initarg :run :reader registration-run)
   (position :initarg :position :reader registration-position)
   (kind :initarg :kind :reader registration-kind)
   (unwind-action :initarg :unwind-action :reader registration-unwind-action)
   (drain :initarg :drain :initform :wait :reader registration-drain))
  (:documentation
   "One tracked registration of one activation run. UNWIND-ACTION is a
function of one argument, the drain policy, that disposes the
registration's stateful setup and its in-flight work; the manager
runs it in reverse position order during unwind and during the
deactivation drain."))

(defclass cleanup-handle ()
  ((run :initarg :run :reader handle-run)
   (thunk :initarg :thunk))
  (:documentation
   "The cleanup handle one activation returned. The manager runs the
recorded thunk during deactivation, after the drain. The thunk's
content is the activation's choice and stays opaque."))

(defvar *run-transitions*
  '((:running . :active)
    (:running . :unwinding)
    (:unwinding . :failed)
    (:active . :draining)
    (:draining . :done))
  "The legal status transitions of one run (spec: entity
ActivationRun.transitions).")

(defun transition-run (run to)
  "Move RUN to the next legal status."
  (let ((from (run-status run)))
    (unless (member (cons from to) *run-transitions* :test #'equal)
      (error "illegal run transition: ~A -> ~A" from to))
    (setf (slot-value run 'status) to)))