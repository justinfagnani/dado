// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.injector;

import 'dart:collection';
import 'dart:mirrors';
import 'binding.dart';
import 'key.dart';
import 'module.dart';
import 'utils.dart' as Utils;

/**
 * An Injector constructs objects based on it's configuration. The Injector
 * tracks dependencies between objects and uses the bindings defined in its
 * modules and parent injector to resolve the dependencies and inject them into
 * newly created objects.
 *
 * Injectors are rarely used directly, usually only at the initialization of an
 * application to create the root objects for the application. The Injector does
 * most of it's work behind the scenes, creating objects as neccessary to
 * fullfill dependencies.
 *
 * Injectors are hierarchical. [createChild] is used to create injectors that
 * inherit their configuration from their parent while adding or overriding
 * some bindings.
 *
 * An Injector contains a default binding for itself, so that it can be used
 * to request instances generically, or to create child injectors. Applications
 * should generally have very little injector aware code.
 *
 */
class Injector {
  // The key that indentifies the default Injector binding.
  static final Key key =
      new Key(reflectClass(Injector).qualifiedName);

  /// The parent of this injector, if it's a child, or null.
  final Injector parent;

  /// The name of this injector, if one was provided.
  final String name;

  /*
   *  The keys for which this injector should provide its own bindings instead
   *  of using the bindings of it's parent.
   */
  final List<Key> _newInstances;

  // The map of bindings and its keys.
  final Map<Key, Binding> _bindings = new Map<Key, Binding>();

  // The map of singleton instances
  final Map<Key, Object> _singletons = new Map<Key, Object>();

  /**
   * Constructs a new Injector using [modules] to provide bindings. If [parent]
   * is specificed, the injector is a child injector that inherits bindings
   * from its parent. The modules of a child injector add to or override its
   * parent's bindings. [newInstances] is a list of types that a child injector
   * should create distinct instances for, separate from it's parent.
   * newInstances only apply to singleton bindings.
   */
  Injector(List<Type> modules, {Injector this.parent, List<Type> newInstances,
    String this.name})
      : _newInstances = (newInstances == null)
          ? []
          : newInstances.map(Utils.makeKey).toList(growable: false)
  {
    if (parent == null && newInstances != null) {
      throw new ArgumentError('newInstances can only be specified for child'
          'injectors.');
    }

    _bindings[key] = new _InjectorBinding(this);

    modules.forEach(_registerBindings);

    _bindings.values.forEach((binding) => _verifyCircularDependency(binding));
  }

  /**
   * Creates a child of this Injector with the additional modules installed.
   * [modules] must be a list of Types that extend Module.
   * [newInstances] is a list of Types that the child should create new
   * instances for, rather than use an instance from the parent.
   */
  Injector createChild(List<Type> modules, {List<Type> newInstances}) =>
      new Injector(modules, parent: this);

  /**
   * Returns an instance of [type]. If [annotatedWith] is provided, returns an
   * instance that was bound with the annotation.
   */
  Object getInstanceOf(Type type, {Object annotatedWith}) {
    var key = new Key(Utils.typeName(type), annotatedWith: annotatedWith);

    return _getInstanceOf(key);
  }

  Object _getInstanceOf(Key key) {
    var binding = _getBinding(key);

    if (binding.singleton) {
      return _getSingletonOf(key);
    }

    return _buildInstanceOfBinding(binding);
  }

  Object _getSingletonOf(Key key) {
    if (parent == null ||
        _newInstances.contains(key) ||
        _bindings.containsKey(key)) {

      if (!_singletons.containsKey(key)) {
        _singletons[key] = _buildInstanceOfBinding(_getBinding(key));
      }

      return _singletons[key];
    } else {
      return parent._getSingletonOf(key);
    }
  }

  /**
   * Execute the function [f], injecting any arguments.
   */
  dynamic callInjected(Function f) {
    var mirror = reflect(f);
    assert(mirror is ClosureMirror);
    var parameterResolution = _resolveParameters(mirror.function.parameters);
    return Function.apply(
        f, parameterResolution.positionalParameters, 
        parameterResolution.namedParameters);
  }

