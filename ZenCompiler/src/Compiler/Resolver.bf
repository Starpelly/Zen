using System;
using System.Collections;

using Zen.Lexer;
using Zen.Parser;

namespace Zen.Compiler;

public class ResolvingError : Zen.Builder.ICompilerError
{
	public Token Token { get; }
	public String Message { get; } ~ delete _;

	public this(Token token, StringView message)
	{
		this.Token = token;
		this.Message = new .(message);
	}
}

public class Resolver
{
	private ZenEnvironment m_environment = new .() ~ delete _;

	private List<Node.Using> m_currentUsings = new .() ~ delete _;
	private List<Dictionary<StringView, Node>> m_scopes = new .() ~ DeleteContainerAndItems!(_);

	private Node.Namespace m_currentNamespace = null;
	private Node.Function m_currentFunction = null;
	private ZenStruct m_currentStruct = null;

	private readonly List<ResolvingError> m_errors = new .() ~ DeleteContainerAndItems!(_);
	private bool m_hadErrors = false;

	public readonly List<ResolvingError> Errors => m_errors;

	public void ThrowError(ErrorCode code, Token token, params Object[] args)
	{
		mixin simpleError(StringView message)
		{
			m_errors.Add(new .(token, message));
		}

		m_hadErrors = true;
		switch (code)
		{
		case .VARIABLE_ASSIGNMENT_IMMUTABLE:
			simpleError!(scope $"Variable '{args[0]}' is immutable and cannot be assigned to.");
			break;

		case .RETURN_TOP_LEVEL:
			simpleError!("Cannot return from top-level code.");
			break;

		case .NO_CURRENT_NAMESPACE:
			simpleError!("Identifiers cannot be defined without a namespace.");
			break;

		case .IDENTIFIER_NOT_FOUND:
			simpleError!(scope $"Identifier '{token.Lexeme}' not found.");
			break;
		case .IDENTIFIER_ALREADY_DEFINED:
			simpleError!(scope $"Identifier already defined.");
			break;
		case .IDENTIFIER_ALREADY_DEFINED_SCOPE:
			simpleError!(scope $"An identifier named '{token.Lexeme}' has already been declared in this scope.");
			break;
		case .IDENTIFIER_AMBIGUOUS:
			simpleError!(scope $"'{token.Lexeme}' is an ambiguous reference between '{args[0]}' and '{args[1]}'.");
			break;

		case .IMPLICIT_CAST_INVALID:
			simpleError!(scope $"Unable to implicitly cast '{args[0]}' to '{args[1]}'.");
			break;

		case .FUNCTION_CALL_TOO_MANY_ARGUMENTS:
			simpleError!(scope $"Too many arguments, expected {args[0]} fewer.");
			break;
		case .FUNCTION_CALL_TOO_FEW_ARGUMENTS:
			simpleError!(scope $"Not enough arguments specified, expected {args[0]} more.");
			break;

		case .OPERATOR_INCOMPATIBLE_TYPES:
			simpleError!(scope $"Operator '{token.Lexeme}' cannot be applied to operands of type '{args[0]}' and '{args[1]}'.");
			break;

		case .CONST_MUST_BE_INITIALIZED:
			simpleError!("Const locals must be initialized.");
			break;
		}
	}

	public Result<ZenEnvironment> Resolve(List<Node> nodes)
	{
		// 1. Define types
		resolveTypes(nodes);

		// 2. Type checking
		for (let node in nodes)
		{
			resolveNodeBody(node);
		}

		if (m_hadErrors)
			return .Err;
		return .Ok(m_environment);
	}

	private void resolveTypes(List<Node> nodes)
	{
		for (let node in nodes)
		{
			resolveNodeDefn(node);
		}
	}

	private void resolveNodeDefn(Node node)
	{
		let type = node.GetType();
		switch (type)
		{
		case .Namespace:
			visitNamespaceNodeDefinition((Node.Namespace)node);
			break;
		case .Function:
			visitFunctionNodeDefinition((Node.Function)node);
			break;
		case .Const:
			visitConstNodeDefinition((Node.Const)node);
			break;
		case .Struct:
			visitStructNodeDefinition((Node.Struct)node);
			break;
		default:
		}
	}

