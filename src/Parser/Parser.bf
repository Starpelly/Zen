using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public class ParseError
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
	private List<Stmt> m_statements = new .() ~ DeleteContainerAndItems!(_);
	private int m_current = 0;

	private List<ParseError> m_errors = new .() ~ DeleteContainerAndItems!(_);
	private bool m_hadErrors = false;

	public List<Token> Tokens { get; }
	public List<ParseError> Errors => m_errors;

	public this(List<Token> tokens)
	{
		this.Tokens = tokens;
	}

	public Result<List<Stmt>> Parse()
	{
		while (!isAtEnd() && !m_hadErrors)
		{
			m_statements.Add(declaration());
		}

		// Type checking
		let functionNames = scope List<StringView>();
		for (let statement in m_statements)
		{
			if (statement.GetType() == typeof(Stmt.Function))
			{
				let fun = (Stmt.Function)statement;

				if (functionNames.Contains(fun.Name.Lexeme))
				{
					error(fun.Name, "Function with name already exists!");
				}

				functionNames.Add(fun.Name.Lexeme);
			}
		}

		if (m_hadErrors)
			return .Err;

		return .Ok(m_statements);
	}

	private Stmt declaration()
	{
		if (match(.Fun))
			return FunctionStatement(.Function);
		if (match(.Struct))
			return StructStatement();
		if (match(.Return))
			return ReturnStatement();
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
		let expr = expression();
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

	private Stmt.Function FunctionStatement(Stmt.Function.FunctionKind kind)
	{
		var kind;

		let type = consume(.Identifier, scope $"Expected {kind} type.");
		let name = consume(.Identifier, scope $"Expected {kind} name.");

		if (name.Lexeme == "main")
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

		return new .(kind, name, type, parameters, body);
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
		let value = expression();
		consume(.Semicolon, "Expected ';' after value.");
		return new .(value);
	}

	private Stmt.Return ReturnStatement()
	{
		let keyword = previous();
		Expr value = null;

		if (!check(.Semicolon))
		{
			value = expression();
		}

		consume(.Semicolon, "Expected ';' after return value.");
		return new .(keyword, value);
	}

	// ----------------------------------------------------------------
	// Expressions
	// ----------------------------------------------------------------

	private Expr expression()
	{
		if (match(.Identifier))
		{
			let @base = previous();

			if (match(.LeftParentheses))
				return functionCall(@base);
		}
		if (match(.String))
			return stringLiteral();
		if (match(.Integer))
			return integerLiteral();

		advance();
		return null;
	}

	private Expr stringLiteral()
	{
		return new Expr.StringLiteral(previous(), new .(previous().Lexeme));
	}

	private Expr integerLiteral()
	{
		return new Expr.IntegerLiteral(previous().Literal.Get<int>());
	}

	private Expr functionCall(Token callee)
	{
		let arguments = new List<Expr>();
		if (!check(.RightParenthesis))
		{
			repeat
			{
				arguments.Add(expression());
			} while(match(.Comma));
		}

		let paren = consume(.RightParenthesis, "Expected ')' after arguments.");

		return new Expr.Call(callee, paren, arguments);
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

	private Token next()
	{
		if (isAtEnd()) return peek();
		return Tokens[m_current++];
	}
}