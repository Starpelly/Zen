using System;
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

	public class EOF : Stmt
	{
	}

	public class Using : Stmt
	{
		public Token Name { get; }

		public this(Token name)
		{
			this.Name = name;
		}
	}

	public class Namespace : Stmt
	{
		public NamespaceList List { get; } ~ delete _;
		public Token Front => List.Front;

		public this(NamespaceList list)
		{
			this.List = list;
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

	public class CEmbed : Stmt
	{
		public String Body { get; } ~ delete _;

		public this(String body)
		{
			this.Body = body;
		}
	}

	public class Function : Stmt
	{
		public enum FunctionKind
		{
			None,
			Main,
			Function,
			Event
		}

		public FunctionKind Kind { get; }
		public Token Name { get; }
		public Token Type { get; }
		public List<Parameter> Parameters { get; } ~ delete _;
		public Block Body { get; } ~ delete _;

		public Namespace Namespace { get; }

		public this(Namespace @namespace, FunctionKind kind, Token name, Token type, List<Parameter> parameters, Block body)
		{
			this.Namespace = @namespace;
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

	public class Variable : Stmt
	{
		public Token Name { get; }
		public Token Type { get; }
		public Expr Initializer { get; } ~ delete _;
		public bool Mutable { get; }

		public bool HasInitializer => Initializer != null;

		public this(Token name, Token type, Expr init, bool mutable)
		{
			this.Name = name;
			this.Type = type;
			this.Initializer = init;
			this.Mutable = mutable;
		}
	}
}