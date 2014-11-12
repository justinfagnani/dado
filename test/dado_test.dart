// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado_test;

import 'package:dado/dado.dart';
import 'package:inject/inject.dart';
import 'package:unittest/unittest.dart';

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
  List l;
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
//class NeedsInjector {
//  Injector injector;
//
//  NeedsInjector(Injector1 this.injector);
//}

// a class that's not injectable, and so needs a provider function
class Provided {
  final int i;

  Provided(int this.i, Foo foo);
}

class HasAnnotatedConstructor {
  String a;

  HasAnnotatedConstructor();

  @inject
  HasAnnotatedConstructor.second(String this.a);
}

class HasNoArgsConstructor {
  String a;

  HasNoArgsConstructor(String this.a);

  HasNoArgsConstructor.noArgs();
}


// Indirect circular dependency tests classes
class Quux {
  Corge corge;

  Quux(Corge this.corge);
}

class Corge {
  Grault grault;

  Corge(Grault this.grault);
}

class Grault {
  Quux quux;

  Grault(Quux this.quux);
}

const A = 'a';
const B = 'b';

abstract class Module1 implements Module {
  int number = 1;

  // an instance of a type, similar to bind(String).toInstance('a') in Guice
  String string = "a";

  // an annotated instance which can be requested independently of an
  // unannotated binding or a binding with a different annotation
  @B String anotherString = "b";

  // a singleton, similar to bind(Foo).in(Singleton.class) in Guice
  Foo get foo;

  @B Foo get fooB;

  // a factory binding, similar to bind(Bar) in Guice
  Bar newBar();

  HasAnnotatedConstructor getHasAnnotatedConstructor();

  HasNoArgsConstructor getHasNoArgsConstructor();

  Baz get baz => singleton(SubBaz);

  Provided provideProvided(Foo foo) => new Provided(1, foo);

  TestInjectable getTest();
}

abstract class Module2 implements Module {

  Foo foo = new Foo('foo2');

//  SubBar newBar() => newInstance(SubBar);
//
  Provided provideProvided(Foo foo) => new Provided(2, foo);
}

abstract class BadChildModule implements Module {
  Foo get foo;
}

abstract class ChildModule implements Module {
  Qux get qux;
}

abstract class Module4 implements Module {
  // to test that direct cyclical dependencies fail.
  Cycle getCycle();
}

abstract class Module5 implements Module {
  // to test that indirect cyclical dependencies fail.
  Quux newQuux(); // => newInstance(Quux);

  Corge newCorge(); // => newInstance(Corge);

  Grault newGrault(); // => newInstance(Grault);
}

class TestInjectable {
  String string;
  String anotherString;
  Foo foo;
  Foo fooB;
  Bar bar;
  Baz baz;
  Provided provided;
//  NeedsInjector needsInjector;
  HasAnnotatedConstructor hasAnnotatedConstructor;
  HasNoArgsConstructor hasNoArgsConstructor;

  @inject
  TestInjectable(
      this.string,
      @B this.anotherString,
      this.foo,
      @B this.fooB,
      this.bar,
      this.baz,
      this.provided,
//      this.needsInjector,
      this.hasAnnotatedConstructor,
      this.hasNoArgsConstructor);
}

class Injector1Module extends Module with Module1 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class Injector1 extends Injector<Injector1Module> {
  Injector1() : super(null);

  TestInjectable getTestInjectable() => get(TestInjectable);
}

class Injector2Module extends Module with Module1, Module2 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class Injector2 extends Injector<Injector2Module> {
  Injector2() : super(null);

  TestInjectable getTestInjectable() => get(TestInjectable);

//  noSuchMethod(i) => super.noSuchMethod(i);
}

class ParentInjectorModule extends Module with Module1 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class ParentInjector extends Injector<ParentInjectorModule> {
  ParentInjector() : super(null);
  TestInjectable getTestInjectable() => get(TestInjectable);
}

