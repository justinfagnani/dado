library test.library;

import 'package:dado/dado.dart';

class App {
  final String name;
  App(String this.name);
}

class Module1 extends _Module1 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class _Module1 extends Module {
  App get app;
}

class Module2 extends _Module2 {
  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class _Module2 extends Module {
  String name = "app name";
}


class TestInjector extends Injector {
  TestInjector() : super(modules: [Module1, Module2]);

  App getApp() => get(App);

}

main() {
  var injector = new TestInjector();
  var app = injector.getApp();
  print("App.name = ${app.name}");
}
