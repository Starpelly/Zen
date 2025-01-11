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
	private ZenEnvironment m_enviornment = new .() ~ delete _;

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
		for (let statement in statements)
		{
			resolve(statement);
		}

		if (m_hadErrors)
			return .Err;
		return .Ok(m_enviornment);
	}

	private void resolve(Stmt statement)
	{
		if (let @namespace = statement as Stmt.Namespace)
		{
			visitNamespaceStmt(@namespace);
		}
		if (let block = statement as Stmt.Block)
		{
			visitBlockStmt(block);
		}
		if (let fun = statement as Stmt.Function)
		{
			visitFunctionStmt(fun);
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

	private void visitNamespaceStmt(Stmt.Namespace stmt)
	{
		let enclosingNamespace = m_currentNamespace;
		m_currentNamespace = stmt;

		// m_currentNamespace = enclosingNamespace;
	}

	private void visitBlockStmt(Stmt.Block stmt)
	{
		beginScope();
		{
			Resolve(stmt.Statements).IgnoreError();
		}
		endScope();
	}

	private void visitFunctionStmt(Stmt.Function stmt)
	{
		// Function already exists
		// Tbh, this should be for all identifiers in a scope
		// But we'll do this simply for now.
		if (m_enviornment.Get(stmt.Name) case .Ok(let val))
		{
			error(stmt.Name, "Identifier already defined");
			return;
		}

		let fun = new ZenFunction(stmt);
		m_enviornment.Define(stmt.Name.Lexeme, Variant.Create(fun));

		let enclosingFunction = m_currentFunction;
		m_currentFunction = stmt.Kind;

		beginScope();
		{
			resolve(stmt.Body);
		}
		endScope();

		m_currentFunction = enclosingFunction;
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
		resolve(stmt.ThenBranch);
		if (stmt.ElseBranch != null) resolve(stmt.ElseBranch);
	}

	private void visitExpressionStmt(Stmt.Expression stmt)
	{
		resolve(stmt.InnerExpression);
	}

	private void visitCallExpr(Expr.Call expr)
	{
		void existCheck()
		{
			if (m_enviornment.Get(expr.Callee.Name) case .Ok(let val))
			{
				let zenFunc = val.Get<ZenFunction>();
				let zenFuncNamespace = zenFunc.Declaration.Namespace;

				let zenFuncNamespaces = scope List<Token>();
				zenFuncNamespaces.Add(zenFuncNamespace.Name);
				zenFuncNamespaces.AddRange(zenFuncNamespace.Children);

				mixin nsError()
				{
					error(expr.Namespaces[0], "Function not available in current namespace.");
					return;
				}

				// Step 1.
				// Compare the function we're calling's namespaces and the callee's namespaces.
				if (!Stmt.Namespace.CompareChildrenLexeme(zenFuncNamespaces, expr.Namespaces))
				{
					nsError!();
				}
				else
				{
					return;
				}

				/*
				// Step 2.
				// Check if we're currently in a namespace and the target function is also in a namespace.
				if (m_currentNamespace != null && zenFuncNamespace != null)
				{
					let compareChildren = Stmt.Namespace.CompareChildrenLexeme(zenFuncNamespace.Children, expr.Namespaces);

					// Step 3.
					// Check if the top level namespace is the same for the curent namespace and the target function.
					if (m_currentNamespace.Name.Lexeme == zenFuncNamespace.Name.Lexeme)
					{
						if (!compareChildren)
						{
							nsError!();
						}
					}
					else
					{
						nsError!();
					}
				}
				*/
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