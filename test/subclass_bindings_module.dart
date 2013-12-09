library dado.test.module;

import 'package:dado/dado.dart';

main(){
  new Injector([SubclassModule]);
}

abstract class SubclassModule extends Module {
  Foo get foo => bindTo(SubFoo).singleton;
  Bar bar() => bindTo(SubBar).newInstance();
  SubFoo newSubFoo();
  SubBar newSubBar();
}

class Foo{}
class Bar{}
class SubFoo{}
class SubBar{}