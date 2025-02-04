;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(in-package :screenshotbot-sdk)

(define-flag *metadata*
  :selector "metadata"
  :default-value nil
  :type (or null string)
  :help "A metadata.xml file (Android only)")

(defun child-by-name (item name)
  (loop for child across (dom:child-nodes item)
        if (string= name (dom:node-name child))
          return child))

(Defun node-value (item)
  (dom:node-value (elt (dom:child-nodes item) 0)))

(defun node-integer-value (item)
  (declare (optimize (speed 0) (debug 3)))
  (parse-integer (node-value item)))

(defclass image-bundle ()
  ((metadata :initarg :metadata
             :accessor metadata-file)))

(defclass directory-image-bundle (image-bundle)
  ((directory :initarg :directory)))

(defclass zip-image-bundle (image-bundle)
  ((zip :initarg :zip)
   (zipfile)))

(defmethod initialize-instance :after ((inst zip-image-bundle) &key zip &allow-other-keys)
  (with-slots (zipfile) inst
    (setf zipfile (zip:open-zipfile zip))
    (let ((zipfile zipfile))
      (trivial-garbage:finalize inst
                                (lambda ()
                                  (zip:close-zipfile zipfile))))))


(defmethod read-image ((bundle directory-image-bundle) name)
  (with-slots (directory) bundle
   (imago:read-image
    (path:catfile directory
                  (format nil "~a.png" name)))))

(defmethod read-image ((bundle zip-image-bundle) name)
  (with-slots (zipfile) bundle
    (uiop:with-temporary-file (:pathname p :stream s :direction :output :type "png"
                               :element-type 'flexi-streams:octet)
     (let ((entry (zip:get-zipfile-entry (format nil "~a.png" name) zipfile)))
       (zip:zipfile-entry-contents entry s)
       (finish-output s)
       (imago:read-image p)))))

(defun merge-tiles (tiles)
  (destructuring-bind (w h)
      (array-dimensions tiles)
    (let ((full-width (loop for i from 0 below w
                             summing (imago:image-width (aref tiles i 0)
)))
          (full-height (loop for i from 0 below h
                            summing (imago:image-height (aref tiles 0 i))))
          (single-tile-width (imago:image-width (aref tiles 0 0)))
          (single-tile-height (imago:image-height (aref tiles 0 0))))

      (let ((dest (make-instance 'imago:rgb-image
                                 :width full-width
                                 :height full-height)))
        (let ((x 0))
          (dotimes (ww w)
            (let ((y 0))
              (dotimes (hh h)
                (log:trace "Writing tile: (~d,~d) to (~d, ~d) "
                          ww hh
                          x y)
                (let ((src (aref tiles ww hh)))
                  (imago:copy dest src
                              :height (imago:image-height src)
                              :width (imago:image-width src)
                              :dest-y y
                              :dest-x x))
                (incf y single-tile-height)))
            (incf x single-tile-width)))
        dest))))

(defmethod read-screenshot-tiles (screenshot (bundle image-bundle))
  (declare (optimize (speed 0) (debug 3)))
  (let* ((name (node-value (child-by-name screenshot "name")))
         (tile-height (node-integer-value (child-by-name screenshot "tile_height")))
         (tile-width (node-integer-value (child-by-name screenshot "tile_width"))))
    (let ((arr (make-array (list tile-width tile-height))))
      (dotimes (w tile-width)
        (dotimes (h tile-height)
          (let ((name (cond
                        ((and (eql 0 h) (eql 0 w))
                         name)
                        (t
                         (format nil "~a_~d_~d" name w h)))))
            (setf (aref arr w h) (read-image bundle name)))))
      (cons name (merge-tiles arr)))))

(defun read-android-metadata (metadata-file image-bundle)
  (let ((xml (cxml:parse-file metadata-file (cxml-dom:make-dom-builder))))
    (loop for screenshot across (dom:child-nodes (dom:document-element xml))
          collect (read-screenshot-tiles screenshot image-bundle))))

(defun make-image-bundle (output &key metadata)
  (cond
    ((path:-d output)
     (make-instance 'directory-image-bundle :directory output
                    :metadata metadata))
    ((path:-e output)
     (make-instance 'zip-image-bundle :zip output
                    :metadata metadata))
    (t
     (error "Does not exist: ~a" output))))


(defmethod list-images ((bundle image-bundle))
  (let ((files (read-android-metadata
                (metadata-file bundle)
                bundle)))
    (loop for (name . im) in files
          collect
          (progn
            (uiop:with-temporary-file (:pathname p :type "png"
                                       :direction :output
                                       :element-type 'flexi-streams:octet)
              (imago:write-png im p)
              (make-instance 'streamed-image
                             :name name
                             :stream (open p :direction :input
                                           :element-type 'flexi-streams:octet)))))))

#+nil
(make-regular-dir (path:catfile (asdf:system-source-directory :screenshotbot.sdk)
                                "example/metadata.xml")
                  #P "/tmp/foog/")


(defun android-run-p ()
  *metadata*)