	private void resolveNodeBody(Node node)
	{
		let type = node.GetType();
		switch (type)
		{
		case .Using:
			visitUsingNodeBody((Node.Using)node);
			break;
		case .Namespace:
			visitNamespaceNodeBody((Node.Namespace)node);
			break;
		case .Function:
			visitFunctionNodeBody((Node.Function)node);
			break;
		case .Struct:
			visitStructNodeBody((Node.Struct)node);
			break;
		case .Block:
			visitBlockNode((Node.Block)node);
			break;
		case .Variable:
			visitVariableNode((Node.Variable)node);
			break;
		case .Return:
			visitReturnNode((Node.Return)node);
			break;
		case .Expression:
			visitExpressionNode((Node.Expression)node);
			break;
		case .If:
			visitIfNode((Node.If)node);
			break;
		case .While:
			visitWhileNode((Node.While)node);
			break;
		case .EOF:
			visitEOFNode((Node.EOF)node);
			break;
		default:
		}
	}

	private void resolveExpr(Expr expr)
	{
		let type = expr.GetType();

		switch (type)
		{
		case .Call:
			visitCallExpr((Expr.Call)expr);
			break;
		case .Variable:
			visitVariableExpr((Expr.Variable)expr);
			break;
		case .Binary:
			visitBinaryExpr((Expr.Binary)expr);
			break;
		case .Assign:
			visitAssignExpr((Expr.Assign)expr);
			break;
		default:
		}
	}

	// ----------------------------------------------------------------
	// Helper Functions
	// ----------------------------------------------------------------
	
	private void BeginScope()
	{
		m_scopes.Add(new .());
	}

	private void EndScope()
	{
		let @scope = m_scopes.PopBack();
		delete @scope;
	}

	private void AddIdentifier(Identifier identifier)
	{
		ZenNamespace namespaceToAdd = null;
		if (m_currentNamespace != null)
		{
			let stmtNSStr = m_currentNamespace.List.NamespaceListToString(.. scope .());
			if (m_environment.Get(stmtNSStr) case .Ok(let @namespace))
			{
				namespaceToAdd = @namespace.Get<ZenNamespace>();

				if (namespaceToAdd.FindIdentifier<Identifier>(identifier.Name.Lexeme, let temp))
				{
					ThrowError(.IDENTIFIER_ALREADY_DEFINED, identifier.Name);
					delete identifier;
					return;
				}
			}
		}
		else
		{
			ThrowError(.NO_CURRENT_NAMESPACE, identifier.Name);
			delete identifier;
			return;
		}

		namespaceToAdd.AddIdentifier(identifier);
	}

	private void AddIdentifierToBackScope(Token token, Node stmt)
	{
		let @scope = m_scopes.Back;
		if (@scope.ContainsKey(token.Lexeme))
		{
			ThrowError(.IDENTIFIER_ALREADY_DEFINED_SCOPE, token);
		}
		@scope[token.Lexeme] = stmt;
	}

	private Result<T> FindLocalIdentifierNode<T>(Token token) where T : Node
	{
		for (let i < m_scopes.Count)
		{
			let @scope = m_scopes[i];
			if (@scope.ContainsKey(token.Lexeme))
			{
				return .Ok((T)@scope[token.Lexeme]);
			}
		}

		return .Err;
	}

	private bool LocalIdentifierExists(Token token)
	{
		for (let i < m_scopes.Count)
		{
			let @scope = m_scopes[i];
			if (@scope.ContainsKey(token.Lexeme))
			{
				return true;
			}
		}
		return false;
	}

	/// Same thing as Parser.CompareDataTypes, but throws an error if false instead.
	private void CompareAndCheckTypes(DataType a, DataType b)
	{
		if (!Parser.CompareDataTypes(a, b))
		{
			ThrowError(.IMPLICIT_CAST_INVALID, a.Token, a.Name, b.Name);
		}
	}

	private Result<DataType> GetTypeFromExpr(Expr expr)
	{
		if (let literal = expr as Expr.Literal)
		{
			return .Ok(literal.Type);
		}
		if (let variable = expr as Expr.Variable)
		{
			if (FindLocalIdentifierNode<Node.Variable>(variable.Name) case .Ok(let ret))
			{
				return .Ok(ret.Type);
			}
		}
		if (let call = expr as Expr.Call)
		{
			if (ZenIdentifierExistCheckExpr<ZenFunction, Expr.Call>(call, call.Callee.Name, .NOT_FOUND) case .Ok(let ret))
			// if (findIdentifierNode<Node.Function>(call.Callee.Name) case .Ok(let ret))
			{
				return .Ok(ret.Declaration.Type);
			}
		}
		return .Err;
	}

