// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.module;

import 'dart:mirrors';
import 'package:inject/inject.dart';
import 'binding.dart';
import 'key.dart';
import 'utils.dart' as Utils;

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
  Map<Key, Binding> get bindings;
}
class DeclarativeModule implements Module {
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
        _bindings[key] = new InstanceBinding(key, instance, moduleMirror);

      } else if (member is MethodMirror) {
        var name = member.returnType.qualifiedName;
        var annotation = Utils.getBindingAnnotation(member);
        Key key = new Key(name, annotatedWith: annotation);
        if (member.isAbstract) {
          if (member.isGetter) {
            // Abstract getters define singleton bindings
            _bindings[key] = new ConstructorBinding(key,
                _selectConstructor(member.returnType),  moduleMirror,
                singleton: true);
          } else {
            // Abstract methods define unscoped bindings
            _bindings[key] = new ConstructorBinding(key,
                _selectConstructor(member.returnType),  moduleMirror);
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
                new ProviderBinding(key, member, moduleMirror,
                    singleton: true);
          } else {
            // methods should define unscoped bindings
            // TODO(justin): allow parameters in module method? This would make
            // defining provided bindings much shorter when they rebind to a
            // new type.
            _bindings[key] =
                new ProviderBinding(key, member, moduleMirror);
          }
        }
      }
    });
  }
  
  MethodMirror _selectConstructor(ClassMirror m) {
    Iterable<MethodMirror> constructors = Utils.getConstructorsMirrors(m);
    // Choose contructor using @inject
    MethodMirror selectedConstructor = constructors.firstWhere(
      (constructor) => constructor.metadata.any(
        (m) => m.reflectee == inject)
      , orElse: () => null);

    // In case there is no constructor annotated with @inject, see if there's a
    // single constructor or a no-args.
    if (selectedConstructor == null) {
      if (constructors.length == 1) {
        selectedConstructor = constructors.first;
      } else {
        selectedConstructor = constructors.firstWhere(
            (c) => c.parameters.where((p) => !p.isOptional).length == 0
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