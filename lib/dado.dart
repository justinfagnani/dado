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

import 'dart:async';
import 'dart:mirrors';
import 'package:inject/inject.dart';
import 'src/mirror_utils.dart';

typedef Object _Provider(Injector injector);

Symbol _typeName(type) {
  if (type is Type)
    return reflectClass(type).qualifiedName;
  else if (type is TypeMirror)
    return type.qualifiedName;
  else if (type is Symbol)
    return type;
  else
    throw new ArgumentError("type must be a Type, a TypeMirror or a Symbol");
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
  final annotation;

  Key(this.name, {annotatedWith}) : annotation = annotatedWith {
    if (name == null) throw new ArgumentError("name must not be null");
  }

  factory Key.forType(Type type, {annotatedWith}) =>
      new Key(_typeName(type), annotatedWith: annotatedWith);

  bool operator ==(o) => o is Key && o.name == name
      && o.annotation == annotation;

  int get hashCode => name.hashCode * 37 + annotation.hashCode;

  String toString() => 'Key(name: $name, annotation: $annotation)';
}


class BindingType {
  final String value;
  
  const BindingType (this.value);
}

class Binding {
  final Key key;
  final BindingType bindingType;
  dynamic instance;
  MethodMirror provider;
  InstanceMirror moduleMirror;
  
  Binding.toInstance (this.key, this.instance) : 
    bindingType = const BindingType ("toInstance");
  
  Binding.toConstructor (this.key, this.provider) :
    bindingType = const BindingType ("toConstructor");
  
  Binding.toSingleton (this.key, this.provider) :
    bindingType = const BindingType ("toSingleton");
  
  Binding.toProvider(this.key, this.provider, this.moduleMirror) :
    bindingType = const BindingType ("toProvider");
  
  Binding.toSingletonProvider (this.key, this.provider, this.moduleMirror) :
    bindingType = const BindingType ("toSingletonProvider");
  
  dynamic getInstance (Injector injector) {
    var i;
    if (bindingType == const BindingType ("toInstance"))
      i = this.instance;
    else if (bindingType == const BindingType ("toConstructor"))
      i = _newInstance(injector);
    else if (bindingType == const BindingType ("toSingleton")) {
      if (instance == null)
        instance = _newInstance(injector);
      
      i = instance;
    } else if (bindingType == const BindingType ("toProvider")) {
      i = _invokeProvider(injector);
    } else {
      if (instance == null)
        instance = _invokeProvider(injector);
      
      i = instance;
    }
    
    return i;
  }
  
  dynamic getSingleton (Injector injector) {
    if (instance == null)
      instance = getInstance(injector);
    
    return instance;
  }
  
  dynamic _newInstance (Injector injector) {
    assert(provider != null);
    assert(provider.isConstructor);
    
    var parameters = injector._resolveParameters(provider.parameters);
    return (provider.owner as ClassMirror)
        .newInstance(provider.constructorName, parameters, null).reflectee;
  }
  
  dynamic _invokeProvider (Injector injector) {
    assert(provider != null);
    
    moduleMirror.reflectee._currentInjector = injector;
    moduleMirror.reflectee._currentKey = key;
    
    if (!provider.isGetter) {
      var parameters = injector._resolveParameters(provider.parameters);
      return moduleMirror
          .invoke(provider.simpleName, parameters, null).reflectee;
    } else {
      return moduleMirror.getField(provider.simpleName).reflectee;
    }
  }
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
  static final Symbol _injectorClassName = reflectClass(Injector).qualifiedName;
  static final Key _injectorKey = new Key(_injectorClassName);
  /// The parent of this injector, if it's a child, or null.
  final Injector parent;

  /// The name of this injector, if one was provided.
  final String name;

  final List<Key> _newInstances;
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
    
    _bindings[_injectorKey] = new Binding.toInstance(_injectorKey, this);
    
    var moduleMirrors = modules.map((moduleType) => reflectClass(moduleType));
    
    moduleMirrors.forEach(_registerBindings);
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
  Object getInstanceOf (type, {annotatedWith}) {
    var key = new Key(_typeName(type), annotatedWith: annotatedWith);
    
    if (_newInstances.contains(key) && !_bindings.containsKey(key))
      _addBindingFromType(key, type, annotatedWith: annotatedWith);
    
    var binding = _getBinding(key);
    if (binding == null)
      throw new ArgumentError('Key: $key has not been bound.');
    
    return binding.getInstance(this);
  }
  
