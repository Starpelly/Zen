using System;
using System.Collections;

using Zen.Parser;

namespace Zen.Compiler;

public class ZenFunction
{
	private readonly Stmt.Function m_declaration;

	public Stmt.Function Declaration => m_declaration;

	public this(Stmt.Function declaration)
	{
		this.m_declaration = declaration;
	}

	public Self Bind(ZenNamespace @namespace)
	{
		return new ZenFunction(m_declaration);
	}
}

public class ZenNamespace
{
	private readonly Self m_parent;
	private readonly Dictionary<StringView, ZenFunction> m_functions = new .() ~ DeleteDictionaryAndValues!(_);

	public String Name { get; } ~ delete _;

	public this(Stmt.Namespace @namespace)
	{
		this.Name = @namespace.ToString(.. new .());
	}

	public this(String name, Self parent, Dictionary<StringView, ZenFunction> functions)
	{
		this.Name = name;
		this.m_parent = parent;
		this.m_functions = functions;
	}

	public bool FindFunction(StringView name, out ZenFunction func)
	{
		if (m_functions.TryGetValue(name, let val))
		{
			func = val;
			return true;
		}

		func = null;
		return false;
	}

	public void AddFunction(ZenFunction @function)
	{
		m_functions.Add(@function.Declaration.Name.Lexeme, @function);
	}
}