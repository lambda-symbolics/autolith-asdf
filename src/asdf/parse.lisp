;;;; parse.lisp --- the :depends-on entry grammar.
;;;
;;; An entry is one of three forms. A plain entry is a name. A
;;; versioned entry is (:version name min-version). A sourced entry
;;; (a full entry) is (name kind location &key :ref :hash :version).
;;; Every shape failure signals SHAPE-ERROR; definition fails with it.

(in-package :autolith-asdf)

(defun coerce-system-name (name form)
  "Coerce a system name designator to a string, like ASDF does."
  (typecase name
    (string name)
    (symbol (string-downcase name))
    (t (shape-error form "the dependency name must be a string or a symbol"))))

(defun parse-ref (form)
  "Parse one ref form (:tag name), (:branch name), or (:commit hash)."
  (unless (and (listp form) (= (length form) 2))
    (shape-error form "a ref form must be one ref keyword and one designator string"))
  (let ((kind (first form))
        (designator (second form)))
    (unless (member kind '(:tag :branch :commit))
      (shape-error form "the ref kind must be :tag, :branch, or :commit"))
    (unless (stringp designator)
      (shape-error form "the ref designator must be a string"))
    (make-instance 'ref :kind kind :designator designator)))

(defun parse-versioned-entry (entry)
  (unless (and (listp entry) (= (length entry) 3))
    (shape-error entry "a version entry must be (:version name min-version)"))
  (let ((min-version (third entry)))
    (unless (stringp min-version)
      (shape-error entry "the version entry minimum must be a string"))
    (make-instance 'dependency
                   :name (coerce-system-name (second entry) entry)
                   :form :versioned
                   :min-version min-version)))

(defun parse-sourced-options (entry kind options)
  "Parse the trailing keyword options of a full entry. Options come in any order; each key appears at most once."
  (let ((ref nil) (pin nil) (min-version nil) (seen-keys nil))
    (unless (evenp (length options))
      (shape-error entry "the trailing options must be keyword-value pairs"))
    (loop for (key value) on options by #'cddr
          do (unless (keywordp key)
               (shape-error entry "an option key must be a keyword"))
             (when (member key seen-keys)
               (shape-error entry "an option key may appear only once"))
             (push key seen-keys)
             (case key
               (:ref
                (setf ref (parse-ref value)))
               (:hash
                (unless (stringp value)
                  (shape-error entry "the pin value must be a string"))
                (setf pin (make-instance 'pin
                                         :kind (if (eq kind :git)
                                                   :git-hash
                                                   :content-digest)
                                         :value value)))
               (:version
                (unless (stringp value)
                  (shape-error entry "the minimum version must be a string"))
                (setf min-version value))
               (otherwise
                (shape-error entry "the option key must be :ref, :hash, or :version"))))
    (values ref pin min-version)))

(defun check-sourced-option-kind (entry kind has-ref has-pin)
  "Reject wrong-kind options on the built-in kinds at definition time."
  (when (and (eq kind :http) has-ref)
    (shape-error entry "an http source accepts no :ref option"))
  (when (and (eq kind :file) (or has-ref has-pin))
    (shape-error entry "a file source accepts neither :ref nor :hash")))

(defun parse-sourced-entry (entry)
  (unless (and (listp entry) (>= (length entry) 3))
    (shape-error entry "a full entry must be (name kind location &key :ref :hash :version)"))
  (let ((kind (second entry)))
    (unless (keywordp kind)
      (shape-error entry "the source kind must be a keyword"))
    (when (member kind '(:version :ref :hash :feature :require))
      (shape-error entry "this keyword cannot name a source kind"))
    (let ((location (third entry)))
      (unless (stringp location)
        (shape-error entry "the source location must be a string"))
      (multiple-value-bind (ref pin min-version)
          (parse-sourced-options entry kind (nthcdr 3 entry))
        (check-sourced-option-kind entry kind ref pin)
        (make-instance 'dependency
                       :name (coerce-system-name (first entry) entry)
                       :form :sourced
                       :source-kind kind
                       :location location
                       :ref ref
                       :pin pin
                       :min-version min-version)))))

(defun parse-dependency-entry (entry)
  "Parse one :depends-on entry into a dependency record."
  (typecase entry
    (null
     (shape-error entry "a dependency entry must be a name or a list"))
    ((or string symbol)
     (make-instance 'dependency
                    :name (coerce-system-name entry entry)
                    :form :plain))
    (list
     (case (first entry)
       (:version
        (parse-versioned-entry entry))
       (:feature
        (shape-error entry "feature entries are not part of the manifest grammar"))
       (:require
        (shape-error entry "require entries are not part of the manifest grammar"))
       (otherwise
        (parse-sourced-entry entry))))
    (t
     (shape-error entry "a dependency entry must be a name or a list"))))

(defun parse-dependency-list (entries)
  "Parse every :depends-on entry. Duplicate names parse as separate records."
  (mapcar #'parse-dependency-entry entries))

(defun load-requirement (dependency)
  "The load requirement one parsed entry contributes: the name only. A versioned entry keeps its :version form so ASDF checks the version natively at load."
  (if (eq (dependency-form dependency) :versioned)
      (list :version (dependency-name dependency) (dependency-min-version dependency))
      (dependency-name dependency)))
