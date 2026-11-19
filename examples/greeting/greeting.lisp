(defpackage :greeting
  (:use :common-lisp)
  (:import-from :autolith-asdf
   #:defskill
   #:defcommand
   #:defcontext))
(in-package :greeting)

(defskill "greet-person"
  "Greets a person by name."
  "Ask for the person's name, then greet them warmly."
  :related ("person-known"))

(defcontext "person-known"
  "The person the lode should greet is known to the session.")

(defcommand greet
  "Greets one person by name."
  "(greet NAME)"
  ("greet-person")
  (name)
  (format nil "Hello, ~A." name))