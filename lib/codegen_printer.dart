part of codegen;

//TODO(bendera): convert to mustache templates.
String handleImportStatement(ImportDirective import) => "${import}";

String handleFactoryCascade(DiscoveredBinding binding, PrintHandler printHandler) {
  return "..addFactory(${printHandler(binding)})";
}

String handleStringSingleton(DiscoveredFieldBinding binding) {
  return "${binding.concreteType}, (DadoFactory i) => ${binding.initializer}, singleton:true";
}

String handleSimpleConcreteType(DiscoveredMethodBinding binding) {
  if(binding.constructorArgs.length == 0) {
    return "${binding.implementedType}, (DadoFactory i) => new ${binding.implementedType}(), singleton:${binding.isSingleton}";
  }
  String constructorArgs =
      binding.constructorArgs.map((ParameterElement el) => "i.getInstanceOf(${el.type.name}) as ${el.type.name}").join(', ');
  return "${binding.implementedType},  (DadoFactory i) => new ${binding.concreteType}($constructorArgs), singleton:true";
}

String handleComplexInitializer(DiscoveredMethodBinding binding) {
  String typedConstructorArgs = binding.constructorArgs.join(', ');
  String constructorArgs =
    binding.constructorArgs.map((ParameterElement el) => el.name).join(', ');
  String instantiationArgs =
      binding.constructorArgs.map((ParameterElement el) => "i.getInstanceOf(${el.type.name}) as ${el.type.name}").join(', ');
  return "${binding.implementedType},  (DadoFactory i) {\n"
    " (($typedConstructorArgs) => new ${binding.concreteType}($constructorArgs))($instantiationArgs);\n"
    "}, singleton:true";
}

String handleSubtype(DiscoveredMethodBinding binding) {
  return "${binding.implementedType}, (DadoFactory i) => i.getInstanceOf(${binding.concreteType}), singleton:${binding.isSingleton}";
}

typedef String PrintHandler(DiscoveredBinding binding);
class InjectorGenerator {

  List<ImportDirective> _imports;
  List<Object> _bindings;
  InjectorGenerator(this._imports, this._bindings);

  void run(PrintWriter writer){
   // _printDirectives(writer);
    _printFactoryCreation(writer);
  }

  _printFactoryCreation(PrintWriter writer) {
    writer.println('DadoFactory factory = new DadoFactory()');
    _bindings.forEach((DiscoveredBinding binding) {
      PrintHandler handler = _findHandler(binding);
      if(handler != null) {
        writer.println(handleFactoryCascade(binding, handler));
      }
    });
    writer.println(';');
  }

  PrintHandler _findHandler(DiscoveredBinding binding) {
    if(implements(binding, DiscoveredFieldBinding)) {
      return (DiscoveredBinding _) => handleStringSingleton(_ as DiscoveredFieldBinding);
    } else if(implements(binding, DiscoveredMethodBinding)) {
        if(!binding.hasInitializer) {
          if(binding.concreteType == binding.implementedType) {
            return (DiscoveredBinding _) => handleSimpleConcreteType(_ as DiscoveredMethodBinding);
          } else {
            return (DiscoveredBinding _) => handleSubtype(_ as DiscoveredMethodBinding);
          }
        } else {
          return (DiscoveredBinding _) => handleComplexInitializer(_ as DiscoveredMethodBinding);
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
