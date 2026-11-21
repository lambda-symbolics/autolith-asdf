;;;; manager.lisp --- activation lifecycle checks for autolith-manager.

(defpackage :autolith-manager-test
  (:use :common-lisp)
  (:import-from :autolith-manager
                #:manager
                #:activate
                #:deactivate
                #:register
                #:runtime-context
                #:activation-run
                #:run-system
                #:run-status
                #:run-registrations
                #:run-handle
                #:run-entry-error
                #:run-failures
                #:registration-position
                #:registration-kind
                #:registration-drain
                #:activation-refused
                #:deactivation-refused
                #:deactivation-refused-dependents
                #:registration-refused
                  #:manager-installed-definitions)
  (:import-from :autolith-test
                #:check
                #:check-condition
                #:record-failure
                #:reset-results
                #:report-results)
  (:export #:run-all-tests))

(in-package :autolith-manager-test)

(defparameter *log* nil)

(defun logf (entry)
  (push entry *log*))

;;;---------------------------------------------------------------------
;;; Manifests and entry points the tests use
;;;---------------------------------------------------------------------

(defun make-lode (name &key capabilities activate depends-on)
  "One manifest the lifecycle tests activate."
  (make-instance 'autolith-asdf:system
                 :name name
                 :capabilities capabilities
                 :activate activate
                 :activation-depends-on depends-on))

(defun entry-ok (context)
  "Registers a timer and a connection, then returns the cleanup handle."
  (register context :timer (lambda (policy) (logf (list :timer policy))))
  (register context :conn (lambda (policy) (logf (list :conn policy)))
            :drain :cancel)
  (lambda () (logf :handle)))

(defun entry-fails (context)
  "Registers a timer and a connection, then signals."
  (register context :timer (lambda (policy) (logf (list :timer policy))))
  (register context :conn (lambda (policy) (logf (list :conn policy))))
  (error "boom"))

(defun entry-unwind-fails (context)
  "Registers a broken timer and a connection, then signals."
  (register context :timer (lambda (policy) (error "timer unwind failed")))
  (register context :conn (lambda (policy) (logf (list :conn policy))))
  (error "boom"))

(defun entry-messy-shutdown (context)
  "Registers a timer that fails to unwind; the handle also fails."
  (register context :timer (lambda (policy) (error "timer drain failed")))
  (lambda () (error "handle failed")))

(defun entry-bad-handle (context)
  "Returns something that is not a cleanup handle."
  42)

(defun entry-bad-drain (context)
  "Registers with a drain policy that does not exist."
  (register context :x (lambda (policy) policy) :drain :sometimes)
  (lambda () nil))

(defun entry-unauthorized-kind (context)
  "Registers a kind the lode does not declare."
  (register context :timer (lambda (policy) policy))
  (lambda () nil))

;;;---------------------------------------------------------------------
;;; Activation
;;;---------------------------------------------------------------------

(defun test-activate-entry-point ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-ok"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-ok"))
         (run (activate manager lode)))
    (check "run returned" (typep run 'activation-run))
    (check "run system" (eq (run-system run) lode))
    (check "run active" (eq (run-status run) :active))
    (check "registrations tracked" (= (length (run-registrations run)) 2))
    (check "first position"
           (= (registration-position (first (run-registrations run))) 1))
    (check "second position"
           (= (registration-position (second (run-registrations run))) 2))
    (check "registration kind"
           (string= (registration-kind (first (run-registrations run))) "timer"))
    (check "drain policy kept"
           (eq (registration-drain (second (run-registrations run))) :cancel))
    (check "handle records the run's return"
           (typep (run-handle run) 'autolith-manager:cleanup-handle))
    (check "no failures" (null (run-failures run)))
    (check "no entry error" (null (run-entry-error run)))
    (check "definitions installed"
           (nth-value 1 (gethash "lode-ok"
                                 (manager-installed-definitions manager))))))

(defun test-entry-failure-unwinds-in-reverse ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-fail"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-fails"))
         run)
    (setf *log* nil)
    (setf run (activate manager lode))
    (check "failed run is failed" (eq (run-status run) :failed))
    (check "unwind ran in reverse order"
           (equal *log* '((:timer :wait) (:conn :wait))))
    (check "no handle for a failed run" (null (run-handle run)))
    (check "entry error recorded" (typep (run-entry-error run) 'error))
    (check "unwind result reported" (null (run-failures run)))
    (setf *log* nil)
    (let ((retry (activate manager lode)))
      (check "retry is a new run" (not (eq retry run)))
      (check "retry runs the entry point again"
             (equal *log* '((:timer :wait) (:conn :wait)))))))

(defun test-unwind-failure-collected ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-unwind-fail"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-unwind-fails"))
         run)
    (setf *log* nil)
    (setf run (activate manager lode))
    (check "run failed" (eq (run-status run) :failed))
    (check "unwind failure collected" (= (length (run-failures run)) 1))
    (check "failure names the registration"
           (search "timer" (first (run-failures run))))
    (check "remaining unwind steps still ran"
           (equal *log* '((:conn :wait))))))

(defun test-register-refused-when-not-running ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-reg-ref"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-ok"))
         (run (activate manager lode)))
    (check-condition "register refuses a non-running run"
      (lambda ()
        (register (make-instance 'runtime-context
                                 :manager manager :run run :lode lode)
                    :late (lambda (policy) policy)))
      'registration-refused)))

(defun test-unauthorized-registration-kind ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-unauth"
                            :capabilities '(:conn)
                          :activate "autolith-manager-test:entry-unauthorized-kind"))
         (run (activate manager lode)))
    (check "unauthorized kind fails the run" (eq (run-status run) :failed))
    (check "refusal recorded" (typep (run-entry-error run) 'registration-refused))))

(defun test-bad-drain-policy-refused ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-bad-drain"
                            :capabilities '(:x)
                          :activate "autolith-manager-test:entry-bad-drain"))
         (run (activate manager lode)))
    (check "bad drain policy fails the run" (eq (run-status run) :failed))
    (check "refusal recorded" (typep (run-entry-error run) 'registration-refused))))

(defun test-one-live-run-per-system ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-live"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-ok")))
    (activate manager lode)
    (check-condition "second activation refused while a run is live"
      (lambda () (activate manager lode))
      'activation-refused)))

(defun test-activation-dependencies ()
  (let* ((manager (make-instance 'manager))
         (base (make-lode "lode-base"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-ok"))
         (top (make-lode "lode-top"
                           :capabilities '(:timer :conn)
                         :activate "autolith-manager-test:entry-ok"
                         :depends-on '("lode-base"))))
    (check-condition "activation without active dependencies refused"
      (lambda () (activate manager top))
      'activation-refused)
    (activate manager base)
    (let ((run (activate manager top)))
      (check "activation after its dependencies runs"
             (eq (run-status run) :active)))))

;;;---------------------------------------------------------------------
;;; Deactivation
;;;---------------------------------------------------------------------

(defun test-deactivate-refuses-active-dependents ()
  (let* ((manager (make-instance 'manager))
         (base (make-lode "lode-dep-base"
                            :capabilities '(:timer :conn)
                          :activate "autolith-manager-test:entry-ok"))
         (top (make-lode "lode-dep-top"
                           :capabilities '(:timer :conn)
                         :activate "autolith-manager-test:entry-ok"
                         :depends-on '("lode-dep-base")))
         (base-run (activate manager base))
         (top-run (activate manager top)))
    (handler-case
        (progn
          (deactivate manager base-run)
          (record-failure "deactivation of a depended-on run"
                         "no refusal was signaled"))
      (deactivation-refused (condition)
        (check "refusal reports the dependents"
               (equal (mapcar (lambda (dependent)
                                (asdf:component-name (run-system dependent)))
                              (deactivation-refused-dependents condition))
                      '("lode-dep-top")))))
    (deactivate manager top-run)
    (let ((failures (deactivate manager base-run)))
      (check "deactivation after the dependents works" (null failures)))))

(defun test-deactivate-sequence ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-shutdown"
                            :capabilities '(:timer :conn :tool)
                          :activate "autolith-manager-test:entry-ok"))
         run)
    (autolith-asdf:record-tool lode "tool" "A tool." "(tool)" #'identity)
    (setf *log* nil)
    (setf run (activate manager lode))
    (check "definitions installed on activation"
           (= (length (gethash "lode-shutdown"
                               (manager-installed-definitions manager)))
              1))
    (let ((failures (deactivate manager run)))
      (check "deactivation returns no failures" (null failures))
      (check "drain runs in reverse order, the handle last"
             (equal *log* '(:handle (:timer :wait) (:conn :cancel))))
      (check "run done" (eq (run-status run) :done))
      (check "definitions removed"
             (not (nth-value 1 (gethash "lode-shutdown"
                                        (manager-installed-definitions manager))))))))

(defun test-deactivate-collects-failures ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-messy"
                            :capabilities '(:timer)
                          :activate "autolith-manager-test:entry-messy-shutdown"))
         (run (activate manager lode))
         (failures (deactivate manager run)))
    (check "run still finishes done" (eq (run-status run) :done))
    (check "drain failure collected"
           (some (lambda (f) (search "timer" f)) failures))
    (check "cleanup failure collected"
           (some (lambda (f) (search "handle" f)) failures))
    (check "exactly two failures" (= (length failures) 2))))

;;;---------------------------------------------------------------------
;;; Definitions-only and refused lodes
;;;---------------------------------------------------------------------

(defun test-definitions-only-activation ()
  (let* ((manager (make-instance 'manager))
           (lode (make-lode "lode-defs-only" :capabilities '(:tool))))
    (autolith-asdf:record-tool lode "tool" "A tool." "(tool)" #'identity)
    (let ((run (activate manager lode)))
      (check "definitions-only run is active" (eq (run-status run) :active))
      (check "definitions-only run has no handle" (null (run-handle run)))
      (check "definitions installed"
             (= (length (gethash "lode-defs-only"
                                 (manager-installed-definitions manager)))
                1))
      (let ((failures (deactivate manager run)))
        (check "definitions-only deactivation succeeds" (null failures))
        (check "definitions-only run done" (eq (run-status run) :done))))))

(defun test-library-lode-refused ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-library" :capabilities nil)))
    (check-condition "a library lode never activates"
      (lambda () (activate manager lode))
      'activation-refused)))

(defun test-entry-resolution-failure ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-ghost-entry"
                            :capabilities '(:timer)
                          :activate "autolith-manager-test:no-such-entry"))
         (run (activate manager lode)))
    (check "unresolved entry fails the run" (eq (run-status run) :failed))
    (check "resolution error recorded" (typep (run-entry-error run) 'error))
    (check "a failed run can retry"
           (eq (run-status (activate manager lode)) :failed))))

(defun test-bad-handle-fails-activation ()
  (let* ((manager (make-instance 'manager))
         (lode (make-lode "lode-bad-handle"
                            :capabilities '(:timer)
                          :activate "autolith-manager-test:entry-bad-handle"))
         (run (activate manager lode)))
    (check "a non-function handle fails activation"
           (eq (run-status run) :failed))))

;;;---------------------------------------------------------------------
;;; Entry point
;;;---------------------------------------------------------------------

(defun run-all-tests ()
  (reset-results)
  (mapc #'funcall
        (list #'test-activate-entry-point
              #'test-entry-failure-unwinds-in-reverse
              #'test-unwind-failure-collected
              #'test-register-refused-when-not-running
              #'test-unauthorized-registration-kind
              #'test-bad-drain-policy-refused
              #'test-one-live-run-per-system
              #'test-activation-dependencies
              #'test-deactivate-refuses-active-dependents
              #'test-deactivate-sequence
              #'test-deactivate-collects-failures
              #'test-definitions-only-activation
              #'test-library-lode-refused
              #'test-entry-resolution-failure
              #'test-bad-handle-fails-activation))
  (report-results "autolith-manager"))