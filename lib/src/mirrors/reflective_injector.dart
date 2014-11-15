part of dado.mirrors;

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
  /// The parent of this injector, if it's a child injector, or null.
  final Injector parent;

  // The map of bindings and its keys.
  final Map<Key, _Binding> _bindings = new Map<Key, _Binding>();

  // The map of singleton instances
  final Map<Key, Object> _singletons = new Map<Key, Object>();

  /**
   * Constructs a new Injector using [modules] to provide bindings. If [parent]
   * is specificed, the injector is a child injector that inherits bindings
   * from its parent. The modules of a child injector add to or override its
   * parent's bindings.
   */
  Injector({List<Type> modules, this.parent}) {
    for (var moduleType in modules) {
      var moduleClassMirror = reflectClass(moduleType);
      var moduleMirror = moduleClassMirror.newInstance(const Symbol(''), []);
      _registerBindings(moduleMirror);
    }
    _bindings.values.forEach((binding) => _verifyCircularDependency(binding));
  }

  /**
   * This method must only be called from an Injector subclass. It should be
   * protected.
   */
  get(Type type, {dynamic annotatedWth}) {
    Key key = new Key.forType(type, annotatedWith: annotatedWth);
    return _getInstanceOf(key);
  }

  Object _getInstanceOf(Key key, {bool autoBind: false}) {
    var binding = _getBinding(key, autoBind: autoBind);

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

  /*
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
//  dynamic callInjected(Function f) {}

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

  void _registerBindings(InstanceMirror moduleMirror) {
    var declarations = _getModuleDeclarations(moduleMirror.type);

    var selfKey = new Key.forType(this.runtimeType);
    _bindings[selfKey] = new _InstanceBinding(selfKey, this);

    declarations.where((m) => !m.isStatic).forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
//        var name = member.type.qualifiedName;
        var annotation = _getBindingAnnotation(member);
        var key = new Key.forType(member.type.reflectedType, annotatedWith: annotation);
        if (parent != null && parent._bindings.containsKey(key)) {
          throw new Exception("child injectors cannot override bindings in "
              "parents");
        }
        _bindings[key] = new _InstanceBinding(key, instance);
      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = _getBindingAnnotation(member);
        Key key = new Key.forType(member.returnType.reflectedType, annotatedWith: annotation);

        if (parent != null && parent._bindings.containsKey(key)) {
          throw new Exception("child injectors cannot override bindings in "
              "parents");
        }

        if (member.isAbstract) {
          if (!_bindings.containsKey(key)) {
            if (member.isGetter) {
              // Abstract getters define singleton bindings
              ClassMirror boundType = firstNonNull(_getBoundType(member), member.returnType);
              _bindings[key] = new _ConstructorBinding(
                  key,
                  _selectConstructor(boundType),
                  moduleMirror,
                  singleton: true);
            } else {
              // Abstract methods define unscoped bindings
              _bindings[key] = new _ConstructorBinding(key,
                  _selectConstructor(member.returnType),  moduleMirror);
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
            // getters define singleton bindings
            _bindings[key] =
                new _ProviderBinding(key, member, moduleMirror,
                    singleton: true);
          } else {
            // methods define unscoped bindings
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

  // TODO: use linear time cycle check on the whole dependency graph
  void _verifyCircularDependency(_Binding binding,
      [Queue<Key> dependencyStack]) {
    if (dependencyStack == null) dependencyStack = new Queue<Key>();

    if (dependencyStack.contains(binding.key)) {
      dependencyStack.add(binding.key);
      var stackInfo = dependencyStack.join('->\n');
      throw new ArgumentError(
          'Circular dependency found on type ${binding.key.type}:\n$stackInfo');
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
}

Object _getBindingAnnotation (DeclarationMirror declarationMirror) {
  // TODO(justin): what do we do when a declaration has multiple
  // annotations? What does Guice do? We should probably only allow one
  // binding annotation per declaration, which means we need a way to
  // identify binding annotations.
  return declarationMirror.metadata
      .map((m) => m.reflectee)
      .firstWhere((m) => m is! BindTo, orElse: () => null);
}

ClassMirror _getBoundType(DeclarationMirror declarationMirror) {
  BindTo bindTo = declarationMirror.metadata
      .map((m) => m.reflectee)
      .firstWhere((m) => m is BindTo, orElse: () => null);
  return bindTo == null ? null : reflectClass(bindTo.type);
}

final _moduleTypeName = getTypeName(Module);

Iterable<DeclarationMirror> _getModuleDeclarations(ClassMirror mirror,
    [declarations]) {
  if (declarations == null) declarations = <DeclarationMirror>[];

  if (mirror.superclass != null) {
    _getModuleDeclarations(mirror.superclass, declarations);
  }

  if (mirror.qualifiedName != _moduleTypeName &&
      classImplements(mirror, _moduleTypeName)) {
    var localDeclarations = mirror.declarations.values
        .where((d) => d.simpleName != #noSuchMethod);
    declarations.addAll(localDeclarations);
  }

  return declarations;
}
