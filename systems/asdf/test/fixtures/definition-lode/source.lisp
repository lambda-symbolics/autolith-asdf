;;; source.lisp --- definition forms of the definition-lode fixture.

(defpackage :definition-lode (:use :common-lisp))
(in-package :definition-lode)

(autolith-asdf:defskill "greet" "Greets the person." "Say hi warmly."
  :related ("wave" "ghost"))
(autolith-asdf:defskill "wave" "Waves." "Wave back.")
(autolith-asdf:defcommand run "Runs the thing." "(run thing)" nil
  (thing) (identity thing))