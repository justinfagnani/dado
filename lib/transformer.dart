// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.transformer;

import 'package:analyzer/analyzer.dart' show Directive, PartOfDirective,
    parseCompilationUnit;
import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer, TransformerGroup;
import 'package:code_transformers/resolver.dart';
import 'dart:async';
import 'package:analyzer/src/generated/element.dart';


/**
 * TODO:
 *
 * Finds imports of dado/dado.dart and replaces them with dado/static.dart
 *
 */
class DadoTransformer extends Transformer with ResolverTransformer  {
  @override
  final Resolvers resolvers;

  DadoTransformer(this.resolvers);

  Future<bool> shouldApplyResolver(Asset asset) {
    // only transform library files, not parts
    return asset.readAsString().then((contents) {
      var cu = parseCompilationUnit(contents, suppressErrors: true);
      var isPart = cu.directives.any((Directive d) => d is PartOfDirective);
      return !isPart;
    });
  }

  @override
  Future<bool> isPrimary(AssetId id) => new Future.value(id.extension == '.dart');

  @override
  applyResolver(Transform transform, Resolver resolver) {
    var input = transform.primaryInput;
    var library = resolver.getLibrary(transform.primaryInput.id);
    // find modules and injectors

  }
}

class DadoVisitor extends RecursiveElementVisitor {

}