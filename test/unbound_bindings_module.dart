library dado.test.module;

import 'package:dado/dado.dart';

main(){
  new Injector([UnboundModule]);
}

abstract class UnboundModule extends Module {
  Foo get foo => bindTo(SubFoo).singleton;
  Bar bar() => bindTo(SubBar).newInstance();
  SubBar newSubBar();
}

class Foo{}
class Bar{}
class SubFoo{}
class SubBar{}