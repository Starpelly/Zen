using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public abstract class Stmt
{
	public class Parameter : Stmt
	{
		public Token Type { get; }
		public Token Name { get; }
		public Token Accessor { get; }

		public this(Token type, Token name, Token accessor)
		{
			this.Type = type;
			this.Name = name;
			this.Accessor = accessor;
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
		public String Code { get; } ~ delete _;

		public this(StringView code)
		{
			this.Code = new .(code);
		}
	}

	public class Function : Stmt
	{
		public enum FunctionKind
		{
			None,
			Main,
			Function,
			LocalFunction,
			Event
		}

		public FunctionKind Kind { get; }
		public Token Name { get; }
		public ASTType Type { get; }
		public List<Variable> Parameters { get; } ~ DeleteContainerAndItems!(_);
		public Block Body { get; private set; } ~ delete _;

		public Namespace Namespace { get; }

		public this(Namespace @namespace, FunctionKind kind, Token name, ASTType type, List<Variable> parameters, Block body)
		{
			this.Namespace = @namespace;
			this.Kind = kind;
			this.Name = name;
			this.Type = type;
			this.Parameters = parameters;
			this.Body = body;
		}

		public this(Namespace @namespace, FunctionKind kind, Token name, ASTType type, List<Variable> parameters)
		{
			this.Namespace = @namespace;
			this.Kind = kind;
			this.Name = name;
			this.Type = type;
			this.Parameters = parameters;
		}

		public void SetBody(Block body)
		{
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
		public ASTType Type { get; }
		public Expr Initializer { get; } ~ delete _;
		public bool Mutable { get; }

		public bool HasInitializer => Initializer != null;

		public this(Token name, ASTType type, Expr initializer, bool mutable)
		{
			this.Name = name;
			this.Type = type;
			this.Initializer = initializer;
			this.Mutable = mutable;
		}
	}
}