//Copyright Google, Inc. 2013
library dado.test.module;

import 'package:dado/dado.dart';

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

  String string1 = "abbra", string2 = "cadabrra";
  Foo get foo;
  Bar newBar();
  Baz get baz => new Baz();
}

class GeneratableModule2 extends Module {
  GeneratableModule2() : super();
  bool aBool = true;
}

class Foo{}
class Bar{}
class Baz{}