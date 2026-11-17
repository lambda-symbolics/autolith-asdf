;;;; system.lisp --- the lode system class, the slot schema, and the
;;;; definition-time hooks.

(in-package :autolith-asdf)

;;; ASDF parses :depends-on with PARSE-DEPENDENCY-DEF before it hands
;;; anything to the system object, and it rejects every list entry it
;;; does not know. This library redefines that parser: a full manifest
;;; entry contributes its name only. Every other form delegates to
;;; ASDF's original parser. If ASDF is upgraded after this library
;;; loads, the upgrade replaces this definition; reload the library.

(defun full-entry-p (entry)
  "One full entry shape: name string, kind keyword, location, options."
  (and (listp entry)
       (stringp (first entry))
       (keywordp (second entry))
       (third entry)))

(defparameter *original-parse-dependency-def*
  (fdefinition 'asdf/parse-defsystem::parse-dependency-def))

(defun asdf/parse-defsystem::parse-dependency-def (dependency-def)
  "Accept the full manifest entry shape; every other form stays ASDF's."
  (if (full-entry-p dependency-def)
      (first dependency-def)
      (funcall *original-parse-dependency-def* dependency-def)))

(defclass system (asdf:system)
  ((activation :initform nil :initarg :activate :accessor activation)
   (capabilities :initform nil :initarg :capabilities :accessor capabilities)
   (activation-depends-on :initform nil
                          :initarg :activation-depends-on
                          :accessor activation-depends-on)
   (parsed-dependencies :initform nil :accessor dependencies))
  (:documentation
   "One parsed defsystem declaration. The library fills the schema
slots at definition time and checks their shape. ASDF ignores the
slots and loads by dependency name."))

(defun validate-system-shape (system)
  "Check the shape of the schema slots. Definition-time checking covers shape only; the consumer owns every semantic check."
  (let ((activation (activation system)))
    (when (and activation (not (stringp activation)))
      (shape-error activation
                   "the activation entry point must be a string or absent")))
  (dolist (capability (capabilities system))
    (unless (or (keywordp capability) (stringp capability))
      (shape-error capability "a capability must be a keyword or a string")))
  (setf (activation-depends-on system)
        (mapcar (lambda (name)
                  (coerce-system-name name name))
                (activation-depends-on system))))

(defmethod initialize-instance :after ((system system) &key &allow-other-keys)
  (validate-system-shape system))

(defmethod reinitialize-instance :after ((system system) &key &allow-other-keys)
  (validate-system-shape system))

(defmethod (setf asdf/component:component-sideway-dependencies) :around
    (value (system system))
  "Parse the raw :depends-on at definition time, keep the records on
the manifest, and hand ASDF only the load requirements."
  (let ((parsed (parse-dependency-list value)))
    (setf (dependencies system) parsed)
    (dolist (dependency parsed)
      (setf (dependency-manifest dependency) system))
    (call-next-method (mapcar #'load-requirement parsed) system)))
