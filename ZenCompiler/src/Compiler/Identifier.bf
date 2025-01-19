using System;
using System.Collections;

using Zen.Lexer;
using Zen.Parser;

namespace Zen.Compiler;

/*
public interface IIdentifier<T> where T : Stmt
{
	public StringView Name { get; }
	public Self Bind(ZenNamespace @namespace);
}
*/

public abstract class Identifier
{
	public abstract Token Name { get; }
	public abstract Identifier Bind(ZenNamespace @namespace);
}

public class ZenConst : Identifier
{
	private Node.Const m_declaration;
	public Node.Const Declaration => m_declaration;

	public this(Node.Const declaration)
	{
		this.m_declaration = declaration;
	}

	public override Token Name => m_declaration.Name;
	public override Identifier Bind(ZenNamespace @namespace)
	{
		return new Self(m_declaration);
	}
}

public class ZenFunction : Identifier
{
	private readonly Node.Function m_declaration;
	public Node.Function Declaration => m_declaration;

	public this(Node.Function declaration)
	{
		this.m_declaration = declaration;
	}

	public override Token Name => m_declaration.Name;
	public override Identifier Bind(ZenNamespace @namespace)
	{
		return new Self(m_declaration);
	}
}

public class ZenStruct : Identifier
{
	private readonly Node.Struct m_declaration;
	public Node.Struct Declaration => m_declaration;

	public this(Node.Struct declaration)
	{
		this.m_declaration = declaration;
	}

	public override Token Name => m_declaration.Name;
	public override Identifier Bind(ZenNamespace @namespace)
	{
		return new Self(m_declaration);
	}

	public ZenFunction Constructor = null ~ delete _;
}