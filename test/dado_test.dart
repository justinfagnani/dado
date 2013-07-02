// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado_test;

import 'package:unittest/unittest.dart';
import 'package:dado/dado.dart';

// object with a dependency bound to an instance
class Foo {
  String name;
  Foo(String this.name);
  String toString() => "Foo { name: $name}";
}

// object with a singleton dependecy
class Bar {
  Foo foo;
  Bar(Foo this.foo);
  String toString() => "Bar {foo: $foo}";
}

// subclass of dependency for binding
class SubBar extends Bar {
  SubBar(Foo foo) : super(foo);
}

// object with an unscoped (non-singleton) dependency
class Baz {
  Bar bar;
  Baz(Bar this.bar);
}

class SubBaz extends Baz {
  SubBaz(Bar bar) : super(bar);
}

class Qux {
}

// object with a cyclic, unscoped dependency
class Cycle {
  Cycle(Cycle c);
}

// object that depends on the module
class NeedsInjector {
  Injector injector;
  NeedsInjector(Injector this.injector);
}

// a class that's not injectable, and so needs a provider function
class Provided {
  final int i;
  Provided(int this.i, Foo foo);
}

abstract class Module1 extends Module {

  // an instance of a type, similar to bind().toInstance() in Guice
  String string = "a";

  // a singleton, similar to bind().to().in(Singleton.class) in Guice
  Foo get foo;

  // a factory binding, similar to bind().to() in Guice
  Bar newBar();

  // to test that direct cyclical dependencies fail. TODO: indirect cycles
  Cycle newCycle();

  // a class that injects the module
  NeedsInjector needsInjector();

  Baz get baz => bindTo(SubBaz).singleton;

  Provided get provided => bindTo(Provided)
      .providedBy((Foo foo) => new Provided(1, foo)).newInstance();
}

abstract class Module2 extends Module1 {

  Foo foo = new Foo('foo2');

  SubBar newBar();

  Provided getProvided(Foo foo) => new Provided(2, foo);
}

abstract class Module3 extends Module {

  Qux get qux;

  Bar newBar() =>bindTo(SubBar).newInstance();
}

main() {

  group('injector',(){
    Injector injector;

    setUp((){
      injector = new Injector([Module1]);
    });

    test('should return the value of an instance field', () {
      expect(injector.getInstanceOf(String), 'a');
    });

    test('should return a singleton of the return type of a getter', () {
      var foo1 = injector.getInstanceOf(Foo);
      var foo2 = injector.getInstanceOf(Foo);
      expect(foo1, new isInstanceOf<Foo>());
      expect(identical(foo1, foo2), true);
    });

    test('should create new objects from methods', () {
      var bar1 = injector.getInstanceOf(Bar);
      var bar2 = injector.getInstanceOf(Bar);
      expect(identical(bar1, bar2), false);
    });

    test('should provide singleton dependencies', () {
      var bar1 = injector.getInstanceOf(Bar);
      var bar2 = injector.getInstanceOf(Bar);
      expect(identical(bar1.foo, bar2.foo), true);
    });

    test('should return a singleton of the type of an explicit binding', () {
      Baz baz1 = injector.getInstanceOf(Baz);
      Baz baz2 = injector.getInstanceOf(Baz);
      expect(baz1, new isInstanceOf<SubBaz>());
      expect(identical(baz1, baz2), true);
    });

    test('should invoke provider methods', () {
      var provided = injector.getInstanceOf(Provided);
      expect(provided, new isInstanceOf<Provided>());
      expect(provided.i, 1);
    });

    test('should use bindings from second module', () {
      injector = new Injector([Module1, Module2]);
      var foo = injector.getInstanceOf(Foo);
      expect(foo, new isInstanceOf<Foo>());
      expect(foo.name, 'foo2');
    });

    test('should use bindings from second module', () {
      injector = new Injector([Module1, Module2]);
      var provided = injector.getInstanceOf(Provided);
      expect(provided.i, 2);
    });

    test('should throw exceptions on dependency cycles', () {
      expect(() => injector.getInstanceOf(Cycle), throws);
    });

    test('should inject itself', () {
      NeedsInjector o = injector.getInstanceOf(NeedsInjector);
      expect(o.injector, same(injector));
    });

  });

  group('child injector', () {
    Injector injector;
    Injector childInjector;

    setUp((){
      injector = new Injector([Module1], name: 'parent');
      childInjector = new Injector([Module3], newInstances: [Baz],
          parent: injector, name: 'child');
    });

    test("should get a singleton from it's parent", () {
      var foo1 = injector.getInstanceOf(Foo);
      var foo2 = childInjector.getInstanceOf(Foo);
      expect(foo1, same(foo2));
    });

    test("should use a binding not in it's parent", () {
      try {
        var qux1 = injector.getInstanceOf(Qux);
        expect(true, false);
      } on ArgumentError catch (e) {
        // pass
      }
      var qux2 = childInjector.getInstanceOf(Qux);
      expect(qux2, new isInstanceOf<Qux>());
    });

    test("should use a binding that overrides it's parent", () {
      var bar1 = injector.getInstanceOf(Bar);
      expect(bar1, new isInstanceOf<Bar>());
      var bar2 = childInjector.getInstanceOf(Bar);
      expect(bar2, new isInstanceOf<SubBar>());
    });

    test('should have distinct singleton of newInstances', () {
      var baz1 = injector.getInstanceOf(Baz);
      var baz2 = childInjector.getInstanceOf(Baz);
      expect(baz1, isNot(same(baz2)));
    });


    test("should inject itself, not it's parent", () {
      injector.callInjected((Injector i) {
        expect(i, same(injector));
      });
      childInjector.callInjected((Injector i) {
        expect(i, same(childInjector));
      });
    });

    test("should inject itself into an object defined in it's parent", () {
      var ni1 = injector.getInstanceOf(NeedsInjector);
      var ni2 = childInjector.getInstanceOf(NeedsInjector);
      expect(ni1.injector, same(injector));
      expect(ni2.injector, same(childInjector));
    });

    test("should maintain singletons for bindings not in the parent", () {
      var childInjector2 = new Injector([Module3], newInstances: [Baz],
          parent: injector, name: 'child 2');
      var qux1 = childInjector.getInstanceOf(Qux);
      var qux2 = childInjector2.getInstanceOf(Qux);
      expect(qux1, isNot(same(qux2)));
    });

  });

}