class BadChildInjectorModule extends Module with BadChildModule {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class BadChildInjector extends Injector<BadChildInjectorModule>{
  BadChildInjector(ParentInjector parent) : super(parent);
  TestInjectable getTestInjectable() => get(TestInjectable);
}

class ChildInjectorModule extends Module with ChildModule {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class ChildInjector extends Injector<ChildInjectorModule>{
  ChildInjector(ParentInjector parent) : super(parent);
  TestInjectable getTestInjectable() => get(TestInjectable);
  Qux getQux() => get(Qux);
}

class Injector4Module extends Module with Module4 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class Injector4 extends Injector<Injector4Module> {
  Injector4() : super(null);
}

class Injector5Module extends Module with Module5 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class Injector5 extends Injector<Injector5Module> {
  Injector5() : super(null);
}

main() {

  group('injector with single module', () {
    Injector1 injector;

    setUp((){
      injector = new Injector1();
    });

    test('should return an instance for a ingector method', () {
      var t = injector.getTestInjectable();
      expect(t, new isInstanceOf<TestInjectable>());
    });

    test('should return the value of an instance field', () {
      var t = injector.getTestInjectable();
      expect(t.string, 'a');
    });

    test('should return the value of an annotated instance field', () {
      var t = injector.getTestInjectable();
      expect(t.anotherString, 'b');
    });

    test('should return a singleton of the return type of a getter', () {
      var t1 = injector.getTestInjectable();
      var t2 = injector.getTestInjectable();
      var foo1 = t1.foo;
      var foo2 = t2.foo;
      expect(foo1, new isInstanceOf<Foo>());
      expect(identical(foo1, foo2), true);
    });

    test('should create new objects from methods', () {
      var t1 = injector.getTestInjectable();
      var t2 = injector.getTestInjectable();
      var bar1 = t1.bar;
      var bar2 = t2.bar;
      expect(bar1, new isInstanceOf<Bar>());
      expect(identical(bar1, bar2), false);
    });

//    test('should provide singleton dependencies', () {
//      var bar1 = injector.newBar();
//      var bar2 = injector.newBar();
//      expect(bar1.foo, new isInstanceOf<Foo>());
//      expect(identical(bar1.foo, bar2.foo), true);
//    });

    test('should return a singleton of the type of an explicit binding', () {
      var t1 = injector.getTestInjectable();
      var t2 = injector.getTestInjectable();
      Baz baz1 = t1.baz;
      Baz baz2 = t2.baz;
      expect(baz1, new isInstanceOf<SubBaz>());
      expect(identical(baz1, baz2), true);
    });

    test('should invoke provider methods', () {
      var t1 = injector.getTestInjectable();
      var provided = t1.provided;
      expect(provided, new isInstanceOf<Provided>());
      expect(provided.i, 1);
    });

    skip_test('should inject itself', () {
      var t1 = injector.getTestInjectable();
//      NeedsInjector o = t1.needsInjector;
//      expect(o.injector, same(injector));
    });

    test('should use annotated constructor', () {
      var t1 = injector.getTestInjectable();
      var o = t1.hasAnnotatedConstructor;
      expect(o, new isInstanceOf<HasAnnotatedConstructor>());
      expect(o.a, 'a');
    });

    // TODO: We probably need to remove callInjected(). It's no different from
    // getInstanceOf(). We could come up with a way for a module to declare
    // that it can invoke a certain closure, basically a specialized version
    // of callInjected per closure type.
    skip_test('should inject and call closures', () {
//      bool called = false;
//      injector.callInjected((Foo foo) {
//        expect(foo, new isInstanceOf<Foo>());
//        called = true;
//      });
//      expect(called, true);
    });

    test('should use no-args constructor', () {
      var t1 = injector.getTestInjectable();
      var o = t1.hasNoArgsConstructor;
      expect(o, new isInstanceOf<HasNoArgsConstructor>());
      expect(o.a, null);
    });

  });

  group('injector with two modules', () {
    Injector2 injector;

    setUp((){
      injector = new Injector2();
    });

    test('should use bindings from second module', () {
      // TODO: create a new TestInjectable, since this one injects Injector1
      var t1 = injector.getTestInjectable();
      var foo = t1.foo;
      expect(foo, new isInstanceOf<Foo>());
      expect(foo.name, 'foo2');
    });

    test('should use bindings from second module', () {
      var t1 = injector.getTestInjectable();
      var provided = t1.provided;
      expect(provided.i, 2);
    });
  });

  group('injector with cyclic dependencies', () {
    // TODO: cycles that pass though providers? binders?
    test('should throw ArgumentError on direct cyclical dependencies', () {
      expect(() => new Injector4(), throwsArgumentError);
    });

    test('should throw ArgumentError on indirect cyclical dependencies', () {
      expect(() => new Injector5(), throwsArgumentError);
    });
  });

  group('child injector', () {
    ParentInjector injector;
    ChildInjector childInjector;

    setUp((){
      injector = new ParentInjector();
      childInjector = new ChildInjector(injector);
    });

    test('should throw if child include key from parent', () {
      injector = new ParentInjector();
      expect(() => new BadChildInjector(injector), throws);
    });

    test("should get a singleton from its parent", () {
      var t1 = injector.getTestInjectable();
      var t2 = childInjector.getTestInjectable();
      var foo1 = t1.foo;
      var foo2 = t2.foo;
      expect(foo1, new isInstanceOf<Foo>());
      expect(foo1, same(foo2));
    });

    test("should use a binding not in its parent", () {
      var qux = childInjector.getQux();
      expect(qux, new isInstanceOf<Qux>());
    });

//    test("should inject itself, not its parent", () {
//      injector.callInjected((Injector i) {
//        expect(i, same(injector));
//      });
//      childInjector.callInjected((Injector i) {
//        expect(i, same(childInjector));
//      });
//    });

    test("should maintain singletons for bindings not in the parent", () {
      var childInjector2 = new ChildInjector(injector);
      var qux1 = childInjector.getQux();
      var qux2 = childInjector2.getQux();
      expect(qux1, isNot(same(qux2)));
    });

  });

}