  Object getSingletonOf (type, {annotatedWith}) {
    var key = new Key(_typeName(type), annotatedWith: annotatedWith);
    
    if (_newInstances.contains(key) && !_bindings.containsKey(key))
      _addBindingFromType(key, type, annotatedWith: annotatedWith);
    
    var binding = _getBinding(key);
    
    if (binding == null)
      throw new ArgumentError('Key: $key has not been bound.');
    
    return binding.getSingleton(this);
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
  
  Binding _getBinding (Key key) =>
      _bindings.containsKey(key)
        ? _bindings[key]
        : (parent != null)
            ? parent._getBinding(key)
            : null;
            
  bool _containsBinding (Key key) => _bindings.containsKey(key) || 
      (parent != null ? parent._containsBinding(key) : false);

  Object _getAnnotation(DeclarationMirror m) {
    // There's some bug with requesting metadata from certain variable mirrors
    // that causes a NoSuchMe thodError because the mirror system is trying to
    // call 'resolve' on null. See dartbug.com/11418
    List<InstanceMirror> metadata;
    try {
      metadata = m.metadata;
    } on NoSuchMethodError catch (e) {
      return null;
    }
    if (metadata.isNotEmpty) {
      // TODO(justin): what do we do when a declaration has multiple
      // annotations? What does Guice do? We should probably only allow one
      // binding annotation per declaration, which means we need a way to
      // identify binding annotations.
      return metadata.first.reflectee;
    }
    return null;
  }

  List<Object> _resolveParameters(List<ParameterMirror> parameters) =>
      parameters.where((ParameterMirror p) => !p.isOptional).map(
          (ParameterMirror p) =>
            getInstanceOf(p.type, annotatedWith: _getAnnotation(p))
      ).toList();

  void _registerBindings(ClassMirror classMirror){
    var moduleMirror = classMirror.newInstance(const Symbol(''), [], null);

    classMirror.members.values.forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
        var name = member.type.qualifiedName;
        var annotation = _getAnnotation(member);
        var key = new Key(name, annotatedWith: annotation);
        _bindings[key] = new Binding.toInstance(key, instance);

      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = _getAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);
        if (member.isAbstract) {
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _bindings[key] = new Binding.toSingleton(key, 
                _selectConstructor(member.returnType));
          } else {
            // Abstract methods define unscoped bindings
            _bindings[key] = new Binding.toConstructor(key, 
                _selectConstructor(member.returnType));
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
                new Binding.toSingletonProvider(key, member, moduleMirror);
          } else {
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            _bindings[key] = 
                new Binding.toProvider(key, member, moduleMirror);
          }
        }
      }
    });
  }
  
  MethodMirror _selectConstructor (ClassMirror m) {
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
        
    if (ctor == null)
      throw new ArgumentError("${m.qualifiedName} must have a no-arg "
        "constructor or a single constructor");
    
    return ctor;
  }

  /**
   * Create a new instance with a type represented by [m], resolving
   * constructor dependencies.
   */
  Key _addBindingFromType(Key key, Type type, {annotatedWith}) {
    var m = reflectClass(type);
    // Select appropriate constructor
    MethodMirror ctor = _selectConstructor(m);
        
    if (ctor == null)
      throw new ArgumentError("${m.qualifiedName} must have a no-arg "
        "constructor or a single constructor");
    
    _bindings[key] = new Binding.toConstructor(key, ctor);
    
  }

  String toString() => 'Injector: $name';
}

class _Binder {
  final Injector _injector;
  final Key _boundKey;
  final Key _boundToKey;

  _Binder(this._injector, this._boundKey, this._boundToKey);

  Object get singleton => _injector.getSingletonOf(_boundToKey.name, 
      annotatedWith: _boundToKey.annotation);

  Object newInstance() => _injector.getInstanceOf(_boundToKey.name, 
      annotatedWith: _boundToKey.annotation);
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
    if (_injector._getBinding(_boundKey).instance == null) {
      _injector._getBinding(_boundKey).instance = _injector.callInjected(provider);
    }
    
    return _injector._getBinding(_boundKey).instance;
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

  Binder bindTo(Type type, {annotatedWith}) {
    assert(_currentInjector != null);
    assert(_currentKey != null);
    
    var boundToKey = new Key(_typeName(type), annotatedWith: annotatedWith);
    
    if (!_currentInjector._containsBinding(boundToKey))
        _currentInjector._addBindingFromType(boundToKey, type, 
            annotatedWith: annotatedWith);
    
    return new Binder._(_currentInjector, _currentKey, boundToKey);
  }
}
