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
import 'package:quiver/mirrors.dart' as quiver;
import 'dart:collection';

part 'src/binding.dart';
part 'src/injector.dart';
part 'src/module.dart';
part 'src/key.dart';

//class _Binder {
//  final Injector _injector;
//  final Key _boundKey;
//  final Key _boundToKey;
//
//  _Binder(this._injector, this._boundKey, this._boundToKey);
//
//  Object get singleton {
//    if (!_injector._singletons.containsKey(_boundKey)) {
//      _injector._singletons[_boundKey] =_injector._getInstanceOf(
//          new Key(_boundToKey.name, annotatedWith: _boundToKey.annotation));
//    }
//
//    return _injector._singletons[_boundKey];
//  }
//
//  Object newInstance() => _injector._getInstanceOf(
//      new Key(_boundToKey.name, annotatedWith: _boundToKey.annotation));
//}
//
///**
// * Returned by [Module.bindTo], defines a binding from one type (the return
// * type of the binding declaration) to another type (the argument to [bindTo]).
// */
//class Binder extends _Binder {
//  Binder._(Injector injector, Key boundKey,
//      Key boundToKey)
//      : super(injector, boundKey, boundToKey);
//
//  ProvidedBinder providedBy(provider) => new ProvidedBinder._(_injector,
//      _boundKey, _boundToKey, provider);
//}
//
//class ProvidedBinder extends _Binder {
//  Function provider;
//
//  ProvidedBinder._(Injector injector, Key boundKey,
//      Key boundToKey, this.provider)
//      : super(injector, boundKey, boundToKey) {
//  }
//
//  Object get singleton {
//    if (!_injector._singletons.containsKey(_boundKey)) {
//      _injector._singletons[_boundKey] = _injector.callInjected(provider);
//    }
//
//    return _injector._singletons[_boundKey];
//  }
//
//  Object newInstance() => _injector.callInjected(provider);
//
//}
//
