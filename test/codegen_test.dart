//Copyright Google, Inc. 2013
library codegen_test;

import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:analyzer_experimental/src/generated/java_io.dart';
import 'package:analyzer_experimental/src/generated/source_io.dart';
import 'package:analyzer_experimental/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer_experimental/src/generated/sdk_io.dart'
  show DirectoryBasedDartSdk;
import 'package:analyzer_experimental/src/generated/engine.dart';
import 'package:analyzer_experimental/src/generated/ast.dart';
import 'package:analyzer_experimental/src/generated/scanner.dart';
import 'package:dado/codegen.dart';
import 'package:path/path.dart' as path;

//These tests currently expect to be run from the top-level dado directory.
main() {
  group('ModuleAstVisitor', (){
    final Options options = new Options();
    final _dadoOptions = new DadoOptions(
        extractSdkPathFromExecutablePath(options.executable),
        absoluteNormalize('.'),
        absoluteNormalize('test/sample_module.dart'));
    CodeGen _codeGen;
    CompilationUnit _result;

    setUp((){
      var dadoPackagePath = absoluteNormalize(
          path.join(_dadoOptions.dadoRoot,'packages'));

      DartSdk _sdk = new DirectoryBasedDartSdk(
          new JavaFile(_dadoOptions.dartSdkPath));

      AnalysisContext _context =
          AnalysisEngine.instance.createAnalysisContext();

      _context.sourceFactory = new SourceFactory.con2(
          [new DartUriResolver(_sdk), new PackageUriResolver(
          [new JavaFile(dadoPackagePath)])]);

      _codeGen = new CodeGen(_dadoOptions, _context,
          new FileBasedSourceFactory(_context));

      _result = _codeGen.run();
    });

    //add tests for bogus dart sdk args
    test('Replaces Injector Constructor Invocation', () {
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
  });

  group('DadoOptions', (){
    setUp((){});

    //add tests for bogus dart sdk args
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
