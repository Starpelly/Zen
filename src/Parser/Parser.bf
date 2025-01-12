using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

typealias NamespaceList = List<Token>;

static
{
	public static void NamespaceListToString(this NamespaceList list, String strBuffer)
	{
		if (list.Count > 0)
		{
			strBuffer.Append(list[0].Lexeme);
			for (let i < list.Count)
			{
				if (i == 0) continue;

				strBuffer.Append("::");
				strBuffer.Append(list[i].Lexeme);
			}
		}
	}
}

public class ParseError : ICompilerError
{
	public Token Token { get; }
	public String Message { get; } ~ delete _;

	public this(Token token, String message)
	{
		this.Token = token;
		this.Message = new .(message);
	}
}

public class Parser
{
	private List<Stmt> m_statements;
	private int m_current = 0;

	private readonly List<ParseError> m_errors = new .() ~ DeleteContainerAndItems!(_);
	private bool m_hadErrors = false;

	private Stmt.Namespace m_currentNamespace = null;

	public readonly List<Token> Tokens { get; }
	public readonly List<ParseError> Errors => m_errors;

	public this(List<Token> tokens)
	{
		this.Tokens = tokens;
	}

	public Result<List<Stmt>> Parse()
	{
		m_statements = new .();

		while (!isAtEnd() && !m_hadErrors)
		{
			m_statements.Add(declaration());
		}

		if (m_hadErrors)
		{
			DeleteContainerAndItems!(m_statements);
			return .Err;
		}

		m_statements.Add(new Stmt.EOF());
		return .Ok(m_statements);
	}

	private Stmt declaration()
	{
		if (match(.Using))
			return UsingStatement();
		if (match(.Namespace))
			return NamespaceStatement();
		if (match(.Fun))
			return FunctionStatement(.Function);
		if (match(.Struct))
			return StructStatement();
		if (match(.Return))
			return ReturnStatement();
		if (match(.If))
			return IfStatement();
		if (match(.While))
			return WhileStatement();
		if (match(.CBlock))
			return CBlockStatement();
		if (match(.Public) || match(.Private))
		{
			return null;
		}

		// if (match(.Print))
		// 	return PrintStatement();

		return statement();
	}

	private Stmt statement()
	{
		if (match(.LeftBrace))
			return new Stmt.Block(Block());

		return expressionStatement();
	}

	private Stmt expressionStatement()
	{
		let expr = Expression();
		consume(.Semicolon, "Expected ';' after expression.");
		return new Stmt.Expression(expr);
	}

	// ----------------------------------------------------------------
	// Non-expression statements
	// ----------------------------------------------------------------

	private List<Stmt> Block()
	{
		let statements = new List<Stmt>();

		while (!check(.RightBrace) && !isAtEnd())
		{
			statements.Add(declaration());
		}

		consume(.RightBrace, "Expected '}' after block.");
		return statements;
	}

	private Stmt.Using UsingStatement()
	{
		let identity = consume(.Identifier, "Expected identifier after 'using'.");

		consume(.Semicolon, "Expected ';' after using identifier.");

		let @using = new Stmt.Using(identity);
		return @using;
	}

	private Stmt.Namespace NamespaceStatement()
	{
		let identity = consume(.Identifier, "Expected identifier after 'namespace'.");

		// var parentNamespace = m_currentNamespace;

		let children = scope List<Token>();
		while (!check(.Semicolon))
		{
			if (match(.DoubleColon))
			{
				let child = consume(.Identifier, "Expected identifier.");
				children.Add(child);
			}
			else
			{
				error(peek(), "Unexpected token.");
				break;
			}
		}

		consume(.Semicolon, "Expected ';' after namespace identifier.");

		m_currentNamespace = new Stmt.Namespace(new NamespaceList()..AddFront(identity)..AddRange(children));
		return m_currentNamespace;
	}

