#!/usr/bin/env -S sbcl --script
;;;; build.lisp --- compile and test the systems of this repository.
;;;
;;; Run ./build.lisp [COMMAND [SYSTEM]]. Commands: compile, test, all,
;;; help. Without SYSTEM, every system of this repository is built.

(require :asdf)

(defparameter *systems* '("autolith-asdf" "autolith-manager")
  "The systems this script builds when no SYSTEM is named.")

(defun script-directory ()
  "The directory that holds this script."
  (uiop:pathname-directory-pathname *load-truename*))

(defun register-local-system ()
  "Make ASDF find the .asd files under systems/."
  (pushnew (script-directory) asdf:*central-registry* :test #'equal)
  (dolist (directory (uiop:subdirectories
                      (merge-pathnames "systems/" (script-directory))))
    (pushnew directory asdf:*central-registry* :test #'equal)))

(defun compile-command (system)
  "Compile all source files of one system without loading them."
  (format t "Compiling ~a ...~%" system)
  (asdf:compile-system system)
  (format t "Compiled ~a.~%" system))

(defun deprecated-recursive-operate-warning-p (condition)
  "Is CONDITION ASDF's warning about a nested operate call?"
  (and (typep condition 'warning)
       (search "Deprecated recursive use" (princ-to-string condition))))

(defun test-command (system)
  "Compile, load and run the tests of one system."
  (format t "Testing ~a ...~%" system)
  (handler-bind
      ((warning
        (lambda (condition)
          (when (deprecated-recursive-operate-warning-p condition)
            (muffle-warning condition)))))
    (asdf:test-system system))
  (format t "All tests passed.~%"))
(defun banner (system)
  "Print the heading that frames one system's output."
  (format t "~2%==================== ~a ====================~%" system))

(defun build-system (system)
  "Compile and test one system."
  (compile-command system)
  (test-command system))

(defun run-per-system (system function)
  "Run FUNCTION on every target system. Return the systems that failed."
  (let (failures)
    (dolist (system (if system (list system) *systems*) (nreverse failures))
      (banner system)
      (handler-case (funcall function system)
        (error (condition)
          (format *error-output* "build.lisp failed: ~a: ~a~%" system condition)
            (push system failures))))))

(defun exit-code (failures)
  "The process exit code for a list of failed systems."
  (when failures
    (format *error-output* "build.lisp failed for: ~{~a~^, ~}~%" failures))
  (if failures 1 0))

(defun help-command ()
  "Print the usage text."
  (format t "usage: build.lisp [COMMAND [SYSTEM]]~2%")
  (format t "  compile   compile the system sources to FASL files~%")
  (format t "  test      compile, load and run the tests~%")
  (format t "  all       compile and test~%")
  (format t "  help      print this help~2%")
  (format t "  SYSTEM is the ASDF system to build.~%")
  (format t "  Without SYSTEM, every system of this repository is built.~%")
  (format t "  Example: build.lisp test autolith-manager~%"))

(defun unknown-command (name)
  "Report an unknown command and print the usage text."
  (format *error-output* "unknown command: ~a~%~%" name)
  (help-command)
  1)

(defun main (argv)
  "Run one command on the target systems. Return the process exit code."
  (register-local-system)
  (let ((command (or (first argv) "all"))
        (system (second argv)))
    (cond
      ((string-equal command "help")
       (help-command)
       0)
      ((string-equal command "compile")
       (exit-code (run-per-system system #'compile-command)))
      ((string-equal command "test")
       (exit-code (run-per-system system #'test-command)))
      ((string-equal command "all")
       (exit-code (run-per-system system #'build-system)))
      (t
       (unknown-command command)))))

(sb-ext:exit
 :code (handler-case
           (main (rest sb-ext:*posix-argv*))
         (error (e)
           (format *error-output* "build.lisp failed: ~a~%" e)
           1)))
