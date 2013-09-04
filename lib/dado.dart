// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Dado is a [dependency injection][di] framework for [Dart][dart].
 *
 * Dado attempts to have minimal set of features and a syntax that takes
 * advantage of Dart, which makes it different from many other popular DI
 * frameworks.
 *
 * Dado tries to make DI more lightweight by letting you define modules as Dart
 * classes and as declaratively as possible. Bindings can be define by simply
 * declaring an abstract method:
 *
 *     class MyModule extends Module {
 *       Foo get foo;
 *     }
 *
 * [dart]: http://dartlang.org
 * [di]: http://en.wikipedia.org/wiki/Dependency_injection
 *
 * Example
 * -------
 *
 *     import 'package:dado/dado.dart';
 *
 *     class MyModule extends Module {
 *
 *       // binding to an instance, similar to toInstance() in Guice
 *       String serverAddress = "127.0.0.1";
 *
 *       // Getters define singletons, similar to in(Singleton.class) in Guice
 *       Foo get foo;
 *
 *       // Methods define a factory binding, similar to bind().to() in Guice
 *       Bar newBar();
 *
 *       // Methods that delegate to bindTo() bind a type to a specific
 *       // implementation of that type
 *       Baz get baz => bindTo(Baz).singleton;
 *
 *       // Bindings can be made to provider methods
 *       Qux newQux() => bindTo(Qux)
 *         .providedBy((Foo foo) => new Qux(foo, 'not injected')).newInstance();
 *       }
 *
 *       class Bar {
 *         // A default method is automatically injected with dependencies
 *         Bar(Foo foo);
 *       }
 *
 *       main() {
 *         var injector = new Injector([MyModule]);
 *         Bar bar = injector.getInstance(Bar);
 *       }
 */
library dado;

import 'dart:mirrors';
import 'package:inject/inject.dart';
import 'package:meta/meta.dart';
import 'src/mirror_utils.dart';

part 'src/binding.dart';

Symbol _typeName(Type type) {
  return reflectClass(type).qualifiedName;
}

Key _makeKey(dynamic k) => (k is Key) ? k : new Key.forType(k);

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
      new Key(_typeName(type), annotatedWith: annotatedWith);

  bool operator ==(o) => o is Key && o.name == name
      && o.annotation == annotation;

  int get hashCode => name.hashCode * 37 + annotation.hashCode;

  String toString() => '$name annotated with $annotation';
}

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
  /// The key that indentifies the default Injector binding.
  static final Key _injectorKey = 
      new Key(reflectClass(Injector).qualifiedName);
  
  /// The parent of this injector, if it's a child, or null.
  final Injector parent;

  /// The name of this injector, if one was provided.
  final String name;

  /// The identity of the bindings that must be overriden by this injector.
  final List<Key> _newInstances;
  
  /// The map of bindings and its indentities.
  final Map<Key, Binding> _bindings = new Map<Key, Binding>();
  
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
          : newInstances.map(_makeKey).toList(growable: false)
  {
    if (parent == null && newInstances != null) {
      throw new ArgumentError('newInstances can only be specified for child'
          'injectors.');
    }
    
    _bindings[_injectorKey] = new _InstanceBinding(_injectorKey, this, null);
    
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
    var key = new Key(_typeName(type), annotatedWith: annotatedWith);
    
    if (_newInstances.contains(key) && !_bindings.containsKey(key)) {
      _createBindingForType(type, annotatedWith: annotatedWith);
    }
    
    return _getInstanceOf(key);
  }
  
  Object _getInstanceOf(Key key) {
    var binding = _getBinding(key);
    
    return binding.getInstance(this);
  }

  /**
   * Execute the function [f], injecting any arguments.
   */
  dynamic callInjected(Function f) {
    var mirror = reflect(f);
    assert(mirror is ClosureMirror);
    var parameters = _resolveParameters(mirror.function.parameters);
    return Function.apply(f, parameters);
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
            
  bool _containsBinding(Key key) => _bindings.containsKey(key) || 
      (parent != null ? parent._containsBinding(key) : false);

  List<Object> _resolveParameters(List<ParameterMirror> parameters) =>
      parameters.where((parameter) => !parameter.isOptional).map(
          (parameter) =>
            _getInstanceOf(
                new Key(parameter.type.qualifiedName, 
                    annotatedWith: getBindingAnnotation(parameter)))
      ).toList(growable: false);

  void _registerBindings(Type moduleType){
    var classMirror = reflectClass(moduleType);
    var moduleMirror = classMirror.newInstance(const Symbol(''), [], null);

    classMirror.members.values.forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
        var name = member.type.qualifiedName;
        var annotation = getBindingAnnotation(member);
        var key = new Key(name, annotatedWith: annotation);
        _bindings[key] = new _InstanceBinding(key, instance, moduleMirror);

      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = getBindingAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);
        if (member.isAbstract) {
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _bindings[key] = new _ConstructorBinding(key, 
                _selectConstructor(member.returnType),  moduleMirror, 
                singleton: true);
          } else {
            // Abstract methods define unscoped bindings
            _bindings[key] = new _ConstructorBinding(key, 
                _selectConstructor(member.returnType),  moduleMirror);
          }
        } else {
          // Non-abstract methods produce instances by being invoked.
          //
          // In order for the method to use the injector to resolve dependencies
          // it must be aware of the injector and the type we're trying to
          // construct so we set the module's _currentInjector and
          // _currentTypeName in the provider function.
          //
          // This is a slightly unfortunately coupling of Module to it's
          // injector, but the only way we could find to make this work. It's
          // a worthwhile tradeoff for having declarative bindings.
          if (member.isGetter) {
            // getters should define singleton bindings
            _bindings[key] = 
                new _ProviderBinding(key, member, moduleMirror, 
                    singleton: true);
          } else {
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            _bindings[key] = 
                new _ProviderBinding(key, member, moduleMirror);
          }
        }
      }
    });
  }
  
  void _verifyCircularDependency(Binding binding, 
                                  {List<Key> dependencyStack}) {
    if (dependencyStack == null) {
      dependencyStack = [];
    }
    
    if (dependencyStack.contains(binding.key)) {
      throw new ArgumentError(
          'Circular dependency found on type ${binding.key.name}');
    }
    
    dependencyStack.add(binding.key);
    
    var dependencies = binding.getDependencies();
    dependencies.forEach((dependency) {
      var dependencyBinding = this._getBinding(dependency);
      
      _verifyCircularDependency(dependencyBinding, 
          dependencyStack: dependencyStack);
    });
    
    dependencyStack.removeLast();
  }
  
  MethodMirror _selectConstructor(ClassMirror m) {
    Iterable<MethodMirror> constructors = m.constructors.values;
    // Choose contructor using @inject
    MethodMirror ctor = constructors.firstWhere(
      (c) => c.metadata.any(
        (m) => m.reflectee == inject)
      , orElse: () => null);
      
    // In case there is no constructor annotated with @inject, see if there's a 
    // single constructor or a no-args.
    if (ctor == null) {
      if (constructors.length == 1) {
        ctor = constructors.first;
      } else {
        ctor = constructors.firstWhere(
            (c) => c.parameters.where((p) => !p.isOptional).length == 0
        , orElse: () =>  null);
      }
    }
        
    if (ctor == null) {
      throw new ArgumentError("${m.qualifiedName} must have a no-arg "
        "constructor or a single constructor");
    }
    
    return ctor;
  }

  /**
   * Create a new constructor binding for [type]
   */
  Key _createBindingForType(Type type, {Object annotatedWith}) {
    var classMirror = reflectClass(type);
    // Select appropriate constructor
    MethodMirror ctor = _selectConstructor(classMirror);
        
    if (ctor == null) {
      throw new ArgumentError("${classMirror.qualifiedName} must have only "
        "one constructor, a constructor annotated with @inject or no-args "
        "constructor");
    }
    
    var key = new Key.forType(type, annotatedWith: annotatedWith);
    
    _bindings[key] = new _ConstructorBinding(key, ctor, null);
    
  }

  String toString() => 'Injector: $name';
}

