#!/usr/bin/env -S sbcl --script
;;;; build.lisp --- compile and test the systems of this repository.
;;;
;;; Run ./build.lisp COMMAND [SYSTEM]. Commands: compile, test, all,
;;; help. SYSTEM defaults to autolith-asdf.

(require :asdf)

(defparameter *system* "autolith-asdf"
  "The default system this script builds.")

(defun script-directory ()
  "The directory that holds this script."
  (uiop:pathname-directory-pathname *load-truename*))

(defun register-local-system ()
  "Make ASDF find the .asd file next to this script."
  (pushnew (script-directory) asdf:*central-registry* :test #'equal))

(defun compile-command (system)
  "Compile all source files of one system without loading them."
  (format t "Compiling ~a ...~%" system)
  (asdf:compile-system system)
  (format t "Compiled ~a.~%" system))

(defun test-command (system)
  "Compile, load and run the tests of one system."
  (format t "Testing ~a ...~%" system)
  (asdf:test-system system)
  (format t "All tests passed.~%"))

(defun help-command ()
  "Print the usage text."
  (format t "usage: build.lisp COMMAND [SYSTEM]~2%")
  (format t "  compile   compile the system to FASL files~%")
  (format t "  test      compile, load and run the tests~%")
  (format t "  all       compile and test~%")
  (format t "  help      print this help~2%")
  (format t "  SYSTEM is the ASDF system to build. Default: autolith-asdf.~%")
  (format t "  Example: build.lisp compile autolith-manager~%"))

(defun unknown-command (name)
  "Report an unknown command and print the usage text."
  (format *error-output* "unknown command: ~a~%~%" name)
  (help-command)
  1)

(defun main (argv)
  "Run one command on one system. Return the process exit code."
  (register-local-system)
  (let ((command (or (first argv) "help"))
        (system (or (second argv) *system*)))
    (cond
      ((string-equal command "help")    (help-command)          0)
      ((string-equal command "compile") (compile-command system) 0)
      ((string-equal command "test")    (test-command system)    0)
      ((string-equal command "all")
       (compile-command system)
       (test-command system)
       0)
      (t (unknown-command command)))))

(sb-ext:exit
 :code (handler-case
           (main (rest sb-ext:*posix-argv*))
         (error (e)
           (format *error-output* "build.lisp failed: ~a~%" e)
           1)))