	private Stmt.Function FunctionStatement(Stmt.Function.FunctionKind kind)
	{
		if (past(2).Type != .Public && past(2).Type != .Private)
		{
			error(peek(), scope $"Expected accessor before 'fun'.");
		}

		var kind;

		let type = consume(.Identifier, scope $"Expected {kind} type.");
		let name = consume(.Identifier, scope $"Expected {kind} name.");

		if (name.Lexeme == "Main")
		{
			kind = .Main;
		}

		consume(.LeftParentheses, scope $"Expected '(' after {kind} name.");

		let parameters = new List<Stmt.Parameter>();
		if (!check(.RightParenthesis))
		{
			repeat
			{
				let pType = consume(.Identifier, "Expected parameter type.");
				let pName = consume(.Identifier, "Expected parameter name.");

				parameters.Add(.(pType, pName));
			} while(match(.Comma));
		}

		consume(.RightParenthesis, "Expected ')' after parameters.");
		consume(.LeftBrace, scope $"Expected '\{\' before {kind} body.");

		let body = Block();

		return new .(m_currentNamespace, kind, name, type, parameters, new .(body));
	}

	private Stmt.Struct StructStatement()
	{
		let name = consume(.Identifier, scope $"Expected struct name.");

		consume(.LeftBrace, "Expected '{' after struct name.");

		let body = Block();
		delete body;

		return new .(name);
	}

	private Stmt.Print PrintStatement()
	{
		let value = Expression();
		consume(.Semicolon, "Expected ';' after value.");
		return new .(value);
	}

	private Stmt.Return ReturnStatement()
	{
		let keyword = previous();
		Expr value = null;

		if (!check(.Semicolon))
		{
			value = Expression();
		}

		consume(.Semicolon, "Expected ';' after return value.");
		return new .(keyword, value);
	}

	private Stmt.If IfStatement()
	{
		consume(.LeftParentheses, "Expected '(' after 'if'.");
		let condition = Expression();
		consume(.RightParenthesis, "Expected ')' after condition.");

		let thenBranch = statement();
		var elseBranch = default(Stmt);

		if (match(.Else))
		{
			elseBranch = statement();
		}

		return new Stmt.If(condition, thenBranch, elseBranch);
	}

	private Stmt.While WhileStatement()
	{
		consume(.LeftParentheses, "Expected '(' after 'while'.");
		let condition = Expression();
		consume(.RightParenthesis, "Expected ')' after condition.");
		let body = statement();

		return new Stmt.While(condition, body);
	}

	private Stmt.CBlock CBlockStatement()
	{
		consume(.LeftBrace, scope $"Expected '\{\' before 'cblock' body.");

		let body = new String();

		while (!check(.RightBrace) && !isAtEnd())
		{
			let next = peek();
			advance();
			body.Append(next.Lexeme);
		}

		consume(.RightBrace, "Expected '}' after block.");

		return new Stmt.CBlock(body);
	}

	// ----------------------------------------------------------------
	// Expressions
	// ----------------------------------------------------------------

	private Expr Expression()
	{
		return Assignment();
	}

	private Expr Assignment()
	{
		let expr = Or();

		if (match(.Equal))
		{
			let equals = previous();
			let value = Assignment();

			/*
			if (let varExpr = expr as Expr.Variable)
			{
				let name = varExpr.Name;
			}

			if (let getExpr = expr as Expr.Get)
			{
			}
			*/

			error(equals, "Invalid assignment target.");
		}

		return expr;
	}

	private Expr Or()
	{
		var expr = And();

		while (match(.Or))
		{
			let op = previous();
			let right = And();
			expr = new Expr.Logical(expr, op, right);
		}

		return expr;
	}

	private Expr And()
	{
		var expr = Equality();

		while (match(.And))
		{
			let op = previous();
			let right = Equality();
			expr = new Expr.Logical(expr, op, right);
		}

		return expr;
	}

	private Expr Equality()
	{
		return parseLeftAssociativeBinaryOparation(
			=> Comparison,
			.BangEqual, .EqualEqual);
	}

	private Expr Comparison()
	{
		return parseLeftAssociativeBinaryOparation(
			=> Addition,
			.Greater, .GreaterEqual, .Less, .LessEqual);
	}

