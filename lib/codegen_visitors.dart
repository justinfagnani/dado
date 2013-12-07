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
  final List<DiscoveredBinding> bindings = [];
  final List<ImportDirective> imports = [];
  final AnalysisContext _context;
  DadoASTVisitor(this._context, this._injectorClass, this._moduleClass);

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
    if (node.staticElement.enclosingElement == _injectorClass) {
      ModuleAstVisitor moduleVisitor = new ModuleAstVisitor(_moduleClass, _context);
      node.argumentList.arguments.accept(moduleVisitor);
      bindings.addAll(moduleVisitor.bindings);
      //TODO(bendera): when we are ready, bring in code transform.
      //return _transformInjectorConstruction(node);
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
  final AnalysisContext _context;
  final Set<DiscoveredBinding> bindings = new Set();
  final Set<Type2> boundTypes = new Set();

  ModuleAstVisitor(this._moduleClass, this._context);

  visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.staticElement;
    if (!element.type.isSubtypeOf(_moduleClass.type)) {
      throw new ArgumentError('Argument: ${element.type} to Injector is not a '
          'subtype of Module');
    }
    //having found a use of a Module we need to build and traverse its AST, which is different than the
    //AST where it was used.
    var locator = new NodeLocator.con1(element.nameOffset);
    locator.searchWithin(_context.resolveCompilationUnit(element.source, element.library));

    //TODO(bendera): what should we do if no node is found?
    var discoveredMembers = (locator.foundNode.parent as ClassDeclaration).members;
    Iterable<DiscoveredBinding> discoveredBindings = discoveredMembers.where(
        (ClassMember m) => m is FieldDeclaration || m is MethodDeclaration)
          .map((m) {
            DiscoveredBinding binding = makeDiscoveredBinding(m);
            if (!boundTypes.contains(binding.implementedType)) {
              boundTypes.add(binding.implementedType);
              return binding;
            } else {
              throw new ArgumentError('Duplicate binding for type: ${binding.implementedType}');
            }
          });
    bindings.addAll(discoveredBindings);
    //----- detect circular deps here & do not allow!
  }
}