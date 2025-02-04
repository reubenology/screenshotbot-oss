;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(pkg:define-package :screenshotbot/dashboard/test-channels
    (:use #:cl
          #:alexandria
          #:../user-api
          #:fiveam)
  (:import-from #:./channels
                #:%list-projects)
  (:import-from #:../factory
                #:test-user
                #:test-channel
                #:test-company))

(def-suite* :screenshotbot/dashboard/test-channels)

(defclass company-with-channels (test-company)
  ())

(defmethod company-channels ((company company-with-channels))
  (list (make-instance 'test-channel)))

(test simple-view
  (let ((user (make-instance 'test-user))
        (company (make-instance 'company-with-channels)))
    (%list-projects :user user
                    :company company)))
