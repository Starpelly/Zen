using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public abstract class Stmt
{
	public struct Parameter
	{
		public Token Type { get; }
		public Token Name { get; }

		public this(Token type, Token name)
		{
			this.Type = type;
			this.Name = name;
		}
	}

	public class Block : Stmt
	{
		public List<Stmt> Statements { get; } ~ DeleteContainerAndItems!(_);

		public this(List<Stmt> statements)
		{
			this.Statements = statements;
		}
	}

	public class Expression : Stmt
	{
		public Expr InnerExpression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.InnerExpression = expression;
		}
	}

	public class Function : Stmt
	{
		public enum FunctionKind
		{
			Main,
			Function,
			Event
		}

		public FunctionKind Kind { get; }
		public Token Name { get; }
		public Token Type { get; }
		public List<Parameter> Parameters { get; } ~ delete _;
		public List<Stmt> Body { get; } ~ DeleteContainerAndItems!(_);

		public this(FunctionKind kind, Token name, Token type, List<Parameter> parameters, List<Stmt> body)
		{
			this.Kind = kind;
			this.Name = name;
			this.Type = type;
			this.Parameters = parameters;
			this.Body = body;
		}
	}

	public class Struct : Stmt
	{
		public Token Name { get; }

		public this(Token name)
		{
			this.Name = name;
		}
	}

	public class Print : Stmt
	{
		public Expr InnerExpression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.InnerExpression = expression;
		}
	}

	public class Return : Stmt
	{
		public Token Keyword { get; }
		public Expr Value { get; } ~ delete _;

		public this(Token keyword, Expr value)
		{
			this.Keyword = keyword;
			this.Value = value;
		}
	}

	public class If : Stmt
	{
		public Expr Condition { get; } ~ delete _;
		public Stmt ThenBranch { get; } ~ delete _;
		public Stmt ElseBranch { get; } ~ delete _;

		public this(Expr condition, Stmt thenBranch, Stmt elseBranch)
		{
			this.Condition = condition;
			this.ThenBranch = thenBranch;
			this.ElseBranch = elseBranch;
		}
	}

	public class While : Stmt
	{
		public Expr Condition { get; } ~ delete _;
		public Stmt Body { get; } ~ delete _;

		public this(Expr condition, Stmt body)
		{
			this.Condition = condition;
			this.Body = body;
		}
	}

	public class Namespace : Stmt
	{
		public Token Name { get; }

		public this(Token name)
		{
			this.Name = name;
		}
	}
}