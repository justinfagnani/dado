Dado
====

Dado is an experimental dependency injection framework for Dart.

Dado has a minimal set of features and some experimental syntax different from
most other popular dependency injection frameworks. This is an experiment
afterall. Feedback and contribution is more than welcome, but use at your own
risk, since this experiment might not work.

Dado tries to make DI more lightweight by letting you define modules as Dart
classes and as declaratively as possible. Bindings can be define by simply
declaring an abstract method:

    class MyModule extends Module {
      Foo get foo;
    } 

See the tests for more examples.

Principles
----------

  1. __Idiomatic__ Dart is a different language that JavaScript or Java and has
     different capabilities and styles. Part of Dado's different approach is
     driven by a desire to figure out exactly what a Dart DI framework could
     look like. We try to use language features to drive configuration whenever
     possible.
  2. __Simplicity__ Dado has very few concepts, Modules are both
     configuration and container, so there's no separate injector as in Guice.
     Dado only support constructor injection.
  3. __Toolability__ Dado modules are configured by defining members on a Module
     subclass. The return type of the variable or method defines the binding.
     This means that 'Find References' will show the module. It also means that
     the module can be used to get instances in a type-safe manner, by calling
     a method, so you get code-completion if you use the module directly.
  4. __Hierarchical__ Dart is at home on the web and in the DOM, and the DOM is
     hierarchical. Interesting applications of DI will involve bindings
     per-node that are visible to subtrees. Enabling this is a high priority for
     Dado, so deeply hierarchical modules should perform well.
     
     
Example
-------

    import 'package:dado/dado.dart';
    
    class Module1 extends Module {
  
	  Module1() : super();
	  Module1.childOf(Module1 parent) : super.childOf(parent);
	    
	  // binding to an instance, similar to bind().toInstance() in Guice
	  String serverAddress = "127.0.0.1";
	  
	  // Getters define a singleton, similar to bind().to().in(Singleton.class)
	  // in Guice
	  Foo get foo;
	    
	  // Methods define a factory binding, similar to bind().to() in Guice
	  Bar newBar();
	  
	  // Methods that delegate to getByType() define mutable factory bindings
	  // that are overridable.
	  Baz get baz => getByType(Baz).singleton;

      // Mutable bindings can be made to provider methods	  
	  Qux newQux() => getByType(Qux)
	      .providedBy((Foo foo) => new Qux(foo, 'not injected')).newInstance();
	}
	
	class Bar {
	  Bar(Foo foo);
	}

    main() {
      var module = new Module1();
      var bar = module.newBar();
    }
    
Status
------

Dado is a proof-of-concept. It has a few tests, but has not been used in
production yet. It also has some several limitations due to bugs and missing
features in mirrors.

Known Issues and Limitations
----------------------------

 * Injectable classes must either have a default constructor or a single
   constructor.
 * There can only be one bindings per type, because mirrors don't allow access
   to annotations yet.
 * Dado only runs in the Dart VM for now since it uses mirrors, but a
   code-generation version should be possible.
 * Certain bindings, those made using `Type` objects with `getByType()` are
   resolved using simple names rather than qualified names, so Dado will be
   unable to distinguish between types from separate libraries with the same
   name.
 * Functions cannot be injected yet.
 * Named parameters are not supported.
 * No custom scope support. The only scopes are unscoped and singleton.
   Hierarchical modules might be enough.
 * Modules must extend `Module`. This means that using mixins as a replacement
   for installing another module doesn't work if the mixed-in module also works
   standalone.
   
Star Fishing
------------

 * http://dartbug.com/5897 Look up classes by name
 * http://dartbug.com/9395 Get qualified name from Type
 * http://dartbug.com/8493 Access annotations via mirrors
 