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
 * * find subclasses of Injector and generate implementation
 */
class DadoTransformer extends Transformer with ResolverTransformer  {
  @override
  final Resolvers resolvers;

  DadoTransformer(this.resolvers);

  @override
  Future<bool> isPrimary(AssetId id) => new Future.value(
      id.extension == '.dart' &&
      !(id.package == 'dado' && id.path.startsWith('lib')));

  Future<bool> shouldApplyResolver(Asset asset) {
    // only transform library files, not parts
    return asset.readAsString().then((contents) {
      var cu = parseCompilationUnit(contents, suppressErrors: true);
      var isPart = cu.directives.any((Directive d) => d is PartOfDirective);
      return !isPart;
    });
  }

  @override
  applyResolver(Transform transform, Resolver resolver) {
    var input = transform.primaryInput;
    print("DadoTransformer.applyResolver: ${input.id.package}|${input.id.path}");
    print(input);
    var library = resolver.getLibrary(transform.primaryInput.id);
    var dadoLibrary = resolver.getLibraryByName('dado');
    var metadataLibrary = resolver.getLibraryByName('dado.metadata');

    // find modules and injectors
    var visitor = new DadoVisitor(dadoLibrary);
    library.accept(visitor);

    transform.addOutput(input);
    return new Future.value(true);
  }
}

class DadoVisitor extends RecursiveElementVisitor {
  final ClassElement injectorClass;
  final ClassElement moduleClass;

  DadoVisitor(
      LibraryElement dadoLibrary)
      : injectorClass = dadoLibrary.getType('Injector'),
        moduleClass = dadoLibrary.getType('Module') {
    assert(injectorClass != null);
    assert(moduleClass != null);
    print(injectorClass);
    print(moduleClass);
  }

  @override
  visitClassElement(ClassElement element) {
    print("class $element ${element.allSupertypes}");

    // TODO: working implements check!
    if (element.allSupertypes.contains(injectorClass)) {
      print("$element is Injector");
    }
    if (element.allSupertypes.contains(moduleClass)) {
      print("$element is Module");
    }
  }
}