class _Binder {
  final Injector _injector;
  final Key _boundKey;
  final Key _boundToKey;

  _Binder(this._injector, this._boundKey, this._boundToKey);

  Object get singleton {
    var binding = _injector._getBinding(_boundKey);
    if (binding.singletonInstance == null) {
      binding.singletonInstance = _injector._getInstanceOf(
          new Key(_boundToKey.name, annotatedWith: _boundToKey.annotation));
    }
    
    return binding.singletonInstance;
  }

  Object newInstance() => _injector._getInstanceOf(
      new Key(_boundToKey.name, annotatedWith: _boundToKey.annotation));
}

/**
 * Returned by [Module.bindTo], defines a binding from one type (the return
 * type of the binding declaration) to another type (the argument to [bindTo]).
 */
class Binder extends _Binder {
  Binder._(Injector injector, Key boundKey,
      Key boundToKey)
      : super(injector, boundKey, boundToKey);

  ProvidedBinder providedBy(provider) => new ProvidedBinder._(_injector,
      _boundKey, _boundToKey, provider);
}

class ProvidedBinder extends _Binder {
  Function provider;

  ProvidedBinder._(Injector injector, Key boundKey,
      Key boundToKey, this.provider)
      : super(injector, boundKey, boundToKey) {
  }

  Object get singleton {
    var binding = _injector._getBinding(_boundKey);
    if (binding.singletonInstance == null) {
      binding.singletonInstance = _injector.callInjected(provider);
    }
    
    return binding.singletonInstance;
  }

  Object newInstance() => _injector.callInjected(provider);

}

/**
 * A Module is a declaration of bindings that instruct an [Injector] how to
 * create objects.
 *
 * Bindings are declared with members on a Module. The return type of the member
 * defines what type the binding is for. The kind of member (variable, getter,
 * method) defines the type of binding:
 *
 * * Variables define instance bindings. The type of the variable is bound to
 *   its value.
 * * Abstract getters define singleton bindings.
 * * Abstract methods define unscoped bindings. A new instance is created every
 *   time [Injector.getInstance] is called.
 * * A non-abstract method must return instances of its return type. Often
 *   this will be done by calling [bindTo] with a type that is bound to, and
 *   then either [Binder.singleton] or [Binder.newInstance] dependeing on
 *   whether the method is a getter or not. Getters define singletons and should
 *   call [Binder.singleton], methods should call [Binder.newInstance].
 */
abstract class Module {
  Injector _currentInjector;
  Key _currentKey;

  Binder bindTo(Type type, {Object annotatedWith}) {
    assert(_currentInjector != null);
    assert(_currentKey != null);
    
    var boundToKey = new Key(_typeName(type), annotatedWith: annotatedWith);
    
    if (!_currentInjector._containsBinding(boundToKey)) {
        _currentInjector._createBindingForType(type, 
            annotatedWith: annotatedWith);
    }
    
    return new Binder._(_currentInjector, _currentKey, boundToKey);
  }
}
