;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(pkg:define-package :screenshotbot/test-installation
    (:use #:cl
          #:alexandria
          #:fiveam
          #:./installation))

(def-suite* :screenshotbot/test-installation)

(defclass my-plugin () ())

(test find-plugin
  (let ((plugin (make-instance 'my-plugin)))
    (is (eql plugin (find-plugin (make-instance 'installation
                                                 :plugins (list plugin))
                                 'my-plugin)))
    (signals simple-error
      (find-plugin (make-instance 'installation)
                   'my-plugin))))
