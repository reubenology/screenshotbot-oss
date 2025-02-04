;;;; Copyright 2018-Present Modern Interpreters Inc.
;;;;
;;;; This Source Code Form is subject to the terms of the Mozilla Public
;;;; License, v. 2.0. If a copy of the MPL was not distributed with this
;;;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(pkg:define-package :screenshotbot/test-taskie
    (:use #:cl
          #:alexandria
          #:./taskie
          #:fiveam)
  (:import-from #:./taskie
                #:with-pagination))

(def-suite* :screeshotbot/test-taskie)

(defclass my-object ()
  ((val :initarg :val)))

(defmethod bknr.datastore:store-object-id ((obj my-object))
  (slot-value obj 'val))

(test happy-path
  (taskie-list :empty-message "No recent runs to show. But that's okay, it's easy to get started!"
               :items (list (make-instance 'my-object :val 1)
                            (make-instance 'my-object :val 2)
                            (make-instance 'my-object :val 3))
               :next-link "/foo/next"
               :prev-link "/foo/prev"
               :row-generator (lambda (x)
                                (taskie-row
                                 :object x
                                 (taskie-timestamp :prefix "" :timestamp (local-time:now))))))

(test with-pagination-happy-path
  (let ((data (loop for i from 1 to 110 collect (make-instance 'my-object :val i))))
    (with-pagination (page data :next-link next-link :prev-link prev-link)
      (is (eql 50 (length page))))))


(test with-pagination-empty-list
  (let ((data nil))
    (with-pagination (page data :next-link next-link :prev-link prev-link)
      (is (equal nil page)))))
