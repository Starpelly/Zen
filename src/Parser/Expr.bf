using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public abstract class Expr
{
	public class Call : Expr
	{
		public Token Callee { get; }
		public Token Paren { get; }
		public List<Expr> Arguments { get; } ~ DeleteContainerAndItems!(_);

		public this(Token callee, Token paren, List<Expr> arguments)
		{
			this.Callee = callee;
			this.Paren = paren;
			this.Arguments = arguments;
		}
	}

	public class StringLiteral : Expr
	{
		public Token Token { get; }
		public String Value { get; } ~ delete _;

		public this(Token token, String value)
		{
			this.Token = token;
			this.Value = value;
		}
	}

	public class Literal : Expr
	{
		public Object Value { get; }

		public this(Object value)
		{
			this.Value = value;
		}
	}

	public class IntegerLiteral : Expr
	{
		public int Value { get; }

		public this(int value)
		{
			this.Value = value;
		}
	}
}