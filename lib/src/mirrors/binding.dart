// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dado.mirrors;

/**
 * Bindings define the way that instances of a [Key] are created. They are used
 * to hide all the logic needed to build an instance, store a singleton instance
 * and analyze dependencies.
 *
 * This is an interface, so there can be several types of Bindings, each one
 * with its own internal logic to build instances and define its scope.
 */
abstract class _Binding {
  final Key key;
  final bool singleton;

  _Binding(Key this.key, {bool this.singleton: false}) {
    assert(key != null);
  }

  Object getInstance(Injector injector);

  Iterable<Key> get dependencies;

}

class _InstanceBinding extends _Binding {
  final Object _instance;
  final Iterable<Key> dependencies = [];

  _InstanceBinding(Key key, this._instance) : super(key, singleton: true);

  Object getInstance(Injector injector) => _instance;

  String toString() => "_InstanceBinding($key -> $_instance)";
}

class _ProviderBinding extends _Binding {
  final InstanceMirror moduleMirror;
  final MethodMirror provider;
  final List<Key> dependencies = <Key>[];

  _ProviderBinding(Key key, this.provider, this.moduleMirror,
      {bool singleton: false})
      : super(key, singleton: singleton) {
    dependencies.addAll(provider.parameters.map((parameter) {
//      var name = parameter.type.qualifiedName;
      var annotation = _getBindingAnnotation(parameter);
      return new Key.forType(parameter.type.reflectedType, annotatedWith: annotation);
    }));
  }

  Object getInstance(Injector injector) {
    if (provider.isGetter) { // and not abstract? or is that take care of when
      // binding is created? If so this logic should be done at binding creation
      // basically the provider should be a function that the binding can just
      // call with no extra logic, maybe abstracting away mirrors altogether
      return moduleMirror.getField(provider.simpleName).reflectee;
    } else {
      var parameters = injector._resolveParameters(provider.parameters);
      return moduleMirror
          .invoke(provider.simpleName, parameters, null).reflectee;
    }
  }
}

class _ConstructorBinding extends _ProviderBinding {

  _ConstructorBinding(
      Key key,
      MethodMirror constructor,
      InstanceMirror moduleMirror, {
      bool singleton: false})
      : super(key, constructor, moduleMirror, singleton: singleton);

  @override
  Object getInstance(Injector injector) {
    var parameters = injector._resolveParameters(provider.parameters);
    var obj = (provider.owner as ClassMirror).newInstance(
        provider.constructorName, parameters, null).reflectee;
    return obj;
  }

  String toString() => "_ConstructorBinding($key -> $provider)";
}
