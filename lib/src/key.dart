part of dado;

Key _makeKey(dynamic k) => (k is Key) ? k : new Key.forType(k);

/**
 * Keys are used to resolve instances in an [Injector], they are used to
 * register bindings and request an object at the injection point.
 *
 * Keys consist of a [Symbol] representing the type name and an optional
 * annotation. If you need to create a Key from a [Type] literal, use [forType].
 */
class Key {
  final Symbol name;
  final Object annotation;

  Key(this.name, {Object annotatedWith}) : annotation = annotatedWith {
    if (name == null) throw new ArgumentError("name must not be null");
  }

  Key.forType(Type type, {Object annotatedWith}) :
      this(quiver.getTypeName(type), annotatedWith: annotatedWith);

  bool operator ==(o) => o is Key && o.name == name
      && o.annotation == annotation;

  int get hashCode => name.hashCode * 37 + annotation.hashCode;

  String toString() => 'Key: $name'
      '${(annotation!=null?' annotated with $annotation': '')}';
}