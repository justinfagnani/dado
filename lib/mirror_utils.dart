// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mirror_utils;

import 'dart:async';
import 'mirrors.dart';

InstanceMirror getValue(Future<InstanceMirror> f) =>
    deprecatedFutureValue(f);

/**
 * Walks the class hierarchy to search for an superclass or interface named
 * [name]. If [useSimple] is true, then it matches on either qualified or simple
 * names.
 */
bool implements(ClassMirror m, String name, {bool useSimple: false}) {
//  print(m.qualifiedName);
  if (m == null) return false;
  if (m.qualifiedName == name || (useSimple && m.simpleName == name)) {
    return true;
  }
  if (m.qualifiedName == "dart.core.Object") return false;
  if (implements(m.superclass, name, useSimple: useSimple)) return true;
  for (ClassMirror i in m.superinterfaces) {
    if (implements(i, name, useSimple: useSimple)) return true;
  }
  return false;
}

/**
 * Walks up the class hierarchy to find a declaration with the given [name].
 */
DeclarationMirror getMemberMirror(ClassMirror classMirror, String name) {
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

ClassMirror getClassMirror(Type type) {
  // terrible hack because we can't get a qualified name from a Type
  var name = type.toString();
  for (var lib in currentMirrorSystem().libraries.values) {
    if (lib.classes.containsKey(name)) {
      return lib.classes[name];
    }
  }
}


