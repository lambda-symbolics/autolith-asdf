(defpackage :autolith-test
  (:use :common-lisp)
  (:export #:*passed*
           #:*failures*
           #:reset-results
           #:record-pass
           #:record-failure
           #:check
           #:check-condition
           #:report-results))

(in-package :autolith-test)

(defparameter *passed* 0)
(defparameter *failures* nil)

(defun reset-results ()
  "Start a fresh run of checks."
  (setf *passed* 0 *failures* nil))

(defun record-pass ()
  "Count one passing check."
  (incf *passed*))

(defun record-failure (name note)
  "Record one failing check under NAME with NOTE."
  (push (format nil "~A: ~A" name note) *failures*))

(defun check (name asserted)
  "Pass when ASSERTED holds, otherwise record the failed assertion."
  (if asserted
      (record-pass)
      (record-failure name "assertion failed")))

(defun check-condition (name thunk condition-type)
  "Run THUNK and pass when it signals a condition of CONDITION-TYPE."
  (handler-case
      (progn
        (funcall thunk)
        (record-failure name "no condition was signaled"))
    (error (condition)
      (if (typep condition condition-type)
          (record-pass)
          (record-failure name (format nil "wrong condition: ~A" condition))))))

(defun report-results (suite)
  "Print the tally for SUITE and signal an error when any check failed."
  (format *standard-output* "~&~A: ~A passed, ~A failed.~%"
          suite *passed* (length *failures*))
  (dolist (failure *failures*)
    (format *error-output* "FAIL ~A~%" failure))
  (when *failures*
    (error "~A tests failed" suite)))