	private Expr Addition()
	{
		return parseLeftAssociativeBinaryOparation(
				=> Multiplication,
				.Minus, .Plus);
	}

	private Expr Multiplication()
	{
		return parseLeftAssociativeBinaryOparation(
			=> Unary,
			.Slash, .Star, .Modulus);
	}

	private Expr Unary()
	{
		if (match(.Bang, .Minus))
		{
			let op = previous();
			let right = Unary();
			return new Expr.Unary(op, right);
		}

		return Call();
	}

	private Expr Call()
	{
		var expr = Primary();

		NamespaceList namespaces = null;
		mixin createNamespaces()
		{
			if (namespaces == null)
			{
				namespaces = new .();
			}
		}
		while (true)
		{
			if (match(.LeftParentheses))
			{
				createNamespaces!();
				expr = FinishCall((Expr.Variable)expr, namespaces);
			}
			else if (match(.DoubleColon))
			{
				createNamespaces!();
				namespaces.Add(((Expr.Variable)expr).Name);

				delete expr;
				expr = Primary();
			}
			else if (match(.Dot))
			{
				let name = consume(.Identifier, "Expected property name after '.'.");
				expr = new Expr.Get(expr, name);
			}
			else
			{
				break;
			}
		}

		return expr;
	}

	private Expr FinishCall(Expr.Variable callee, NamespaceList namespaces)
	{
		let arguments = new List<Expr>();
		if (!check(.RightParenthesis))
		{
			repeat
			{
				arguments.Add(Expression());
			} while (match(.Comma));
		}

		let paren = consume(.RightParenthesis, "Expected ')' after arguments.");

		return new Expr.Call(callee, paren, arguments, namespaces);
	}

	private Expr Primary()
	{
		if (match(.False)) return new Expr.Literal(Variant.Create<bool>(false));
		if (match(.True)) return new Expr.Literal(Variant.Create<bool>(true));
		if (match(.Null)) return new Expr.Literal(Variant.CreateFromBoxed(null));

		if (match(.Integer, .String))
		{
			return new Expr.Literal(previous().Literal);
		}

		if (match(.Identifier))
		{
			return new Expr.Variable(previous());
		}

		if (match(.LeftParentheses))
		{
			let expr = Expression();
			consume(.RightParenthesis, "Expected ')' after expression.");
			return new Expr.Grouping(expr);
		}

		error(peek(), "Expected expression.");
		return null;
	}

	private Expr parseLeftAssociativeBinaryOparation(
		function Expr(Self this) higherPrecedence,
		params TokenType[] tokenTypes)
	{
		var expr = higherPrecedence(this);

		while (match(params tokenTypes))
		{
			let op = previous();
			let right = higherPrecedence(this);
			expr = new Expr.Binary(expr, op, right);
		}

		return expr;
	}

	// ----------------------------------------------------------------
	// Parsing helper functions
	// ----------------------------------------------------------------

	private Token consume(TokenType type, String message)
	{
		if (check(type))
		{
			advance();
			return previous();
		}

		error(peek(), message);
		return peek();
	}

	private void error(Token token, String message)
	{
		// Log error here.
		m_hadErrors = true;
		m_errors.Add(new .(token, message));
	}

	private bool match(params TokenType[] types)
	{
		for (let type in types)
		{
			if (check(type))
			{
				advance();
				return true;
			}
		}
		return false;
	}

	/// Checks to see if the current token is the passed-in type.
	private bool check(TokenType type)
	{
		if (isAtEnd()) return false;
		return peek().Type == type;
	}

	private bool isAtEnd()
	{
		return peek().Type == .EOF;
	}

	private void advance()
	{
		if (!isAtEnd()) m_current++;
	}

	private Token peek()
	{
		return Tokens[m_current];
	}

	private Token previous()
	{
		return Tokens[m_current - 1];
	}

	private Token past(int count)
	{
		return Tokens[m_current - count];
	}

	private Token next()
	{
		if (isAtEnd()) return peek();
		return Tokens[m_current++];
	}
}