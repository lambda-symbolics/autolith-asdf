#!/usr/bin/env -S sbcl --script
;;;; build.lisp --- compile and test the autolith-asdf system.
;;;
;;; Run ./build.lisp COMMAND. Commands: compile, test, all, help.

(require :asdf)

(defparameter *system* "autolith-asdf"
  "The system this script builds.")

(defun script-directory ()
  "The directory that holds this script."
  (uiop:pathname-directory-pathname *load-truename*))

(defun register-local-system ()
  "Make ASDF find the .asd file next to this script."
  (pushnew (script-directory) asdf:*central-registry* :test #'equal))

(defun compile-command ()
  "Compile all source files without loading them."
  (format t "Compiling ~a ...~%" *system*)
  (asdf:compile-system *system*)
  (format t "Compiled ~a.~%" *system*))

(defun test-command ()
  "Compile, load and run the tests."
  (format t "Testing ~a ...~%" *system*)
  (asdf:test-system *system*)
  (format t "All tests passed.~%"))

(defun help-command ()
  "Print the usage text."
  (format t "usage: build.lisp COMMAND~2%")
  (format t "  compile   compile the system to FASL files~%")
  (format t "  test      compile, load and run the tests~%")
  (format t "  all       compile and test~%")
  (format t "  help      print this help~%"))

(defun unknown-command (name)
  "Report an unknown command and print the usage text."
  (format *error-output* "unknown command: ~a~%~%" name)
  (help-command)
  1)

(defun main (argv)
  "Run one command. Return the process exit code."
  (register-local-system)
  (let ((command (or (first argv) "help")))
    (cond
      ((string-equal command "help")    (help-command)    0)
      ((string-equal command "compile") (compile-command) 0)
      ((string-equal command "test")    (test-command)    0)
      ((string-equal command "all")
       (compile-command)
       (test-command)
       0)
      (t (unknown-command command)))))

(sb-ext:exit
 :code (handler-case
           (main (rest sb-ext:*posix-argv*))
         (error (e)
           (format *error-output* "build.lisp failed: ~a~%" e)
           1)))
