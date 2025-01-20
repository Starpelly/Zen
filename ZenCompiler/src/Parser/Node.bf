using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Parser;

public enum NodeType
{
	Using,
	Namespace,
	Block,
	Expression,
	CEmbed,
	Function,
	Const,
	Struct,
	Print, // Deprecated
	Return,
	If,
	While,
	Variable,
	EOF
}

[AttributeUsage(.Class, .ReflectAttribute, ReflectUser = .Type)]
public struct RegisterNodeAttribute : Attribute, IOnTypeInit
{
	public NodeType Type;

	public this(NodeType type)
	{
		this.Type = type;
	}

	[Comptime]
	public void OnTypeInit(Type type, Self* prev)
	{
		Compiler.EmitTypeBody(type, "public override NodeType GetType() {");
		Compiler.EmitTypeBody(type, scope $"return NodeType.{Type};");
		Compiler.EmitTypeBody(type, "}");
	}
}

public abstract class Node
{
	public abstract NodeType GetType();

	public interface IIdentifier
	{
		public Namespace Namespace { get; }
	}

	// @NOTE
	// Parameters are deprecated because they're essentially variables,
	// but parameters in C# can have `in`, `ref`, and `out` modifiers.
	//
	// This should probably be investigated.
	// - Starpelly, 1/20/25
 	//
	[RegisterNode(.Variable)]
	public class Variable : Node
	{
		public Token Name { get; }
		public DataType Type { get; } ~ delete _;
		public Expr Initializer { get; } ~ delete _;
		public bool Mutable { get; }

		public bool HasInitializer => Initializer != null;

		public this(Token name, DataType type, Expr initializer, bool mutable)
		{
			this.Name = name;
			this.Type = type;
			this.Initializer = initializer;
			this.Mutable = mutable;
		}
	}

	[RegisterNode(.EOF)]
	public class EOF : Node
	{
	}

	[RegisterNode(.Using)]
	public class Using : Node
	{
		public Token Name { get; }

		public this(Token name)
		{
			this.Name = name;
		}
	}

	[RegisterNode(.Namespace)]
	public class Namespace : Node
	{
		public NamespaceList List { get; } ~ delete _;
		public Token Front => List.Front;

		public this(NamespaceList list)
		{
			this.List = list;
		}

		public this()
		{
			List = new .();
		}
	}

	[RegisterNode(.Block)]
	public class Block : Node
	{
		public List<Node> Nodes { get; } ~ DeleteContainerAndItems!(_);

		public this(List<Node> nodes)
		{
			this.Nodes = nodes;
		}
	}

	[RegisterNode(.Expression)]
	public class Expression : Node
	{
		public Expr InnerExpression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.InnerExpression = expression;
		}
	}

	[RegisterNode(.CEmbed)]
	public class CEmbed : Node
	{
		public String Code { get; } ~ delete _;

		public this(StringView code)
		{
			this.Code = new .(code);
		}
	}

	[RegisterNode(.Function)]
	public class Function : Node, IIdentifier
	{
		public enum FunctionKind
		{
			None,
			Main,
			Function,
			LocalFunction,
			Constructor,
			Event
		}

		public FunctionKind Kind { get; }
		public Token Name { get; set; }
		public DataType Type { get; set; } ~ delete _;
		public List<Variable> Parameters { get; } ~ DeleteContainerAndItems!(_);
		public Block Body { get; private set; } ~ delete _;
		public Namespace Namespace { get; } = new .() ~ delete _;

		public this(FunctionKind kind, Token name, DataType type, List<Variable> parameters, Block body, Namespace @namespace)
		{
			this.Kind = kind;
			this.Name = name;
			this.Type = type;
			this.Parameters = parameters;
			this.Body = body;
			this.Namespace.List.AddRange(@namespace.List);
		}

		public this(FunctionKind kind, Token name, DataType type, List<Variable> parameters, Namespace @namespace)
		{
			this.Kind = kind;
			this.Name = name;
			this.Type = type;
			this.Parameters = parameters;
			this.Namespace.List.AddRange(@namespace.List);
		}

		public void SetBody(Block body)
		{
			this.Body = body;
		}
	}

	[RegisterNode(.Const)]
	public class Const : Node, IIdentifier
	{
		public Token Name { get; }
		public DataType Type { get; } ~ delete _;
		public Expr Initializer { get; } ~ delete _;
		public Namespace Namespace { get; } = new .() ~ delete _;

		public this(Token name, DataType type, Expr initializer, Namespace @namespace)
		{
			this.Name = name;
			this.Type = type;
			this.Initializer = initializer;
			this.Namespace.List.AddRange(@namespace.List);
		}
	}

	[RegisterNode(.Struct)]
	public class Struct : Node, IIdentifier
	{
		public Token Name { get; }
		public Block Body { get; private set; } ~ delete _;
		public Namespace Namespace { get; } = new .() ~ delete _;

		public this(Token name, Block body, Namespace @namespace)
		{
			this.Name = name;
			this.Body = body;
			this.Namespace.List.AddRange(@namespace.List);
		}
	}

	[RegisterNode(.Print)]
	public class Print : Node
	{
		public Expr InnerExpression { get; } ~ delete _;

		public this(Expr expression)
		{
			this.InnerExpression = expression;
		}
	}

	[RegisterNode(.Return)]
	public class Return : Node
	{
		public Token Keyword { get; }
		public Expr Value { get; } ~ delete _;

		public this(Token keyword, Expr value)
		{
			this.Keyword = keyword;
			this.Value = value;
		}
	}

	[RegisterNode(.If)]
	public class If : Node
	{
		public Expr Condition { get; } ~ delete _;
		public Node ThenBranch { get; } ~ delete _;
		public Node ElseBranch { get; } ~ delete _;

		public this(Expr condition, Node thenBranch, Node elseBranch)
		{
			this.Condition = condition;
			this.ThenBranch = thenBranch;
			this.ElseBranch = elseBranch;
		}
	}

	[RegisterNode(.While)]
	public class While : Node
	{
		public Expr Condition { get; } ~ delete _;
		public Node Body { get; } ~ delete _;

		public this(Expr condition, Node body)
		{
			this.Condition = condition;
			this.Body = body;
		}
	}
}