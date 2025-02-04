;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(pkg:define-package :screenshotbot/git-repo
    (:use #:cl
          #:alexandria)
  (:import-from #:./user-api
                #:commit-link)
  (:export #:generic-git-repo
           #:commit-graph
           #:get-parent-commit
           #:repo-ancestor-p
           #:public-repo-p
           #:repo-link
           #:commit-link

           ;; forward declarations
           #:find-or-create-commit-graph
           #:commit-graph-dag))


(defclass generic-git-repo ()
  ((link :initarg :link
         :accessor repo-link)
   (company :initarg :company
            :accessor company)))

(defmethod commit-graph ((repo generic-git-repo))
  (find-or-create-commit-graph
   (company repo)
   (repo-link repo)))

(defmethod get-parent-commit ((repo generic-git-repo)
                              commit)
  (declare (optimize (debug 3)))
  (assert commit)
  (let* ((dag (commit-graph-dag (commit-graph repo))))
    (let ((commit (dag:get-commit dag commit)))
      (car (dag:parents commit)))))

(defmethod repo-ancestor-p ((repo generic-git-repo)
                            commit
                            branch-commit)
  (dag:ancestorp (commit-graph-dag (commit-graph repo))
                 commit
                 branch-commit))

(defmethod public-repo-p ((repo generic-git-repo))
  nil)

(defmethod commit-link ((repo generic-git-repo) hash)
  "#")
