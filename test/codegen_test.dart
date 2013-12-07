//Copyright Google, Inc. 2013
library codegen_test;

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/sdk_io.dart'
  show DirectoryBasedDartSdk;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:dado/codegen.dart';
import 'package:path/path.dart' as path;

//These tests currently expect to be run from the top-level dado directory.
main() {
  group('ModuleAstVisitor', (){
    CodeGen _codeGen;
    CompilationUnit _result;

    setupCodeGen(String testFile) {
      var dadoOptions = new DadoOptions(
          extractSdkPathFromExecutablePath(Platform.executable),
          absoluteNormalize('.'),
          absoluteNormalize(testFile));
      var dadoPackagePath = absoluteNormalize(
          path.join(dadoOptions.dadoRoot,'packages'));

      DartSdk _sdk = new DirectoryBasedDartSdk(
          new JavaFile(dadoOptions.dartSdkPath));

      AnalysisContext context =
          AnalysisEngine.instance.createAnalysisContext();

      context.sourceFactory = new SourceFactory.con2(
          [new DartUriResolver(_sdk), new PackageUriResolver(
          [new JavaFile(dadoPackagePath)])]);

      return new CodeGen(dadoOptions, context,
          new FileBasedSourceFactory(context));
    }

    test('Replaces Injector Constructor Invocation', () {
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

    test('correctly identifies field bindings',(){
      CodeGen codeGen = setupCodeGen('test/field_bindings_module.dart');

      expect(codeGen.bindings, isEmpty);

      codeGen.run();

      expect(codeGen.bindings, contains(
          new SimpleDiscoveredFieldBinding("\"abbra\"", true, "String")));
      expect(codeGen.bindings, contains(
          new SimpleDiscoveredFieldBinding("true", true, "bool")));
      expect(codeGen.bindings, contains(
          new SimpleDiscoveredFieldBinding("12345", true, "int")));
    });
  });

  group('DadoOptions', (){
    setUp((){});

    //TODO(bendera): add tests for bogus dart sdk args
    test('Empty Options Cause Exceptions', () {
      expect(() => new DadoOptions(
          null,
          absoluteNormalize('.'),
          absoluteNormalize('test/sample_module.dart')),
      throwsArgumentErrorWithMsg('invalid sdk path'));

      expect(() => new DadoOptions(
          extractSdkPathFromExecutablePath(options.executable),
          null,
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('invalid dado path'));

      expect(()=> new DadoOptions(
          extractSdkPathFromExecutablePath(options.executable),
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
          extractSdkPathFromExecutablePath(options.executable),
          '',
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('does not exist'));

      expect(()=> new DadoOptions(
          extractSdkPathFromExecutablePath(options.executable),
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
          extractSdkPathFromExecutablePath(options.executable),
          absoluteNormalize('test'), //test dir is not dado lib
          absoluteNormalize('test/sample_module.dart')),
          throwsArgumentErrorWithMsg('must contain'));
    });
  });
}

class SimpleDiscoveredFieldBinding implements DiscoveredFieldBinding {
  final Object initializer;
  final bool isSingleton;
  final String type;

  SimpleDiscoveredFieldBinding(this.initializer, this.isSingleton, this.type);
  FieldDeclaration get bindingDeclaration => null;
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
