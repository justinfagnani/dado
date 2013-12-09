//Copyright Google, Inc. 2013
library codegen_test;

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:dado/codegen.dart';

//These tests currently expect to be run from the top-level dado directory.
main() {
  group('CodeGen', (){
    CodeGen _codeGen;
    CompilationUnit _result;
    var dadoOptions;

    setupCodeGen(String testFile) {
      dadoOptions = new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          absoluteNormalize('.'),
          absoluteNormalize(testFile));
      return new CodeGen(dadoOptions);
    }

    skip_test('Replaces Injector Constructor Invocation', () {
      _result = setupCodeGen('test/sample_module.dart').run();
      var newConstructorMatcher =
          new InjectorConstructorMatcher('GeneratedInjector');
      var replacedConstructorMatcher =
          new InjectorConstructorMatcher('Injector');
      _result
          ..visitChildren(newConstructorMatcher)
          ..visitChildren(replacedConstructorMatcher);
      expect(newConstructorMatcher.found, true,
          reason: 'Generated constructor statement not found');
      expect(replacedConstructorMatcher.found, false,
          reason: 'Original constructor statement found');
    });

    test('bindings are empty initially',(){
      CodeGen codeGen = setupCodeGen('test/field_bindings_module.dart');
      expect(codeGen.bindings, isEmpty);
    });

    test('correctly identifies field bindings',(){
      CodeGen codeGen = setupCodeGen('test/field_bindings_module.dart');

      codeGen.run();

      expect(codeGen, containsBinding("\"abbra\"", 'String', 'String', true));
      expect(codeGen, containsBinding("true", 'bool', 'bool', true));
      expect(codeGen, containsBinding("12345", 'int', 'int', true));
    });

    test('correctly identifies simple intance bindings',(){
      CodeGen codeGen =
          setupCodeGen('test/simple_instance_bindings_module.dart');

      codeGen.run();

      expect(codeGen, containsBinding(null, 'Foo', 'Foo', false));
      expect(codeGen, containsBinding(null, 'Bar', 'Bar', true));
    });

    test('correctly identifies subclassed bindings',(){
      CodeGen codeGen = setupCodeGen('test/subclass_bindings_module.dart');

      codeGen.run();

      expect(codeGen, containsBinding(null, 'Foo', 'SubFoo', true));
      expect(codeGen, containsBinding(null, 'Bar', 'SubBar', false));
    });

    test('correctly identifies provider bindings',(){
      CodeGen codeGen = setupCodeGen('test/provider_bindings_module.dart');

      codeGen.run();

      expect(codeGen, containsBinding('(Bar b, Foo f) => new Snap(b, f)',
                                      'Snap', 'Snap', true));
      expect(codeGen, containsBinding('(Bar b, Snap s) => new Resnap(b, s)',
                                      'Resnap', 'Resnap', false));
    });

    test('correctly identifies unbound types',(){
      CodeGen codeGen = setupCodeGen('test/unbound_bindings_module.dart');

      expect(() => codeGen.run(), throwsArgumentError);
    });

    //TODO(bendera): need to test printing too.
  });

  group('DadoOptions', (){
    //TODO(bendera): add tests for bogus dart sdk args
    test('Empty Options Cause Exceptions', () {
      expect(() => new DadoOptions(
          null,
          absoluteNormalize('.'),
          absoluteNormalize('test/sample_module.dart')),
      throwsArgumentErrorWithMsg('invalid sdk path'));

      expect(() => new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          null,
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('invalid dado path'));

      expect(()=> new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          absoluteNormalize('.'),
          null),
          throwsArgumentErrorWithMsg('invalid target path'));
    });

    test('Non-existant paths cause exceptions', () {
      expect(() => new DadoOptions(
          '',
          absoluteNormalize('.'),
          absoluteNormalize('test/sample_module.dart')),
      throwsArgumentErrorWithMsg('does not exist'));

      expect(() => new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          '',
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('does not exist'));

      expect(()=> new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          absoluteNormalize('.'),
          ''),
          throwsArgumentErrorWithMsg('does not exist'));
    });

    test('Dart SDK Path without actual sdk fails', () {
      expect(() => new DadoOptions(
          absoluteNormalize('.'), //dado path is not valid sdk path
          absoluteNormalize('.'),
          absoluteNormalize('test/sample_module.dart')),
      throwsArgumentErrorWithMsg('must contain'));
    });

    test('Dado Path without Dado Lib', () {
      expect(() => new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          absoluteNormalize('test'), //test dir is not dado lib
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('must contain'));
    });
  });
}

class InjectorConstructorMatcher extends GeneralizingASTVisitor {
  final String targetInjectorName;
  bool found = false;
  InjectorConstructorMatcher(this.targetInjectorName);

  InstanceCreationExpression visitInstanceCreationExpression(
    InstanceCreationExpression node){
    if (node.constructorName.beginToken.lexeme == targetInjectorName) {
      found = true;
      return null;
    }
    return super.visitInstanceCreationExpression(node);
  }
}

class InjectorImportMatcher extends GeneralizingASTVisitor {
  final String targetImportString;
  bool found = false;
  InjectorImportMatcher(this.targetImportString);

  ImportDirective visitImportDirective(ImportDirective node){
    if (node.uri.stringValue == targetImportString) {
      found = true;
      return null;
    }
    return super.visitImportDirective(node);
  }
}

Matcher throwsArgumentErrorWithMsg(String msg) =>
    new Throws(new ArgumentErrorWithMsg(msg));

class ArgumentErrorWithMsg extends Matcher {
  final String _msg;
  const ArgumentErrorWithMsg(this._msg);
  bool matches(item, Map matchState) => item is ArgumentError &&
      item.message.toString().toLowerCase().contains(_msg.toLowerCase());

  Description describe(Description description) =>
      description.add('ArgumentError with message containing "$_msg"');
}

Matcher containsBinding(String initializer, String concreteType,
                        String implementedType, bool isSingleton) =>
  new _ContainsBinding(initializer, concreteType, implementedType, isSingleton);

class _ContainsBinding extends Matcher {

  final String _initializer;
  final String _implementedType;
  final String _concreteType;
  final bool _isSingleton;

  const _ContainsBinding(this._initializer, this._implementedType,
      this._concreteType, this._isSingleton);

  bool matches(CodeGen codeGen, Map matchState) {
    for (DiscoveredBinding binding in codeGen.bindings) {
      if (binding.concreteType.toString() == _concreteType &&
          binding.implementedType.toString() == _implementedType &&
          _initializerMatches(binding) &&
          binding.isSingleton == _isSingleton) {
        return true;
      }
    }
    return false;
  }

  bool _initializerMatches(binding) => binding.initializer == null ?
      _initializer == null : binding.initializer.toString() == _initializer;

  Description describe(Description description) =>
      description.add('contains binding with initializer, implementedType, '
          'concreteType, isSingleton: ').addDescriptionOf("$_initializer, "
          "$_implementedType, $_concreteType, $_isSingleton");

  Description describeMismatch(item, Description mismatchDescription,
                               Map matchState, bool verbose) {
    if (item is CodeGen) {
      return super.describeMismatch(item.bindings, mismatchDescription,
          matchState, verbose);
    } else {
      return mismatchDescription.add('is not a CodeGen object');
    }
  }
}
