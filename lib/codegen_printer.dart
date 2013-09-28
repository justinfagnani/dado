part of codegen;

//TODO(bendera): convert to mustache templates.
String handleImportStatement(ImportDirective import) => "${import}";

String handleFactoryCascade(Object binding, PrintHandler printHandler) {
  return "..addFactory(${printHandler(binding)})";
}

String handleStringSingleton(FieldElement binding) {
  return "${binding.type}, (DadoFactory i) => new ${binding.type}(), singleton:true";
}

typedef String PrintHandler(Object binding);
class InjectorGenerator {

  List<ImportDirective> _imports;
  List<Object> _bindings;
  InjectorGenerator(this._imports, this._bindings);

  void run(PrintWriter writer){
    _printDirectives(writer);
    _printFactoryCreation(writer);
  }

  _printFactoryCreation(PrintWriter writer) {
    writer.println('DadoFactory factory = new DadoFactory()');
    _bindings.forEach((Object binding) {
      PrintHandler handler = _findHandler(binding);
      if(handler != null) {
        writer.println(handleFactoryCascade(binding, handler));
      }
    });
  }

  PrintHandler _findHandler(Object binding) {
    if (implements(binding, FieldElement)) {
      var fieldElem = binding as FieldElement;
      print("${fieldElem.type}");
      if (fieldElem.type.toString() == "String") {
        print("${fieldElem.source}");
        return (Object _) => handleStringSingleton(_ as FieldElement);
      }
    }
  }

  void _printDirectives(PrintWriter writer){
    _imports.map(handleImportStatement).forEach(writer.println);
  }

  String _extractDirectivePath(CompilationUnitElement libraryPath) {
    //TODO(bendera): need to handle package imports and relative imports
    var lastDir = path.split(path.dirname(libraryPath.source.fullName)).last;
    return path.join(lastDir, path.basename(libraryPath.source.fullName));
  }
}
