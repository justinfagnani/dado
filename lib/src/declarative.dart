// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Dado's declarative library.
 * 
 * This library contains the implementation of the [DeclarativeModule], that is,
 * as it name suggests, a declarative implementation of [Module].
 */
library dado.declarative;

import 'dart:collection';
import 'dart:mirrors';
import 'package:inject/inject.dart';
import 'binding.dart';
import 'key.dart';
import 'module.dart';
import 'utils.dart' as Utils;


/**
 * A declarative implementation of [Module].
 * 
 * In this kind of module, bindings are defined in a declarative manner.
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
 * * A non-abstract method must return instances of its return type. Getters 
 *   define singletons.
 * 
 * Example
 * -------
 *
 *     import 'package:dado/dado.dart';
 *
 *     class MyModule extends DeclarativeModule {
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
 *       Baz baz(SubBaz subBaz) => subBaz;
 *       
 *       SubBaz get subBaz;
 *
 *       // Bindings can be made to provider methods
 *       Qux newQux(Foo foo) => new Qux(foo, 'not injected');
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
abstract class DeclarativeModule implements Module {
  Map<Key, Binding> get bindings {
    if (_bindings == null) {
      _readBindings();
    }
    
    return _bindings;
  }
  
  Map<Key, Binding> _bindings;
  
  void _readBindings() {
    if (_bindings == null) {
      _bindings = new Map<Key, Binding>();
    }
    
    var moduleMirror = reflect(this);
    var classMirror = moduleMirror.type;

    classMirror.declarations.values.forEach((member) {
      if (member is VariableMirror) {
        // Variables define "to instance" bindings
        var instance = moduleMirror.getField(member.simpleName).reflectee;
        var name = member.type.qualifiedName;
        var annotation = Utils.getBindingAnnotation(member);
        var key = new Key(name, annotatedWith: annotation);
        
        _bindings[key] = new _InstanceBinding(key, instance);
        
      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = Utils.getBindingAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);
        
        if (member.isAbstract) {
          var typeMirror = member.returnType;
          
          if (!(typeMirror is ClassMirror)) {
            throw new ArgumentError(
                '${typeMirror.simpleName} is not a class '
                'and can not be used in a constructor binding.');
          }
          
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _bindings[key] = 
                new _ConstructorBinding(key, 
                                        member.returnType, 
                                        moduleMirror, 
                                        singleton: true);
          } else {
            // Abstract methods define unscoped bindings
            _bindings[key] =  
                new _ConstructorBinding(key, 
                                        member.returnType, 
                                        moduleMirror);
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
                new _ProviderBinding(key, 
                                     member, 
                                     moduleMirror,
                                     singleton: true);
          } else {
            // methods should define unscoped bindings
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
  
}

class _InstanceBinding extends Binding {
  Object _instance;
  List<Dependency> _dependencies = [];
  
  _InstanceBinding(Key key, Object instance) : 
    super(key, singleton: true) {
    _instance = instance;
  }
  
  Object buildInstance(DependencyResolution dependencyResolution) => _instance;
  
  Iterable<Dependency> get dependencies => 
      new UnmodifiableListView(_dependencies);
  
}

class _ProviderBinding extends Binding {
  final InstanceMirror moduleMirror;
  final MethodMirror provider;
  List<Dependency> _dependencies;
  
  _ProviderBinding(Key key, 
                   MethodMirror this.provider, 
                   InstanceMirror this.moduleMirror, 
                   {bool singleton: false}) :
        super(key, singleton: singleton);
  
  Object buildInstance(DependencyResolution dependencyResolution) {
    if (!provider.isGetter) {
      var positionalArguments = 
            _getPositionalArgsFromResolution(dependencyResolution);
      var namedArguments = 
            _getNamedArgsFromResolution(dependencyResolution);
      
      return moduleMirror.invoke(provider.simpleName,
                                  positionalArguments,
                                  namedArguments).reflectee;
    } else {
      return moduleMirror.getField(provider.simpleName).reflectee;
    }
  }
  
  Iterable<Dependency> get dependencies {
    if (_dependencies == null) {
      _dependencies = new List<Dependency>(provider.parameters.length);
      int position = 0;
      
      provider.parameters.forEach(
        (parameter) {
          var parameterClassMirror = 
              (parameter.type as ClassMirror).reflectedType;
          var annotation = Utils.getBindingAnnotation(parameter);
          
          var key = new Key.forType(
              parameterClassMirror,
              annotatedWith: annotation);
          
          var dependency = 
              new Dependency(parameter.simpleName,
                             key, 
                             isNullable: parameter.isNamed || 
                                         parameter.isOptional,
                             isPositional: !parameter.isNamed,
                             position: position);
          
          _dependencies[position] = dependency;
          
          position++;
        });
    }
    
    return new UnmodifiableListView(_dependencies);
  }
  
  List<Object> _getPositionalArgsFromResolution(
      DependencyResolution dependencyResolution) {
    var positionalArgs = new List(dependencyResolution.instances.length);
    
    dependencyResolution.instances.forEach(
        (dependency, instance) {
          if (dependency.isPositional) {
            positionalArgs[dependency.position] = instance;
          }
        });
    
    return positionalArgs.where((e) => e != null).toList(growable: false);
  }
  
  Map<Symbol, Object> _getNamedArgsFromResolution(
      DependencyResolution dependencyResolution) {
    var namedArgs= new Map();
    
    dependencyResolution.instances.forEach(
        (dependency, instance) {
          if (!dependency.isPositional) {
            namedArgs[dependency.name] = instance;
          }
        });
    
    return namedArgs;
  }
  
}

class _ConstructorBinding extends _ProviderBinding {
  ClassMirror classMirror;
  
  _ConstructorBinding(Key key, 
                      ClassMirror classMirror, 
                      InstanceMirror moduleMirror, 
                      {bool singleton: false}) : 
          super(key, 
                 _selectConstructor(classMirror),
                 moduleMirror, 
                 singleton: singleton),
          this.classMirror = classMirror;
  
  @override
  Object buildInstance(DependencyResolution dependencyResolution) {
    var positionalArguments = 
          _getPositionalArgsFromResolution(dependencyResolution);
    var namedArguments = 
          _getNamedArgsFromResolution(dependencyResolution);
    
    var obj = classMirror.newInstance(provider.constructorName,
                                      positionalArguments,
                                      namedArguments).reflectee;
    
    return obj;
  }
  
  static MethodMirror _selectConstructor(ClassMirror m) {
    Iterable<MethodMirror> constructors = Utils.getConstructorsMirrors(m);
    // Choose contructor using @inject
    MethodMirror selectedConstructor = constructors.firstWhere(
      (constructor) => constructor.metadata.any(
        (metadata) => metadata.reflectee == inject)
      , orElse: () => null);

    // In case there is no constructor annotated with @inject, see if there's a
    // single constructor or a no-args.
    if (selectedConstructor == null) {
      if (constructors.length == 1) {
        selectedConstructor = constructors.first;
      } else {
        selectedConstructor = constructors.firstWhere(
            (constructor) => constructor.parameters.where(
                (parameter) => !parameter.isOptional).length == 0
        , orElse: () =>  null);
      }
    }

    if (selectedConstructor == null) {
      throw new ArgumentError("${m.qualifiedName} must have only "
        "one constructor, a constructor annotated with @inject or no-args "
        "constructor");
    }

    return selectedConstructor;
  }

}