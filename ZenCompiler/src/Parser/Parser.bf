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
	public enum PrimitiveType
	{
		Void = 0,
		Integer = 1,
		Float = _*2,
		Double = _*2,
		Boolean = _*2,
		Char = _*2,
		StringView = _*2
	}

	public static Dictionary<StringView, PrimitiveType> PrimitiveDataTypes { get; private set; } = new .()
	{
		("void", 			.Void),

		("int", 			.Integer | .Float | .Double),
		("int8", 			.Integer | .Float | .Double),
		("int16", 			.Integer | .Float | .Double),
		("int32", 			.Integer | .Float | .Double),
		("int64", 			.Integer | .Float | .Double),

		("uint", 			.Integer | .Float | .Double),
		("uint8", 			.Integer | .Float | .Double),
		("uint16", 			.Integer | .Float | .Double),
		("uint32", 			.Integer | .Float | .Double),
		("uint64", 			.Integer | .Float | .Double),

		("float", 			.Float | .Integer),
		("double", 			.Double),

		("bool", 			.Boolean),

		("char8",			.Char),
		("char16",			.Char),
		("char32",			.Char),

		("string_view", 	.StringView),
	} ~ delete _;

	private List<Node> m_nodes;
	private int m_current = 0;

	public List<Node> Nodes => m_nodes;

	private readonly List<ParseError> m_errors = new .() ~ DeleteContainerAndItems!(_);
	private bool m_hadErrors = false;

	private Node.Namespace m_currentNamespace = null;
	private Node.Function m_currentFunction = null;

	public readonly List<Token> Tokens { get; }
	public readonly List<ParseError> Errors => m_errors;

	public this(List<Token> tokens)
	{
		this.Tokens = tokens;
	}

	public Result<List<Node>> Parse()
	{
		m_nodes = new .();

		while (!isAtEnd() && !m_hadErrors)
		{
			let decl = declaration();
			if (decl != null)
			{
				m_nodes.Add(decl);
			}
		}

		if (m_hadErrors)
		{
			DeleteContainerAndItems!(m_nodes);
			return .Err;
		}

		m_nodes.Add(new Node.EOF());
		return .Ok(m_nodes);
	}

	private Node declaration()
	{
		if (match(.Using))
			return UsingNode();
		if (match(.Namespace))
			return NamespaceNode();
		if (match(.Fun))
			return FunctionNode(.Function);
		if (match(.Struct))
			return StructNode();
		if (match(.Return))
			return ReturnNode();
		if (match(.If))
			return IfNode();
		if (match(.While))
			return WhileNode();
		if (match(.CEmbed))
			return CEmbedNode();
		if (match(.Public) || match(.Private))
			return null;
		if (match(.Var))
			return VariableDeclaration(true);
		if (match(.Let))
			return VariableDeclaration(false);
		if (match(.Const))
			return ConstDeclaration();

		// if (match(.Print))
		// 	return PrintNode();

		return node();
	}

	private Node node()
	{
		if (match(.LeftBrace))
			return new Node.Block(Block());

		return expressionNode();
	}

	private Node expressionNode()
	{
		let expr = Expression();
		consume(.Semicolon, "Expected ';' after expression.");
		return new Node.Expression(expr);
	}

	public static DataType GetDataTypeFromTypeToken(Token typeToken)
	{
		DataType paramType;

		if (PrimitiveDataTypes.ContainsKey(typeToken.Lexeme))
		{
			paramType = new PrimitiveDataType(typeToken);
			return paramType;
		}

		paramType = new NonPrimitiveDataType(typeToken);
		return paramType;
	}

	/// @Note - this should also work for non primitive data types, but it doesn't right now.
	public static bool CompareDataTypes(DataType a, DataType b)
	{
		if (!(a is PrimitiveDataType && b is PrimitiveDataType))return false;

		let aType = a as PrimitiveDataType;
		let bType = b as PrimitiveDataType;

		let aFlags = PrimitiveDataTypes[aType.Name];
		let bFlags = PrimitiveDataTypes[bType.Name];
		if (bFlags.HasFlag(aFlags))
		{
			return true;
		}

		return false;
	}

	// ----------------------------------------------------------------
	// Non-expression nodes
	// ----------------------------------------------------------------

	private List<Node> Block()
	{
		let nodes = new List<Node>();

		while (!check(.RightBrace) && !isAtEnd())
		{
			nodes.Add(declaration());
		}

		consume(.RightBrace, "Expected '}' after block.");
		return nodes;
	}

	private Node.Using UsingNode()
	{
		let identity = consume(.Identifier, "Expected identifier after 'using'.");

		consume(.Semicolon, "Expected ';' after using identifier.");

		let @using = new Node.Using(identity);
		return @using;
	}

	private Node.Namespace NamespaceNode()
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

		m_currentNamespace = new Node.Namespace(new NamespaceList()..AddFront(identity)..AddRange(children));
		return m_currentNamespace;
	}

	private Node.Function FunctionNode(Node.Function.FunctionKind kind)
	{
		var kind;
		DataType type;
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
			let selfType = consume(.Self, scope $"Expected {kind} type.");
			type = GetDataTypeFromTypeToken(selfType);
			name = selfType;
			kind = .Constructor;
		}
		else
		{
			// type = consume(.Identifier, scope $"Expected {kind} type.");
			type = consumeDataType();
			name = consume(.Identifier, scope $"Expected {kind} name.");
			
			if (name.Lexeme == "Main" && kind != .LocalFunction)
			{
				kind = .Main;
			}
		}

		consume(.LeftParentheses, scope $"Expected '(' after {kind} name.");

		let parameters = new List<Node.Variable>();
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

				let pType = consumeDataType();
				let pName = consume(.Identifier, "Expected parameter name.");

				// let paramType = GetDataTypeFromTypeToken(pType);

				parameters.Add(new .(pName, pType, null, (accessor.Type == .Var)));
			} while(match(.Comma));
		}

		consume(.RightParenthesis, "Expected ')' after parameters.");
		consume(.LeftBrace, scope $"Expected '\{\' before {kind} body.");

		var retFunc = new Node.Function(kind, name, type, parameters, m_currentNamespace);

		let lastFunc = m_currentFunction;
		m_currentFunction = retFunc;
		{
			let body = Block();
			retFunc.SetBody(new .(body));
		}
		m_currentFunction = lastFunc;

		return retFunc;
	}

	private Node.Struct StructNode()
	{
		if (past(2).Type != .Public && past(2).Type != .Private)
		{
			reportError(peek(), scope $"Expected accessor before 'struct'.");
		}

		let name = consume(.Identifier, scope $"Expected struct name.");

		consume(.LeftBrace, "Expected '{' before struct body.");
		var scopeDepth = 0;
		let nodes = new List<Node>();

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

			nodes.Add(declaration());
			// advance();
		}

		m_currentNamespace.List.PopBack();

		consume(.RightBrace, "Expected '}' after struct body.");

		let body = new Node.Block(nodes);
		return new .(name, body, m_currentNamespace);
	}

	private Node.Print PrintNode()
	{
		let value = Expression();
		consume(.Semicolon, "Expected ';' after value.");
		return new .(value);
	}

	private Node.Return ReturnNode()
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

	private Node.If IfNode()
	{
		consume(.LeftParentheses, "Expected '(' after 'if'.");
		let condition = Expression();
		consume(.RightParenthesis, "Expected ')' after condition.");

		let thenBranch = node();
		var elseBranch = default(Node);

		if (match(.Else))
		{
			elseBranch = node();
		}

		return new Node.If(condition, thenBranch, elseBranch);
	}

	private Node.While WhileNode()
	{
		consume(.LeftParentheses, "Expected '(' after 'while'.");
		let condition = Expression();
		consume(.RightParenthesis, "Expected ')' after condition.");
		let body = node();

		return new Node.While(condition, body);
	}

	private Node.CEmbed CEmbedNode()
	{
		consume(.LeftParentheses, scope $"Expected '(' before 'cembed' body.");

		let code = peek().Literal.Get<StringView>();
		advance();

		consume(.RightParenthesis, "Expected ')' after 'cembed' body.");
		consume(.Semicolon, "Expected ';' after cembed declaration.");

		return new Node.CEmbed(code);
	}

	private Node.Variable VariableDeclaration(bool mutable)
	{
		let type = consumeDataType();
		let name = consume(.Identifier, "Expected variable name.");

		Expr initializer = null;

		// consume(.Equal, "Implicitly typed variables must be initalized.");
		// if (previous().Type == .Equal)

		if (match(.Equal))
		{
			initializer = Expression();
		}

		consume(.Semicolon, "Expected ';' after variable declaration.");

		// let varType = GetDataTypeFromTypeToken(type);
		// let inferredType = Token(.Integer, )
		return new Node.Variable(name, type, initializer, mutable);
	}

	private Node.Const ConstDeclaration()
	{
		let type = consumeDataType();
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

		return new Node.Const(name, type, initializer, m_currentNamespace);
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
				return new Expr.Assign(varExpr, value);
			}
			if (let getExpr = expr as Expr.Get)
			{
				return new Expr.Assign(getExpr, value);
			}

			reportError(equals, "Invalid assignment target.");
			delete expr;
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
			case .Char:
				typeName = "char8";
				break;
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

	private DataType consumeDataType()
	{
		let namespaces = scope NamespaceList();
		var identifier = default(Token);

		repeat
		{
			identifier = consume(.Identifier, "Expected variable type.");
			namespaces.Add(identifier);
		} while (match(.DoubleColon));

		namespaces.PopBack();
		let dataType = Parser.GetDataTypeFromTypeToken(identifier);
		if (let nonPrim = dataType as NonPrimitiveDataType)
		{
			nonPrim.SetNamespace(namespaces);
		}

		return dataType;
	}

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