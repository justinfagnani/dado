part of codegen;


/**
 * Visits a target source file and preforms the following tasks:
 * * Replaces imports of injector.dart with generated_injector.dart
 * * Replaces invocations of Injector constructor with GeneratedInjector
 * * Collects all bindings defined module arguments to Injector.
 */
class DadoASTVisitor extends ASTCloner {
  final ClassElement _injectorClass;
  final ClassElement _moduleClass;
  final List<Object> bindings = [];
  final List<ImportDirective> imports = [];
  final LibraryElement _targetLibrary;
  final AnalysisContext _context;

  DadoASTVisitor(this._context, LibraryElement _dadoLibrary, this._targetLibrary)
      : _injectorClass = _dadoLibrary.getType("Injector"),
        _moduleClass = _dadoLibrary.getType("Module");

  /**
   * Finds invocations of Injector constructor and builds a new
   * InstanceCreationExpression AST based on GeneratedInjector. Ultimately the
   * implementation of GeneratedInjector will contain all the code necessary to
   * satisfy the injector contract visits arguments to constructor with the
   * [ModuleAstVisitor].
   */
  InstanceCreationExpression visitInstanceCreationExpression(
      InstanceCreationExpression node) {
    //TODO(bendera): Introduce caching for module and this injector in case
    //of revisit
    if (node.element.enclosingElement == _injectorClass) {
      ModuleAstVisitor moduleVisitor = new ModuleAstVisitor(_moduleClass, _context, _targetLibrary);
      node.argumentList.arguments.accept(moduleVisitor);
      bindings.addAll(moduleVisitor.bindings);
      return _transformInjectorConstruction(node);
    }
    return super.visitInstanceCreationExpression(node);
  }

  ImportDirective visitImportDirective(ImportDirective node) {
    imports.add(node);
    return super.visitImportDirective(node);
  }


  InstanceCreationExpression
    _transformInjectorConstruction(InstanceCreationExpression node) =>
        new InstanceCreationExpression.full(
            node.keyword,
            _buildSyntheticInjector(node.constructorName),
            clone2(node.argumentList));

  ConstructorName _buildSyntheticInjector(ConstructorName node) =>
      new ConstructorName.full(_buildSyntheticTypeName(node.type),
          node.period,
          node.name);

  TypeName _buildSyntheticTypeName(TypeName node) {
    return new TypeName.full(_buildSyntheticIdentifier(node.name),
        node.typeArguments);
  }

  SimpleIdentifier _buildSyntheticIdentifier(Identifier node) =>
      new SimpleIdentifier.full(new StringToken(TokenType.IDENTIFIER,
          "GeneratedInjector", node.offset));
}

/**
 * Visits a module and extracts all defined bindings.
 */
class ModuleAstVisitor extends GeneralizingASTVisitor {
  final ClassElement _moduleClass;
  final LibraryElement _targetLibrary;
  final BindingCollectionVisitor bindingCollector =
      new BindingCollectionVisitor();
  final AnalysisContext _context;
  List<Object> get bindings => bindingCollector.bindings;

  ModuleAstVisitor(this._moduleClass, this._context, this._targetLibrary);

  visitSimpleIdentifier(SimpleIdentifier node) {
    // TODO(abendera): node.element no longer exists on SimpleIdentifier. I
    // don't know if the intent here is to use propagatedElement, staticElement,
    // or bestElement.
    var element = (node.bestElement as ClassElement);
    if (!element.type.isSubtypeOf(_moduleClass.type)) {
      throw new ArgumentError('Argument: ${element.type} to Injector is not a '
          'subtype of Module');
    }
    CompilationUnit unit = _context.resolveCompilationUnit(element.source, _targetLibrary);
    var locator = new NodeLocator.con1(element.nameOffset);
    locator.searchWithin(unit);
    print(locator.foundNode);
  }
}
/**
 * Collects bindings defined as Fields, Methods, or Accessors.
 */
class BindingCollectionVisitor extends GeneralizingElementVisitor<Object> {
  final List<Object> bindings = [];

  visitFieldElement(FieldElement node) {
    if (node.initializer != null)
      print(node.initializer.localVariables);
    bindings.add(node);
    return super.visitFieldElement(node);
  }

  visitMethodElement(MethodElement node) {
    bindings.add(node);
    return super.visitMethodElement(node);
  }

  visitPropertyAccessorElement(PropertyAccessorElement node) {
    bindings.add(node);
    return super.visitPropertyAccessorElement(node);
  }
}
