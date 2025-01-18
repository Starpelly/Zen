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

	private List<Stmt.Using> m_currentUsings = new .() ~ delete _;
	private List<Dictionary<StringView, Stmt>> m_scopes = new .() ~ DeleteContainerAndItems!(_);

	private Stmt.Namespace m_currentNamespace = null;
	private Stmt.Function m_currentFunction = null;
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

	public Result<ZenEnvironment> Resolve(List<Stmt> statements)
	{
		// 1. Define types
		resolveDefinitions(statements);

		// 2. Type checking
		for (let statement in statements)
		{
			resolveStmtBody(statement);
		}

		if (m_hadErrors)
			return .Err;
		return .Ok(m_environment);
	}

	private void resolveDefinitions(List<Stmt> statements)
	{
		for (let stmt in statements)
		{
			resolveStmtDefn(stmt);
		}
	}

	private void resolveStmtDefn(Stmt stmt)
	{
		if (let @namespace = stmt as Stmt.Namespace)
		{
			visitNamespaceStmtDefinition(@namespace);
		}
		if (let fun = stmt as Stmt.Function)
		{
			visitFunctionStmtDefinition(fun);
		}
		if (let @const = stmt as Stmt.Const)
		{
			visitConstStmtDefinition(@const);
		}
		if (let @struct = stmt as Stmt.Struct)
		{
			visitStructStmtDefinition(@struct);
		}
		if (let @var = stmt as Stmt.Variable)
		{
			visitVariableStmtDefinition(@var);
		}
	}

	private void resolveStmtBody(Stmt stmt)
	{
		if (let @using = stmt as Stmt.Using)
		{
			visitUsingStmtBody(@using);
		}
		if (let @namespace = stmt as Stmt.Namespace)
		{
			visitNamespaceStmtBody(@namespace);
		}
		if (let fun = stmt as Stmt.Function)
		{
			visitFunctionStmtBody(fun);
		}
		if (let block = stmt as Stmt.Block)
		{
			visitBlockStmt(block);
		}
		if (let @var = stmt as Stmt.Variable)
		{
			visitVariableStmt(@var);
		}
		if (let ret = stmt as Stmt.Return)
		{
			visitReturnStmt(ret);
		}
		if (let expr = stmt as Stmt.Expression)
		{
			visitExpressionStmt(expr);
		}
		if (let @if = stmt as Stmt.If)
		{
			visitIfStatement(@if);
		}
		if (let @while = stmt as Stmt.While)
		{
			visitWhileStatement(@while);
		}
		if (let eof = stmt as Stmt.EOF)
		{
			visitEOFStmt(eof);
		}
	}

	private void resolveExpr(Expr expression)
	{
		if (let call = expression as Expr.Call)
		{
			visitCallExpr(call);
		}
		if (let variable = expression as Expr.Variable)
		{
			visitVariableExpr(variable);
		}
		if (let assign = expression as Expr.Assign)
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

	private Result<T> findIdentifierStmt<T>(Token token) where T : Stmt
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

	private void addIdentifierToBackScope(Token token, Stmt stmt)
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
				// Temp hack fix, there needs to be a system for this.
				if ((a.Name == "string" && literal.Type.Name == "string_view") ||
					(a.Name == "string_view" && literal.Type.Name == "string"))
				{
							
				}
				else
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
			if (findIdentifierStmt<Stmt.Variable>(variable.Name) case .Ok(let ret))
			{
				return .Ok(ret.Type);
			}
		}
		if (let call = expr as Expr.Call)
		{
			if (findIdentifierStmt<Stmt.Function>(call.Callee.Name) case .Ok(let ret))
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

	private void visitUsingStmtBody(Stmt.Using stmt)
	{
		m_currentUsings.Add(stmt);
	}

	// ----------------------------------------------------------------
	// Namespace
	// ----------------------------------------------------------------

	private void visitNamespaceStmtDefinition(Stmt.Namespace stmt)
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

	private void visitNamespaceStmtBody(Stmt.Namespace stmt)
	{
		m_currentNamespace = stmt;
	}

	// ----------------------------------------------------------------
	// Functions
	// ----------------------------------------------------------------

	private ZenFunction visitFunctionStmtDefinition(Stmt.Function stmt)
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

	private void visitFunctionStmtBody(Stmt.Function stmt)
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

	private void visitConstStmtDefinition(Stmt.Const stmt)
	{
		let @const = new ZenConst(stmt);
		AddIdentifier(@const);
	}

	// ----------------------------------------------------------------
	// Struct
	// ----------------------------------------------------------------

	private void visitStructStmtDefinition(Stmt.Struct stmt)
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
		for (let statement in ref stmt.Body.Statements)
		{
			if (let fun = statement as Stmt.Function)
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

	private void visitVariableStmtDefinition(Stmt.Variable stmt)
	{
		if (let nonPrim = stmt.Type as NonPrimitiveDataType)
		{
			if (nonPrim.Namespace == null)
				nonPrim.Namespace = new .();

			let nn = scope NamespaceList();
			if (ZenIdentifierExistCheck<ZenStruct>(stmt.Type.Token, nonPrim.Namespace, nn, true) case .Ok(let zenConst))
			{
				nonPrim.Namespace.Clear();
				nonPrim.Namespace.AddRange(nn);
			}
		}
	}

	private void visitVariableStmt(Stmt.Variable stmt)
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

	private void visitReturnStmt(Stmt.Return stmt)
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

	private void visitIfStatement(Stmt.If stmt)
	{
		resolveExpr(stmt.Condition);
		resolveStmtBody(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolveStmtBody(stmt.ElseBranch);
	}

	// ----------------------------------------------------------------
	// While
	// ----------------------------------------------------------------

	private void visitWhileStatement(Stmt.While stmt)
	{
		resolveExpr(stmt.Condition);
		resolveStmtBody(stmt.Body);
	}

	// ----------------------------------------------------------------
	// Misc.
	// ----------------------------------------------------------------

	private void visitBlockStmt(Stmt.Block stmt)
	{
		beginScope();
		{
			Resolve(stmt.Statements).IgnoreError();
		}
		endScope();
	}

	private void visitExpressionStmt(Stmt.Expression stmt)
	{
		resolveExpr(stmt.InnerExpression);
	}

	private void visitEOFStmt(Stmt.EOF stmt)
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
						if (findIdentifierStmt<Stmt.Variable>(@var.Name) case .Ok(let argDef))
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
						if (parameter.Type.Name != literal.Type.Name)
						{
							ThrowError(.IMPLICIT_CAST_INVALID, literal.Token, literal.Type.Name, parameter.Type.Name);
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

	private void visitAssignExpr(Expr.Assign expr)
	{
		if (findIdentifierStmt<Stmt.Variable>(expr.Name) case .Ok(let identifier))
		{
			if (!identifier.Mutable)
			{
				ThrowError(.VARIABLE_ASSIGNMENT_IMMUTABLE, expr.Name, identifier.Name.Lexeme);
				return;
			}

			if (GetTypeFromExpr(expr.Value) case .Ok(let typeB))
			{
				compareAndCheckTypes(expr.Value, identifier.Type, typeB);
			}
		}
		else
		{
			ThrowError(.IDENTIFIER_NOT_FOUND, expr.Name);
		}

		resolveExpr(expr.Value);
	}
}