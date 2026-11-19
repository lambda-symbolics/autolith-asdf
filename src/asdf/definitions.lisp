;;;; definitions.lisp --- lode definition records, the registry, and the
;;;; definition forms.
;;;
;;; The lode author writes defskill, defcommand, and defcontext forms in
;;; the lode's source. The library records each form against the lode
;;; that owns the loaded file, checks each definition's kind against the
;;; manifest's capabilities, and fails the load on an undeclared kind or
;;; a duplicate name. At the end of the load the library warns about
;;; declared kinds with no recorded definition and about related names
;;; with no matching definition in the lode.
;;; (spec: src/asdf/module.allium, contract LodeDefinitions.)

(in-package :autolith-asdf)

;;;---------------------------------------------------------------------
;;; Definition records
;;;---------------------------------------------------------------------

(defclass definition ()
  ((lode :initarg :lode :reader definition-lode)
   (name :initarg :name :reader definition-name)
   (description :initarg :description :reader definition-description)
   (related :initarg :related :initform nil :reader definition-related))
  (:documentation
   "One recorded definition of one lode. Each definition records under
the lode that owns the file that defined it. Within one lode each
definition name is unique across the three kinds."))

(defclass skill-definition (definition)
  ((instructions :initarg :instructions :reader skill-instructions))
  (:documentation "One recorded skill: the instruction text the model follows."))

(defclass tool-definition (definition)
  ((usage :initarg :usage :reader tool-usage)
   (handler :initarg :handler :reader tool-handler))
  (:documentation
   "One recorded application command. The handler is the function the
defcommand body defined."))

(defclass context-definition (definition)
  ()
  (:documentation
   "One recorded context contribution. The defcontext form is pending;
this kind records the common fields first (spec open question)."))

;;;---------------------------------------------------------------------
;;; Load failures
;;;---------------------------------------------------------------------

(define-condition definition-error (asdf:system-definition-error)
  ((lode :initarg :lode :reader definition-error-lode)
   (name :initarg :name :reader definition-error-name)
   (reason :initarg :reason :reader definition-error-reason))
  (:report (lambda (condition stream)
             (format stream "Lode definition error: ~A~%  lode: ~A, name: ~A"
                     (definition-error-reason condition)
                     (definition-error-lode condition)
                     (definition-error-name condition))))
  (:documentation "A recorded definition fails the load."))

(defun definition-error (lode name reason)
  "Signal one load-time definition failure for LODE."
  (error 'definition-error :lode lode :name name :reason reason))

;;;---------------------------------------------------------------------
;;; The registry
;;;---------------------------------------------------------------------

(defvar *definitions* (make-hash-table :test #'eq)
  "Recorded definitions, keyed by lode. Each value holds the lode's
definitions, newest first.")

(defvar *current-lode* nil
  "The lode that owns the file currently being loaded. The load-op
:around method below binds it while each source file of a lode loads.")

(defun lode-definitions (lode)
  "The definitions LODE recorded, in load order."
  (nreverse (gethash lode *definitions*)))

(defun find-definition (lode name)
  "The definition LODE recorded under NAME, of any kind, or NIL."
  (find name (gethash lode *definitions*)
        :key #'definition-name :test #'string=))

(defun clear-definitions (lode)
  "Drop every definition LODE recorded. A lode load that starts again
calls this, so records never outlive their source files."
  (remhash lode *definitions*))

(defun name-designator (lode name)
  "One definition name: a string stays, a symbol reads as lowercase."
  (typecase name
    (string name)
    (symbol (string-downcase name))
    (t (definition-error lode name
                         "a definition name must be a string or a symbol"))))

(defun related-designators (lode related)
  "Coerce every related name to its recorded form."
  (mapcar (lambda (name) (name-designator lode name)) related))

(defun check-kind-declared (lode kind name)
  "An undeclared kind fails the load (spec: KindsCheckedAtLoad)."
  (unless (member kind (capabilities lode) :test #'string-equal)
    (definition-error lode name
        (format nil "the manifest does not declare the ~A capability"
                    (string-downcase kind)))))

(defun check-name-free (lode name)
  "A duplicate name fails the load (spec: NamesUniquePerLode)."
  (when (find-definition lode name)
    (definition-error lode name
                      "the lode already records a definition under this name")))

(defun record-skill (lode name description instructions &key (related '()))
  "Record one skill the lode author defined (spec: rule RecordSkill)."
  (let ((name (name-designator lode name))
        (related (related-designators lode related)))
    (check-kind-declared lode :skill name)
    (check-name-free lode name)
    (let ((skill (make-instance 'skill-definition :lode lode :name name
                                :description description
                                :instructions instructions
                                :related related)))
      (push skill (gethash lode *definitions*))
      skill)))

(defun record-tool (lode name description usage handler &key (related '()))
  "Record one application command the lode author defined (spec: rule
RecordTool). HANDLER is the function the defcommand body defined."
  (let ((name (name-designator lode name))
        (related (related-designators lode related)))
    (check-kind-declared lode :tool name)
    (check-name-free lode name)
    (let ((tool (make-instance 'tool-definition :lode lode :name name
                               :description description :usage usage
                               :handler handler :related related)))
      (push tool (gethash lode *definitions*))
      tool)))

(defun record-context (lode name description &key (related '()))
  "Record one context contribution the lode author defined (spec: rule
RecordContext)."
  (let ((name (name-designator lode name))
        (related (related-designators lode related)))
    (check-kind-declared lode :context name)
    (check-name-free lode name)
    (let ((context (make-instance 'context-definition :lode lode :name name
                                  :description description :related related)))
      (push context (gethash lode *definitions*))
      context)))

;;;---------------------------------------------------------------------
;;; End-of-load checks
;;;---------------------------------------------------------------------

(defun kind-of (definition)
  "The capability name of one definition's kind."
  (typecase definition
      (skill-definition :skill)
      (tool-definition :tool)
      (context-definition :context)))

(defun finish-lode-load (lode)
  "Report at the end of one lode's load (spec: UnusedKindWarns,
RelatedLinksQueryable). A declared kind with no recorded definition
warns. A related name with no matching definition in the lode warns."
  (let ((definitions (lode-definitions lode)))
    (dolist (kind '(:skill :tool :context))
      (when (and (member kind (capabilities lode) :test #'string-equal)
                 (notany (lambda (d) (eq (kind-of d) kind)) definitions))
        (warn "The lode ~A declares the ~A capability but no ~A definition was recorded."
              (asdf:component-name lode)
              (string-downcase kind) (string-downcase kind))))
    (dolist (definition definitions)
      (dolist (related (definition-related definition))
        (unless (find-definition lode related)
          (warn "The ~A ~A of lode ~A relates to ~A, which is not defined in this lode."
                  (string-downcase (kind-of definition)) (definition-name definition)
                (asdf:component-name lode) related)))))
  (values))

;;;---------------------------------------------------------------------
;;; Definition forms
;;;---------------------------------------------------------------------

(defun current-lode ()
  "The lode that owns the file being loaded."
  (or *current-lode*
      (error "no lode owns this load: a definition form ran outside a lode load")))

(defmacro defskill (name description instructions &key (related '()))
  "Record one skill against the lode that owns this file."
  `(record-skill (current-lode) ,name ,description ,instructions
                 :related ,related))

(defmacro defcommand (name description usage related arguments &body body)
  "Define the command's handler function and record the command against
the lode that owns this file. NAME is a symbol."
  `(progn
     (defun ,name ,arguments ,@body)
     (record-tool (current-lode) ',name ,description ,usage
                  (fdefinition ',name) :related ,related)))

(defmacro defcontext (name description &key (related '()))
  "Record one context contribution against the lode that owns this
file. Pending: the full defcontext form (spec open question); this
form records the common fields first."
  `(record-context (current-lode) ,name ,description :related ,related))

;;;---------------------------------------------------------------------
;;; ASDF load integration
;;;---------------------------------------------------------------------

(defun component-lode (component)
  "The lode that owns COMPONENT, or NIL when its system is not a lode."
  (loop for parent = (asdf/component:component-parent component)
          then (asdf/component:component-parent parent)
        while parent
        when (typep parent 'system)
          return parent))

(defmethod asdf:perform :around ((op asdf:load-op)
                                 (file asdf:cl-source-file))
  "Bind *current-lode* to the lode that owns FILE while it loads, so
every definition form in the file attributes its record to that lode
(spec: DefinitionsAttributed)."
  (let ((lode (component-lode file)))
    (if lode
        (let ((*current-lode* lode)) (call-next-method))
        (call-next-method))))

(defmethod asdf:perform :before ((op asdf:load-op) (s system))
  "A lode load that starts again drops the lode's stale records first."
  (clear-definitions s))

(defmethod asdf:perform :after ((op asdf:load-op) (s system))
  "Report the end-of-load definition checks for one lode."
  (finish-lode-load s))