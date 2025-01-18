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
	private Stmt.Const m_declaration;
	public Stmt.Const Declaration => m_declaration;

	public this(Stmt.Const declaration)
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
	private readonly Stmt.Function m_declaration;
	public Stmt.Function Declaration => m_declaration;

	public this(Stmt.Function declaration)
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
	private readonly Stmt.Struct m_declaration;
	public Stmt.Struct Declaration => m_declaration;

	public this(Stmt.Struct declaration)
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