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

	public class Namespace : Stmt
	{
		public Token Name { get; }
		public List<Token> Children { get; } ~ delete _;

		public this(Token name, List<Token> children)
		{
			this.Name = name;
			this.Children = children;
		}

		public this(List<Token> tokens)
		{
			Children = new .();
			if (tokens.Count > 0)
			{
				Name = tokens[0];
				if (tokens.Count > 1)
				{
					for (let i < tokens.Count)
					{
						if (i == 0) continue;
						Children.Add(tokens[i]);
					}
				}
			}
		}

		public static bool operator == (Self a, Self b)
		{
			if (a.Name.Lexeme != b.Name.Lexeme) return false;
			if (a.Children.Count != b.Children.Count) return false;

			for (let i < a.Children.Count)
			{
				if (a.Children[i].Lexeme != b.Children[i].Lexeme)
					return false;
			}

			return true;
		}

		public static bool operator != (Self a, Self b)
		{
			return !(a == b);
		}

		public static bool CompareChildrenLexeme(List<Token> a, List<Token> b)
		{
			if (a.IsEmpty && b.IsEmpty) return true;
			if (a.Count != b.Count) return false;

			for (let i < a.Count)
			{
				if (a[i].Lexeme != b[i].Lexeme)
					return false;
			}

			return true;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.Append(Name.Lexeme);
			for (let child in Children)
			{
				strBuffer.Append("::");
				strBuffer.Append(child.Lexeme);
			}
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

	public class CBlock : Stmt
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
}