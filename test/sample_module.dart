//Copyright Google, Inc. 2013
library dado.test.module;

import 'package:dado/dado.dart';
import 'sample_lib.dart';
import 'another_sample_lib.dart';

///triple slash comment 1
///triple slash comment 2
main(){
  //double slash comment 1
  //double slash comment 2
  new Injector([GeneratableModule1, GeneratableModule2]);
}

/**
 * Block comment 1
 */
/**
 * Block comment 2
 */
abstract class GeneratableModule1 extends Module {
  GeneratableModule1() : super();

  String string1 = "abbra";
  Foo get foo;
  Bar newBar();
  Baz get baz => bindTo(SubBaz).singleton;
  //does this need a newInstance if it is the default?
  Fuzz fuzz() => bindTo(SubFuzz).newInstance();
  Snap snap() => bindTo(Snap).providedBy((Bar b) => new Snap(b)).singleton;
  Resnap resnap() => bindTo(Resnap).providedBy((Bar b) => new Resnap(b)).newInstance();
}

class GeneratableModule2 extends Module {
  GeneratableModule2() : super();
  bool aBool = true;
  Qux newQux();
}

DadoFactory factory = new DadoFactory()
  ..addFactory(Snap, (DadoFactory i) {
    ((Bar b) => new Snap(b))(i.getInstanceOf(Bar) as Bar);
   }, singleton:true)
  ..addFactory(String, (DadoFactory i) => "abbra", singleton:true)
  ..addFactory(bool, (DadoFactory i) => true, singleton:true)
  ..addFactory(SubBaz, (DadoFactory i) => new SubBaz(i.getInstanceOf(Qux)))
  ..addFactory(Baz, (DadoFactory i) => i.getInstanceOf(SubBaz), singleton:true)
  ..addFactory(SubFuzz, (DadoFactory i) => new SubFuzz())
  ..addFactory(Fuzz, (DadoFactory i) => i.getInstanceOf(SubFuzz))
  ..addFactory(Bar, (DadoFactory i) => new Bar())
  ..addFactory(Foo, (DadoFactory i) => new Foo(), singleton:true)
  ..addFactory(Qux, (DadoFactory i) => new Qux(i.getInstanceOf(Foo) as Foo));


class DadoFactory {
  Map<Key, Function> map = {};
  Map<Key, Object> singletons = {};

  Object getInstanceOf(Type t) => map[t](this);

  void addFactory(Type type, Object factory(DadoFactory injector),
      {annotatedWith, singleton: false}) {

    Key key = new Key(type, annotatedWith:annotatedWith);
    map[key] = singleton ? _fetchSingleton(key, factory) : factory;
  }

  Function _fetchSingleton(Key key, Object factory(DadoFactory injector)) => () {
      if(!singletons.containsKey(key)) {
        singletons[key] = factory(this);
      }
      return singletons[key];
    };
}

class Key {
  final Type name;
  final annotation;

  Key(this.name, {annotatedWith}) : annotation = annotatedWith {
    if (name == null) throw new ArgumentError("name must not be null");
  }

  bool operator ==(o) => o is Key && o.name == name
      && o.annotation == annotation;

  int get hashCode => name.hashCode * 37 + annotation.hashCode;

  String toString() => 'Key(name: $name, annotation: $annotation)';
}
