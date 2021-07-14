(pkg:define-package :screenshotbot/mailer
    (:use #:cl
          #:alexandria)
  (:export #:noop-mailer
           #:smtp-mailer
           #:local-smtp-mailer
           #:background-mailer
           #:send-mail))

(defclass mailer ()
  ((from :initarg :from
         :accessor from)))

(defclass noop-mailer (mailer)
  ()
  (:documentation "A mailer that does nothing"))

(defclass smtp-mailer (mailer)
  ((host :initarg :hostname
         :accessor host)
   (port :initarg :port
         :initform 587
         :accessor port)
   (ssl :initarg :ssl
        :initform t
        :accessor ssl)
   (user :initarg :user
         :accessor user)
   (password :initarg :password
             :accessor password)))

(defclass background-mailer (mailer)
  ((delegate :initarg :delegate
             :accessor delegate)))

(defclass local-smtp-mailer (smtp-mailer)
  ((host :initform "localhost"
         :initarg :hostname)
   (ssl :initform nil)
   (port :initarg :port
         :initform 25))
  (:documentation "A mailer that uses the local SMTP port. We expect
  that this SMTP server shouldn't require authentication."))

(defgeneric send-mail (mailer &key from subject to html-message))

(defmethod authentication ((mailer local-smtp-mailer))
  nil)

(defmethod authentication ((mailer smtp-mailer))
  `(:plain ,(user mailer) ,(password mailer)))

(defmethod send-mail ((mailer noop-mailer) &key &allow-other-keys)
  (declare (ignore mailer)))

(defmethod send-mail ((mailer smtp-mailer)
                      &key from subject to html-message)
  (restart-case
      (unless util:*disable-emails*
       (cl-smtp:send-email
        (host mailer)
        (or from (from mailer))
        to
        subject
        (util:html2text html-message)
        :ssl (ssl mailer)
        :port (port mailer)
        :authentication (authentication mailer)
        :port (port mailer)
        :html-message (markup:write-html html-message)))
    (dont-send-the-mail ()
      nil)))

(defmethod send-mail ((mailer background-mailer) &rest args)
  (bt:make-thread
   (lambda ()
     (apply #'send-mail (delegate mailer) args))))
