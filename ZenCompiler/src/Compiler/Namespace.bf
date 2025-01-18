using System;
using System.Collections;

using Zen.Lexer;
using Zen.Parser;

namespace Zen.Compiler;

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
			if (let retVal = val as T)
			{
				func = retVal;
				return true;
			}
		}

		func = null;
		return false;
	}

	public void AddIdentifier(Identifier identifier)
	{
		m_identifiers.Add(identifier.Name.Lexeme, identifier);
	}
}
