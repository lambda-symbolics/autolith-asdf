# Examples

## greeting

One minimal lode: a skill, a context contribution, and a command.

Load it from a REPL started in the repository root:

```lisp
(push (truename #p".") asdf:*central-registry*)
(push (truename #p"examples/greeting/") asdf:*central-registry*)
(asdf:load-system "greeting")
```

The library records the three definitions against the lode:

```lisp
(autolith-asdf:lode-definitions (asdf:find-system "greeting"))
```

A lode with capabilities and no activation entry point activates from its
definitions alone:

```lisp
(defparameter *manager* (make-instance 'autolith-manager:manager))
(defparameter *run* (autolith-manager:activate *manager*
                                               (asdf:find-system "greeting")))
(autolith-manager:run-status *run*)
(gethash "greeting" (autolith-manager:manager-installed-definitions *manager*))
(autolith-manager:deactivate *manager* *run*)
```