  Binding _getBinding(Key key) {
      var binding = _bindings.containsKey(key)
        ? _bindings[key]
        : (parent != null)
            ? parent._getBinding(key)
            : null;

    if (binding == null) {
      throw new ArgumentError('$key has no binding.');
    }

    return binding;
  }
  
  Object _buildInstanceOfBinding (Binding binding) {
    var dependencyResolution = _resolveDependencies(binding.dependencies);
    return binding.buildInstance(dependencyResolution);
  }

  bool containsBinding(Key key) => _bindings.containsKey(key) ||
      (parent != null ? parent.containsBinding(key) : false);

  DependencyResolution _resolveDependencies(List<Dependency> dependencies) {
      var dependencyResolution = new DependencyResolution();
      
      dependencies.forEach((dependency) {
          if (!dependency.isNullable || containsBinding(dependency.key)) {
            dependencyResolution[dependency] = 
                _getInstanceOf(dependency.key);
          }
      });
      
      return dependencyResolution;
  }
  
  _ParameterResolution _resolveParameters(List<ParameterMirror> parameters) {
    var positionalParameters = parameters
        .where((parameter) => !parameter.isOptional)
          .map((parameter) =>
              getInstanceOf((parameter.type as ClassMirror).reflectedType,
                  annotatedWith: Utils.getBindingAnnotation(parameter))
        ).toList(growable: false);
      
      var namedParameters = new Map<Symbol, Object>();
      parameters.forEach((parameter) {
        if (parameter.isNamed) {
          var parameterClassMirror = 
              (parameter.type as ClassMirror).reflectedType;
          var annotation = Utils.getBindingAnnotation(parameter);
          
          var key = new Key.forType(
              parameterClassMirror,
              annotatedWith: annotation);
          
          if (containsBinding(key)) {
            namedParameters[parameter.simpleName] = 
                getInstanceOf(parameterClassMirror,
                  annotatedWith: annotation);
          }
        }
      });
      
      return new _ParameterResolution(positionalParameters, namedParameters);
  }

  void _registerBindings(Type moduleType){
    var classMirror = reflectClass(moduleType);
    var module = classMirror.newInstance(const Symbol(''), []).reflectee;
    
    if (module is Module) {
      _bindings.addAll(module.bindings);
    } else {
      throw new ArgumentError('$moduleType is not a Module');
    }
  }

  void _verifyCircularDependency(Binding binding,
                                  {List<Key> dependencyStack}) {
    if (dependencyStack == null) {
      dependencyStack = [];
    }

    if (dependencyStack.contains(binding.key)) {
      dependencyStack.add(binding.key);
      var stackInfo = dependencyStack.fold(null, (value, dependency) {
        if (value == null) {
          return dependency.toString();
        } else {
          return '$value =>\n$dependency';
        }
      });
      throw new ArgumentError(
          'Circular dependency found on type ${binding.key.name}:\n$stackInfo');
    }

    dependencyStack.add(binding.key);

    var dependencies = binding.dependencies;
    dependencies.forEach((dependency) {
      if (!dependency.isNullable || containsBinding(dependency.key)) {
        var dependencyBinding = this._getBinding(dependency.key);

        _verifyCircularDependency(dependencyBinding,
          dependencyStack: dependencyStack);
      }
    });

    dependencyStack.removeLast();
  }

  String toString() => 'Injector: $name';
}

class _ParameterResolution {
  List<Object> positionalParameters;
  Map<Symbol, Object> namedParameters;
  
  _ParameterResolution (this.positionalParameters, this.namedParameters);
  
}

class _InjectorBinding extends Binding {
  Injector _injector;
  List<Dependency> _dependencies = [];
  
  _InjectorBinding(Injector injector) : 
    super(Injector.key, singleton: true) {
    _injector = injector;
  }
  
  Object buildInstance(DependencyResolution dependencyResolution) => _injector;
  
  Iterable<Dependency> get dependencies => 
      new UnmodifiableListView(_dependencies);
  
}
