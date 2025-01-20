using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public enum ExprType
{
	Binary,
	Variable,
	Call,
	Logical,
	Literal,
	Unary,
	Get,
	Set,
	Grouping,
	Assign
}

[AttributeUsage(.Class, .ReflectAttribute, ReflectUser = .Type)]
public struct RegisterExprAttribute : Attribute, IOnTypeInit
{
	public ExprType Type;

	public this(ExprType type)
	{
		this.Type = type;
	}

	[Comptime]
	public void OnTypeInit(Type type, Self* prev)
	{
		Compiler.EmitTypeBody(type, "public override ExprType GetType() {");
		Compiler.EmitTypeBody(type, scope $"return ExprType.{Type};");
		Compiler.EmitTypeBody(type, "}");
	}
}

public abstract class Expr
{
	public abstract ExprType GetType();

	public interface IHaveType
	{
		public abstract DataType GetType();
	}

	public interface IHaveNamespaces
	{
		public NamespaceList Namespaces { get; set; }
	}

	[RegisterExpr(.Binary)]
	public class Binary : Expr
	{
		public Expr Left { get; } ~ delete _;
		public Token Operator { get; }
		public Expr Right { get; } ~ delete _;

		public this(Expr left, Token @operator, Expr right)
		{
			this.Left = left;
			this.Operator = @operator;
			this.Right = right;
		}
	}

	[RegisterExpr(.Variable)]
	public class Variable : Expr, IHaveNamespaces
	{
		public Token Name { get; set; }
		public NamespaceList Namespaces { get; set; } ~ delete _;

		public this(Token name, NamespaceList namespaces)
		{
			this.Name = name;
			this.Namespaces = namespaces;
		}
	}

	[RegisterExpr(.Call)]
	public class Call : Expr, IHaveNamespaces
	{
		public Expr.Variable Callee { get; } ~ delete _;
		public Token Paren { get; }
		public List<Expr> Arguments { get; } ~ DeleteContainerAndItems!(_);
		public NamespaceList Namespaces { get; set; } ~ delete _;

		public this(Expr.Variable callee, Token paren, List<Expr> arguments, NamespaceList namespaces)
		{
			this.Callee = callee;
			this.Paren = paren;
			this.Arguments = arguments;
			this.Namespaces = namespaces;
		}
	}

	[RegisterExpr(.Logical)]
	public class Logical : Expr
	{
		public Expr Left { get; } ~ delete _;
		public Token Operator { get; }
		public Expr Right { get; } ~ delete _;

		public this(Expr left, Token @operator, Expr right)
		{
			this.Left = left;
			this.Operator = @operator;
			this.Right = right;
		}
	}

	[RegisterExpr(.Literal)]
	public class Literal : Expr
	{
		public DataType Type { get; } ~ delete _;
		public Token Token { get; }
		public Variant Value { get; }

		public this(DataType type, Token token, Variant value)
		{
			this.Type = type;
			this.Token = token;
			this.Value = value;
		}

		public String GetTypeName() // @Temp
		{
			switch (Token.Type)
			{
			case .String: return "string";
			case .IntNumber: return "int";
			case .Bool: return "bool";
			default:
			}
			return default(String);
		}
	}

	[RegisterExpr(.Unary)]
	public class Unary : Expr
	{
		public Token Operator { get; }
		public Expr Right { get; } ~ delete _;

		public this(Token @operator, Expr right)
		{
			this.Operator = @operator;
			this.Right = right;
		}
	}

	[RegisterExpr(.Get)]
	public class Get : Expr
	{
		public Expr Object { get; } ~ delete _;
		public Token Name { get; }

		public this(Expr object, Token name)
		{
			this.Object = object;
			this.Name = name;
		}
	}

	[RegisterExpr(.Set)]
	public class Set : Expr
	{
		public Expr Object { get; } ~ delete _;
		public Token Name { get; }
		public Expr Value { get; }

		public this(Expr object, Token name, Expr value)
		{
			this.Object = object;
			this.Name = name;
			this.Value = value;
		}
	}

	[RegisterExpr(.Grouping)]
	public class Grouping : Expr
	{
		public Expr Expression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.Expression = expression;
		}
	}

	[RegisterExpr(.Assign)]
	public class Assign : Expr
	{
		public Expr Name { get; } ~ delete _;
		public Expr Value { get; } ~ delete _;

		public this(Expr name, Expr value)
		{
			this.Name = name;
			this.Value = value;
		}
	}
}