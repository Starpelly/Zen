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
		}
	}

	public Result<ZenEnvironment> Resolve(List<Node> nodes)
	{
		// 1. Define types
		resolveDefinitions(nodes);

		// 2. Type checking
		for (let node in nodes)
		{
			resolveStmtBody(node);
		}

		if (m_hadErrors)
			return .Err;
		return .Ok(m_environment);
	}

	private void resolveDefinitions(List<Node> nodes)
	{
		for (let stmt in nodes)
		{
			resolveStmtDefn(stmt);
		}
	}

	private void resolveStmtDefn(Node stmt)
	{
		if (let @namespace = stmt as Node.Namespace)
		{
			visitNamespaceStmtDefinition(@namespace);
		}
		if (let fun = stmt as Node.Function)
		{
			visitFunctionStmtDefinition(fun);
		}
		if (let @const = stmt as Node.Const)
		{
			visitConstStmtDefinition(@const);
		}
		if (let @struct = stmt as Node.Struct)
		{
			visitStructStmtDefinition(@struct);
		}
		if (let @var = stmt as Node.Variable)
		{
			visitVariableStmtDefinition(@var);
		}
	}

	private void resolveStmtBody(Node stmt)
	{
		if (let @using = stmt as Node.Using)
		{
			visitUsingNodeBody(@using);
		}
		if (let @namespace = stmt as Node.Namespace)
		{
			visitNamespaceNodeBody(@namespace);
		}
		if (let fun = stmt as Node.Function)
		{
			visitFunctionNodeBody(fun);
		}
		if (let block = stmt as Node.Block)
		{
			visitBlockNode(block);
		}
		if (let @var = stmt as Node.Variable)
		{
			visitVariableNode(@var);
		}
		if (let ret = stmt as Node.Return)
		{
			visitReturnNode(ret);
		}
		if (let expr = stmt as Node.Expression)
		{
			visitExpressionNode(expr);
		}
		if (let @if = stmt as Node.If)
		{
			visitIfNode(@if);
		}
		if (let @while = stmt as Node.While)
		{
			visitWhileNode(@while);
		}
		if (let eof = stmt as Node.EOF)
		{
			visitEOFNode(eof);
		}
	}

	private void resolveExpr(Expr expr)
	{
		if (let call = expr as Expr.Call)
		{
			visitCallExpr(call);
		}
		if (let variable = expr as Expr.Variable)
		{
			visitVariableExpr(variable);
		}
		if (let binary = expr as Expr.Binary)
		{
			visitBinaryExpr(binary);
		}
		if (let assign = expr as Expr.Assign)
		{
			visitAssignExpr(assign);
		}
	}

	private bool localIdentifierExists(Token token)
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

	private Result<T> findIdentifierStmt<T>(Token token) where T : Node
	{
		for (let i < m_scopes.Count)
		{
			let @scope = m_scopes[i];
			if (@scope.ContainsKey(token.Lexeme))
			{
				// resolve
				return .Ok((T)@scope[token.Lexeme]);
			}
		}

		return .Err;
	}

	private void addIdentifierToBackScope(Token token, Node stmt)
	{
		let @scope = m_scopes.Back;
		if (@scope.ContainsKey(token.Lexeme))
		{
			ThrowError(.IDENTIFIER_ALREADY_DEFINED_SCOPE, token);
		}
		@scope[token.Lexeme] = stmt;
	}

	/// Compares two types to see if type 'b' can be implicitly casted to type 'a'.
	/// This does NOT check the inverse!
	private void compareAndCheckTypes(Expr expr, DataType a, DataType b)
	{
		if (b != a)
		{
			if (let literal = expr as Expr.Literal)
			{
				if (!Parser.CompareDataTypes(a, b))
				{
					ThrowError(.IMPLICIT_CAST_INVALID, a.Token, literal.Type.Name, a.Name);
				}
			}
			/*
			else if (let call = expr as Expr.Call)
			{
	
			}
			*/
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
			if (findIdentifierStmt<Node.Variable>(variable.Name) case .Ok(let ret))
			{
				return .Ok(ret.Type);
			}
		}
		if (let call = expr as Expr.Call)
		{
			if (findIdentifierStmt<Node.Function>(call.Callee.Name) case .Ok(let ret))
			{
				return .Ok(ret.Type);
			}
		}
		return .Err;
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
	
	private void beginScope()
	{
		m_scopes.Add(new .());
	}

	private void endScope()
	{
		let @scope = m_scopes.PopBack();
		delete @scope;
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

	private void visitNamespaceStmtDefinition(Node.Namespace stmt)
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

	private ZenFunction visitFunctionStmtDefinition(Node.Function stmt)
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
			resolveStmtDefn(param);
		}

		beginScope();
		{
			for (let param in stmt.Parameters)
			{
				addIdentifierToBackScope(param.Name, param);
			}

			resolveStmtBody(stmt.Body);
		}
		endScope();

		m_currentFunction = enclosingFunction;
	}

	// ----------------------------------------------------------------
	// Const
	// ----------------------------------------------------------------

	private void visitConstStmtDefinition(Node.Const stmt)
	{
		let @const = new ZenConst(stmt);
		AddIdentifier(@const);
	}

	// ----------------------------------------------------------------
	// Struct
	// ----------------------------------------------------------------

	private void visitStructStmtDefinition(Node.Struct stmt)
	{
		let @struct = new ZenStruct(stmt);
		AddIdentifier(@struct);

		/*
		let tempList = scope NamespaceList();
		tempList.AddRange(m_currentNamespace.List);
		tempList.Add(@struct.Name);

		let ns = new ZenNamespace(tempList);
		m_environment.Define(tempList.NamespaceListToString(.. scope .()), Variant.Create(ns));

		m_currentNamespace.List.Add(@struct.Name);
		defer m_currentNamespace.List.PopBack();
		*/

		m_currentStruct = @struct;
		defer { m_currentStruct = null; }

		// Add construtors to identifiers if any
		for (let node in ref stmt.Body.Nodes)
		{
			if (let fun = node as Node.Function)
			{
				if (fun.Kind == .Constructor)
				{
					delete fun.Type;
					fun.Type = new NonPrimitiveDataType(stmt.Name)..SetNamespace(stmt.Namespace.List);

					let zenFunc = visitFunctionStmtDefinition(fun);
					@struct.Constructor = zenFunc;
				}
			}
		}
	}

	// ----------------------------------------------------------------
	// Variables
	// ----------------------------------------------------------------

	private void visitVariableStmtDefinition(Node.Variable stmt)
	{
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
	}

	private void visitVariableNode(Node.Variable stmt)
	{
		if (m_scopes.Count == 0) return;

		addIdentifierToBackScope(stmt.Name, stmt);

		if (GetTypeFromExpr(stmt.Initializer) case .Ok(let typeB))
		{
			compareAndCheckTypes(stmt.Initializer, stmt.Type, typeB);
		}

		if (stmt.HasInitializer)
			resolveExpr(stmt.Initializer);
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
			if (m_currentFunction.Type != returnType)
			{
				ThrowError(.IMPLICIT_CAST_INVALID, returnType.Token, returnType.Name, m_currentFunction.Type.Name);
			}
		}
	}

	// ----------------------------------------------------------------
	// If
	// ----------------------------------------------------------------

	private void visitIfNode(Node.If stmt)
	{
		resolveExpr(stmt.Condition);
		resolveStmtBody(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolveStmtBody(stmt.ElseBranch);
	}

	// ----------------------------------------------------------------
	// While
	// ----------------------------------------------------------------

	private void visitWhileNode(Node.While stmt)
	{
		resolveExpr(stmt.Condition);
		resolveStmtBody(stmt.Body);
	}

	// ----------------------------------------------------------------
	// Misc.
	// ----------------------------------------------------------------

	private void visitBlockNode(Node.Block stmt)
	{
		beginScope();
		{
			Resolve(stmt.Nodes).IgnoreError();
		}
		endScope();
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

	/// Checks if an identifier exists, taking into consideration the usings in the current file, the current namespace, and the token supplied.
	/// Ref `namespaces` is used to add onto any namespaces so it can be safely sent to the transpiler.
	private Result<TIdentifier> ZenIdentifierExistCheck<TIdentifier>(Token name, NamespaceList namespaces, NamespaceList newNamespaces, bool reportErrors) where TIdentifier : Identifier
	{
		newNamespaces.AddRange(namespaces);

		void addNamespaceToExpr(Token namespaceToken)
		{
			newNamespaces.AddFront(namespaceToken);
		}

		mixin notAvailableError()
		{
			if (reportErrors)
			{
				ThrowError(.IDENTIFIER_NOT_FOUND, name);
			}
			return .Err;
		}

		mixin ambigRefError(Token one, Token two)
		{
			if (reportErrors)
			{
				let childNString = scope String();
				for (let child in namespaces)
				{
					childNString.Append("::");
					childNString.Append(child.Lexeme);
				}
				childNString.Append("::");
				childNString.Append(name.Lexeme);

				ThrowError(.IDENTIFIER_AMBIGUOUS, name, scope $"{one.Lexeme}{childNString}", scope $"{two.Lexeme}{childNString}");
			}
			return .Err;
		}

		// Check if the identifier we're looking for is global.
		if (newNamespaces.Count > 0)
		{
			let namespaceKey = newNamespaces.NamespaceListToString(.. scope .());

			/*
			if (m_environment.Get(namespaceKey) case .Ok)
			{
				return .Err;
			}
			*/

			var foundUsing = false;
			var foundUsings = scope NamespaceList();
			var foundUsingName = default(Token);

			for (let @using in m_currentUsings)
			{
				let usingCheckKey = scope $"{@using.Name.Lexeme}::{namespaceKey}";
				if (m_environment.Get(usingCheckKey) case .Ok)
				{
					if (foundUsing)
					{
						ambigRefError!(foundUsings[0], @using.Name);
					}

					// addNamespaceToExpr(@using.Name);
					foundUsing = true;
					foundUsings.Add(@using.Name);
					foundUsingName = @using.Name;
				}
			}

			if (!foundUsing)
			{
				if (m_environment.Get(namespaceKey) case .Err)
				{
					addNamespaceToExpr(m_currentNamespace.Front);
				}
			}
			else
			{
				addNamespaceToExpr(foundUsingName);
			}
		}
		else
		{
			// If it is global, we can cheat and just add the current push the current namespace so the compiler thinks it's part of the namespace.
			//
			// We've already checked for duplicates earlier in the identifier definition.
			addNamespaceToExpr(m_currentNamespace.Front);
		}

		let namespaceKey = newNamespaces.NamespaceListToString(.. scope .());
		if (m_environment.Get(namespaceKey) case .Ok(let val))
		{
			let zenNamespace = val.Get<ZenNamespace>();

			if (zenNamespace.FindIdentifier<TIdentifier>(name.Lexeme, let zenFunc))
			{
				// let zenFuncNamespace = zenFunc.Declaration.Namespace;
				return .Ok(zenFunc);
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

	private Result<TIdentifier> ZenIdentifierExistCheckExpr<TIdentifier, TExpr>(TExpr expr, Token name, bool reportErrors) where TIdentifier : Identifier where TExpr : Expr, Expr.IHaveNamespaces
	{
		let newNamespaces = scope NamespaceList();
		if (expr.Namespaces == null)
			expr.Namespaces = new .();
		let result = ZenIdentifierExistCheck<TIdentifier>(name, expr.Namespaces, newNamespaces, reportErrors);

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
						if (findIdentifierStmt<Node.Variable>(@var.Name) case .Ok(let argDef))
						{
							if (parameter.Type.Name != argDef.Type.Name)
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
						// Compare the input parameter to the function argument.
						if (let type = Parser.GetDataTypeFromTypeToken(parameter.Type.Token))
						{
							defer delete type;
							if (let prim = type as PrimitiveDataType)
							{
								let otherType = Parser.GetDataTypeFromTypeToken(prim.Token);
								defer delete otherType;
								if (!Parser.CompareDataTypes(type, otherType))
								{
									ThrowError(.IMPLICIT_CAST_INVALID, literal.Token, literal.Type.Name, parameter.Type.Name);
								}
							}
							else
							{
								if (parameter.Type.Name != literal.Type.Name)
								{
									ThrowError(.IMPLICIT_CAST_INVALID, literal.Token, literal.Type.Name, parameter.Type.Name);
								}
							}
						}
					}
					else if (let call = argument as Expr.Call)
					{
						resolveExpr(call);
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

		if (ZenIdentifierExistCheckExpr<ZenStruct, Expr.Call>(expr, expr.Callee.Name, false) case .Ok(let zenStruct))
		{
			expr.Callee.Namespaces = new .();
			expr.Callee.Namespaces.Add(zenStruct.Name);
			expr.Callee.Name = Token(expr.Callee.Name.Type, expr.Callee.Name.Literal, "self", expr.Callee.Name.File, expr.Callee.Name.Line, expr.Callee.Name.Col, expr.Callee.Name.ColReal);
			actuallyCheckFunction(zenStruct.Constructor);

			return;
		}
		if (ZenIdentifierExistCheckExpr<ZenFunction, Expr.Call>(expr, expr.Callee.Name, true) case .Ok(let zenFunc))
		{
			actuallyCheckFunction(zenFunc);
		}
	}

	private void visitVariableExpr(Expr.Variable expr)
	{
		if (localIdentifierExists(expr.Name))
		{
			return;
		}
		if (ZenIdentifierExistCheckExpr<ZenConst, Expr.Variable>(expr, expr.Name, true) case .Ok(let zenConst))
		{
			return;
		}

		ThrowError(.IDENTIFIER_NOT_FOUND, expr.Name);
	}

	private void visitBinaryExpr(Expr.Binary expr)
	{
	}

	private void visitAssignExpr(Expr.Assign expr)
	{
		if (let @var = expr.Name as Expr.Variable)
		{
			if (findIdentifierStmt<Node.Variable>(@var.Name) case .Ok(let identifier))
			{
				if (!identifier.Mutable)
				{
					ThrowError(.VARIABLE_ASSIGNMENT_IMMUTABLE, @var.Name, identifier.Name.Lexeme);
					return;
				}

				if (GetTypeFromExpr(expr.Value) case .Ok(let typeB))
				{
					compareAndCheckTypes(expr.Value, identifier.Type, typeB);
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
				if (findIdentifierStmt<Node.Variable>(@var.Name) case .Ok(let variable))
				{
					if (!variable.Mutable)
					{
						ThrowError(.VARIABLE_ASSIGNMENT_IMMUTABLE, @var.Name, variable.Name.Lexeme);
						return;
					}

					if (let nonPrim = variable.Type as NonPrimitiveDataType)
					{
						let _ = scope NamespaceList();
						if (ZenIdentifierExistCheck<ZenStruct>(variable.Type.Token, nonPrim.Namespace, _, true) case .Ok(let zenStruct))
						{
							// Structs should probably store these...
							for (let node in zenStruct.Declaration.Body.Nodes)
							{
								if (let structVar = node as Node.Variable)
								{
									let typeA = structVar.Type;
									if (GetTypeFromExpr(expr.Value) case .Ok(let typeB))
									{
										compareAndCheckTypes(expr.Value, typeA, typeB);
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