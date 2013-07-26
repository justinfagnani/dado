part of dado;

/**
 * Bindings define the way that instances of a [Key] are created. They are used
 * to hide all the logic needed to build an instance, store a singleton instance
 * and analize dependencies.
 * 
 * This is an interface, so there can be several types of Bindings, each one 
 * with its own internal logic to build instances and define its scope.
 */
abstract class Binding {
  final Key key;
  
  Binding (this.key);
  
  Object getInstance (Injector injector);
  
  Object getSingleton (Injector injector);
  
  void _verifyCircularDependency (Injector injector, {List<Key> dependencyStack});
}

class _InstanceBinding extends Binding {
  final Object instance;
  
  _InstanceBinding (Key key, Object this.instance) : 
    super(key);
  
  Object getInstance (Injector injector) => instance;
  
  Object getSingleton (Injector injector) => instance;
  
  void _verifyCircularDependency (Injector injector, {List<Key> dependencyStack}) {}
}

class _ConstructorBinding extends Binding {
  final MethodMirror constructor;
  final bool singleton;
  Object singletonInstance;
  
  _ConstructorBinding 
    (Key key, MethodMirror this.constructor) :
    singleton = false, super(key);
  
  _ConstructorBinding.asSingleton
    (Key key, MethodMirror this.constructor) :
    singleton = true, super(key);
  
  Object getInstance (Injector injector) {
    if (singleton && singletonInstance != null)
      return singletonInstance;
    
    var parameters = injector._resolveParameters(constructor.parameters);
    var obj = (constructor.owner as ClassMirror)
        .newInstance(constructor.constructorName, parameters, null).reflectee;
    
    if (singleton)
      singletonInstance = obj;
    
    return obj;
  }
  
  Object getSingleton (Injector injector) {
    if (singletonInstance == null)
      singletonInstance = getInstance(injector);
    
    return singletonInstance;
  }
  
  void _verifyCircularDependency (Injector injector, {List<Key> dependencyStack}) {
    if (dependencyStack == null)
      dependencyStack = [key];
    
    var parametersKeys = constructor.parameters.map((p) {
      var name = _typeName(p.type);
      var annotation = injector._getAnnotation(p);
      return new Key(name, annotatedWith: annotation);
    });
    
    parametersKeys.forEach((parameterKey) {
      if (dependencyStack.contains(parameterKey))
        throw new ArgumentError(
            'Circular dependency found on type ${parameterKey.name}');
      
      var parameterBinding = injector._getBinding(parameterKey);
      
      if (parameterBinding == null)
        throw new ArgumentError('Key: $parameterKey has not been bound.');
      
      dependencyStack.add(parameterKey);
      parameterBinding._verifyCircularDependency(injector, dependencyStack: dependencyStack);
      dependencyStack.remove(parameterKey);
    });
  }
}

class _ProviderBinding extends Binding {
  final MethodMirror provider;
  final bool singleton;
  final InstanceMirror moduleMirror;
  Object singletonInstance;
  
  _ProviderBinding 
    (Key key, MethodMirror this.provider, InstanceMirror this.moduleMirror) :
    singleton = false, super(key);
  
  _ProviderBinding.asSingleton
    (Key key, MethodMirror this.provider, InstanceMirror this.moduleMirror) :
    singleton = true, super(key);
  
  Object getInstance (Injector injector) {
    if (singleton && singletonInstance != null)
      return singletonInstance;
    
    moduleMirror.reflectee._currentInjector = injector;
    moduleMirror.reflectee._currentKey = key;
    
    var obj;
    if (!provider.isGetter) {
      var parameters = injector._resolveParameters(provider.parameters);
      obj = moduleMirror
          .invoke(provider.simpleName, parameters, null).reflectee;
    } else {
      obj = moduleMirror.getField(provider.simpleName).reflectee;
    }
    
    if (singleton)
      singletonInstance = obj;
    
    return obj;
  }
  
  Object getSingleton (Injector injector) {
    if (singletonInstance == null)
      singletonInstance = getInstance(injector);
    
    return singletonInstance;
  }
  
  void _verifyCircularDependency (Injector injector, {List<Key> dependencyStack}) {
    if (dependencyStack == null)
      dependencyStack = [key];
    
    var parametersKeys = provider.parameters.map((p) {
      var name = _typeName(p.type);
      var annotation = injector._getAnnotation(p);
      return new Key(name, annotatedWith: annotation);
    });
    
    parametersKeys.forEach((parameterKey) {
      if (dependencyStack.contains(parameterKey))
        throw new ArgumentError(
            'Circular dependency found on type ${parameterKey.name}');
      
      var parameterBinding = injector._getBinding(parameterKey);
      
      if (parameterBinding == null)
        throw new ArgumentError('Key: $parameterKey has not been bound.');
      
      dependencyStack.add(parameterKey);
      parameterBinding._verifyCircularDependency(injector, dependencyStack: dependencyStack);
      dependencyStack.remove(parameterKey);
    });
  }
}