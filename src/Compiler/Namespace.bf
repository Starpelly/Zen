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

	public String Name { get; }

	public this(String name, Self parent, Dictionary<StringView, ZenFunction> functions)
	{
		this.Name = name;
		this.m_parent = parent;
		this.m_functions = functions;
	}

	public Result<ZenFunction> FindFunction(StringView name)
	{
		if (m_functions.TryGetValue(name, let val))
		{
			return .Ok(val.Bind(this));
		}

		return .Err;
	}
}