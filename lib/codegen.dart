//Copyright Google Inc. 2013
library codegen;

import 'dart:io';
import 'dart:collection' show SplayTreeMap;
import 'package:args/args.dart';
import 'package:analyzer_experimental/src/generated/ast.dart';
import 'package:analyzer_experimental/src/generated/element.dart';
import 'package:analyzer_experimental/src/generated/engine.dart' hide Logger;
import 'package:analyzer_experimental/src/generated/java_io.dart';
import 'package:analyzer_experimental/src/generated/java_core.dart';
import 'package:analyzer_experimental/src/generated/parser.dart';
import 'package:analyzer_experimental/src/generated/scanner.dart';
import 'package:analyzer_experimental/src/generated/sdk_io.dart'
  show DirectoryBasedDartSdk;
import 'package:analyzer_experimental/src/generated/source_io.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

part 'codegen_utils.dart';
part 'codegen_visitors.dart';

const DART_SDK_PATH_FLAG = "dartSdk";
const TARGET_PATH_FLAG = "targetPath";
const DADO_ROOT_FLAG = "dadoRoot";

Logger _logger;
final Options options = new Options();
final ArgParser parser = new ArgParser()
      ..addOption(
          DART_SDK_PATH_FLAG,
          defaultsTo: extractSdkPathFromExecutablePath(options.executable),
          help: 'Required, the path to your Dart SDK')
      ..addOption(
          DADO_ROOT_FLAG,
          help: 'Required, the path to Dado Library')
      ..addOption(
          TARGET_PATH_FLAG,
          help: 'Required, the path to the source you'
              ' want to generate dado injectors for.');

main(){
  setupLogger();
  _logger = new Logger('BackgroundMain');
  var args = parser.parse(options.arguments);
  var dadoOptions = null;
  try {
      dadoOptions = new DadoOptions(args[DART_SDK_PATH_FLAG],
          args[DADO_ROOT_FLAG], args[TARGET_PATH_FLAG]);
  } catch (e){
    _logger.severe(e);
    _logger.info('Usage: ${parser.getUsage()}');
    return false;
  }

  _logger.info('Running with options: $dadoOptions');
  var dadoPackagePath = absoluteNormalize(path.join(dadoOptions.dadoRoot,
                                                    'packages'));
  var sdk = new DirectoryBasedDartSdk(new JavaFile(dadoOptions.dartSdkPath));

  var sourceFactory = new SourceFactory.con2([new DartUriResolver(sdk),
      new PackageUriResolver([new JavaFile(dadoPackagePath)])]);

  var context = AnalysisEngine.instance.createAnalysisContext()
      ..sourceFactory = sourceFactory;

  var codeGen = new CodeGen(dadoOptions, context,
      new FileBasedSourceFactory(context));

  var result = codeGen.run();

  var writer = new PrintStringWriter();
  result.accept(new ToFormattedSourceVisitor(writer));


  _logger.fine('------ Discovered Libraries -----');
  _logger.fine(codeGen.libraries.toString());
  _logger.fine('------ Discovered Bindings -----');
  _logger.fine(codeGen.bindings.toString());
  _logger.fine('------ generated class using injector-----');
  _logger.fine(writer.toString());

  var generatedSource = new PrintStringWriter();
  new InjectorGenerator(codeGen.libraries).run(generatedSource);
  _logger.fine('------ generated  injector -----');
  _logger.fine(generatedSource.toString());
}

void setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    StringBuffer sb = new StringBuffer();
    sb
        ..write(r.time.toString())
        ..write(":")
        ..write(r.loggerName)
        ..write(":")
        ..write(r.level.name)
        ..write(":")
        ..write(r.sequenceNumber)
        ..write(": ")
        ..write(r.message.toString());
    print(sb.toString());
  });
}

class CodeGen {
  final AnalysisContext _context;
  final FileBasedSourceFactory _fileBasedSourceFactory;
  final DadoOptions _dadoOptions;
  final List<Object> bindings = [];
  final Set<CompilationUnitElement> libraries = new Set();
  CompilationUnit _mutatedSource;

  CodeGen(this._dadoOptions, this._context, this._fileBasedSourceFactory);

