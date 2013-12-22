Dado
====

Dado is a [dependency injection][di] framework for [Dart][dart].

[![Build Status](https://drone.io/github.com/dart-lang/dado/status.png)](https://drone.io/github.com/dart-lang/dado/latest)

Dado attempts to have minimal set of features and a syntax that takes advantage
of Dart, which makes it different from many other popular DI frameworks.

Dado tries to make DI more lightweight by letting you define modules as Dart
classes and as declaratively as possible. Bindings can be define by simply
declaring an abstract method:

```dart
class MyModule extends Module {
  Foo get foo;
}
```

Then you can create an injector and get an instance of Foo:

```dart
var injector = new Injector([MyModule]);
injector.getInstanceOf(Foo);
```

Or call an injected closure:

```dart
injector.callInjected((Foo foo) {
  print("foo is $foo");
});
```

See the tests for more examples.

[dart]: http://dartlang.org
[di]: http://en.wikipedia.org/wiki/Dependency_injection "Dependency Injection"

Principles
----------

  1. __Idiomatic:__ Dart is a different language than JavaScript or Java and has
     different capabilities and styles. Part of Dado's approach is driven by a
     desire to figure out exactly what a Dart DI framework should look like. We
     try to use language features to drive configuration whenever possible.
  2. __Dev-Time Productivity, Deploy-Time Optimization__ Dado uses Dart mirrors
     to implement injectors dynamically, but we are working on a code generator
     that will allow tools like dart2js to produce smaller output.
  3. __Play Well with the Web:__ Dart is at home on the web and Dado should be
     too, working well with the DOM, and new technologies like custom elements
     and MDV.
  4. __Simplicity__ Dado should be as simple as possible, but no simpler.
  5. __Toolability__ Dado should work well with tools and operations like static find
     references, refactoring, minifiers, tree-shakers, etc.

Documentation
-------------

See the [dartdoc documentation for Dado][doc]

[doc]: http://dart-lang.github.io/dado/docs/dado.html

Installation
------------

Use [Pub][pub] and simply add the following to your `pubspec.yaml` file:

```
dependencies:
  dado: 0.5.1
```

You can find more details on the [Dado page on Pub][dado_pub]

[pub]: http://pub.dartlang.org
[dado_pub]: http://pub.dartlang.org/packages/dado

Binding Examples
----------------

```dart
import 'package:dado/dado.dart';

class MyModule extends Module {

  // binding to an instance, similar to bind().toInstance() in Guice
  String serverAddress = "127.0.0.1";

  // Getters define a singleton, similar to bind().to().in(Singleton.class)
  // in Guice
  Foo get foo;

  // Methods define a factory binding, similar to bind().to() in Guice
  Bar newBar();

  // Methods that delegate to bindTo() bind a type to a specific
  // implementation of that type
  Baz get baz => bindTo(Baz).singleton;

  // Bindings can be made to provider methods
  Qux newQux() => bindTo(Qux)
      .providedBy((Foo foo) => new Qux(foo, 'not injected')).newInstance();
}

class Bar {
  // When there is only one constructor, it is automatically injected with
  // dependencies
  Bar(Foo foo);
}

class Baz {
  String serverAddress;
  
  Baz();
  
  // In classes that have multiple constructors, the desired constructor can
  // be selected using the @inject annotation. Otherwise, Dado will look for
  // a no-args constructor.
  @inject
  Baz.injectable(String this.serverAddress);
}

main() {
  var injector = new Injector([MyModule]);
  Bar bar = injector.getInstance(Bar);
}
```

Status
------

Dado is under active development. It has a few tests, but has not been used in
production yet.

Known Issues and Limitations
----------------------------

 * Functions cannot be injected yet.
 * No custom scope support. The only scopes are unscoped and singleton.
   Hierarchical modules might be enough.
 * Modules must extend `Module`. When mixins are better supported in Dart,
   `Module` can be mixed in instead.
