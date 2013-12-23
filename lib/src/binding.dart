// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.binding;

import 'key.dart';

/**
 * Bindings define the way that instances of a [Key] are created. They are used
 * to hide all the logic needed to build an instance, store a singleton instance
 * and analyze dependencies.
 * 
 * This is an interface, so there can be several types of Bindings, each one 
 * with its own internal logic to build instances and define its scope.
 */
abstract class Binding {
  final Key key;
  final bool singleton;
  
  Binding(Key this.key, {bool this.singleton: false});
  
  Object buildInstance(DependencyResolution dependencyResolution);
  
  Iterable<Dependency> get dependencies;
  
}

class Dependency {
  final Symbol name;
  final Key key;
  final bool isNullable;
  final bool isPositional;
  final int position;
  
  Dependency(
      Symbol this.name,
      Key this.key, {
        bool this.isNullable: false, 
        bool this.isPositional: true, 
        int this.position: 0
      });
}

class DependencyResolution {
  Map<Dependency, Object> instances;
  
  DependencyResolution([Map<Dependency, Object> this.instances]) {
    if (this.instances == null) {
      this.instances = new Map<Dependency, Object>();
    }
  }
  
  Object operator [] (Dependency dependency) {
    return instances[dependency];
  }
  
  void operator []=(Dependency dependency, Object instance) {
      instances[dependency] = instance;
  }
}