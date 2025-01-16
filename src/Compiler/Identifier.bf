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

public class ZenNamespace
{
	private readonly Dictionary<StringView, Identifier> m_identifiers = new .() ~ DeleteDictionaryAndValues!(_);

	public String Name { get; } ~ delete _;

	public this(Stmt.Namespace @namespace)
	{
		this.Name = @namespace.List.NamespaceListToString(.. new .());
	}

	public this(NamespaceList list)
	{
		this.Name = list.NamespaceListToString(.. new .());
	}

	public this(String name, Self parent, Dictionary<StringView, Identifier> identifiers)
	{
		this.Name = name;
		this.m_identifiers = identifiers;
	}

	public bool FindIdentifier<T>(StringView name, out T func) where T : Identifier
	{
		if (m_identifiers.TryGetValue(name, let val))
		{
			func = (T)val;
			return true;
		}

		func = null;
		return false;
	}

	public void AddIdentifier(Identifier identifier)
	{
		m_identifiers.Add(identifier.Name.Lexeme, identifier);
	}
}