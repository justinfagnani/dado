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

class SubBar extends Bar {
  SubBar(Foo foo) : super(foo);
}

// object with an unscoped dependency
class Baz {
  Bar bar;
  Baz(Bar this.bar);
}

class SubBaz extends Baz {
  SubBaz(Bar bar) : super(bar);
}

// object with a cyclic, unscoped dependency 
class Cycle {
  Cycle(Cycle c);
}

// object that depends on the module
class NeedsModule {
  NeedsModule(Module1 module);
}

// a class that's not injectable, and so needs a provider function
class Provided {
  final int i;
  Provided(int this.i, Foo foo);
}

class Module1 extends Module {
  
  Module1() : super();
  
  Module1.childOf(Module1 parent) : super.childOf(parent);
  
  // an instance of a type, similar to bind().toInstance() in Guice
  String string = "a";
  
  // a singleton, similar to bind().to().in(Singleton.class) in Guice
  Foo get foo;
  
  // a factory binding, similar to bind().to() in Guice
  Bar newBar();
  
  // to test that direct cyclical dependencies fail. TODO: indirect cycles
  Cycle newCycle();
  
  // a class that inject the module
  NeedsModule get needsModule;
  
  // a rebindable or mutable binding. can be overriden with rebind()
  Baz get baz => getByType(Baz).singleton;
  
  Provided get provided => getByType(Provided)
      .providedBy((Foo foo) => new Provided(1, foo)).newInstance();
}

class Module2 extends Module1 {
  
  Foo foo = new Foo('foo2');
  
  SubBar newBar();
}

main() {
  test('get constant', () {
    expect(new Module1().string, 'a');
  });

  test('get object', () {
    expect(new Module1().foo, new isInstanceOf<Foo>());
  });

  test('get object by type', () {
    expect(new Module1().getInstanceOf(Foo), new isInstanceOf<Foo>());
  });
  
  test('get object with binding', () {
    expect(new Module1().baz, new isInstanceOf<Baz>());
  });
  
  test('get object with dependencies', () {
    expect(new Module1().newBar(), new isInstanceOf<Bar>());
  });
  
  test('getter defines a singleton', () {
    var module = new Module1();
    var foo = module.foo;
    expect(foo, new isInstanceOf<Foo>());
    var foo2 = module.foo;
    expect(identical(foo, foo2), true);
  });

  test('method creates new instances', () {
    var module = new Module1();
    var bar1 = module.newBar();
    var bar2 = module.newBar();
    expect(bar1, new isInstanceOf<Bar>());
    expect(identical(bar1, bar2), false);
  });

  test('provided binding', () {
    var module = new Module1();
    var provided = module.provided;
    expect(provided, new isInstanceOf<Provided>());
    expect(provided.i, 1);
  });
  
  test('module subclass', () {
    var module = new Module2();
    var foo = module.foo;
  });
  
  test('override singleton binding', () {
    var module = new Module2();
    var foo = module.foo;
    expect(foo.name, 'foo2');
  });

  test('override method binding', () {
    var module = new Module2();
    var bar = module.newBar();
    expect(bar, new isInstanceOf<Bar>());
  });
  
  test('deendency cycles throw', () {
    var module = new Module1();
    expect(() => module.newCycle(), throws);
  });
  
  test('inject the module', () {
    var module = new Module1();
    var m = module.needsModule;
  });

  test('inject the module superclass', () {
    var module = new Module2();
    var m = module.needsModule;
  });

  test('child module has distinct singleton', () {
    var parent = new Module1();
    Module1 child = parent.createChild();
    child.string = 'b';
    expect(parent.string, 'a');
    expect(child.string, 'b');
  });

  test('child module overrides binding', () {
    var parent = new Module1();
    Module1 child = parent.createChild();
    child.bind(Baz).to(SubBaz);
    expect(parent.baz, new isInstanceOf<Baz>());
    expect(child.baz, new isInstanceOf<SubBaz>());
  });

  test('descendents inherit overriden binding', () {
    var parent = new Module1();
    Module1 child = parent.createChild();
    Module1 grandchild = child.createChild();
    child.bind(Baz).to(SubBaz);
    expect(parent.baz, new isInstanceOf<Baz>());
    expect(grandchild.baz, new isInstanceOf<SubBaz>());
  });

  test('rebind with provider', () {
    var module = new Module1();
    var provided1 = module.provided;
    expect(provided1.i, 1);
    module.bind(Provided).to(() => new Provided(2, null));
    var provided2 = module.provided;
    expect(provided2.i, 2);
  });
}
