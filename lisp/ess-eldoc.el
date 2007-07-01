;;; ess-eldoc.el --- Use eldoc to report R function names.
;;; 2007-06-30 Stephen Eglen
;;; GPL.

;;; Commentary:

;; This is an initial attempt to use the emacs facility ELDOC in R
;; buffers.  Eldoc is used in Emacs lisp buffers to show the function
;; arglist and docstrings for variables.  To try it, view an emacs
;; lisp buffer, and then do M-x turn-on-eldoc-mode, and move over
;; function and variable namess.

;; This file extends eldoc to work in R buffers.  It currently uses
;; Sven's essd-r-args.el file to retrieve args for a given R function
;; (via ess-r-args-get).  Note that it works slightly different to
;; Sven's code, in that you just need to have the point over the name
;; of an R function, or inside its arguments list, for eldoc to show
;; the arg list.


;; To use this functionality, simply add 
;;
;; (require 'ess-eldoc)
;;
;; to your .emacs file.  When you visit a R mode, eldoc will be turned
;; on.  However, you will first need to associate the R buffer with an
;; *R* process so that args can be looked up -- otherwise, eldoc will
;; silently not report anything.  So, e.g. try:
;; C-x C-f somefile.R
;; M-x R   (so that somefile.R is associated with *R*)
;; eldoc should then work.

;; e.g. put the following rnorm() command in an R buffer.  The line
;; underneath shows a key of what arg list will be shown as you move
;; across the rnorm line.

;; rnorm(n=100, mean=sqrt(20), sd=10)
;; 1111111111111222223333333311444111
;; 1: rnorm
;; 2: mean
;; 3: sqrt
;; 4: sd
;;

;; Note that the arg list for rnorm() should be shown either when you
;; are on the function name, or in the arg list.  However, since the
;; 2nd and 3rd arguments are also function names, the arg lists of
;; those function names are reported instead.  This might be seen as
;; undesirable behaviour, in which case a solution would be to only
;; look up the function name if it is followed by (.

;; In the current version, I do not cache the arg list, but that was
;; done in an earlier version, to save repeated calls to
;; ess-r-args-get.

;; This code has been tested only in Emacs 22.1.

;; Bug (in eldoc?): the arg list for legend() is too long to fit in
;; minibuffer, and it seems that we see the last N lines of the arg
;; list, rather than the first N lines.  It would be better to see the
;; first N lines since the more important args come first.

;; Doc issue: the eldoc vars (e.g. eldoc-echo-area-use-multiline-p)
;; work only for elisp mode.

;; If *R* is currently busy (e.g. processing Sys.sleep(999)), then the
;; eldoc commands won't work; ess-command could be silenced in this
;; regard perhaps with a new SILENT arg for example to prevent the
;; call to (ess-error).


;;; Code:

;; This could be done on buffer local basis.
(setq ess-r-args-noargsmsg "")

;; following two defvars are not currently used.
(defvar ess-eldoc-last-name nil
  "Name of the last function looked up in eldoc.
We remember this to see whether we need to look up documentation, or used 
the cached value in `ess-eldoc-last-args'.")

(defvar ess-eldoc-last-args nil
  "Args list last looked up for eldoc.  Used as cache.")

(defun ess-eldoc ()
  "Return the doc string, or nil.
If an ESS process is not associated with the buffer, do not try
to look up any doc strings."
  (interactive)
  (let ((doc nil)
	name)
    (when ess-current-process-name
      (setq name (ess-guess-fun))		;guess the word at point.
      (unless (= (length name) 0) 
	;; look up function name at point.
	(setq doc (ess-r-args-get name)))
      (unless doc
	;; no function found at point; see if we are in a arg-list
	;; of a function.
	(save-excursion
	  (condition-case nil 
	      (progn 
		(up-list -1)
		(setq doc (ess-r-args-get (ess-guess-fun))))
	    ;; error handler -- not possible to go up one list level.
	    (error nil) ))))
    doc))
  
(defun ess-eldoc-2 ()
  ;; simple, old version.
  (interactive)
  (ess-r-args-get (ess-read-object-name-default)))

(defun ess-eldoc-1 ()
  "Return the doc string, or nil.
This is the first version; works only on function name, not within arg list."
  (interactive)

  ;; Possible ways to get the function at point.
  ;;(setq name (thing-at-point 'sexp))
  ;;(setq name (ess-read-object-name-default))
  ;;(setq name (find-tag-default))

  (if ess-current-process-name
      (progn
	(setq name (ess-guess-fun))		;guess the word at point.
	(if (equal (length name) 0) 
	    nil
	  ;; else 
	  (unless (equal name ess-eldoc-last-name)
	    ;; name is different to the last name we lookedup, so get
	    ;; new args from R and store them.
	    (setq ess-eldoc-last-args (ess-r-args-get name)
		  ess-eldoc-last-name name))
	  ess-eldoc-last-args))
    ;; no ESS process current.
    nil)
)


(defsubst ess-guess-fun ()
  "Guess what the function at point is."
  ;; Derived from Man-default-man-entry in man.el
  (let (word)
    (save-excursion
      (skip-chars-backward "-a-zA-Z0-9._+:")
      (let ((start (point)))
	(skip-chars-forward "-a-zA-Z0-9._+:")
	(setq word (buffer-substring-no-properties start (point)))))
      word))

(defun ess-use-eldoc ()
  "Switch on eldoc for ESS (R mode only)."
  (interactive)
  (when (equal ess-dialect "R")
    (set (make-local-variable 'eldoc-documentation-function) 'ess-eldoc)
    (eldoc-mode t)))

;; For now, while testing, switch on ess-eldoc.  Later, ths could be removed
;; and instead ask user to add it.
(add-hook 'ess-mode-hook 'ess-use-eldoc)

(provide 'ess-eldoc)