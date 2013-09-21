// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dado;

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
  final InstanceMirror moduleMirror;
  final bool singleton;
  Object singletonInstance;
  
  _Binding(Key this.key, InstanceMirror this.moduleMirror, 
      {bool this.singleton: false});
  
  Object getInstance(Injector injector) {
    if (singleton && singletonInstance != null)
      return singletonInstance;
    
    var instance = buildInstance(injector);
    
    if (singleton) {
      singletonInstance = instance;
    }
    
    return instance;
  }
  
  Object buildInstance(Injector injector);
  
  Iterable<Key> getDependencies();
  
}

class _InstanceBinding extends _Binding {
  
  _InstanceBinding(Key key, Object instance, InstanceMirror moduleMirror) : 
    super(key, moduleMirror, singleton: true) {
    singletonInstance = instance;
  }
  
  Object buildInstance(Injector injector) => singletonInstance;
  
  Iterable<Key> getDependencies() => [];
  
}

class _ProviderBinding extends _Binding {
  final MethodMirror provider;
  
  _ProviderBinding 
  (Key key, MethodMirror this.provider, InstanceMirror moduleMirror, 
      {bool singleton: false}) :
        super(key, moduleMirror, singleton: singleton);
  
  Object buildInstance(Injector injector) {
    if (moduleMirror == null)
      return null;
    
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
  
  Iterable<Key> getDependencies() {
    return provider.parameters.map((parameter) {
      var name = parameter.type.qualifiedName;
      var annotation = getBindingAnnotation(parameter);
      return new Key(name, annotatedWith: annotation);
    });
  }
  
}

class _ConstructorBinding extends _ProviderBinding {
  
  _ConstructorBinding 
    (Key key, MethodMirror constructor, InstanceMirror moduleMirror, 
        {bool singleton: false}) : 
      super(key, constructor, moduleMirror, singleton: singleton);
  
  @override
  Object buildInstance(Injector injector) {
    var parameters = injector._resolveParameters(provider.parameters);
    var obj = (provider.owner as ClassMirror)
        .newInstance(provider.constructorName, parameters, null).reflectee;
    
    return obj;
  }

}
