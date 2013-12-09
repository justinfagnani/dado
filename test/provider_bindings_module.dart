library dado.test.module;

import 'package:dado/dado.dart';

main(){
  new Injector([ProviderModule]);
}

abstract class ProviderModule extends Module {
  Snap snap() => bindTo(Snap).providedBy((Bar b, Foo f) => new Snap(b, f)).singleton;
  Resnap resnap() => bindTo(Resnap).providedBy((Bar b, Snap s) => new Resnap(b, s)).newInstance();
  Bar get bar;
  Foo get foo;
}

class Snap {
  Snap(Bar b, Foo f);
}
class Resnap {
  Resnap(Bar b, Snap s);
}

class Foo{}
class Bar{}
