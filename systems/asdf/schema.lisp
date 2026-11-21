;;;; schema.lisp --- the shape error condition and the parsed records.

(in-package :autolith-asdf)

(define-condition shape-error (asdf:system-definition-error)
  ((form :initarg :form :initform nil :reader shape-error-form)
   (reason :initarg :reason :reader shape-error-reason))
  (:report (lambda (condition stream)
             (format stream "Manifest shape error: ~A~%  in entry: ~S"
                     (shape-error-reason condition)
                     (shape-error-form condition)))))

(defun shape-error (form reason)
  "Signal a definition-time shape error for the dependency entry FORM."
  (error 'shape-error :form form :reason reason))

(defclass ref ()
  ((kind :initarg :kind :reader ref-kind)
   (designator :initarg :designator :reader ref-designator))
  (:documentation "One ref in a sourced dependency entry. KIND is one of the keywords :tag, :branch, :commit; DESIGNATOR is a string."))

(defclass pin ()
  ((kind :initarg :kind :reader pin-kind)
   (value :initarg :value :reader pin-value))
  (:documentation "One pin in a sourced dependency entry. KIND is :git-hash or :content-digest; VALUE is a string."))

(defclass dependency ()
  ((name :initarg :name :reader dependency-name)
   (form :initarg :form :reader dependency-form)
   (manifest :initform nil :accessor dependency-manifest)
   (min-version :initform nil :initarg :min-version :reader dependency-min-version)
   (source-kind :initform nil :initarg :source-kind :reader dependency-source-kind)
   (location :initform nil :initarg :location :reader dependency-location)
   (ref :initform nil :initarg :ref :reader dependency-ref)
   (pin :initform nil :initarg :pin :reader dependency-pin))
  (:documentation "One :depends-on entry of a manifest. FORM is one of the keywords :plain, :versioned, :sourced. MANIFEST points back to the declaring system."))
