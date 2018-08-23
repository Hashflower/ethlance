;;;; Usage: ensure ethlance.el is on your load-path
;;;; i.e: M-: (add-to-list 'load-path "/path/to/ethlance/checkout")
;;;; then require ethlance `M-x load-library ethlance`
;;;;
;;;; (once): customize ethlance-root
;;;; M-x customize-variable ethlance-root
;;;; Set to same path as checkout dir above
;;;;
;;;; Add to Emacs init:
;;;; (add-to-list 'load-path "/path/to/ethlance/checkout")
;;;; (load-library "ethlance")
;;;;
;;;; use M-x ethlance-jack-in to jack-in a Clojure and ClojureScript REPL
;;;;     M-x ethlance-start to start auto-compiling Solidity and testrpc
;;;;     M-x ethlance-quit to quit all processes
;;;;
;;;; Notes:
;;;;
;;;; testrpc has been replaced by ganache-cli, a workaround:
;;;; - remove testrpc
;;;; - install ganache-cli
;;;; - run command as root `ln -s /usr/bin/ganache-cli /usr/bin/testrpc`
;;;;
;;;; TODO: Replace testrpc calls with ganache-cli calls.


(defcustom ethlance-root
  "/please/set/ethlance-root"
  "The root directory of the Ethlance repo.")

(defun start-compile-solidity-auto ()
  (message "Starting auto-compiling Solidity Smart Contracts")
  (start-process-shell-command "compile-solidity"
                               "*compile-solidity*"
                               (concat "cd " ethlance-root " && " "lein auto compile-solidity")))


(defun start-testrpc ()
  (message "Starting testrpc...")
  (start-process-shell-command "testrpc"
                               "*testrpc*"
                               (concat "cd " ethlance-root " && "  "lein start-testrpc")))


(defun stop-compile-solidity-auto ()
  (message "Stopping auto-compiling Solidity Smart Contracts")
  (when-let ((buf (get-buffer "*compile-solidity*")))
    (kill-buffer buf)))

(defun stop-testrpc ()
  (message "Stopping testrpc...")
  (when-let ((buf (get-buffer "*testrpc*")))
    (kill-buffer buf)))

(defun quit-cider (repl-buffer)
  (set-buffer repl-buffer)
  ;; essence of cider-interaction.el
  (cider--quit-connection (cider-current-connection))
  (unless (cider-connected-p)
    (cider-close-ancillary-buffers))
  (message (format "Quit %s" (car p))))

(defun ethlance-jack-in* ()
  (message "Jack in REPL")
  ;; Not Required: you can include project-dir in later version of cider
  ;;(find-file (concat ethlance-root "/project.clj"))
  (cider-jack-in-clojurescript `(:project-dir ,ethlance-root
                                 :cljs-repl-type "figwheel")))

(defun ethlance-jack-in ()
  (interactive)
  (ethlance-jack-in*))

(defun ethlance-start ()
  (interactive)
  (message "Autocompile Solidity Smart Contracts")
  (start-compile-solidity-auto)
  (start-testrpc))

(defun ethlance-stop ()
  (interactive)
  (stop-compile-solidity-auto)
  (stop-testrpc))

(defun ethlance-project-repl (&optional cljs-repl)
  (get-buffer (concat "*cider-repl " (when cljs-repl "CLJS ") "ethlance*")))

(defun ethlance-quit ()
  (interactive)
  (stop-compile-solidity-auto)
  (stop-testrpc)
  (when-let ((repl-buffer (ethlance-project-repl)))
    (quit-cider repl-buffer))
  (when-let ((cljs-repl-buffer (ethlance-project-repl t)))
    (quit-cider cljs-repl-buffer)))

(provide 'ethlance)
