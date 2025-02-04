;; -*- coding: utf-8 -*-
;; Copyright 2018-Present Modern Interpreters Inc.
;;
;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

(in-package :test-util)

(markup:enable-reader)

(test simple-check ()
  (is (equal "hello world
" (html2text <html><body>hello world</body></html>))))

(test with-utf-8 ()
      (is (equal "hello हिन्दी,
"
                 (html2text <html><body>hello हिन्दी,</body></html>))))
