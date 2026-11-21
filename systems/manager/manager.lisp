;;;; manager.lisp --- the lode manager: activation and deactivation.
;;;
;;; The consumer side of lode systems (spec: src/manager/module.allium,
;;; contract ActivationLifecycle). The manager drives one activation
;;; run for a loaded lode system: it resolves the activation name at
;;; activation time, invokes the entry point with a runtime context it
;;; builds, tracks the entry point's registrations, unwinds them in
;;; reverse position order when the entry point signals, installs the
;;; lode's recorded definitions when activation succeeds, and drains
;;; before cleanup at deactivation. The autolith-asdf library stays
;;; inert throughout.

(in-package :autolith-manager)

;;;---------------------------------------------------------------------
;;; The manager
;;;---------------------------------------------------------------------

(defclass manager ()
  ((runs :initform nil :reader manager-runs)
   (installed :initform (make-hash-table :test #'equal)
              :reader manager-installed-definitions))
  (:documentation
   "The consumer that drives lode activation. RUNS holds every run the
manager created, newest first. INSTALLED holds the definitions of the
lodes with active runs, keyed by system name."))

(defclass runtime-context ()
  ((manager :initarg :manager :reader context-manager)
   (run :initarg :run :reader context-run)
   (lode :initarg :lode :reader context-lode)
   (data :initarg :data :initform nil :reader context-data))
  (:documentation
   "The runtime context the manager builds for one activation run. The
activation entry point interprets it; no other party reads it. DATA
carries whatever the consumer passed to ACTIVATE."))

;;;---------------------------------------------------------------------
;;; Refusals
;;;---------------------------------------------------------------------

(define-condition activation-refused (error)
  ((lode :initarg :lode :reader activation-refused-lode)
   (reason :initarg :reason :reader activation-refused-reason))
  (:report (lambda (condition stream)
             (format stream "Activation refused for ~A: ~A"
                     (asdf:component-name (activation-refused-lode condition))
                     (activation-refused-reason condition))))
  (:documentation "The manager refuses to start one activation run."))

(define-condition deactivation-refused (error)
  ((run :initarg :run :reader deactivation-refused-run)
   (dependents :initarg :dependents :reader deactivation-refused-dependents))
  (:report (lambda (condition stream)
             (format stream "Deactivation refused for ~A: active runs depend on it: ~{~A~^, ~}"
                     (run-name (deactivation-refused-run condition))
                     (mapcar #'run-name
                             (deactivation-refused-dependents condition)))))
  (:documentation "The manager refuses to deactivate one active run."))

(define-condition registration-refused (error)
  ((run :initarg :run :reader registration-refused-run)
   (reason :initarg :reason :reader registration-refused-reason))
  (:report (lambda (condition stream)
             (format stream "Registration refused for the run of ~A: ~A"
                     (run-name (registration-refused-run condition))
                     (registration-refused-reason condition))))
  (:documentation "The manager refuses to track one registration."))

;;;---------------------------------------------------------------------
;;; Run helpers
;;;---------------------------------------------------------------------

(defun run-name (run)
  "The name of the lode system one run activates."
  (asdf:component-name (run-system run)))

(defun live-run-p (run)
  "A run that has not reached a terminal state."
  (member (run-status run) '(:running :unwinding :active :draining)))

(defun active-runs (manager)
  "The manager's runs whose lodes are active now."
  (remove-if-not (lambda (run) (eq (run-status run) :active))
                 (manager-runs manager)))

(defun run-unwind-action (run registration)
  "Run one registration's unwind action with its drain policy,
collecting a failure instead of signaling (spec: invariant
CleanupFailuresCollected)."
  (handler-case
      (funcall (registration-unwind-action registration)
               (registration-drain registration))
    (error (condition)
      (push (format nil "the ~A registration at position ~A failed to unwind: ~A"
                    (registration-kind registration)
                    (registration-position registration)
                    condition)
            (slot-value run 'failures)))))

;;;---------------------------------------------------------------------
;;; The registration primitive
;;;---------------------------------------------------------------------

(defun register (context kind unwind-action &key (drain :wait))
  "Track one completed registration on the current run (spec: rule
TrackRegistration). KIND names the registration, a keyword or a string,
and must be one of the lode's declared capabilities (spec:
src/asdf/module.allium, entity Manifest.capabilities: absent or empty
means an activation registers nothing). UNWIND-ACTION is a function of
one argument, the drain policy, that disposes the registration's
stateful setup and its in-flight work. DRAIN is :wait or :cancel, the
policy the manager applies when it runs the unwind action."
  (let ((run (context-run context)))
    (flet ((refuse (reason)
             (error 'registration-refused :run run :reason reason)))
      (unless (eq (run-status run) :running)
        (refuse "the run is not running"))
        (let ((kind (typecase kind
                      (string kind)
                      (symbol (string-downcase kind))
                      (t (refuse "the kind must be a keyword or a string")))))
        (unless (member kind (autolith-asdf:capabilities (context-lode context))
                        :test #'string-equal)
          (refuse (format nil "the lode declares no ~A capability" kind)))
        (unless (member drain '(:wait :cancel))
          (refuse "the drain policy must be :wait or :cancel"))
        (let ((registration
                (make-instance 'registration
                               :run run
                               :position (1+ (length (run-registrations run)))
                               :kind kind
                               :unwind-action unwind-action
                               :drain drain)))
          (push registration (slot-value run 'registrations))
          registration)))))

;;;---------------------------------------------------------------------
;;; Activation
;;;---------------------------------------------------------------------

(defun resolve-entry-point (name)
  "Resolve the package:symbol activation NAME at activation time (spec:
invariant EntryPointResolvedAtActivation). The resolution tries the
name as written, then its uppercase form, so manifest strings read
naturally in either case."
  (let ((colon (position #\: name)))
    (unless colon
      (error "the activation name ~S names no package:symbol" name))
    (let* ((package-name (subseq name 0 colon))
           (symbol-name (subseq name (1+ colon)))
           (package (or (find-package package-name)
                        (find-package (string-upcase package-name)))))
      (unless package
        (error "the activation name ~S names no loaded package" name))
      (let ((symbol (or (find-symbol symbol-name package)
                        (find-symbol (string-upcase symbol-name) package))))
        (unless symbol
          (error "the activation name ~S names no symbol in its package" name))
        (unless (fboundp symbol)
          (error "the activation name ~S names no function" name))
        (fdefinition symbol)))))

(defun check-activatable (manager lode)
  "Refuse one activation before a run exists (spec: rule
StartActivation). A lode with no activation entry point and no
capabilities is a library lode and never activates (spec:
src/asdf/module.allium, entity Manifest.activation)."
  (unless (or (autolith-asdf:activation lode)
              (autolith-asdf:capabilities lode))
    (error 'activation-refused :lode lode
           :reason "the lode declares no activation and no capabilities"))
  (let ((live (find-if (lambda (run)
                         (and (eq (run-system run) lode) (live-run-p run)))
                       (manager-runs manager))))
    (when live
      (error 'activation-refused :lode lode
             :reason (format nil "the lode has a live run, currently ~A"
                             (run-status live)))))
  (let ((unmet
          (remove-if
           (lambda (name)
             (find name (active-runs manager) :key #'run-name :test #'string=))
           (autolith-asdf:activation-depends-on lode))))
    (when unmet
      (error 'activation-refused :lode lode
             :reason (format nil "no active run provides ~{~A~^, ~}" unmet)))))

(defun install-definitions (manager run)
  "Install every definition the lode recorded (spec: invariant
InstalledAtActivation). Deactivation removes them again."
  (setf (gethash (run-name run) (manager-installed-definitions manager))
        (autolith-asdf:lode-definitions (run-system run))))

(defun fail-run (run condition)
  "Unwind the tracked registrations in reverse position order and
finish the failed run (spec: rules ActivationFails, CompleteUnwind).
The unwind path never uses a cleanup handle: none exists for a failed
run."
  (setf (slot-value run 'entry-error) condition)
  (transition-run run :unwinding)
  (dolist (registration (reverse (run-registrations run)))
    (run-unwind-action run registration))
  (transition-run run :failed)
  run)

(defun activate (manager lode &key context)
  "Start and drive one activation run for the loaded lode system LODE
(spec: rules StartActivation, ActivationSucceeds, ActivationFails).
Returns the run. A failed activation returns a failed run whose
failures list reports the unwind result; the lode stays loaded and
inactive, and a retry is a new run. A lode with capabilities and no
activation entry point activates from its definitions alone (spec:
invariant InstalledAtActivation)."
  (check-activatable manager lode)
  (let ((run (make-instance 'activation-run :system lode)))
    (push run (slot-value manager 'runs))
    (if (null (autolith-asdf:activation lode))
        (progn
          (install-definitions manager run)
          (transition-run run :active)
          run)
        (handler-case
            (let* ((entry-point
                     (resolve-entry-point (autolith-asdf:activation lode)))
                   (runtime-context
                     (make-instance 'runtime-context
                                    :manager manager
                                    :run run
                                    :lode lode
                                    :data context))
                   (thunk (funcall entry-point runtime-context)))
              (unless (functionp thunk)
                (error "the activation entry point ~S returned ~S, not a cleanup handle"
                       (autolith-asdf:activation lode) thunk))
              (transition-run run :active)
              (setf (slot-value run 'handle)
                    (make-instance 'cleanup-handle :run run :thunk thunk))
              (install-definitions manager run)
              run)
          (error (condition)
            (fail-run run condition))))))

;;;---------------------------------------------------------------------
;;; Deactivation
;;;---------------------------------------------------------------------

(defun deactivate (manager run)
  "Drain, clean up, and finish one active run (spec: rules
StartDeactivation, CompleteDeactivation). Stops new work by moving the
run to draining, drains each registration's in-flight work in reverse
position order by applying its drain policy, removes the lode's
installed definitions, runs the cleanup handle, and returns the
cleanup failures as one list. Across systems the consumer deactivates
in reverse activation order; the dependent refusal below forces that
order."
  (unless (eq (run-status run) :active)
    (error "the run of ~A is ~A, not active"
           (run-name run) (run-status run)))
  (let ((dependents
          (remove run
                  (remove-if-not
                   (lambda (other)
                     (member (run-name run)
                             (autolith-asdf:activation-depends-on
                              (run-system other))
                             :test #'string=))
                   (active-runs manager)))))
    (when dependents
      (error 'deactivation-refused :run run :dependents dependents)))
  (transition-run run :draining)
  (dolist (registration (reverse (run-registrations run)))
    (run-unwind-action run registration))
  (remhash (run-name run) (manager-installed-definitions manager))
  (let ((handle (run-handle run)))
    (when handle
      (handler-case (funcall (slot-value handle 'thunk))
        (error (condition)
          (push (format nil "the cleanup handle of ~A failed: ~A"
                        (run-name run) condition)
                (slot-value run 'failures))))))
  (transition-run run :done)
  (run-failures run))