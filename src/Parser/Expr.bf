using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public abstract class Expr
{
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

	public class Call : Expr
	{
		public Expr.Variable Callee { get; } ~ delete _;
		public Token Paren { get; }
		public List<Expr> Arguments { get; } ~ DeleteContainerAndItems!(_);
		public NamespaceList Namespaces { get; } ~ delete _;

		public this(Expr.Variable callee, Token paren, List<Expr> arguments, NamespaceList namespaces)
		{
			this.Callee = callee;
			this.Paren = paren;
			this.Arguments = arguments;
			this.Namespaces = namespaces;
		}
	}

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

	public class Literal : Expr
	{
		public Variant Value { get; }

		public this(Variant value)
		{
			this.Value = value;
		}
	}

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

	public class Grouping : Expr
	{
		public Expr Expression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.Expression = expression;
		}
	}

	public class Variable : Expr
	{
		public Token Name { get; }

		public this(Token name)
		{
			this.Name = name;
		}
	}
}