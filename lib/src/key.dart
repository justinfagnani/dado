// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.key;

import 'utils.dart' as Utils;

/**
 * Keys are used to resolve instances in an [Injector], they are used to
 * register bindings and request an object at the injection point.
 *
 * Keys consist of a [Symbol] representing the type name and an optional
 * annotation. If you need to create a Key from a [Type] literal, use [forType].
 */
class Key {
  final Symbol name;
  final Object annotation;

  Key(this.name, {Object annotatedWith}) : annotation = annotatedWith {
    if (name == null) throw new ArgumentError("name must not be null");
  }

  factory Key.forType(Type type, {Object annotatedWith}) =>
      new Key(Utils.typeName(type), annotatedWith: annotatedWith);

  bool operator ==(o) => o is Key && o.name == name
      && o.annotation == annotation;

  int get hashCode => name.hashCode * 37 + annotation.hashCode;

  String toString() => 'Key: $name'
      '${(annotation!=null?' annotated with $annotation': '')}';
}