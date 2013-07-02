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
import 'src/mirror_utils.dart';

typedef Object _Provider(Injector injector);

Symbol _typeName(Type type) => reflectClass(type).qualifiedName;

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

  final List<Symbol> _newInstances;
  final Map<Symbol, _Provider> _providers = new Map<Symbol, _Provider>();
  final Map<Symbol, Object> _singletons = new Map<Symbol, Object>();

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
          : newInstances.map(_typeName).toList(growable: false) {
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
   * Returns an instance of [type].
   */
  Object getInstanceOf(Type type) =>
      _getInstanceOf(_typeName(type), reflectClass(type));

  /**
   * Execute the function [f], injecting any arguments.
   */
  dynamic callInjected(Function f) {
    var mirror = reflect(f);
    assert(mirror is ClosureMirror);
    var pargs = mirror.function.parameters.map((ParameterMirror p) =>
        _getInstanceOf(p.type.qualifiedName, p.type)).toList();
    return Function.apply(f, pargs);
  }

  _Provider _getProvider(Symbol name) =>
      _providers.containsKey(name)
          ? _providers[name]
          : (parent != null)
              ? parent._getProvider(name)
              : null;

  Object _getInstanceOf(Symbol name, ClassMirror mirror,
      {bool allowImplicit: false}) {
    if (name == _injectorClassName) return this;
    _Provider provider = _getProvider(name);
    if (provider == null) {
      if (allowImplicit == true) {
        return _newFromTypeMirror(mirror);
      } else {
        throw new ArgumentError('Type: $name has not been bound.');
      }
    }

    return provider(this);
  }

  Object _getSingletonOf(Symbol name, ClassMirror mirror) {
    if (parent == null || _newInstances.contains(name) ||
        _providers.containsKey(name)) {
      if (!_singletons.containsKey(name)) {
        _singletons[name] = _newFromTypeMirror(mirror);
      }
      return _singletons[name];
    } else {
      return parent._getSingletonOf(name, mirror);
    }
  }

  void _registerBindings(Type moduleType){
    var typeMirror = reflectClass(moduleType);
    var moduleMirror = typeMirror.newInstance(new Symbol(''), [], null);
    var module = moduleMirror.reflectee;

    typeMirror.members.values.forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
        _providers[member.type.qualifiedName] = (injector) => instance;
      } else if (member is MethodMirror) {
        if (member.isAbstract) {
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _providers[member.returnType.qualifiedName] = (injector) {
              var returnType = member.returnType;
              return injector
                  ._getSingletonOf(returnType.qualifiedName, returnType);
            };
          } else {
            // Abstract methods define unscoped bindings
            _providers[member.returnType.qualifiedName] =
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
            _providers[member.returnType.qualifiedName] = (injector) {
              module._currentInjector = injector;
              module._currentTypeName = member.returnType.qualifiedName;
              return moduleMirror.getField(member.simpleName).reflectee;
            };
          } else {
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            var pargs = member.parameters.map((ParameterMirror p) =>
                _getInstanceOf(p.type.qualifiedName, p.type)).toList();
            _providers[member.returnType.qualifiedName] = (injector) {
              module._currentInjector = injector;
              module._currentTypeName = member.returnType.qualifiedName;
              return moduleMirror
                  .invoke(member.simpleName, pargs, null).reflectee;
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
      var pargs = ctor.parameters.map((p) =>
          _getInstanceOf(p.type.qualifiedName, p.type)).toList();
      return m.newInstance(ctor.constructorName, pargs, null).reflectee;
  }

  String toString() => 'Injector: $name';
}

class _Binder {
  final Injector _injector;
  final Symbol _boundType;
  final Type type;

  _Binder(this._injector, this._boundType, this.type);

  dynamic get singleton {
    var mirror = reflectClass(type);
    return _injector._getSingletonOf(_boundType, mirror);
  }

  dynamic newInstance() {
    var mirror = reflectClass(type);
    var name = mirror.qualifiedName;
    return _injector._getInstanceOf(name, mirror, allowImplicit: true);
  }

}

/**
 * Returned by [Module.bindTo], defines a binding from one type (the return
 * type of the binding declaration) to another type (the argument to [bindTo]).
 */
class Binder extends _Binder {
  Binder(injector, boundType, type) : super(injector, boundType, type);

  ProvidedBinder providedBy(provider) =>
      new ProvidedBinder(_injector, _boundType, type, provider);
}

class ProvidedBinder extends _Binder {
  Function provider;

  ProvidedBinder(injector, boundType, type, this.provider)
      : super(injector, boundType, type);

  dynamic get singleton {
    Symbol name = _typeName(type);
    if (!_injector._singletons.containsKey(name)) {
      _injector._singletons[name] = _injector.callInjected(provider);
    }
    return _injector._singletons[name];
  }

  dynamic newInstance() => _injector.callInjected(provider);

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
  Symbol _currentTypeName;

  Binder bindTo(Type type) =>
      new Binder(_currentInjector, _currentTypeName, type);
}
