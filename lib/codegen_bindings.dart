part of codegen;

makeDiscoveredBinding(ClassMember m) => m is MethodDeclaration ?
    new DiscoveredMethodBinding.parse(m) : new DiscoveredFieldBinding.parse(m);

abstract class DiscoveredBinding {
  Type2 get implementedType;
  Type2 get concreteType;
  bool get isSingleton;
  Expression get initializer;
  bool get hasInitializer;
}

class DiscoveredFieldBinding extends DiscoveredBinding {
  final Type2 implementedType;
  final Type2 concreteType;
  final bool isSingleton;
  final Expression initializer;

  factory DiscoveredFieldBinding.parse(FieldDeclaration fieldDeclaration) {
    if (fieldDeclaration.fields.variables.length > 1) {
      throw new IllegalArgumentException("Multiple Field Declrations supported,"
          " ${fieldDeclaration.fields}");
    }
    Type2 implementedType = fieldDeclaration.fields.type.type;
    Type2 concreteType = implementedType;
    Expression initializer = fieldDeclaration.fields.variables[0].initializer;
    if (initializer == null) {
      //TODO(bendera): A simple field like String a with no RHS is probably
      //a mistake, should it be a warning or an error?
    }
    return new DiscoveredFieldBinding(implementedType, concreteType, true,
        initializer);
  }

  DiscoveredFieldBinding(this.implementedType, this.concreteType,
                         this.isSingleton, this.initializer);

  bool get hasInitializer => true;

  String toString() => "DiscoveredFieldBinding["
      "ImplementedType: $implementedType, "
      "ConcreteType: $concreteType, "
      "Initializer: $initializer, "
      "singleton: $isSingleton]";

  bool operator ==(Object other) {
    if (other is! DiscoveredFieldBinding)
      return false;
    DiscoveredFieldBinding otherBinding = other;
    return implementedType == otherBinding.implementedType &&
        concreteType == otherBinding.concreteType &&
        isSingleton == otherBinding.isSingleton &&
        initializer.toString()  == otherBinding.initializer.toString();
  }

  int get hashCode {
    int prime = 31;
    int result = 1;
    result = prime * result +
        ((implementedType == null) ? 0 : implementedType.hashCode);
    result = prime * result +
        ((concreteType == null) ? 0 : concreteType.hashCode);
    result = prime * result +
        ((isSingleton == null) ? 0 : isSingleton.hashCode);
    result = prime * result +
        ((initializer == null) ? 0 : initializer.hashCode);
    return result;
  }
}

class DiscoveredMethodBinding extends DiscoveredBinding {
  final bool isSingleton;
  final Type2 concreteType;
  final Type2 implementedType;
  final Expression initializer;
  final List<ParameterElement> constructorArgs;
  final Set<Type2> transitiveDependencies;


  static bool isSingletonBinding(MethodDeclaration methodDeclaration) {
    if (methodDeclaration.body is EmptyFunctionBody) {
      return methodDeclaration.isGetter;
    } else if (methodDeclaration.body is ExpressionFunctionBody) {
      if ((methodDeclaration.body as ExpressionFunctionBody).expression is
          PropertyAccess) {
        var bindingExpression  = methodDeclaration.body as ExpressionFunctionBody;
        var propertyAccessExp = bindingExpression.expression as PropertyAccess;
        return propertyAccessExp.propertyName.toString() == 'singleton';
      }
    }
    return false;
  }

  //TODO(bendera): should capture context of decleration for later reporting
  //e.g. when we get an error can we point to which module/line # caused it.
  factory DiscoveredMethodBinding.parse(MethodDeclaration methodDeclaration) {
    Type2 implementedType = methodDeclaration.returnType.type;
    Type2 concreteType;
    Expression initializer;
    List<ParameterElement> constructorArgs = [];
    Set<Type2> transitiveDependencies = new Set();

    if (methodDeclaration.body is EmptyFunctionBody) {
      //ex. Foo get foo, Bar newBar()
      concreteType = implementedType;
    } else if (methodDeclaration.body is ExpressionFunctionBody) {
      var bindingExpression = methodDeclaration.body as ExpressionFunctionBody;
      MethodInvocation bindingMethodInv = null;
      if (bindingExpression.expression is PropertyAccess) {
        var propertyAccessExp = bindingExpression.expression as PropertyAccess;
        bindingMethodInv = propertyAccessExp.target as MethodInvocation;
      } else {
        var expressionInvo = bindingExpression.expression as MethodInvocation;
        bindingMethodInv = expressionInvo.target as MethodInvocation;
      }
      var bindingInvArgs = bindingMethodInv.argumentList.arguments[0];
      if(bindingInvArgs is SimpleIdentifier) {
        //ex. Baz get baz => bindTo(SubBaz)
        var bindingTarget = bindingInvArgs as SimpleIdentifier;
        concreteType = (bindingTarget.staticElement as ClassElement).type;
      } else if(bindingInvArgs is FunctionExpression) {
        //ex. Snap snap() => bindTo(Snap).providedBy((Bar b) => new Snap(b));
        var bindingFunctionExp = bindingInvArgs as FunctionExpression;
        initializer = bindingFunctionExp;
        concreteType = bindingFunctionExp.element.returnType;
      }
    }

    //enumerate dependency graph so we can check that all types were bound later
    constructorArgs.addAll(
        (concreteType.element as ClassElement).constructors.first.parameters);
    transitiveDependencies = _enumerateDepenedenyGraph(constructorArgs);
    return new DiscoveredMethodBinding(implementedType,
        concreteType,
        isSingletonBinding(methodDeclaration),
        initializer,
        new UnmodifiableListView(constructorArgs),
        new UnmodifiableSetView(transitiveDependencies));
  }

  //TODO(bendera): this could be improved using some memoization
  static Set<Type2> _enumerateDepenedenyGraph(List<ParameterElement> graphRoots)
      => graphRoots.expand((ParameterElement el) =>
      _enumerateDepenedenyGraph(
          (el.type.element as ClassElement).constructors[0].parameters)
              ..add(el.type)).toSet();


  DiscoveredMethodBinding(this.implementedType,
      this.concreteType,
      this.isSingleton,
      this.initializer,
      this.constructorArgs,
      this.transitiveDependencies);

  bool get hasInitializer => initializer != null;
  bool operator == (Object other) {
    if (other == null || other is! DiscoveredMethodBinding)
      return false;
    DiscoveredMethodBinding otherBinding = other;
    return implementedType == otherBinding.implementedType &&
        concreteType == otherBinding.concreteType &&
        isSingleton == otherBinding.isSingleton;
  }

  int get hashCode {
    int prime = 31;
    int result = 1;
    result = prime * result +
        ((implementedType == null) ? 0 : implementedType.hashCode);
    result = prime * result +
        ((isSingleton == null) ? 0 : isSingleton.hashCode);
    return result;
  }

  String toString() => "DiscoveredMethodBinding["
      "ImplementedType: $implementedType, "
      "ConcreteType: $concreteType, "
      "Initializer: $initializer, "
      "singleton: $isSingleton, "
      "constructorArgs: ${constructorArgs.toList()}, "
      "transitiveDependencies: ${transitiveDependencies.toSet()}]";
}