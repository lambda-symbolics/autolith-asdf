;;;; test.lisp --- shape checks for the autolith-asdf manifest schema.

(defpackage :autolith-asdf-test
  (:use :common-lisp)
  (:import-from :autolith-asdf
                #:system
                #:activation
                #:capabilities
                #:activation-depends-on
                #:dependencies
                #:shape-error
                #:dependency-name
                #:dependency-form
                #:dependency-manifest
                #:dependency-min-version
                #:dependency-source-kind
                #:dependency-location
                #:dependency-ref
                #:dependency-pin
                #:ref-kind
                #:ref-designator
                #:pin-kind
                #:pin-value)
  (:export #:run-all-tests))

(in-package :autolith-asdf-test)

(defparameter *passed* 0)
(defparameter *failures* nil)

(defun record-pass ()
  (incf *passed*))

(defun record-failure (name note)
  (push (format nil "~A: ~A" name note) *failures*))

(defun check (name asserted)
  (if asserted
      (record-pass)
      (record-failure name "assertion failed")))

(defun check-shape-error (name thunk)
  "Run THUNK and pass when it signals SHAPE-ERROR."
  (handler-case
      (progn
        (funcall thunk)
        (record-failure name "no shape error was signaled"))
    (shape-error ()
      (record-pass))
    (error (condition)
      (record-failure name (format nil "wrong error: ~A" condition)))))
(defun check-definition-error (name thunk)
  "Run THUNK and pass when it signals a system definition error."
  (handler-case
      (progn
        (funcall thunk)
        (record-failure name "no error was signaled"))
    (asdf:system-definition-error ()
      (record-pass))
    (error (condition)
      (record-failure name (format nil "wrong error: ~A" condition)))))

(defun run-all-tests ()
  (setf *passed* 0 *failures* nil)
  (mapc #'funcall
        (list #'test-plain-entry
              #'test-versioned-entry
              #'test-sourced-entry
              #'test-option-shapes
              #'test-wrong-kind-options
              #'test-slot-shapes
                #'test-definition-hook
                #'test-absent-slots
                #'test-duplicate-names
                #'test-load-requirements))
  (format *standard-output* "~&autolith-asdf: ~A passed, ~A failed.~%"
          *passed* (length *failures*))
  (dolist (failure *failures*)
    (format *error-output* "FAIL ~A~%" failure))
  (when *failures*
    (error "autolith-asdf tests failed")))

(defun parse (entries)
  (autolith-asdf::parse-dependency-list entries))

(defun test-plain-entry ()
  (let ((dependencies (parse '("alexandria" :fiveam))))
    (check "plain entry count" (= (length dependencies) 2))
    (check "plain entry name"
           (string= (dependency-name (first dependencies)) "alexandria"))
    (check "plain entry form"
           (eq (dependency-form (first dependencies)) :plain))
      (check "plain keyword name coerced"
             (string= (dependency-name (second dependencies)) "fiveam"))
    (check "plain keyword form"
           (eq (dependency-form (second dependencies)) :plain)))
  (check-shape-error "plain entry with a non-name"
    (lambda () (parse '(42))))
  (check-shape-error "nil entry"
    (lambda () (parse '(nil)))))

(defun test-versioned-entry ()
  (let ((dependencies (parse '((:version "fiveam" "1.4")))))
    (check "versioned entry count" (= (length dependencies) 1))
    (check "versioned entry name"
           (string= (dependency-name (first dependencies)) "fiveam"))
    (check "versioned entry form"
           (eq (dependency-form (first dependencies)) :versioned))
    (check "versioned entry minimum"
           (string= (dependency-min-version (first dependencies)) "1.4")))
  (check-shape-error "version entry with one argument"
    (lambda () (parse '((:version "a")))))
  (check-shape-error "version entry with a symbol minimum"
    (lambda () (parse '((:version "a" b)))))
  (check-shape-error "asdf-native version form is out of grammar"
    (lambda () (parse '(("a" :version "1.0"))))))

(defun test-sourced-entry ()
  (let ((dependency
            (first (parse '(("pu" :git "github.com/example/pu"
                             :ref (:tag "v1.1.0") :hash "a91c04f0"))))))
    (check "sourced entry name" (string= (dependency-name dependency) "pu"))
    (check "sourced entry form" (eq (dependency-form dependency) :sourced))
    (check "sourced entry kind" (eq (dependency-source-kind dependency) :git))
    (check "sourced entry location"
           (string= (dependency-location dependency) "github.com/example/pu"))
    (check "sourced entry ref kind"
           (eq (ref-kind (dependency-ref dependency)) :tag))
    (check "sourced entry ref designator"
           (string= (ref-designator (dependency-ref dependency)) "v1.1.0"))
    (check "sourced entry pin kind"
           (eq (pin-kind (dependency-pin dependency)) :git-hash))
    (check "sourced entry pin value"
           (string= (pin-value (dependency-pin dependency)) "a91c04f0")))
  (let ((dependency
            (first (parse '(("arc" :http "https://example.com/a.tgz"
                            :hash "sha256-abc"))))))
    (check "http pin kind"
           (eq (pin-kind (dependency-pin dependency)) :content-digest)))
  (let ((dependency
            (first (parse '(("loc" :file "/opt/lodes/loc"))))))
    (check "file entry kind" (eq (dependency-source-kind dependency) :file))
    (check "file entry has no ref" (null (dependency-ref dependency)))
    (check "file entry has no pin" (null (dependency-pin dependency))))
  (let ((dependency
            (first (parse '(("c" :nix "nixpkgs#c"
                             :ref (:branch "main") :hash "abc"
                             :version "2.0"))))))
    (check "custom kind ref"
           (eq (ref-kind (dependency-ref dependency)) :branch))
    (check "custom kind minimum"
           (string= (dependency-min-version dependency) "2.0")))
  (let ((dependency
            (first (parse '(("d" :git "url" :hash "abc"
                               :ref (:commit "def")))))))
    (check "free option order"
           (eq (ref-kind (dependency-ref dependency)) :commit)))
  (let ((dependency
            (first (parse '(("e" :git "url" :version "1.0"))))))
    (check "sourced entry minimum"
           (string= (dependency-min-version dependency) "1.0"))))

(defun test-option-shapes ()
  (check-shape-error "repeated option key"
      (lambda () (parse '(("a" :git "u" :hash "h" :hash "h2")))))
  (check-shape-error "unknown option key"
      (lambda () (parse '(("a" :git "u" :pin "x")))))
  (check-shape-error "ref form with one element"
      (lambda () (parse '(("a" :git "u" :ref (:tag))))))
  (check-shape-error "unknown ref kind"
      (lambda () (parse '(("a" :git "u" :ref (:bogus "x"))))))
  (check-shape-error "ref designator not a string"
      (lambda () (parse '(("a" :git "u" :ref (:tag 42))))))
  (check-shape-error "pin value not a string"
      (lambda () (parse '(("a" :git "u" :hash 42)))))
  (check-shape-error "option minimum not a string"
      (lambda () (parse '(("a" :git "u" :version 1.0)))))
  (check-shape-error "kind not a keyword"
    (lambda () (parse '(("a" "git" "u")))))
  (check-shape-error "location not a string"
      (lambda () (parse '(("a" :git 42)))))
  (check-shape-error "odd option tail"
      (lambda () (parse '(("a" :git "u" :ref)))))
  (check-shape-error "name not a designator"
    (lambda () (parse '((42 :git "u"))))))

(defun test-wrong-kind-options ()
  (check-shape-error "http source with a ref"
      (lambda () (parse '(("a" :http "u.tgz" :ref (:tag "v1"))))))
  (check-shape-error "file source with a pin"
      (lambda () (parse '(("a" :file "/opt/x" :hash "h")))))
  (check-shape-error "file source with a ref"
      (lambda () (parse '(("a" :file "/opt/x" :ref (:branch "main"))))))
  (check "http source accepts a pin"
      (not (null (parse '(("a" :http "u.tgz" :hash "d")))))))

(defun test-slot-shapes ()
  (check-shape-error "activation not a string"
    (lambda ()
      (asdf:defsystem "autolith-asdf-shape-bad-activate"
        :class "autolith-asdf:system"
        :activate 42)))
  (check-shape-error "capability not a name"
    (lambda ()
      (asdf:defsystem "autolith-asdf-shape-bad-capability"
        :class "autolith-asdf:system"
        :capabilities (:tools 42))))
  (check-shape-error "activation dependency not a name"
    (lambda ()
      (asdf:defsystem "autolith-asdf-shape-bad-actdep"
        :class "autolith-asdf:system"
        :activation-depends-on (42)))))

(defun test-definition-hook ()
  (asdf:defsystem "autolith-asdf-shape-ok"
    :class "autolith-asdf:system"
    :version "1.0.0"
    :depends-on ("alexandria"
                 ("pu" :git "github.com/example/pu"
                  :ref (:tag "v1.1.0") :hash "a91c04f0")
                 (:version "fiveam" "1.4"))
    :activate "autolith-asdf-shape-ok:activate"
    :capabilities (:tools :skills)
    :activation-depends-on ("pu"))
  (let ((manifest (asdf:find-system "autolith-asdf-shape-ok")))
    (check "depends-on rewritten to load requirements"
           (equal (asdf:system-depends-on manifest)
                  '("alexandria" "pu" (:version "fiveam" "1.4"))))
    (let ((parsed (dependencies manifest)))
      (check "dependency records kept" (= (length parsed) 3))
      (check "manifest back-pointer"
             (eq (dependency-manifest (first parsed)) manifest))
      (check "sourced record form"
             (eq (dependency-form (second parsed)) :sourced))
      (check "versioned record form"
             (eq (dependency-form (third parsed)) :versioned)))
    (check "activation slot"
           (string= (activation manifest) "autolith-asdf-shape-ok:activate"))
    (check "capabilities slot"
           (equal (capabilities manifest) '(:tools :skills)))
    (check "activation depends on slot"
           (equal (activation-depends-on manifest) '("pu"))))
  (check-definition-error "malformed depends-on fails definition"
    (lambda ()
      (asdf:defsystem "autolith-asdf-shape-bad-depends"
        :class "autolith-asdf:system"
          :depends-on ((:version "a")))))
  (check-shape-error "repeated option key fails definition"
    (lambda ()
      (asdf:defsystem "autolith-asdf-shape-bad-dupkey"
        :class "autolith-asdf:system"
        :depends-on (("a" :git "u" :hash "h" :hash "h2"))))))

(defun test-absent-slots ()
  (asdf:defsystem "autolith-asdf-absent-slots"
    :class "autolith-asdf:system"
    :version "0.1.0")
  (let ((manifest (asdf:find-system "autolith-asdf-absent-slots")))
    (check "activation absent is nil" (null (activation manifest)))
    (check "capabilities absent is nil" (null (capabilities manifest)))
    (check "activation depends on absent is nil"
           (null (activation-depends-on manifest)))
    (check "dependencies absent is nil" (null (dependencies manifest)))))

(defun test-duplicate-names ()
  (let ((dependencies (parse '("x" ("x" :git "url") "x"))))
    (check "duplicate names kept" (= (length dependencies) 3))
    (check "duplicate names equal"
           (every (lambda (d) (string= (dependency-name d) "x")) dependencies))
    (check "duplicate records distinct forms"
           (and (eq (dependency-form (first dependencies)) :plain)
                (eq (dependency-form (second dependencies)) :sourced)
                (eq (dependency-form (third dependencies)) :plain)))))

(defun test-load-requirements ()
  (let ((dependencies (parse '("x" (:version "x" "1.0") ("x" :git "url" :hash "h")))))
    (check "plain requirement is the name"
           (string= (autolith-asdf::load-requirement (first dependencies)) "x"))
    (check "versioned requirement keeps the version form"
           (equal (autolith-asdf::load-requirement (second dependencies))
                  '(:version "x" "1.0")))
    (check "sourced requirement is the name only"
           (string= (autolith-asdf::load-requirement (third dependencies)) "x"))))

;;;---------------------------------------------------------------------
;;; Lode definition records
;;;---------------------------------------------------------------------

(defun make-recording-lode (name capabilities)
  "One manifest for definition-recording tests."
  (make-instance 'autolith-asdf:system :name name :capabilities capabilities))

(defun test-definition-records ()
  (let ((lode (make-recording-lode "recording-lode" '(:skill :tool)))
        (handler (lambda (thing) thing)))
    (let ((skill (autolith-asdf:record-skill lode "greet" "Greets."
                                             "Say hi."
                                             :related '("wave"))))
      (check "record-skill class"
             (typep skill 'autolith-asdf:skill-definition))
      (check "skill name"
             (string= (autolith-asdf:definition-name skill) "greet"))
      (check "skill description"
             (string= (autolith-asdf:definition-description skill) "Greets."))
      (check "skill instructions"
             (string= (autolith-asdf:skill-instructions skill) "Say hi."))
      (check "skill related"
             (equal (autolith-asdf:definition-related skill) '("wave")))
      (check "skill attributed"
             (eq (autolith-asdf:definition-lode skill) lode)))
    (let ((tool (autolith-asdf:record-tool lode "run" "Runs." "(run thing)"
                                           handler)))
      (check "record-tool class"
             (typep tool 'autolith-asdf:tool-definition))
      (check "tool usage"
             (string= (autolith-asdf:tool-usage tool) "(run thing)"))
      (check "tool handler"
             (eq (autolith-asdf:tool-handler tool) handler)))
    (check "lode-definitions count"
           (= (length (autolith-asdf:lode-definitions lode)) 2))
    (check "lode-definitions order"
           (equal (mapcar #'autolith-asdf:definition-name
                          (autolith-asdf:lode-definitions lode))
                  '("greet" "run")))
    (check "find-definition finds any kind"
           (typep (autolith-asdf:find-definition lode "run")
                  'autolith-asdf:tool-definition))
    (check "find-definition misses"
           (null (autolith-asdf:find-definition lode "nope")))
    (check "symbol name records lowercase"
           (string= (autolith-asdf:definition-name
                     (autolith-asdf:record-skill lode 'sym "d" "i"))
                    "sym"))))

(defun test-definition-failures ()
  (let ((lode (make-recording-lode "failing-lode" '(:tool))))
    (check-definition-error "undeclared kind fails the load"
      (lambda () (autolith-asdf:record-skill lode "sneaky" "d" "i")))
    (check "tool records under a declared kind"
           (typep (autolith-asdf:record-tool lode "dup" "d" "u" #'identity)
                  'autolith-asdf:tool-definition))
    (check-definition-error "duplicate name fails the load"
      (lambda () (autolith-asdf:record-tool lode "dup" "d2" "u2" #'identity)))
    (check-definition-error "context kind undeclared"
      (lambda () (autolith-asdf:record-context lode "ctx" "d")))
    (check "failed records left no trace"
           (null (autolith-asdf:find-definition lode "sneaky")))))

;;;---------------------------------------------------------------------
;;; Lode load integration
;;;---------------------------------------------------------------------

(defun fixture-directory (name)
  "The directory that holds one fixture lode."
  (asdf:system-relative-pathname
   (asdf:find-system "autolith-asdf")
   (format nil "test/fixtures/~A/" name)))

(defun register-fixture-directory (name)
  "Make ASDF find one fixture lode's .asd file."
  (pushnew (fixture-directory name) asdf:*central-registry* :test #'equal))

(defun test-lode-load-integration ()
  (register-fixture-directory "definition-lode")
  (let ((warnings '()))
    (flet ((collect (condition)
             (push (princ-to-string condition) warnings)
             (muffle-warning condition)))
      (handler-bind ((warning #'collect))
        (asdf:load-system "definition-lode"))
      (let* ((lode (asdf:find-system "definition-lode"))
             (definitions (autolith-asdf:lode-definitions lode)))
        (check "fixture records three definitions"
               (= (length definitions) 3))
        (check "fixture definitions attributed to the lode"
               (every (lambda (d) (eq (autolith-asdf:definition-lode d) lode))
                      definitions))
        (check "fixture skill related links"
               (equal (autolith-asdf:definition-related
                       (autolith-asdf:find-definition lode "greet"))
                      '("wave" "ghost")))
        (check "fixture defcommand recorded a handler"
               (functionp (autolith-asdf:tool-handler
                           (autolith-asdf:find-definition lode "run"))))
        (check "unused kind warns"
               (some (lambda (w) (search "context" w)) warnings))
        (check "missing related name warns"
               (some (lambda (w) (search "ghost" w)) warnings)))
        (handler-bind ((warning #'collect))
          (let ((reload-lode (make-recording-lode "reload-lode" '(:skill))))
            (autolith-asdf:record-skill reload-lode "old" "Old." "Stale.")
            (autolith-asdf::begin-lode-load reload-lode)
            (autolith-asdf::end-lode-load reload-lode)
            (check "a lode load that starts again drops its stale records"
                   (null (autolith-asdf:find-definition reload-lode "old"))))))))
  (register-fixture-directory "definition-lode-bad")
  (check-definition-error "undeclared kind fails the lode load"
      (lambda () (asdf:load-system "definition-lode-bad")))
