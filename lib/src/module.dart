part of dado;

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

//  Injector _injector;

//  Binder provide(Type type, {Object annotatedWith});

//  {
//    assert(_currentInjector != null);
//    assert(_currentKey != null);
//
//    var boundToKey = new Key(_typeName(type), annotatedWith: annotatedWith);
//
//    if (!_currentInjector._containsBinding(boundToKey)) {
//        _currentInjector._createBindingForType(type,
//            annotatedWith: annotatedWith);
//    }
//
//    return new Binder._(_currentInjector, _currentKey, boundToKey);
//  }

//  dynamic singleton(Type type, {Object annotatedWith}) {
////    Key key = new Key.forType(type, annotatedWith: annotatedWith);
////    _injector._ensureBinding(key);
//    return _injector._singleton(type, annotatedWith: annotatedWith);
//  }
////      bindTo(type, annotatedWith: annotatedWith).singleton;
//
//  dynamic newInstance(Type type, {Object annotatedWith}) =>
//      _injector._newInstance(type, annotatedWith: annotatedWith);
//  //      bindTo(type, annotatedWith: annotatedWith).newInstance();

}
