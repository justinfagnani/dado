Dado
====

Dado is a [dependency injection][di] framework for [Dart][dart].

Dado attempts to have minimal set of features and a syntax that takes advantage
of Dart, which makes it different from many other popular DI frameworks.

Dado tries to make DI more lightweight by letting you define modules as Dart
classes and as declaratively as possible. Bindings can be define by simply
declaring an abstract method:

    class MyModule extends Module {
      Foo get foo;
    }

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
  5. __Toolability__ Dado should work well tools and operations like static find
     references, refactoring, minifiers, tree-shakers, etc.

Documentation
-------------

Dartdoc documentation for Dado can be found here:
http://dart-lang.github.io/dado/docs/dado.html

Example
-------

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
      // A default method is automatically injected with dependencies
	  Bar(Foo foo);
	}

    main() {
      var injector = new Injector([MyModule]);
      Bar bar = injector.getInstance(Bar);
    }

Status
------

Dado is under active development. It has a few tests, but has not been used in
production yet.

Known Issues and Limitations
----------------------------

 * Injectable classes must either have a default constructor or a single
   constructor.
 * There can only be one binding per type, because Dado doesn't use annotations
   yet.
 * Functions cannot be injected yet.
 * Named parameters are not supported.
 * No custom scope support. The only scopes are unscoped and singleton.
   Hierarchical modules might be enough.
 * Modules must extend `Module`. When mixins are better supported in Dart,
   `Module` can be mixed in instead.

Star Fishing
------------

 * http://dartbug.com/5897 Look up classes by name
 * http://dartbug.com/9395 Get qualified name from Type
 * http://dartbug.com/8493 Access annotations via mirrors
