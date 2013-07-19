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

Symbol _typeName(Type type) => reflectClass(type).qualifiedName;

Key _makeKey(dynamic k) => (k is Key) ? k : new Key.forType(k);

class Named extends BindingAnnotation {
  const Named (String value) : super (value);
}

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

  /// The parent of this injector, if it's a child, or null.
  final Injector parent;

  /// The name of this injector, if one was provided.
  final String name;

  final List<Key> _newInstances;
  final Map<Key, _Provider> _providers = new Map<Key, _Provider>();
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
          : newInstances.map(_makeKey).toList(growable: false)
  {
    if (parent == null && newInstances != null) {
      throw new ArgumentError('newInstances can only be specified for child'
          'injectors.');
    }
    modules.forEach(_registerBindings);
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
  Object getInstanceOf(Type type, {annotatedWith}) {
    var key = new Key(_typeName(type), annotatedWith: annotatedWith);
    return _getInstanceOf(key, reflectClass(type));
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

  _Provider _getProvider(Key key) =>
      _providers.containsKey(key)
          ? _providers[key]
          : (parent != null)
              ? parent._getProvider(key)
              : null;

  Object _getInstanceOf(Key key, ClassMirror mirror,
      {bool allowImplicit: false}) {
    if (key.name == _injectorClassName) return this;
    _Provider provider = _getProvider(key);
    if (provider == null) {
      if (allowImplicit == true) {
        return _newFromTypeMirror(mirror);
      } else {
        throw new ArgumentError('Key: $key has not been bound.');
      }
    }

    return provider(this);
  }

  Object _getSingletonOf(Key key, ClassMirror mirror) {
    if (parent == null || _newInstances.contains(key) ||
        _providers.containsKey(key)) {
      if (!_singletons.containsKey(key)) {
        _singletons[key] = _newFromTypeMirror(mirror);
      }
      return _singletons[key];
    } else {
      return parent._getSingletonOf(key, mirror);
    }
  }

  Object _getAnnotation(DeclarationMirror m) {
    // There's some bug with requesting metadata from certain variable mirrors
    // that causes a NoSuchMethodError because the mirror system is trying to
    // call 'resolve' on null. See dartbug.com/11418
    List<InstanceMirror> metadata;
    try {
      metadata = m.metadata;
    } on NoSuchMethodError catch (e) {
      return null;
    }
    if (metadata.isNotEmpty) {
      Iterable<InstanceMirror> bindingAnnotations = 
        metadata.where((annotation) => annotation.reflectee is BindingAnnotation);
      
      if (bindingAnnotations.isEmpty)
        return null;
      else if (bindingAnnotations.length == 1)
        return bindingAnnotations.first.reflectee;
      else
        throw new ArgumentError('Binding has more than one BindingAnnotation');
    }
    return null;
  }

  List<Object> _resolveParameters(List<ParameterMirror> parameters) =>
      parameters.map((ParameterMirror p) {
        var name = p.type.qualifiedName;
        var annotation = _getAnnotation(p);
        var key = new Key(name, annotatedWith: annotation);
        return _getInstanceOf(key, p.type);
      }).toList();

  void _registerBindings(Type moduleType){
    var typeMirror = reflectClass(moduleType);
    var moduleMirror = typeMirror.newInstance(const Symbol(''), [], null);
    Module module = moduleMirror.reflectee;

    typeMirror.members.values.forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
        var name = member.type.qualifiedName;
        var annotation = _getAnnotation(member);
        var key = new Key(name, annotatedWith: annotation);
        _providers[key] = (injector) => instance;
      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = _getAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);
        if (member.isAbstract) {
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _providers[key] = (injector) {
              return injector._getSingletonOf(key, member.returnType);
            };
          } else {
            // Abstract methods define unscoped bindings
            _providers[key] =
                (injector) => injector._newFromTypeMirror(member.returnType);
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
            _providers[key] = (injector) {
              module._currentInjector = injector;
              module._currentKey = key;
              return moduleMirror.getField(member.simpleName).reflectee;
            };
          } else {
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            var parameters = _resolveParameters(member.parameters);
            _providers[key] = (injector) {
              module._currentInjector = injector;
              module._currentKey = key;
              return moduleMirror
                  .invoke(member.simpleName, parameters, null).reflectee;
            };
          }
        }
      }
    });
  }

  /**
   * Create a new instance with a type represented by [m], resolving
   * constructor dependencies.
   */
  Object _newFromTypeMirror(ClassMirror m) {
      // Choose contructor using @inject when we can
      MethodMirror ctor = (m.constructors.length == 1)
          ? m.constructors.values.first
          : m.constructors[new Symbol('')];
      if (ctor == null) {
        throw new ArgumentError("${m.qualifiedName} must have a no-arg"
            "constructor or a single constructor");
      }
      // resolve dependencies
      var parameters = _resolveParameters(ctor.parameters);
      return m.newInstance(ctor.constructorName, parameters, null).reflectee;
  }

  String toString() => 'Injector: $name';
}

class _Binder {
  final Injector _injector;
  final Key _boundKey;
  final Key _boundToKey;
  final ClassMirror _boundToMirror;

  _Binder(this._injector, this._boundKey, this._boundToKey,
      this._boundToMirror);

  Object get singleton => _injector._getSingletonOf(_boundKey, _boundToMirror);

  Object newInstance() => _injector._getInstanceOf(_boundToKey, _boundToMirror,
      allowImplicit: true);
}

/**
 * Returned by [Module.bindTo], defines a binding from one type (the return
 * type of the binding declaration) to another type (the argument to [bindTo]).
 */
class Binder extends _Binder {
  Binder._(Injector injector, Key boundKey,
      Key boundToKey, ClassMirror boundToMirror)
      : super(injector, boundKey, boundToKey, boundToMirror);

  ProvidedBinder providedBy(provider) => new ProvidedBinder._(_injector,
      _boundKey, _boundToKey, _boundToMirror, provider);
}

class ProvidedBinder extends _Binder {
  Function provider;

  ProvidedBinder._(Injector injector, Key boundKey,
      Key boundToKey, ClassMirror boundToMirror, this.provider)
      : super(injector, boundKey, boundToKey, boundToMirror);

  Object get singleton {
    if (!_injector._singletons.containsKey(_boundKey)) {
      _injector._singletons[_boundKey] = _injector.callInjected(provider);
    }
    return _injector._singletons[_boundKey];
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
    var boundToMirror = reflectClass(type);
    return new Binder._(_currentInjector, _currentKey, boundToKey,
        boundToMirror);
  }
}
