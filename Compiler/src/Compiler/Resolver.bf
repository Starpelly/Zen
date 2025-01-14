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
		for (let statement in statements)
		{
			if (let @namespace = statement as Stmt.Namespace)
			{
				visitNamespaceStmtDefinition(@namespace);
			}
			if (let fun = statement as Stmt.Function)
			{
				visitFunctionStmtDefinition(fun);
			}
		}
	}

	private void resolveStmtBody(Stmt statement)
	{
		if (let @using = statement as Stmt.Using)
		{
			visitUsingStmtBody(@using);
		}
		if (let @namespace = statement as Stmt.Namespace)
		{
			visitNamespaceStmtBody(@namespace);
		}
		if (let fun = statement as Stmt.Function)
		{
			visitFunctionStmtBody(fun);
		}
		if (let block = statement as Stmt.Block)
		{
			visitBlockStmt(block);
		}
		if (let @var = statement as Stmt.Variable)
		{
			visitVarStmt(@var);
		}
		if (let ret = statement as Stmt.Return)
		{
			visitReturnStmt(ret);
		}
		if (let expr = statement as Stmt.Expression)
		{
			visitExpressionStmt(expr);
		}
		if (let @if = statement as Stmt.If)
		{
			visitIfStatement(@if);
		}
		if (let eof = statement as Stmt.EOF)
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

	private bool identifierExists(Token token)
	{
		for (let i < m_scopes.Count)
		{
			let @scope = m_scopes[i];
			if (@scope.ContainsKey(token.Lexeme))
			{
				return true;
			}
		}
		ThrowError(.IDENTIFIER_NOT_FOUND, token);
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
	private void compareAndCheckTypes(Expr expr, ASTType a, ASTType b)
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
			else if (let call = expr as Expr.Call)
			{
	
			}
		}
	}

	// ----------------------------------------------------------------
	// Non-expression statements
	// ----------------------------------------------------------------

	private void visitUsingStmtBody(Stmt.Using stmt)
	{
		m_currentUsings.Add(stmt);
	}

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

	private void visitFunctionStmtDefinition(Stmt.Function stmt)
	{
		// Function already exists
		// Tbh, this should be for all identifiers in a scope
		// But we'll do this simply for now.

		ZenNamespace @namespaceToAdd = null;
		if (stmt.Namespace != null)
		{
			let stmtNSStr = stmt.Namespace.List.NamespaceListToString(.. scope .());
			if (m_environment.Get(stmtNSStr) case .Ok(let @namespace))
			{
				@namespaceToAdd = @namespace.Get<ZenNamespace>();
			}
		}
		else
		{
			if (m_environment.Get(stmt.Name) case .Ok(let val))
			{
				ThrowError(.IDENTIFIER_ALREADY_DEFINED, stmt.Name);
				return;
			}
		}

		let fun = new ZenFunction(stmt);

		if (@namespaceToAdd == null) // Global function
		{
			m_environment.Define(stmt.Name.Lexeme, Variant.Create(fun));
		}
		else
		{
			@namespaceToAdd.AddFunction(fun);
		}
	}

	private void visitFunctionStmtBody(Stmt.Function stmt)
	{
		let enclosingFunction = m_currentFunction;
		m_currentFunction = stmt;

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

	private void visitBlockStmt(Stmt.Block stmt)
	{
		beginScope();
		{
			Resolve(stmt.Statements).IgnoreError();
		}
		endScope();
	}

	private void visitVarStmt(Stmt.Variable stmt)
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

	private Result<ASTType> GetTypeFromExpr(Expr expr)
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

	private void visitIfStatement(Stmt.If stmt)
	{
		resolveExpr(stmt.Condition);
		resolveStmtBody(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolveStmtBody(stmt.ElseBranch);
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

	private void visitCallExpr(Expr.Call expr)
	{
		Result<ZenFunction> existCheck()
		{
			void addNamespaceToExpr(Token namespaceToken)
			{
				expr.Namespaces.AddFront(namespaceToken);
			}

			mixin notAvailableError()
			{
				ThrowError(.IDENTIFIER_NOT_FOUND, expr.Callee.Name);
				// reportError(expr.Callee.Name, scope $"Function '{expr.Callee.Name.Lexeme}' does not exist. ({expr.Namespaces.NamespaceListToString(.. scope .())})");
				return .Err;
			}

			mixin ambigRefError(Token one, Token two)
			{
				let childNString = scope String();
				for (let child in expr.Namespaces)
				{
					childNString.Append("::");
					childNString.Append(child.Lexeme);
				}
				childNString.Append("::");
				childNString.Append(expr.Callee.Name.Lexeme);

				ThrowError(.IDENTIFIER_AMBIGUOUS, expr.Callee.Name, scope $"{one.Lexeme}{childNString}", scope $"{two.Lexeme}{childNString}");
				// reportError(expr.Callee.Name, scope $"'{expr.Callee.Name.Lexeme}' is an ambiguous reference between '{one.Lexeme}{childNString}' and '{two.Lexeme}{childNString}'.");
				return .Err;
			}

			// Check if the function we're calling is global.
			if (expr.Namespaces.Count > 0)
			{
				let namespaceKey = expr.Namespaces.NamespaceListToString(.. scope .());

				if (m_environment.Get(namespaceKey) case .Ok)
				{
					return .Err;
				}

				var foundUsing = false;
				var foundUsings = scope NamespaceList();
				var foundUsingName = default(Token);
				for (let @using in m_currentUsings)
				{
					if (m_environment.Get(@using.Name) case .Ok)
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
					// Test if the same type exists in the current namespace.

					let temp = scope NamespaceList();
					temp.AddFront(m_currentNamespace.Front);
					temp.AddRange(expr.Namespaces);

					let tempStr = temp.NamespaceListToString(.. scope .());
					if (m_environment.Get(tempStr) case .Ok)
					{
						ambigRefError!(foundUsings[0], m_currentNamespace.Front);
					}
					else
					{
						addNamespaceToExpr(foundUsingName);
					}
				}
			}
			else
			{
				// If it isn't global, we can cheat and just add the current push the current namespace so the compiler-
				// thinks it's part of the namespace.
				//
				// We've already checked for duplicates earlier in the function definition.
				addNamespaceToExpr(m_currentNamespace.Front);
			}

			let namespaceKey = expr.Namespaces.NamespaceListToString(.. scope .());
			if (m_environment.Get(namespaceKey) case .Ok(let val))
			{
				let zenNamespace = val.Get<ZenNamespace>();

				if (zenNamespace.FindFunction(expr.Callee.Name.Lexeme, let zenFunc))
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
		let zenFunc = existCheck().Value;

		// resolveExpr(expr.Callee);

		if (zenFunc.Declaration.Parameters.Count < expr.Arguments.Count)
		{
			let fewer = expr.Arguments.Count - zenFunc.Declaration.Parameters.Count;
			ThrowError(.FUNCTION_CALL_TOO_MANY_ARGUMENTS, expr.Callee.Name, fewer);
			// reportError(expr.Callee.Name, scope $"Too many arguments, expected {fewer} fewer.");
		}
		else if (zenFunc.Declaration.Parameters.Count > expr.Arguments.Count)
		{
			let more = zenFunc.Declaration.Parameters.Count - expr.Arguments.Count;
			ThrowError(.FUNCTION_CALL_TOO_FEW_ARGUMENTS, expr.Callee.Name, more);
			// reportError(expr.Callee.Name, scope $"Not enough arguments specified, expected {more} more.");
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
				else
				{
					// There needs to be an error here.
					// Although, this should never be the case?
					// Are functions variables? Probably not...
				}
			}
		}
	}

	private void visitVariableExpr(Expr.Variable expr)
	{
		identifierExists(expr.Name);
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

	private void beginScope()
	{
		m_scopes.Add(new .());
	}

	private void endScope()
	{
		let @scope = m_scopes.PopBack();
		delete @scope;
	}
}