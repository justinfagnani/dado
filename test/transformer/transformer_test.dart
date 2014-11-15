// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dado.test.transformer.transformer_test;

import 'package:code_transformers/src/test_harness.dart';
import 'package:dado/transformer.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {

  group('DadoTransformer', () {

    test('runs', () {
      var resolvers = mockResolvers();
      var transformer = new DadoTransformer(resolvers);
      var testHelper = new TestHelper([[transformer]], {
        'test|lib/library.dart': readTestFile('library.dart'),
        'dado|lib/dado.dart': readPackageFile('dado.dart'),
        'dado|lib/src/injector.dart': readPackageFile('src/injector.dart'),
        'dado|lib/src/key.dart': readPackageFile('src/key.dart'),
        'dado|lib/src/metadata.dart': readPackageFile('src/metadata.dart'),
        'dado|lib/src/module.dart': readPackageFile('src/module.dart'),
        'dado|lib/src/mirrors/binding.dart': readPackageFile('src/mirrors/binding.dart'),
        'dado|lib/src/mirrors/mirrors.dart': readPackageFile('src/mirrors/mirrors.dart'),
        'dado|lib/src/mirrors/reflective_injector.dart': readPackageFile('src/mirrors/reflective_injector.dart'),
      }, null);
      testHelper.run(testHelper.files.keys);
      return testHelper['test|lib/library.dart'].then((testSource) {
        print(testSource);
      });
    });
  });
}
