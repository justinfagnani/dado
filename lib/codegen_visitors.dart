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
  final AnalysisContext _context;
  List<DiscoveredBinding> bindings = [];

  ModuleAstVisitor(this._moduleClass, this._context, this._targetLibrary);

  visitSimpleIdentifier(SimpleIdentifier node) {

    var element = node.element != null ? node.element : node.staticElement;
    if (!element.type.isSubtypeOf(_moduleClass.type)) {
      throw new ArgumentError('Argument: ${element.type} to Injector is not a '
          'subtype of Module');
    }
    CompilationUnit unit = _context.resolveCompilationUnit(element.source, _targetLibrary);
    var locator = new NodeLocator.con1(element.nameOffset);
    locator.searchWithin(unit);
    var discoveredMembers = (locator.foundNode.parent as ClassDeclaration).members;
    bindings.addAll(discoveredMembers.where(
        (ClassMember m) => m is FieldDeclaration || m is MethodDeclaration)
          .map((m) => makeDiscoveredBinding(m)));
  }
}

makeDiscoveredBinding(ClassMember m) => m is MethodDeclaration ?
    new DiscoveredMethodBinding(m) : new DiscoveredFieldBinding(m);

abstract class DiscoveredBinding {
  String get type;
  bool get isSingleton;
  //should expose type, value if constant
}

class DiscoveredFieldBinding extends DiscoveredBinding {
  final FieldDeclaration bindingDeclaration;
  DiscoveredFieldBinding(this.bindingDeclaration) {
    if (bindingDeclaration.fields.variables.length > 1) {
      throw new IllegalArgumentException("Multiple Field Declrations supported,"
          " ${bindingDeclaration.fields}");
    }
    if (_variableDeclaration.initializer == null) {
      //TODO(bendera): A simple field like String a with no RHS is probably
      //a mistake, should it be a warning or an error?
    }
  }

  String get type => bindingDeclaration.fields.type.toString();

  bool get isSingleton => true;

  Object get initializer => _variableDeclaration.initializer;

  VariableDeclaration get _variableDeclaration =>
      bindingDeclaration.fields.variables[0];

  String toString() => "DiscoveredFieldBinding[Type: $type, Initializer: $initializer, singleton: $isSingleton]";

  bool operator == (Object other) {
    if (other is! DiscoveredFieldBinding)
      return false;
    DiscoveredFieldBinding otherBinding = other;
    var t = initializer.toString();
    var q = otherBinding.initializer.toString();
    return type == otherBinding.type && isSingleton == otherBinding.isSingleton
        && initializer.toString()  == otherBinding.initializer.toString();
  }

  int get hashCode {
    int prime = 31;
    int result = 1;
    result = prime * result + ((type == null) ? 0 : type.hashCode);
    result = prime * result + ((isSingleton == null) ? 0 : isSingleton.hashCode);
    result = prime * result + ((initializer == null) ? 0 : initializer.hashCode);
    return result;
  }
}

class DiscoveredMethodBinding extends DiscoveredBinding {
  MethodDeclaration bindingDeclaration;
  bool _isSingleton = false;
  DiscoveredMethodBinding(this.bindingDeclaration) {
    if (bindingDeclaration.body is ExpressionFunctionBody) {
      if ((bindingDeclaration.body as ExpressionFunctionBody).expression is PropertyAccess) {
        _isSingleton = ((bindingDeclaration.body as ExpressionFunctionBody).expression as PropertyAccess).propertyName.toString() == 'singleton';
      }
    }
  }

  //TODO
  //* work out how to represent if this a sub class binding
  //* how to deal with objects that take params in constructor

  bool get isSingleton => _isSingleton;

  String get type => bindingDeclaration.returnType.toString();

  String toString() => "DiscoveredMethodBinding[Type: $type, singleton: $isSingleton]";
}