	private bool CompareDataTypesExpr(Expr a, Expr b)
	{
		if (GetTypeFromExpr(a) case .Ok(let typeA))
		{
			if (GetTypeFromExpr(b) case .Ok(let typeB))
			{
				return (Parser.CompareDataTypes(typeA, typeB));
			}
		}

		return false;
	}

	// ----------------------------------------------------------------
	// Using
	// ----------------------------------------------------------------

	private void visitUsingNodeBody(Node.Using stmt)
	{
		m_currentUsings.Add(stmt);
	}

	// ----------------------------------------------------------------
	// Namespace
	// ----------------------------------------------------------------

	private void visitNamespaceNodeDefinition(Node.Namespace stmt)
	{
		// let enclosingNamespace = m_currentNamespace;
		m_currentNamespace = stmt;

		let tempList = scope NamespaceList();
		tempList.AddRange(stmt.List);
		for (let nsItem in stmt.List)
		{
			defer tempList.PopBack();

			let nsString = tempList.NamespaceListToString(.. scope .());
			if (m_environment.Get(nsString) case .Ok(let val))
			{
				// No error, this is why namespaces exist at all.
				return;
			}

			let ns = new ZenNamespace(tempList);
			m_environment.Define(nsString, Variant.Create(ns));
		}

		// m_currentNamespace = enclosingNamespace;
	}

	private void visitNamespaceNodeBody(Node.Namespace stmt)
	{
		m_currentNamespace = stmt;
	}

	// ----------------------------------------------------------------
	// Functions
	// ----------------------------------------------------------------

	private ZenFunction visitFunctionNodeDefinition(Node.Function stmt)
	{
		let fun = new ZenFunction(stmt);
		if (m_currentStruct != null)
		{
			// m_currentStruct.Constructor = fun;
		}
		else
		{
			AddIdentifier(fun);
		}

		return fun;
	}

	private void visitFunctionNodeBody(Node.Function stmt)
	{
		let enclosingFunction = m_currentFunction;
		m_currentFunction = stmt;

		// Resolve parameters
		for (let param in stmt.Parameters)
		{
			visitVariableNode(param);
		}

		BeginScope();
		{
			for (let param in stmt.Parameters)
			{
				AddIdentifierToBackScope(param.Name, param);
			}

			resolveNodeBody(stmt.Body);
		}
		EndScope();

		m_currentFunction = enclosingFunction;
	}

	// ----------------------------------------------------------------
	// Const
	// ----------------------------------------------------------------

	private void visitConstNodeDefinition(Node.Const stmt)
	{
		let @const = new ZenConst(stmt);
		AddIdentifier(@const);
	}

	// ----------------------------------------------------------------
	// Struct
	// ----------------------------------------------------------------

	private void visitStructNodeDefinition(Node.Struct node)
	{
		let @struct = new ZenStruct(node);
		AddIdentifier(@struct);

		m_currentStruct = @struct;
		defer { m_currentStruct = null; }

		// Add construtors to identifiers if any
		for (let bodyNode in ref node.Body.Nodes)
		{
			if (let fun = bodyNode as Node.Function)
			{
				if (fun.Kind == .Initializer)
				{
					delete fun.Type;
					fun.Type = new NonPrimitiveDataType(node.Name)..SetNamespace(node.Namespace.List);

					let zenFunc = visitFunctionNodeDefinition(fun);
					@struct.Constructor = zenFunc;
				}
			}
		}
	}

	private void visitStructNodeBody(Node.Struct node)
	{
		for (let bodyNode in ref node.Body.Nodes)
		{
			if (let fun = bodyNode as Node.Function)
			{
				visitFunctionNodeBody(fun);
			}
		}
	}

	// ----------------------------------------------------------------
	// Variables
	// ----------------------------------------------------------------

