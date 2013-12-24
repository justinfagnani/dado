// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.binding;

import 'key.dart';

/**
 * Bindings define the way that instances of a [Key] are created. They are used
 * to hide all the logic needed to build an instance and analyze its 
 * dependencies.
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

/**
 * Dependencies define what instances are needed to construct a instance of a
 * binding. A dependency can be nullable, which means it doesn't need to be
 * satisfied. It can also be positional, which is the case of positional 
 * arguments of a constructor.
 */
class Dependency {
  /// The name of this dependency. Usually the same name as a parameter.
  final Symbol name;
  
  /// The key that identifies the type of this dependency.
  final Key key;
  
  final bool isNullable;
  final bool isPositional;
  
  /// If this dependency [isPositional], this is its position.
  final int position;
  
  Dependency(
      Symbol this.name,
      Key this.key, {
        bool this.isNullable: false, 
        bool this.isPositional: true, 
        int this.position: 0
      });
}

/**
 * A DependencyResolution provides everything that a binding may need to build a
 * instance.
 * 
 * In an analogy to baking a cake, if the [Binding] is a recipe, the 
 * DependencyResolution would be its ingredients.
 */
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