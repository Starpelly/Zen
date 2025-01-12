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

	private Stmt.Namespace m_currentNamespace = null;
	private Stmt.Function.FunctionKind m_currentFunction = .None;

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
			resolveBody(statement);
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

	private void resolveBody(Stmt statement)
	{
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
	}

	private void resolve(Expr expression)
	{
		if (let call = expression as Expr.Call)
		{
			visitCallExpr(call);
		}
	}

	private void visitNamespaceStmtDefinition(Stmt.Namespace stmt)
	{
		// let enclosingNamespace = m_currentNamespace;
		m_currentNamespace = stmt;

		let nsString = stmt.List.NamespaceListToString(.. scope .());
		if (m_environment.Get(nsString) case .Ok(let val))
		{
			// No error, this is why namespaces exist at all.
			return;
		}

		let ns = new ZenNamespace(stmt);
		m_environment.Define(nsString, Variant.Create(ns));

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
		m_currentFunction = stmt.Kind;

		beginScope();
		{
			resolveBody(stmt.Body);
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

	private void visitReturnStmt(Stmt.Return stmt)
	{
		if (m_currentFunction == .None)
		{
			error(stmt.Keyword, "Cannot return from top-level code.");
		}
	}

	private void visitIfStatement(Stmt.If stmt)
	{
		resolve(stmt.Condition);
		resolveBody(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolveBody(stmt.ElseBranch);
	}

	private void visitExpressionStmt(Stmt.Expression stmt)
	{
		resolve(stmt.InnerExpression);
	}

	private void visitCallExpr(Expr.Call expr)
	{
		void existCheck()
		{
			if (expr.Callee.Name.Lexeme == "printf") return; // Temp

			void addDefaultNamespaceToExpr()
			{
				expr.Namespaces.AddFront(m_currentNamespace.Front);
			}

			mixin notAvailableError()
			{
				error(expr.Callee.Name, "Function not available in namespace.");
				return;
			}

			if (expr.Namespaces.Count > 0)
			{
				let namespaceKey = expr.Namespaces.NamespaceListToString(.. scope .());
				if (m_environment.Get(namespaceKey) case .Err)
				{
					addDefaultNamespaceToExpr();
				}
			}
			else
			{
				addDefaultNamespaceToExpr();
			}

			let namespaceKey = expr.Namespaces.NamespaceListToString(.. scope .());
			if (m_environment.Get(namespaceKey) case .Ok(let val))
			{
				let zenNamespace = val.Get<ZenNamespace>();

				if (zenNamespace.FindFunction(expr.Callee.Name.Lexeme, let zenFunc))
				{
					// let zenFuncNamespace = zenFunc.Declaration.Namespace;
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
		existCheck();

		resolve(expr.Callee);

		for (let argument in expr.Arguments)
		{
			resolve(argument);
		}
	}

	private void beginScope()
	{
		// m_scopes.AddFront(new .());
	}

	private void endScope()
	{
		// m_scopes.PopBack();
	}
}