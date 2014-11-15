// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.transformer.remove_mirrors_transformer;

import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer;

class RemoveMirrorsTransformer extends Transformer {

  RemoveMirrorsTransformer();

  RemoveMirrorsTransformer.asPlugin(BarbackSettings settings);

  @override
  isPrimary(AssetId id) => id.package == 'dado' && id.path == 'lib/dado.dart';

  @override
  apply(Transform transform) {
    var input = transform.primaryInput;
    return input.readAsString().then((source) {
      var newSource = source.replaceAll(
          "import 'src/mirrors/mirrors.dart' as impl;",
          "import 'src/static/static.dart' as impl;");
      transform.addOutput(new Asset.fromString(input.id, newSource));
    });
  }
}
