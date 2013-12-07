library sample;
class Snap{
  Snap(Bar b, Foo f);
}
class Resnap{
  Resnap(Bar b, Snap s);
}
class Foo{}
class Fuzz{}
class SubFuzz extends Fuzz{}
class Bar{}