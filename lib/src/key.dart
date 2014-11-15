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
  final Type type;
//  final Symbol name;
  final Object annotation;

//  Key(this.name, {Object annotatedWith}) : annotation = annotatedWith {
//    if (name == null) throw new ArgumentError("name must not be null");
//  }

  Key.forType(Type this.type, {Object annotatedWith})
      : annotation = annotatedWith;
//      this(getTypeName(type), annotatedWith: annotatedWith);

  bool operator ==(o) => o is Key
      && o.type == type
      && o.annotation == annotation;

  int get hashCode => hash2(type, annotation);

  String toString() => 'Key: $type'
      '${(annotation!=null?' annotated with $annotation': '')}';
}
