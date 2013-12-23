// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.binding;

import 'dart:collection';
import 'dart:mirrors';
import 'key.dart';
import 'utils.dart' as Utils;

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
  final InstanceMirror moduleMirror;
  final bool singleton;
  
  Binding(Key this.key, InstanceMirror this.moduleMirror, 
      {bool this.singleton: false});
  
  Object buildInstance(DependencyResolution dependencyResolution);
  
  Iterable<Dependency> get dependencies;
  
}

class InstanceBinding extends Binding {
  Object _instance;
  List<Dependency> _dependencies = [];
  
  InstanceBinding(Key key, Object instance, InstanceMirror moduleMirror) : 
    super(key, moduleMirror, singleton: true) {
    _instance = instance;
  }
  
  Object buildInstance(DependencyResolution dependencyResolution) => _instance;
  
  Iterable<Dependency> get dependencies => 
      new UnmodifiableListView(_dependencies);
  
}

class ProviderBinding extends Binding {
  final MethodMirror provider;
  List<Dependency> _dependencies;
  
  ProviderBinding 
  (Key key, MethodMirror this.provider, InstanceMirror moduleMirror, 
      {bool singleton: false}) :
        super(key, moduleMirror, singleton: singleton);
  
  Object buildInstance(DependencyResolution dependencyResolution) {
    if (!provider.isGetter) {
      var positionalArguments = 
          _getPositionalArgsFromResolution(dependencyResolution);
      var namedArguments = 
          _getNamedArgsFromResolution(dependencyResolution);

      return moduleMirror
          .invoke(
              provider.simpleName, 
              positionalArguments, 
              namedArguments).reflectee;
    } else {
      return moduleMirror.getField(provider.simpleName).reflectee;
    }
  }
  
  Iterable<Dependency> get dependencies {
    if (_dependencies == null) {
      _dependencies = new List<Dependency>(provider.parameters.length);
      int position = 0;
      
      provider.parameters.forEach(
        (parameter) {
          var parameterClassMirror = 
              (parameter.type as ClassMirror).reflectedType;
          var annotation = Utils.getBindingAnnotation(parameter);
          
          var key = new Key.forType(
              parameterClassMirror,
              annotatedWith: annotation);
          
          var dependency = 
              new Dependency(parameter.simpleName,
                             key, 
                             isNullable: parameter.isNamed || 
                                         parameter.isOptional,
                             isPositional: !parameter.isNamed,
                             position: position);
          
          _dependencies[position] = dependency;
          
          position++;
        });
    }
    
    return new UnmodifiableListView(_dependencies);
  }
  
  List<Object> _getPositionalArgsFromResolution(
      DependencyResolution dependencyResolution) {
    var positionalArgs = new List(dependencyResolution.instances.length);
    
    dependencyResolution.instances.forEach(
        (dependency, instance) {
          if (dependency.isPositional) {
            positionalArgs[dependency.position] = instance;
          }
        });
    
    return positionalArgs.where((e) => e != null).toList(growable: false);
  }
  
  Map<Symbol, Object> _getNamedArgsFromResolution(
      DependencyResolution dependencyResolution) {
    var namedArgs= new Map();
    
    dependencyResolution.instances.forEach(
        (dependency, instance) {
          if (!dependency.isPositional) {
            namedArgs[dependency.name] = instance;
          }
        });
    
    return namedArgs;
  }
  
}

class ConstructorBinding extends ProviderBinding {
  
  ConstructorBinding 
    (Key key, MethodMirror constructor, InstanceMirror moduleMirror, 
        {bool singleton: false}) : 
      super(key, constructor, moduleMirror, singleton: singleton);
  
  @override
  Object buildInstance(DependencyResolution dependencyResolution) {
    var positionalArguments = 
        _getPositionalArgsFromResolution(dependencyResolution);
    var namedArguments = 
        _getNamedArgsFromResolution(dependencyResolution);
    
    var obj = (provider.owner as ClassMirror)
          .newInstance(
            provider.constructorName, 
            positionalArguments, 
            namedArguments).reflectee;
    
    return obj;
  }

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