(pkg:define-package :screenshotbot/github/access-checks
    (:use #:cl
          #:alexandria
          #:./github-installation)
  (:import-from #:../java
                #:java-syntax
                #:read-java-field
                #:java-list->list
                #:new-instance)
  (:import-from #:bknr.datastore
                #:persistent-class
                #:store-object
                #:unique-index)
  (:import-from #:../secret
                #:defsecret
                #:secret)
  (:import-from #:../model
                #:github-repo
                #:repo-left-ancestor-p)
  (:import-from #:../git-repo
                #:get-parent-commit
                #:repo-link
                #:commit-link
                #:generic-git-repo)
  (:import-from #:./webhook
                #:github-installation-with-repo-name
                #:installation-id)
  (:export #:github-repo
           #:github-user-service
           #:github-repos-for-user
           #:github-org-service
           #:github-repo-id
           #:github-star-service
           #:github-client
           #:get-repo-id
           #:with-throttler
           #:throttler
           #:with-cache)

  ;; forward decls
  (:export #:fix-github-link))

(import 'repo-name)

(named-readtables:in-readtable java-syntax)

;; TODO: security

(defclass throttler ()
  ((lock :initform (bt:make-lock)
         :reader throttler-lock)
   (last-ts :initform (local-time:now))))

(defparameter *github-throttler* (make-instance 'throttler))

(defun %with-throttler (throttler fn)
  (bt:with-lock-held ((throttler-lock throttler))
    (with-slots (last-ts) throttler
      (loop while (local-time:timestamp> last-ts (local-time:timestamp- (local-time:now) 0.8 :sec))
            do (progn
                 (log:debug "Waiting for throttling lock")
                 (sleep 0.2)))
      (setf last-ts (local-time:now))))
  (funcall fn))

(defmacro with-throttler ((throttler) &body body)
  `(flet ((body () ,@body))
     (%with-throttler ,throttler #'body)))


(defclass github-repo (generic-git-repo)
  ((cache :initform (make-hash-table :test 'equal)
          :accessor github-repo-cache)
   (commit-cache :initform (make-hash-table :test 'equal)
                 :accessor commit-cache)))

(defsecret :github-user
  "Github user used for accessing the GitHub API. Practically, the
  only time this is used is to check if a repository is public. We
  also use it for some internal code at Screenshotbot.io.

  If you don't care about the public repo logic, you can safely ignore
  this. Leaving this out will treat all GitHub repos as private.")

(defsecret :github-api-secret
  "Github API secret key corresponding to :github-user")

(defun github-client (&key
                        oauth-token
                        installation-id)
  (declare (ignore repo))
  (let ((client (new-instance #,org.eclipse.egit.github.core.client.GitHubClient
                              ))
        (token (or oauth-token installation-id)))
    (cond
      (token
       (#_setOAuth2Token client token))
      (t
       (#_setCredentials client (secret :github-user)
                         (secret :github-api-secret))))
    client))

(defmacro with-cache ((place args) &body body)
  `(flet ((body () ,@body))
     (let ((args ,args)
           (place ,place))
      (symbol-macrolet ((hash-val (gethash  args place)))
        (or
         hash-val
         (setf hash-val (body)))))))

(defun github-commit-service (&optional (github-client (github-client)))
  (new-instance #,com.tdrhq.CustomCommitService
                github-client))

(defun github-issue-service ()
  (new-instance #,org.eclipse.egit.github.core.service.IssueService
                (github-client)))

(defun github-user-service (&optional (github-client (github-client)))
  (new-instance #,org.eclipse.egit.github.core.service.UserService
                github-client))

(defun github-repos-for-user (user)
  (mapcar #_getCloneUrl
          (java-list->list
           (with-throttler (*github-throttler*)
             (#_getRepositories (github-repo-service) user)))))

(defun github-org-service ()
  (new-instance #,org.eclipse.egit.github.core.service.OrganizationService
                (github-client)))

(defun github-repo-service (&optional (client (github-client)))
  (new-instance #,org.eclipse.egit.github.core.service.RepositoryService
                client))

(defun github-star-service ()
  (new-instance #,org.eclipse.egit.github.core.service.StargazerService
                (github-client)))

;; (#_getStargazers (github-star-service) (github-repo-id "https://github.com/facebook/screenshot-tests-for-android"))

(defun github-create-issue (repo title body)
  (let* ((issue-service (github-issue-service))
         (issue (new-instance #,org.eclipse.egit.github.core.Issue)))
    (#_setTitle issue title)
    (#_setBody issue body)
    (#_getUrl
     (with-throttler (*github-throttler*)
       (#_createIssue issue-service
                      (github-repo-id repo)
                      issue)))))


(defun make-users-csv (users output)
  (with-open-file (s output :direction :output :if-exists :supersede
                            :element-type 'character
                            :external-format :utf-8)
    (dolist (u users)
      (loop for stream in (list s) do
        (format stream "~a,~a,~a~%" (#_getLogin u) (#_getEmail u) (#_getCompany u))))))

(defmethod github-repo-id (repo)
  (assert (not (str:emptyp (fix-github-link repo))))
  (#_createFromUrl
   #,org.eclipse.egit.github.core.RepositoryId
   (fix-github-link repo)))

(defmethod github-repo-id ((repo github-repo))
  (github-repo-id (repo-link repo)))

(defun can-access-github-repo (github-link)
  (let ((repo-id (github-repo-id github-link)))
    (#_getIssues repo-id
                 (new-instance #,java.util.HashMap))))

(defmethod public-repo-p ((repo github-repo))
  (when (and
         (secret :github-user)
         (secret :github-api-secret))
   (let ((repo-id (github-repo-id repo)))
     (handler-case
         (progn
           (with-throttler (*github-throttler*)
             (#_getRepository (github-repo-service
                               (github-client))
                              repo-id))
           t)
       #+lispworks
       (lw-ji:java-method-exception (e)
         nil)))))


(defun github-integration-test ()
  (let ((repo (make-instance 'github-repo :link "https://github.com/tdrhq/screenshotbot-example")))
    (assert
     (public-repo-p repo))
    (assert (not (public-repo-p (make-instance 'github-repo :link "https://github.com/tdrhq/web"))))))

;; (github-integration-test)

(defun get-repo-id (repo)
  (cl-ppcre:regex-replace-all
   "^(git@github.com:|https://github.com/)([^.]*)([.]git)?$"
   repo
   "\\2"))

(defmethod commit-link ((repo github-repo) hash)
  (format nil "https://github.com/~a/commit/~a"
          (get-repo-id (repo-link repo))
          hash))
