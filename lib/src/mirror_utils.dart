// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.mirror_utils;

import 'dart:async';
import 'dart:collection';
import 'dart:mirrors';

Map<Type, ClassMirror> _classMirrorCache = new HashMap<Type, ClassMirror>();

/**
 * Caches the result of [reflectClass] to work around performance issues.
 */
// not using this just yet, but might soon
ClassMirror reflectClassCached(Type type) {
  _classMirrorCache.putIfAbsent(type, () => reflectClass(type));
  return _classMirrorCache[type];
}

/**
 * Walks the class hierarchy to search for a superclass or interface named
 * [name]. If [useSimple] is true, then it matches on either qualified or simple
 * names, otherwise only qualified names are matched.
 */
bool implements(ClassMirror m, Symbol name, {bool useSimple: false}) {
  if (m == null) return false;
  if (m.qualifiedName == name || (useSimple && m.simpleName == name)) {
    return true;
  }
  if (m.qualifiedName == new Symbol("dart.core.Object")) return false;
  if (implements(m.superclass, name, useSimple: useSimple)) return true;
  for (ClassMirror i in m.superinterfaces) {
    if (implements(i, name, useSimple: useSimple)) return true;
  }
  return false;
}

/**
 * Walks up the class hierarchy to find a declaration with the given [name].
 */
DeclarationMirror getMemberMirror(ClassMirror classMirror, Symbol name) {
  assert(classMirror != null);
  assert(name != null);
  if (classMirror.members[name] != null) {
    return classMirror.members[name];
  }
  if (hasSuperclass(classMirror)) {
    var memberMirror = getMemberMirror(classMirror.superclass, name);
    if (memberMirror != null) {
      return memberMirror;
    }
  }
  for (ClassMirror supe in classMirror.superinterfaces) {
    var memberMirror = getMemberMirror(supe, name);
    if (memberMirror != null) {
      return memberMirror;
    }
  }
  return null;
}

/**
 * Work-around for http://dartbug.com/5794
 */
bool hasSuperclass(ClassMirror classMirror) {
  ClassMirror superclass = classMirror.superclass;
  return (superclass != null)
      && (superclass.qualifiedName != "dart.core.Object");
}

Object getBindingAnnotation (DeclarationMirror m) {
  // There's some bug with requesting metadata from certain variable mirrors
  // that causes a NoSuchMe thodError because the mirror system is trying to
  // call 'resolve' on null. See dartbug.com/11418
  List<InstanceMirror> metadata;
  try {
    metadata = m.metadata;
  } on NoSuchMethodError catch (e) {
    return null;
  }
  if (metadata.isNotEmpty) {
    // TODO(justin): what do we do when a declaration has multiple
    // annotations? What does Guice do? We should probably only allow one
    // binding annotation per declaration, which means we need a way to
    // identify binding annotations.
    return metadata.first.reflectee;
  }
  return null;
}
