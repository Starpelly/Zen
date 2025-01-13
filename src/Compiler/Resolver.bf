using System;
using System.Collections;

using Zen.Lexer;
using Zen.Parser;

namespace Zen.Compiler;

public class ResolvingError : ICompilerError
{
	public Token Token { get; }
	public String Message { get; } ~ delete _;

	public this(Token token, String message)
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

	private void error(Token token, String message)
	{
		// Log error here.
		m_hadErrors = true;
		m_errors.Add(new .(token, message));
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
			identifierExists(variable.Name);
		}
		if (let assign = expression as Expr.Assign)
		{
			visitAssignExpr(assign);
		}
	}

	private bool identifierExists(Token token)
	{
		let @scope = m_scopes.Back;
		if (!@scope.ContainsKey(token.Lexeme))
		{
			error(token, scope $"Identifier '{token.Lexeme}' not found.");
			return false;
		}
		return true;
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
				error(stmt.Name, "Identifier already defined");
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

		let @scope = m_scopes.Back;
		if (@scope.ContainsKey(stmt.Name.Lexeme))
		{
			error(stmt.Name, scope $"An identifier named '{stmt.Name.Lexeme}' has already been declared in this scope.");
		}

		@scope[stmt.Name.Lexeme] = stmt;
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
		return .Err;
	}

	private void visitReturnStmt(Stmt.Return stmt)
	{
		if (m_currentFunction == null)
		{
			error(stmt.Keyword, "Cannot return from top-level code.");
			return;
		}

		if (GetTypeFromExpr(stmt.Value) case .Ok(let returnType))
		{
			if (m_currentFunction.Type != returnType)
			{
				error(returnType.Token, scope $"Unable to cast '{returnType.Name}' to '{m_currentFunction.Type.Name}'.");
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
				error(expr.Callee.Name, scope $"Function '{expr.Callee.Name.Lexeme}' does not exist. ({expr.Namespaces.NamespaceListToString(.. scope .())})");
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

				error(expr.Callee.Name, scope $"'{expr.Callee.Name.Lexeme}' is an ambiguous reference between '{one.Lexeme}{childNString}' and '{two.Lexeme}{childNString}'.");
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
			error(expr.Callee.Name, scope $"Too many arguments, expected {fewer} fewer.");
		}
		else if (zenFunc.Declaration.Parameters.Count > expr.Arguments.Count)
		{
			let more = zenFunc.Declaration.Parameters.Count - expr.Arguments.Count;
			error(expr.Callee.Name, scope $"Not enough arguments specified, expected {more} more.");
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
						if (parameter.Type.Lexeme != argDef.Type.Name)
						{
							error(@var.Name, "Expected type doesn't match.");
							return;
						}
						resolveExpr(argument);
					}
					else
					{
						error(@var.Name, scope $"Identifier '{@var.Name.Lexeme}' not found.");
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

	private void visitAssignExpr(Expr.Assign expr)
	{
		if (findIdentifierStmt<Stmt.Variable>(expr.Name) case .Ok(let identifier))
		{
			if (!identifier.Mutable)
			{
				error(expr.Name, scope $"Variable '{identifier.Name.Lexeme}' is immutable and cannot be assigned to.");
				return;
			}
		}
		else
		{
			error(expr.Name, scope $"Identifier '{expr.Name.Lexeme}' not found.");
		}
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