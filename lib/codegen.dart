//Copyright Google Inc. 2013
library codegen;

import 'dart:collection';
import 'dart:io';
import 'package:args/args.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/java_core.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/sdk_io.dart'
  show DirectoryBasedDartSdk;
import 'package:analyzer/src/generated/source_io.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:quiver/mirrors.dart';
import 'package:unmodifiable_collection/unmodifiable_collection.dart';

part 'codegen_utils.dart';
part 'codegen_visitors.dart';
part 'codegen_bindings.dart';
part 'codegen_printer.dart';

const DART_SDK_PATH_FLAG = "dartSdk";
const TARGET_PATH_FLAG = "targetPath";
const DADO_ROOT_FLAG = "dadoRoot";

Logger _logger;
final ArgParser parser = new ArgParser()
      ..addOption(
          DART_SDK_PATH_FLAG,
          defaultsTo: extractSdkPathFromExecutablePath(Platform.executable),
          help: 'Required, the path to your Dart SDK')
      ..addOption(
          DADO_ROOT_FLAG,
          help: 'Required, the path to Dado Library')
      ..addOption(
          TARGET_PATH_FLAG,
          help: 'Required, the path to the source you'
              ' want to generate dado injectors for.');

main(List<String> arguments){
  setupLogger();
  _logger = new Logger('codegen');
  var args = parser.parse(arguments);
  var dadoOptions = null;
  try {
      dadoOptions = new DadoOptions(args[DART_SDK_PATH_FLAG],
          args[DADO_ROOT_FLAG], args[TARGET_PATH_FLAG]);
  } catch (e){
    _logger.severe(e.toString());
    _logger.info('Usage: ${parser.getUsage()}');
    return false;
  }

  _logger.info('Running with options: $dadoOptions');

  var codeGen = new CodeGen(dadoOptions);
  codeGen.run();

//  debugging tools
//  var writer = new PrintStringWriter();
//  result.accept(new ToFormattedSourceVisitor(writer));

  _logger.fine('------ Discovered Bindings -----');
  codeGen.bindings.forEach((_) => _logger.fine(_.toString()));
//  debugging tools
//  _logger.fine('------ generated class using injector-----');
//  _logger.fine(writer.toString());

  var generatedSource = new PrintStringWriter();
  new InjectorGenerator(codeGen.imports, codeGen.bindings).run(generatedSource);
  _logger.fine('------ generated  injector -----');
  _logger.fine(generatedSource.toString());
}


void setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    StringBuffer sb = new StringBuffer();
    sb..write(r.time.toString())
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
  final DadoOptions _dadoOptions;
  final List<DiscoveredBinding> bindings = [];
  final List<ImportDirective> imports = [];
  CompilationUnit mutatedSource;

  CodeGen(this._dadoOptions);

  void run() {
    var dadoPackagePath = absoluteNormalize(path.join(_dadoOptions.dadoRoot,
    'packages'));
    var targetPackagePath =
        absoluteNormalize('/Users/bendera/Development/code/usesdado/packages/');
    var sdk = new DirectoryBasedDartSdk(new JavaFile(_dadoOptions.dartSdkPath));

    var sourceFactory = new SourceFactory.con2([
        new DartUriResolver(sdk),
        new PackageUriResolver([new JavaFile(dadoPackagePath),
                                new JavaFile(targetPackagePath)])]);

    var context = AnalysisEngine.instance.createAnalysisContext()
        ..sourceFactory = sourceFactory;
    var fileBasedSourceFactory = new FileBasedSourceFactory(context);
    var targetSourcePath = path.normalize(
        path.absolute(_dadoOptions.targetSourcePath));
    var targetLibrarySource =
        fileBasedSourceFactory.getFileSouce(targetSourcePath);
    var targetLibrary = context.computeLibraryElement(targetLibrarySource);
    var resolvedTargetCompilationUnit = context.resolveCompilationUnit(
        targetLibrarySource, targetLibrary);

    var dadoLibraryPath = absoluteNormalize(
        path.join(_dadoOptions.dadoRoot,'lib','dado.dart'));
    var dadoLibrarySource =
        fileBasedSourceFactory.getFileSouce(dadoLibraryPath);
    var dadoLibrary = context.computeLibraryElement(dadoLibrarySource);
    var injectorClass = dadoLibrary.getType("Injector");
    var moduleClass = dadoLibrary.getType("Module");

    var injectorVisitor =
        new DadoASTVisitor(context, injectorClass, moduleClass);
    resolvedTargetCompilationUnit.accept(injectorVisitor);
    bindings.addAll(injectorVisitor.bindings);
    imports.addAll(injectorVisitor.imports);
    _checkForUnboundTypes();
  }

  void _checkForUnboundTypes() {
    Set<Type2> boundTypes = new Set();
    Set<Type2> concreteTypes = new Set();
    Set<Type2> transitiveDeps = new Set();

    bindings.where(
        (DiscoveredBinding b) => b is DiscoveredMethodBinding)
          .forEach((DiscoveredMethodBinding binding) {
            boundTypes.add(binding.implementedType);
            concreteTypes.add(binding.concreteType);
            transitiveDeps.addAll(binding.transitiveDependencies);
          });
    var unboundDeps = transitiveDeps.difference(boundTypes);
    if (unboundDeps.length > 0) {
      throw new IllegalArgumentException("One or more types found in your "
          "application was not bound: $unboundDeps");
    }
    var unboundConcreteTypes = concreteTypes.difference(boundTypes);
    if (unboundConcreteTypes.length > 0) {
      throw new IllegalArgumentException("One or more types found in your "
          "application was not bound: $unboundConcreteTypes");
    }
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
      if(!new File(targetPath).existsSync())
        throw 'target not found $targetPath';
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