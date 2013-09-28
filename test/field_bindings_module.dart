library dado.test.module;

import 'package:dado/dado.dart';

main(){
  new Injector([FieldsOnlyModule]);
}

abstract class FieldsOnlyModule extends Module {
  FieldsOnlyModule() : super();

  String aString = "abbra";
  bool aBool = true;
  int anInt = 12345;
}
