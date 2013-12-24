// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.module;

import 'binding.dart';
import 'key.dart';

/**
 * A Module is a declaration of bindings that instruct an [Injector] how to
 * create objects.
 *
 * This abstract class defines the interface that must be implemented by any
 * module.
 */
abstract class Module {
  Map<Key, Binding> get bindings;
}
