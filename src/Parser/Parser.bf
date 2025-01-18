using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

typealias NamespaceList = List<Token>;

public abstract class DataType
{
	public StringView Name { get; }
	public Token Token { get; }

	public this(StringView name, Token token)
	{
		this.Name = name;
		this.Token = token;
	}

	public this(Token token)
	{
		this.Name = token.Lexeme;
		this.Token = token;
	}

	public static bool operator ==(Self a, Self b)
	{
		return a.Name == b.Name;
	}

	public static bool operator !=(Self a, Self b)
	{
		return !(a == b);
	}
}

public class PrimitiveDataType : DataType
{
	public this(StringView name, Token token) : base(name, token)
	{
	}

	public this(Token token) : base(token)
	{
	}
}

public class NonPrimitiveDataType : DataType
{
	public NamespaceList Namespace { get; set; } ~ delete _;

	public void SetNamespace(NamespaceList @namespace)
	{
		this.Namespace = new .(@namespace);
	}

	public this(StringView name, Token token) : base(name, token)
	{
	}

	public this(Token token) : base(token)
	{
	}
}

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

public class ParseError : Zen.Builder.ICompilerError
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
	private static List<StringView> PrimitiveDataTypes = new .()
	{
		"void",

		"int",
		"int8",
		"int16",
		"int32",
		"int64",

		"uint",
		"uint8",
		"uint16",
		"uint32",
		"uint64",

		"float",
		"double",

		"bool",

		"string_view",

	} ~ delete _;

	private List<Stmt> m_statements;
	private int m_current = 0;

	private readonly List<ParseError> m_errors = new .() ~ DeleteContainerAndItems!(_);
	private bool m_hadErrors = false;

	private Stmt.Namespace m_currentNamespace = null;
	private Stmt.Function m_currentFunction = null;

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
		if (match(.CEmbed))
			return CEmbedStatement();
		if (match(.Public) || match(.Private))
			return null;
		if (match(.Var))
			return VariableDeclaration(true);
		if (match(.Let))
			return VariableDeclaration(false);
		if (match(.Const))
			return ConstDeclaration();

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

	private DataType GetDataTypeFromToken(Token typeToken)
	{
		DataType paramType;

		if (PrimitiveDataTypes.Contains(typeToken.Lexeme))
		{
			paramType = new PrimitiveDataType(typeToken);
		}
		else
		{
			paramType = new NonPrimitiveDataType(typeToken);
		}

		return paramType;
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
				reportError(peek(), "Unexpected token.");
				break;
			}
		}

		consume(.Semicolon, "Expected ';' after namespace identifier.");

		m_currentNamespace = new Stmt.Namespace(new NamespaceList()..AddFront(identity)..AddRange(children));
		return m_currentNamespace;
	}

	private Stmt.Function FunctionStatement(Stmt.Function.FunctionKind kind)
	{
		var kind;
		Token type;
		Token name;

		if (m_currentFunction == null)
		{
			if (past(2).Type != .Public && past(2).Type != .Private)
			{
				reportError(peek(), scope $"Expected accessor before 'fun'.");
			}
		}
		else
		{
			kind = .LocalFunction;
		}

		if (check(.Self))
		{
			type = consume(.Self, scope $"Expected {kind} type.");
			name = type;
			kind = .Constructor;
		}
		else
		{
			type = consume(.Identifier, scope $"Expected {kind} type.");
			name = consume(.Identifier, scope $"Expected {kind} name.");
			
			if (name.Lexeme == "Main" && kind != .LocalFunction)
			{
				kind = .Main;
			}
		}

		consume(.LeftParentheses, scope $"Expected '(' after {kind} name.");

		let parameters = new List<Stmt.Variable>();
		if (!check(.RightParenthesis))
		{
			repeat
			{
				var accessor = default(Token);
				if (peek().Type == .Let || peek().Type == .Var)
				{
					accessor = peek();
				}
				else
				{
					reportError(peek(), "Expected parameter accessor type.");
				}
				advance();

				let pType = consume(.Identifier, "Expected parameter type.");
				let pName = consume(.Identifier, "Expected parameter name.");

				let paramType = GetDataTypeFromToken(pType);

				parameters.Add(new .(pName, paramType, null, (accessor.Type == .Var)));
			} while(match(.Comma));
		}

		consume(.RightParenthesis, "Expected ')' after parameters.");
		consume(.LeftBrace, scope $"Expected '\{\' before {kind} body.");

		let funcType = GetDataTypeFromToken(type);
		var retFunc = new Stmt.Function(kind, name, funcType, parameters, m_currentNamespace);

		let lastFunc = m_currentFunction;
		m_currentFunction = retFunc;
		{
			let body = Block();
			retFunc.SetBody(new .(body));
		}
		m_currentFunction = lastFunc;

		return retFunc;
	}

	private Stmt.Struct StructStatement()
	{
		if (past(2).Type != .Public && past(2).Type != .Private)
		{
			reportError(peek(), scope $"Expected accessor before 'struct'.");
		}

		let name = consume(.Identifier, scope $"Expected struct name.");

		consume(.LeftBrace, "Expected '{' before struct body.");
		var scopeDepth = 0;
		let statements = new List<Stmt>();

		m_currentNamespace.List.Add(name);

		while (true && !isAtEnd())
		{
			if (check(.LeftBrace))
			{
				scopeDepth++;
			}
			if (check(.RightBrace))
			{
				if (scopeDepth <= 0)
				{
					break;
				}

				scopeDepth--;
			}

			statements.Add(declaration());
			// advance();
		}

		m_currentNamespace.List.PopBack();

		consume(.RightBrace, "Expected '}' after struct body.");

		let body = new Stmt.Block(statements);
		return new .(name, body, m_currentNamespace);
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

	private Stmt.CEmbed CEmbedStatement()
	{
		consume(.LeftParentheses, scope $"Expected '(' before 'cembed' body.");

		let code = peek().Literal.Get<StringView>();
		advance();

		consume(.RightParenthesis, "Expected ')' after 'cembed' body.");
		consume(.Semicolon, "Expected ';' after cembed declaration.");

		return new Stmt.CEmbed(code);
	}

	private Stmt.Variable VariableDeclaration(bool mutable)
	{
		let type = consume(.Identifier, "Expected variable type.");
		let name = consume(.Identifier, "Expected variable name.");

		Expr initializer = null;

		// consume(.Equal, "Implicitly typed variables must be initalized.");
		// if (previous().Type == .Equal)

		if (match(.Equal))
		{
			initializer = Expression();
		}

		consume(.Semicolon, "Expected ';' after variable declaration.");

		let varType = GetDataTypeFromToken(type);
		// let inferredType = Token(.Integer, )
		return new Stmt.Variable(name, varType, initializer, mutable);
	}

	private Stmt.Const ConstDeclaration()
	{
		let type = consume(.Identifier, "Expected const type.");
		let name = consume(.Identifier, "Expected const name.");

		Expr initializer = null;
		if (match(.Equal))
		{
			initializer = Expression();
		}
		else
		{
			reportError(name, "Expected value for const type.");
		}

		consume(.Semicolon, "Expected ';' after const declaration.");

		let constType = GetDataTypeFromToken(type);
		return new Stmt.Const(name, constType, initializer, m_currentNamespace);
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

			if (let varExpr = expr as Expr.Variable)
			{
				let name = varExpr.Name;
				delete varExpr; // @Sus
				return new Expr.Assign(name, value);
			}

			reportError(equals, "Invalid assignment target.");
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
				if (let variable = expr as Expr.Variable)
				{
					variable.Namespaces = namespaces;
					// variable.SetNamespaces(namespaces);
				}
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
		mixin returnLiteral(Token prevToken, Variant value)
		{
			var typeName = "";
			switch (prevToken.Type)
			{
			case .String:
				typeName = "string_view";
				break;
			case .IntNumber:
				typeName = "int";
				break;
			case .DoubleNumber:
				typeName = "double";
				break;
			case .True:
				typeName = "bool";
				break;
			case .False:
				typeName = "bool";
				break;
			default:
			}
			return new Expr.Literal(new PrimitiveDataType(typeName, prevToken), prevToken, prevToken.Literal);
		}

		if (match(.False)) returnLiteral!(previous(), Variant.Create<bool>(false));
		if (match(.True)) returnLiteral!(previous(), Variant.Create<bool>(true));
		if (match(.Null)) returnLiteral!(previous(), Variant.CreateFromBoxed(null));

		if (match(.IntNumber, .DoubleNumber, .String))
		{
			returnLiteral!(previous(), previous().Literal);
		}

		if (match(.Identifier))
		{
			/*
			NamespaceList namespaces = null;
			mixin createNamespaces()
			{
				if (namespaces == null)
				{
					namespaces = new .();
				}
			}
			*/

			return new Expr.Variable(previous(), null);
		}

		if (match(.LeftParentheses))
		{
			let expr = Expression();
			consume(.RightParenthesis, "Expected ')' after expression.");
			return new Expr.Grouping(expr);
		}

		reportError(peek(), "Expected expression.");
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

		reportError(peek(), message);
		return peek();
	}

	private void reportError(Token token, String message)
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