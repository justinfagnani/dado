library dado.test.module;

import 'package:dado/dado.dart';

main(){
  new Injector([SimpleInstanceModule]);
}

abstract class SimpleInstanceModule extends Module {
  Foo newFoo();
  Bar get bar;
}

class Foo{}
class Bar{}