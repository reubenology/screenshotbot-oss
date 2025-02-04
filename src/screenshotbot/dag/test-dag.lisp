;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(defpackage :screenshotbot.dag.test-dag
  (:use #:cl
        #:dag
        #:alexandria
        #:fiveam)
  (:import-from #:dag
                #:dag
                #:merge-dag
                #:get-commit
                #:commit
                #:node-already-exists
                #:add-commit))

(in-package :screenshotbot.dag.test-dag)

(def-suite* :screenshotbot.dag.test-dag)

(def-fixture state ()
  (let ((dag (make-instance 'dag)))
    (flet ((add-edge (from to)
             (add-commit dag (make-instance 'commit :sha from :parents (cond
                                                                         ((listp to)
                                                                          to)
                                                                         (t (list to)))))))
      (add-edge "bb" nil)
      (add-edge "aa" "bb")
      (&body))))

(defun make-big-linear-dag ()
  (let* ((num 100)
         (dag (make-instance 'dag))
         (commits (loop for i from 1 to num collect
                                            (format nil "~4,'0X" i)))
         (fns nil))
    (flet ((add-edge (from to)
             (add-commit dag (make-instance 'commit :sha from :parents (cond
                                                                         ((listp to)
                                                                          to)
                                                                         (t (list to)))))))
      (loop for to in commits
            for from in (cdr commits)
            do
               (let ((to to) (from from))
                 (push
                  (lambda ()
                    (add-edge from to))
                  fns)))

      (add-edge (car commits) nil))

    (loop for fn in (reverse fns)
          do (funcall fn))

    (values dag commits)))

(defmacro pp (x)
  `(let ((y ,x))
     (log:info "Got ~S for ~S" y ',x)
     y))

(test preconditions
  (with-fixture state ()
    (pass)))

(test wont-let-me-add-cycles
  (with-fixture state ()
    (signals node-already-exists
      (add-edge "bb" nil))))

(test serialize
  (with-fixture state ()
    (let ((json (with-output-to-string (s)
                  (write-to-stream dag s))))
      (is (equal `(((:sha . "bb")
                    (:parents . nil))
                   ((:sha . "aa")
                    (:parents . ,(list "bb"))))
                 (assoc-value (json:decode-json-from-string json)
                              :commits))))))

(test read
  (with-fixture state ()
    (let ((json (with-output-to-string (s)
                  (write-to-stream dag s))))
      (let ((dag (read-from-stream (make-string-input-stream json))))
        (is (equal `(((:sha . "bb")
                      (:parents . nil))
                     ((:sha . "aa")
                      (:parents . ,(list "bb"))))
                   (assoc-value (json:decode-json-from-string
                                 (with-output-to-string (s)
                                   (write-to-stream dag s)))
                                :commits)))))))

(test merge-dag
  (with-fixture state ()
    (let ((to-dag (make-instance 'dag)))
      (merge-dag to-dag dag)
      (is-true (get-commit to-dag "aa"))
      (is-true (get-commit to-dag "bb"))
      (uiop:with-temporary-file (:stream s :pathname p)
        (dag:write-to-stream to-dag s)
        (with-open-file (input p :direction :input)
          (let ((re-read (dag:read-from-stream input)))
            (is-true (get-commit re-read "aa"))
            (is-true (get-commit re-read "bb"))))))))

(test big-dag-topological-sort
  (multiple-value-bind (dag commits) (make-big-linear-dag)
    (let ((final-order (loop for x in (assoc-value
                                       (json:decode-json-from-string
                                        (with-output-to-string (s)
                                          (write-to-stream dag s)))
                                       :commits)
                             collect (assoc-value x :sha))))
      (is (equal final-order commits)))))

(test add-edge-directly-from-graph
  (with-fixture state ()
    (is (equal '((#xaa #xbb))
                (gethash #xaa (graph::node-h (dag::digraph dag)))))))
