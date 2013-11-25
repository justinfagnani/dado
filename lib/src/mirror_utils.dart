// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.mirror_utils;

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
  if (classMirror.instanceMembers[name] != null) {
    return classMirror.instanceMembers[name];
  }
  if (classMirror.superclass != null) {
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

Object getBindingAnnotation (DeclarationMirror declarationMirror) {
  List<InstanceMirror> metadata;
  metadata = declarationMirror.metadata;
  
  if (metadata.isNotEmpty) {
    // TODO(justin): what do we do when a declaration has multiple
    // annotations? What does Guice do? We should probably only allow one
    // binding annotation per declaration, which means we need a way to
    // identify binding annotations.
    return metadata.first.reflectee;
  }
  
  return null;
}

List<MethodMirror> getConstructorsMirrors(ClassMirror classMirror) {
  var constructors = new List<MethodMirror>();
  
  classMirror.declarations.values.forEach((declaration) {
    if ((declaration is MethodMirror) && (declaration.isConstructor))
        constructors.add(declaration);
  });
  
  return constructors;
}
