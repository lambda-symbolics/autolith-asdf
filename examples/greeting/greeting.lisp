(defpackage :greeting
  (:use :common-lisp))
(in-package :greeting)

(autolith-asdf:defskill "greet-person"
  "Greets a person by name."
  "Ask for the person's name, then greet them warmly."
  :related ("person-known"))

(autolith-asdf:defcontext "person-known"
  "The person the lode should greet is known to the session.")

(autolith-asdf:defcommand greet
  "Greets one person by name."
  "(greet NAME)"
  ("greet-person")
  (name)
  (format nil "Hello, ~A." name))