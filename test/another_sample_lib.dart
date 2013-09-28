library anothersample;

import 'sample_lib.dart';

class Baz{}
class SubBaz extends Baz{
  SubBaz(Qux q);
}
class Qux{
  Qux(Foo foo);
}