  CompilationUnit run() {
    var targetSourcePath = path.normalize(
        path.absolute(_dadoOptions.targetSourcePath));
    var targetLibrarySource =
        _fileBasedSourceFactory.getFileSouce(targetSourcePath);
    var targetLibrary = _context.computeLibraryElement(targetLibrarySource);
    var resolvedTargetSource = _context.resolveCompilationUnit(
        targetLibrarySource, targetLibrary);


    var dadoLibraryPath = absoluteNormalize(
        path.join(_dadoOptions.dadoRoot,'lib','dado.dart'));
    var dadoLibrarySource =
        _fileBasedSourceFactory.getFileSouce(dadoLibraryPath);
    var dadoLibrary = _context.computeLibraryElement(dadoLibrarySource);

    var injectorVisitor = new DadoASTVisitor(dadoLibrary);
    _mutatedSource = resolvedTargetSource.accept(injectorVisitor)
        as CompilationUnit;
    bindings.addAll(injectorVisitor.bindings);
    libraries.addAll(injectorVisitor.libraries);
    return _mutatedSource;
  }
}

//TODO(bendera): convert to mustache templates.
String handleImportStatement(String library) =>
  '''import package:$library;''';

String handleClass(String className) =>
'''
class $className {

}''';


class InjectorGenerator {
  final Set<CompilationUnitElement> _libraries;

  InjectorGenerator(this._libraries);

  void run(PrintWriter writer){
    _printDirectives(writer);
    _printClassBody(writer);
  }

  _printClassBody(PrintWriter writer) {
    writer.println(handleClass('GeneratedInjector'));
  }

  void _printDirectives(PrintWriter writer){
    _libraries.map(_extractDirectivePath)
      .map(handleImportStatement).forEach(writer.println);
    writer.println('');
  }

  String _extractDirectivePath(CompilationUnitElement libraryPath) {
    //TODO(bendera): need to handle package imports and relative imports
    var lastDir = path.split(path.dirname(libraryPath.source.fullName)).last;
    return path.join(lastDir, path.basename(libraryPath.source.fullName));
  }
}

/**
 * Wraps a SourceFactory and allows direct retrieval of Source.
 */
class FileBasedSourceFactory {
  final AnalysisContext _context;
  FileBasedSourceFactory(this._context);

  Source getFileSouce(String path) =>
    new FileBasedSource.con1(_context.sourceFactory.contentCache,
        new JavaFile(path));
}

/**
 * Provides simple data structure for Dado command line options.
 */
class DadoOptions {

  final String dadoRoot;

  final String targetSourcePath;

  final String dartSdkPath;

  DadoOptions(String dartSdkPath, String dadoRoot, String targetSourcePath)
      : this.dartSdkPath = _checkSdkPath(dartSdkPath),
        this.dadoRoot = _checkDadoRoot(dadoRoot),
        this.targetSourcePath = _checkTargetPath(targetSourcePath);


  String toString() =>'dartSdk=$dartSdkPath, dadoRoot:$dadoRoot,'
      ' targetSourcePath:$targetSourcePath';

  static String _checkTargetPath(String targetPath) {
    var targetFile;
    try {
      if(!new File(targetPath).existsSync()) throw 'target not found $targetPath';
    } catch(e) {
      throw new ArgumentError('Invalid Target Path, path $targetPath does not '
          'exist or is not a file');
    }
    return targetPath;
    //TODO(bendera): will need to support directories and single files
  }

  static String _checkDadoRoot(String dadoRootPath) {
    var dadoRoot;
    try {
      dadoRoot = new Directory(dadoRootPath);
    } catch(e) {
      throw new ArgumentError('Invalid Dado Path, path must not be null.');
    }
    if(!_falseIfException(dadoRoot.existsSync)) {
      throw new ArgumentError('Invalid Dado Path, path $dadoRootPath does not '
          'exist or is not a directory.');
    }
    var dadoLib = new File(path.join(dadoRoot.path,'lib','dado.dart'));
    if (!_falseIfException(dadoLib.existsSync)) {
      throw new ArgumentError('Invalid Dado Path, path $dadoRootPath must '
          'contain dado library');
    }
    return dadoRootPath;
  }

  static String _checkSdkPath(String sdkPath) {
    var dartSdk;
    try {
      dartSdk = new Directory(sdkPath);
    } catch(e) {
      throw new ArgumentError('Invalid SDK Path, path must not be null.');
    }
    if (!_falseIfException(dartSdk.existsSync)) {
      throw new ArgumentError('Invalid SDK Path, path $sdkPath does not exist '
          'or is not a directory.');
    }
    var dartBin = new File(path.join(dartSdk.path,'bin','dart'));
    if (!_falseIfException(dartBin.existsSync)) {
      throw new ArgumentError('Invalid SDK Path, path $sdkPath must contain '
          'dart binary at bin/dart');
    }
    return sdkPath;
    //TODO(bendera): Is this enough? Should we try to execute something or check
    //versions?
  }

  static bool _falseIfException(bool f()) {
    try {
      return f();
    } catch(e){
      return false;
    }
  }
}