	/*
	private void visitVariableStmtDefinition(Node.Variable stmt)
	{
		/*
		if (let nonPrim = stmt.Type as NonPrimitiveDataType)
		{
			if (nonPrim.Namespace == null)
				nonPrim.Namespace = new .();

			let _ = scope NamespaceList();
			if (ZenIdentifierExistCheck<ZenStruct>(stmt.Type.Token, nonPrim.Namespace, _, true) case .Ok(let zenConst))
			{
				nonPrim.Namespace.Clear();
				nonPrim.Namespace.AddRange(_);
			}
		}
		*/
	}
	*/

	private void visitVariableNode(Node.Variable stmt)
	{
		// Check if type exists
		{
			if (let nonPrim = stmt.Type as NonPrimitiveDataType)
			{
				if (nonPrim.Namespace == null)
					nonPrim.Namespace = new .();

				let _ = scope NamespaceList();
				if (ZenIdentifierExistCheckUsings<ZenStruct>(stmt.Type.Token, nonPrim.Namespace, _, .ALL) case .Ok(let zenConst))
				{
					nonPrim.Namespace.Clear();
					nonPrim.Namespace.AddRange(_);
				}
			}
		}

		if (m_scopes.Count == 0) return;

		AddIdentifierToBackScope(stmt.Name, stmt);

		if (stmt.HasInitializer)
		{
			if (GetTypeFromExpr(stmt.Initializer) case .Ok(let typeB))
			{
				CompareAndCheckTypes(typeB, stmt.Type);
			}

			resolveExpr(stmt.Initializer);
		}
		else
		{
			if (!stmt.Mutable)
			{
				ThrowError(.CONST_MUST_BE_INITIALIZED, stmt.Accessor);
			}
		}
	}

	// ----------------------------------------------------------------
	// Return
	// ----------------------------------------------------------------

	private void visitReturnNode(Node.Return stmt)
	{
		if (m_currentFunction == null)
		{
			ThrowError(.RETURN_TOP_LEVEL, stmt.Keyword);
			return;
		}

		if (GetTypeFromExpr(stmt.Value) case .Ok(let returnType))
		{
			if (!Parser.CompareDataTypes(returnType, m_currentFunction.Type))
			{
				ThrowError(.IMPLICIT_CAST_INVALID, returnType.Token, returnType.Name, m_currentFunction.Type.Name);
			}
		}

		resolveExpr(stmt.Value);
	}

	// ----------------------------------------------------------------
	// If
	// ----------------------------------------------------------------

	private void visitIfNode(Node.If stmt)
	{
		resolveExpr(stmt.Condition);
		resolveNodeBody(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolveNodeBody(stmt.ElseBranch);
	}

	// ----------------------------------------------------------------
	// While
	// ----------------------------------------------------------------

	private void visitWhileNode(Node.While stmt)
	{
		resolveExpr(stmt.Condition);
		resolveNodeBody(stmt.Body);
	}

	// ----------------------------------------------------------------
	// Misc.
	// ----------------------------------------------------------------

	private void visitBlockNode(Node.Block stmt)
	{
		BeginScope();
		{
			Resolve(stmt.Nodes).IgnoreError();
		}
		EndScope();
	}

	private void visitExpressionNode(Node.Expression stmt)
	{
		resolveExpr(stmt.InnerExpression);
	}

	private void visitEOFNode(Node.EOF stmt)
	{
		m_currentUsings.Clear();
		m_currentNamespace = null;
	}

	// ----------------------------------------------------------------
	// Expressions
	// ----------------------------------------------------------------

	public enum IdentifierError : uint8
	{
		ALL = 0,
		NONE = 1,
		AMBIGUOUS = _*2,
		NOT_FOUND = _*2,
	}

	private Result<TIdentifier, IdentifierError> ZenIdentifierExistCheckNamespace<TIdentifier>(Token name, NamespaceList namespaces, IdentifierError reportErrorFlags) where TIdentifier : Identifier
	{
		let reportAllErrors = reportErrorFlags.HasFlag(.ALL) || reportErrorFlags == .ALL;

		mixin notAvailableError()
		{
			if (reportAllErrors || reportErrorFlags.HasFlag(.NOT_FOUND))
			{
				ThrowError(.IDENTIFIER_NOT_FOUND, name);
			}
			return .Err(.NOT_FOUND);
		}

		let namespaceKey = namespaces.NamespaceListToString(.. scope .());
		if (m_environment.Get(namespaceKey) case .Ok(let val))
		{
			let zenNamespace = val.Get<ZenNamespace>();

			if (zenNamespace.FindIdentifier<TIdentifier>(name.Lexeme, let zenIdentifier))
			{
				return .Ok(zenIdentifier);
			}
			else
			{
				notAvailableError!();
			}
		}
		else
		{
			notAvailableError!();
		}
	}

	/// Checks if an identifier exists, taking into consideration the usings in the current file, the current namespace, and the token supplied.
	/// Ref `namespaces` is used to add onto any namespaces so it can be safely sent to the transpiler.
	private Result<TIdentifier, IdentifierError> ZenIdentifierExistCheckUsings<TIdentifier>(Token name, NamespaceList namespaces, NamespaceList newNamespaces, IdentifierError reportErrorFlags) where TIdentifier : Identifier
	{
		newNamespaces.AddRange(namespaces);
		let reportAllErrors = reportErrorFlags.HasFlag(.ALL) || reportErrorFlags == .ALL;

		void addNamespaceToExpr(Token namespaceToken)
		{
			newNamespaces.AddFront(namespaceToken);
		}

		mixin notAvailableError()
		{
			if (reportAllErrors || reportErrorFlags.HasFlag(.NOT_FOUND))
			{
				ThrowError(.IDENTIFIER_NOT_FOUND, name);
			}
			return .Err(.NOT_FOUND);
		}

		mixin ambigRefError(NamespaceList nsOne, Token one, NamespaceList nsTwo, Token two)
		{
			if (reportAllErrors || reportErrorFlags.HasFlag(.AMBIGUOUS))
			{
				ThrowError(.IDENTIFIER_AMBIGUOUS, name, scope $"{nsOne.NamespaceListToString(.. scope .())}::{one.Lexeme}", scope $"{nsTwo.NamespaceListToString(.. scope .())}::{two.Lexeme}");
			}
			return .Err(.AMBIGUOUS);
		}

		var foundIdentifierInLocal = false;
		var foundIdentifierLocal = default(TIdentifier);
		var foundIdentifierInUsings = false;
		var foundIdentifierUsings = scope List<(Token, TIdentifier)>();

		var foundIdentifierInExplicit = false;
		var foundIdentifierExplicitToken = default(Token);
		var foundIdentifierExplicit = default(TIdentifier); // Useful so we don't compare with itself when searching for ambig types.

		/*
		if (newNamespaces.Count > 0)
		{
			let checkNamespace = scope NamespaceList();
			// checkNamespace.AddRange(m_currentNamespace.List);
			checkNamespace.AddRange(newNamespaces);
			if (ZenIdentifierExistCheckNamespace<TIdentifier>(name, checkNamespace, reportErrorFlags) case .Ok(let identifier))
			{
				return .Ok(identifier);
			}

			return .Err(.NOT_FOUND);
		}
		else
		*/
		{
			// Fist, check the current namespace for the identifier.
			{
				let _ = scope NamespaceList(m_currentNamespace.List.Count);
				_.AddRange(m_currentNamespace.List);
				_.AddRange(newNamespaces);

				if (ZenIdentifierExistCheckNamespace<TIdentifier>(name, _, .NONE) case .Ok(let identifier))
				{
					// Great! We found this identifier in out current namespace!

					foundIdentifierInLocal = true;
					foundIdentifierLocal = identifier;

					newNamespaces.Clear();
					newNamespaces.AddRange(_);
				}
			}

			// Next, check from the first namespace provided (if any).
			{
				if (ZenIdentifierExistCheckNamespace<TIdentifier>(name, newNamespaces, .NONE) case .Ok(let identifier))
				{
					// Great! We found this identifier in out current namespace!

					foundIdentifierInExplicit = true;
					foundIdentifierExplicit = identifier;

					foundIdentifierExplicitToken = newNamespaces[0];
				}
			}

			// Finally, check for the identifier in the current file's usings.
			for (let @using in m_currentUsings)
			{
				if (@using.Name != foundIdentifierExplicitToken) continue;

				// This is utterly fucking retarded.
				let _ = scope NamespaceList(1);
				_.Add(@using.Name);

				if (ZenIdentifierExistCheckNamespace<TIdentifier>(name, _, .NONE) case .Ok(let identifier))
				{
					if (foundIdentifierInLocal)
					{
						let one = m_currentNamespace.List;
						let two = scope NamespaceList(1);
						two.Add(@using.Name);

						ambigRefError!(one, foundIdentifierLocal.Name, two, name);
					}
					else
					{
						if (foundIdentifierInUsings)
						{
							let one = scope NamespaceList(1);
							let two = scope NamespaceList(1);

							one.Add(foundIdentifierUsings[0].0);
							two.Add(@using.Name);

							ambigRefError!(one, name, two, name);
						}

						foundIdentifierInUsings = true;
						foundIdentifierUsings.Add((@using.Name, identifier));

						newNamespaces.Clear();
						newNamespaces.AddRange(_);
					}
				}
			}

			// Check for an identifier conflict.
			if (foundIdentifierInLocal == true && foundIdentifierInUsings == true)
			{
				let two = scope NamespaceList(1);
				two.Add(foundIdentifierUsings[0].0);
				ambigRefError!(m_currentNamespace.List, foundIdentifierLocal.Name, two, foundIdentifierLocal.Name);
			}

			if (foundIdentifierInExplicit)
			{
				return .Ok(foundIdentifierExplicit);
			}
			else if (foundIdentifierInLocal)
			{
				// newNamespaces.AddRange(m_currentNamespace.List);
				return .Ok(foundIdentifierLocal);
			}
			else if (foundIdentifierInUsings)
			{
				return .Ok(foundIdentifierUsings[0].1);
			}

			return .Err(.NOT_FOUND);
		}
	}

	private Result<TIdentifier, IdentifierError> ZenIdentifierExistCheckExpr<TIdentifier, TExpr>(TExpr expr, Token name, IdentifierError reportErrorFlags) where TIdentifier : Identifier where TExpr : Expr, Expr.IHaveNamespaces
	{
		let newNamespaces = scope NamespaceList();
		if (expr.Namespaces == null)
			expr.Namespaces = new .();
		let result = ZenIdentifierExistCheckUsings<TIdentifier>(name, expr.Namespaces, newNamespaces, reportErrorFlags);

		expr.Namespaces.Clear();
		expr.Namespaces.AddRange(newNamespaces);

		return result;
	}

	private void visitCallExpr(Expr.Call expr)
	{
		void actuallyCheckFunction(ZenFunction zenFunc)
		{
			// Throws an error if we have too many parameters.
			if (zenFunc.Declaration.Parameters.Count < expr.Arguments.Count)
			{
				let fewer = expr.Arguments.Count - zenFunc.Declaration.Parameters.Count;
				ThrowError(.FUNCTION_CALL_TOO_MANY_ARGUMENTS, expr.Callee.Name, fewer);
			}
			// Throws an error if we have too little parameters.
			else if (zenFunc.Declaration.Parameters.Count > expr.Arguments.Count)
			{
				let more = zenFunc.Declaration.Parameters.Count - expr.Arguments.Count;
				ThrowError(.FUNCTION_CALL_TOO_FEW_ARGUMENTS, expr.Callee.Name, more);
			}
			else
			{
				for (let i < expr.Arguments.Count)
				{
					let argument = expr.Arguments[i];
					let parameter = zenFunc.Declaration.Parameters[i];

					if (let @var = argument as Expr.Variable)
					{
						if (FindLocalIdentifierNode<Node.Variable>(@var.Name) case .Ok(let argDef))
						{
							if (!Parser.CompareDataTypes(parameter.Type, argDef.Type))
							{
								ThrowError(.IMPLICIT_CAST_INVALID, @var.Name, argDef.Type.Name, parameter.Type.Name);
								return;
							}
							resolveExpr(argument);
						}
						else
						{
							ThrowError(.IDENTIFIER_NOT_FOUND, @var.Name);
						}
					}
					else if (let literal = argument as Expr.Literal)
					{
						// Compare the input argument to the function parameter.
						if (!Parser.CompareDataTypes(literal.Type, parameter.Type))
						{
							ThrowError(.IMPLICIT_CAST_INVALID, literal.Token, literal.Type.Name, parameter.Type.Name);
						}
					}
					else if (let call = argument as Expr.Call)
					{
						resolveExpr(call);
					}
					else if (let binary = argument as Expr.Binary)
					{
						resolveExpr(binary);
					}
					else
					{
						// There needs to be an error here.
						// Although, this should never be the case?
						// Are functions variables? Probably not...
					}
				}
			}
		}

		// Check if the call is a constructor.
		switch (ZenIdentifierExistCheckExpr<ZenStruct, Expr.Call>(expr, expr.Callee.Name, .AMBIGUOUS))
		{
		case .Ok(let zenStruct):
			expr.Callee.Namespaces = new .();
			expr.Callee.Namespaces.Add(zenStruct.Name);
			expr.Callee.Name = Token(expr.Callee.Name.Type, expr.Callee.Name.Literal, "init", expr.Callee.Name.File, expr.Callee.Name.Line, expr.Callee.Name.Col, expr.Callee.Name.ColReal);
			if (zenStruct.Constructor == null)
			{
				expr.IsEmptyStructInitializer = true;
				return;
			}
			actuallyCheckFunction(zenStruct.Constructor);
			return;
		case .Err(let errorCode):
			if (errorCode == .AMBIGUOUS)
			{
				return;
			}
			break;
		}

		// Check if the call is a function.
		switch (ZenIdentifierExistCheckExpr<ZenFunction, Expr.Call>(expr, expr.Callee.Name, .ALL))
		{
		case .Ok(let zenFunc):
			actuallyCheckFunction(zenFunc);
			break;
		case .Err(.NOT_FOUND):
			ThrowError(.IDENTIFIER_NOT_FOUND, expr.Callee.Name);
			break;
		default:
		}

		// @NOTE
		// This is misleading because the identifier COULD exist but it could just not be a function or have a constructor.
		// We would need to handle that in this case.
		// - Starpelly, 1/21/25
		//

	}

	private void visitVariableExpr(Expr.Variable expr)
	{
		if (LocalIdentifierExists(expr.Name))
		{
			return;
		}
		if (ZenIdentifierExistCheckExpr<ZenConst, Expr.Variable>(expr, expr.Name, .ALL) case .Ok(let zenConst))
		{
			return;
		}

		ThrowError(.IDENTIFIER_NOT_FOUND, expr.Name);
	}

	private void visitBinaryExpr(Expr.Binary expr)
	{
		resolveExpr(expr.Left);
		resolveExpr(expr.Right);

		if (GetTypeFromExpr(expr.Left) case .Ok(let typeA))
		{
			if (GetTypeFromExpr(expr.Right) case .Ok(let typeB))
			{
				if (!Parser.CompareDataTypes(typeA, typeB))
				{
					ThrowError(.OPERATOR_INCOMPATIBLE_TYPES, expr.Operator, typeA.Name, typeB.Name);
				}
			}
		}
	}

	private void visitAssignExpr(Expr.Assign expr)
	{
		if (let @var = expr.Name as Expr.Variable)
		{
			if (FindLocalIdentifierNode<Node.Variable>(@var.Name) case .Ok(let identifier))
			{
				if (!identifier.Mutable)
				{
					ThrowError(.VARIABLE_ASSIGNMENT_IMMUTABLE, @var.Name, identifier.Name.Lexeme);
					return;
				}

				if (GetTypeFromExpr(expr.Value) case .Ok(let typeB))
				{
					CompareAndCheckTypes(identifier.Type, typeB);
				}
			}
			else
			{
				ThrowError(.IDENTIFIER_NOT_FOUND, @var.Name);
			}
		}
		else if (let get = expr.Name as Expr.Get)
		{
			resolveExpr(get.Object);

			// @Note
			// This is a lot of code, and it's making me uncomfortable...
			if (let @var = get.Object as Expr.Variable)
			{
				if (FindLocalIdentifierNode<Node.Variable>(@var.Name) case .Ok(let variable))
				{
					if (!variable.Mutable)
					{
						ThrowError(.VARIABLE_ASSIGNMENT_IMMUTABLE, @var.Name, variable.Name.Lexeme);
						return;
					}

					if (let nonPrim = variable.Type as NonPrimitiveDataType)
					{
						let _ = scope NamespaceList();
						if (ZenIdentifierExistCheckUsings<ZenStruct>(variable.Type.Token, nonPrim.Namespace, _, .ALL) case .Ok(let zenStruct))
						{
							// Structs should probably store these...
							for (let node in zenStruct.Declaration.Body.Nodes)
							{
								if (let structVar = node as Node.Variable)
								{
									let typeA = structVar.Type;
									if (GetTypeFromExpr(expr.Value) case .Ok(let typeB))
									{
										CompareAndCheckTypes(typeA, typeB);
									}
								}
							}
						}
					}
				}
			}
		}

		resolveExpr(expr.Value);
	}
}