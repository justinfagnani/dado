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
  final List<CompilationUnitElement> libraries = [];

  DadoASTVisitor(LibraryElement _dadoLibrary)
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
      ModuleAstVisitor moduleVisitor = new ModuleAstVisitor(_moduleClass);
      node.argumentList.arguments.accept(moduleVisitor);
      bindings.addAll(moduleVisitor.bindings);
      libraries.addAll(moduleVisitor.libraries);
      return _transformInjectorConstruction(node);
    }
    return super.visitInstanceCreationExpression(node);
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
  final BindingCollectionVisitor bindingCollector =
      new BindingCollectionVisitor();

  List<Object> get bindings => bindingCollector.bindings;
  Set<CompilationUnitElement> get libraries => bindingCollector.libraries;

  ModuleAstVisitor(this._moduleClass);

  visitSimpleIdentifier(SimpleIdentifier node) {
    // TODO(abendera): node.element no longer exists on SimpleIdentifier. I
    // don't know if the intent here is to use propagatedElement, staticElement,
    // or bestElement.
    var element = (node.bestElement as ClassElement);
    if (!element.type.isSubtypeOf(_moduleClass.type)) {
      throw new ArgumentError('Argument: ${element.type} to Injector is not a '
          'subtype of Module');
    }
    element.visitChildren(bindingCollector);
    return super.visitSimpleIdentifier(node);
  }
}

/**
 * Collects bindings defined as Fields, Methods, or Accessors.
 */
class BindingCollectionVisitor extends GeneralizingElementVisitor<Object> {
  final List<Object> bindings = [];
  final Set<CompilationUnitElement> libraries = new Set();

  visitFieldElement(FieldElement node) {
    bindings.add(node);
    libraries.add(node.library.definingCompilationUnit);
  }

  visitMethodElement(MethodElement node) {
    bindings.add(node);
    libraries.add(node.library.definingCompilationUnit);
  }

  visitPropertyAccessorElement(PropertyAccessorElement node) {
    bindings.add(node);
    libraries.add(node.library.definingCompilationUnit);
  }
}
