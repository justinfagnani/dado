part of dado;

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
abstract class Injector<M extends Module> {
  // The key that indentifies the default Injector binding.
  static final Key _injectorKey = new Key.forType(Injector);

  /// The parent of this injector, if it's a child injector, or null.
  final Injector parent;

  // The map of bindings and its keys.
  final Map<Key, _Binding> _bindings = new Map<Key, _Binding>();

  // The map of singleton instances
  final Map<Key, Object> _singletons = new Map<Key, Object>();

  // instance mirror on the module
  InstanceMirror _moduleMirror;

  /**
   * Constructs a new Injector using [modules] to provide bindings. If [parent]
   * is specificed, the injector is a child injector that inherits bindings
   * from its parent. The modules of a child injector add to or override its
   * parent's bindings. [newInstances] is a list of types that a child injector
   * should create distinct instances for, separate from it's parent.
   * newInstances only apply to singleton bindings.
   */
  Injector(this.parent) {
    if (M == dynamic) {
      throw 'you must declare the type parameter for Injector';
    }
    var _moduleClassMirror = reflectClass(M);
//    print("module mirror: $_moduleMirror");
    _moduleMirror = _moduleClassMirror.newInstance(const Symbol(''), []);
    var module = _moduleMirror.reflectee;
    module._injector = this;
//    print(module);
//    _mirror = reflect(this);
    _registerBindings();
    _bindings.values.forEach((binding) => _verifyCircularDependency(binding));
  }

  /**
   * This method must only be called from an Injector subclass. It should be
   * protected.
   */
  get(Type type, {annotatedWth}) {
    Key key = new Key.forType(type, annotatedWith: annotatedWth);
    return _getInstanceOf(key);
  }

  /**
   * Creates a child of this Injector with the additional modules installed.
   * [modules] must be a list of Types that extend Module.
   * [newInstances] is a list of Types that the child should create new
   * instances for, rather than use an instance from the parent.
   */
//  Injector createChild(List<Type> modules, {List<Type> newInstances}) =>
//      new Injector(parent: this);

  /**
   * Returns an instance of [type]. If [annotatedWith] is provided, returns an
   * instance that was bound with the annotation.
   */
//  Object getInstanceOf(Type type, {Object annotatedWith}) {
//    var key = new Key(_typeName(type), annotatedWith: annotatedWith);
//    return _getInstanceOf(key);
//  }

//  dynamic noSuchMethod(Invocation i) {
//    print('Injector.noSuchMethod: ${i.memberName}');
//    var name = i.memberName;
//    var member = quiver.getDeclaration(_mirror.type, name);
//    print('member: $member');
//    var annotation = _getBindingAnnotation(member);
//
//    if (member is MethodMirror && !member.isSetter) {
//      var type = member.returnType.reflectedType;
//      // Abstract getters define singleton bindings
//      Key key = new Key.forType(type, annotatedWith: annotation);
//      return _getInstanceOf(key);
//    }
//
//    return super.noSuchMethod(i);
//  }

  // should only be called from Module.singleton
  dynamic _singleton(Type type, {Object annotatedWith}) {
    var boundToKey = new Key.forType(type, annotatedWith: annotatedWith);
    return _singletons.putIfAbsent(boundToKey, () {
      if (!_containsBinding(boundToKey)) {
        // TODO: _createBindingForType is recreating the key, why not reuse it?
        _createBindingForType(reflectClass(type), annotatedWith: annotatedWith);
      }
      return _getInstanceOf(boundToKey);
    });
  }

  // should only be called from Module.newInstance
  dynamic _newInstance(Type type, {Object annotatedWith}) {
    var boundToKey = new Key.forType(type, annotatedWith: annotatedWith);
    if (!_bindings.containsKey(boundToKey)) {
      // TODO: _createBindingForType is recreating the key, why not reuse it?
      _createBindingForType(reflectClass(type), annotatedWith: annotatedWith);
    }
    return _getInstanceOf(boundToKey);
  }

  Object _getInstanceOf(Key key, {bool autoBind: false}) {
    var binding = _getBinding(key, autoBind: autoBind);

//    print("binding($key): $binding");

    if (binding.singleton) {
      return _getSingletonOf(key);
    }

    return binding.getInstance(this);
  }

  Object _getSingletonOf(Key key) {
    if (parent == null || _bindings.containsKey(key)) {
      if (!_singletons.containsKey(key)) {
        _singletons[key] = _getBinding(key).getInstance(this);
      }
      return _singletons[key];
    } else {
      return parent._getSingletonOf(key);
    }
  }

  /**
   * Execute the function [f], injecting any arguments.
   */
  /**
   * This method was removed because to implement it with the very static style
   * of code generation is tricky. As is, it requires a map->factory to create
   * resolve instances for parameters. Instead we can configure the injector
   * to generate functions to call certain method signatures ahead of time.
   *
   *     typedef Foo(A a, B b);
   *
   *     class MyInjector {
   *       invokeFoo(Foo f);
   *     }
   */
//  dynamic callInjected(Function f) {
//    var mirror = reflect(f);
//    assert(mirror is ClosureMirror);
//    var parameters = _resolveParameters(mirror.function.parameters);
//    return Function.apply(f, parameters);
//  }

  _Binding _getBinding(Key key, {bool autoBind: false}) {
      var binding = _bindings.containsKey(key)
        ? _bindings[key]
        : (parent != null)
            ? parent._getBinding(key)
            : null;

    if (binding == null) {
      if (autoBind == true) {
        // create binding for key
      } else {
        throw new ArgumentError('$key has no binding.\n'
            '${_bindings.keys}');
      }
    }

    return binding;
  }

  bool _containsBinding(Key key) => _bindings.containsKey(key)
      || (parent != null && parent._containsBinding(key));

  List<Object> _resolveParameters(List<ParameterMirror> parameters) =>
      parameters.where((parameter) => !parameter.isOptional).map((parameter) {
          var type = (parameter.type as ClassMirror).reflectedType;
          var key = new Key.forType(type,
              annotatedWith: _getBindingAnnotation(parameter));
          return _getInstanceOf(key);
        }).toList(growable: false);

  void _registerBindings() {
    var declarations = _getModuleDeclarations(_moduleMirror.type);
//    print('declarations: ${declarations}');

    var selfKey = new Key.forType(this.runtimeType);
    _bindings[selfKey] = new _InstanceBinding(selfKey, this);

    declarations.forEach((member) {
      if (member is VariableMirror && !member.isStatic) {
        // Variables define "to instance" bindings
        var instance = _moduleMirror.getField(member.simpleName).reflectee;
        var name = member.type.qualifiedName;
        var annotation = _getBindingAnnotation(member);
        var key = new Key(name, annotatedWith: annotation);
        if (parent != null && parent._bindings.containsKey(key)) {
          throw new Exception("child injectors cannot override bindings in "
              "parents");
        }
        _bindings[key] = new _InstanceBinding(key, instance);
//        print("adding instance binding for $key");
      } else if (member is MethodMirror && !member.isStatic) {
        var name = member.returnType.qualifiedName;
        var annotation = _getBindingAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);

        if (parent != null && parent._bindings.containsKey(key)) {
          throw new Exception("child injectors cannot override bindings in "
              "parents");
        }

        if (member.isAbstract) {
          if (!_bindings.containsKey(key)) {
            if (member.isGetter) {
              // Abstract getters define singleton bindings
              _bindings[key] = new _ConstructorBinding(key,
                  _selectConstructor(member.returnType),  _moduleMirror,
                  singleton: true);
//              print("adding abstract getter binding for $key");
            } else {
              // Abstract methods define unscoped bindings
              _bindings[key] = new _ConstructorBinding(key,
                  _selectConstructor(member.returnType),  _moduleMirror);
//              print("adding abstract method binding for $key");
            }
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
//            print("adding getter binding for $key");
            // getters should define singleton bindings
            _bindings[key] =
                new _ProviderBinding(key, member, _moduleMirror,
                    singleton: true);
          } else {
//            print("adding method binding for $key");
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            _bindings[key] =
                new _ProviderBinding(key, member, _moduleMirror);
          }
        }
      }
    });
  }

  // TODO: use linear time cycle check on the whole dependency graph
  void _verifyCircularDependency(_Binding binding,
      [Queue<Key> dependencyStack]) {
    if (dependencyStack == null) dependencyStack = new Queue<Key>();

    if (dependencyStack.contains(binding.key)) {
      dependencyStack.add(binding.key);
      var stackInfo = dependencyStack.join('->\n');
      throw new ArgumentError(
          'Circular dependency found on type ${binding.key.name}:\n$stackInfo');
    }

    dependencyStack.add(binding.key);

    for (var dependency in binding.dependencies) {
      var dependencyBinding = this._getBinding(dependency);
      _verifyCircularDependency(dependencyBinding, dependencyStack);
    }
    dependencyStack.removeLast();
  }

  MethodMirror _selectConstructor(ClassMirror m) {
    Iterable<DeclarationMirror> constructors = m.declarations.values.where(
        (d) => (d is MethodMirror) && (d.isConstructor));

    // First, find a contructor annotated with @inject
    MethodMirror ctor = constructors.firstWhere(
        (c) => c.metadata.any((m) => m.reflectee == inject),
        orElse: () => null);

    // In case there is no constructor annotated with @inject, see if there's a
    // single constructor or a no-args.
    if (ctor == null) {
      if (constructors.length == 1) {
        ctor = constructors.first;
      } else {
        ctor = constructors.firstWhere(
            (c) => c.parameters.where((p) => !p.isOptional).length == 0,
            orElse: () =>  null);
      }
    }

    if (ctor == null) {
      throw new ArgumentError("${m.qualifiedName} must have only "
        "one constructor, a constructor annotated with @inject or no-args "
        "constructor");
    }

    return ctor;
  }

  /**
   * Create a new constructor binding for the type represented by [classMirror]
   * and return the binding.
   */
  _Binding _createBindingForType(ClassMirror classMirror, {Object annotatedWith,
      bool singleton: false}) {

    MethodMirror ctor = _selectConstructor(classMirror);
    var key = new Key(classMirror.qualifiedName, annotatedWith: annotatedWith);
    return _bindings[key] =
        new _ConstructorBinding(key, ctor, _moduleMirror, singleton: singleton);
  }
}

Object _getBindingAnnotation (DeclarationMirror declarationMirror) {
  List<InstanceMirror> metadata;
  metadata = declarationMirror.metadata;

  if (metadata.isNotEmpty) {
    // TODO(justin): what do we do when a declaration has multiple
    // annotations? What does Guice do? We should probably only allow one
    // binding annotation per declaration, which means we need a way to
    // identify binding annotations.
    return metadata.first.reflectee;
  }

  return null;
}

final _moduleTypeName = quiver.getTypeName(Module);

Iterable<DeclarationMirror> _getModuleDeclarations(ClassMirror mirror,
    [declarations]) {
  if (declarations == null) declarations = <DeclarationMirror>[];

  if (mirror.superclass != null) {
    _getModuleDeclarations(mirror.superclass, declarations);
  }

  if (mirror.qualifiedName != _moduleTypeName &&
      quiver.classImplements(mirror, _moduleTypeName)) {
    var localDeclarations = mirror.declarations.values
        .where((d) => d.simpleName != #noSuchMethod);
    declarations.addAll(localDeclarations);
  }

  return declarations;
}
