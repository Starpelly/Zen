using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Compiler;

public class ZenEnvironment
{
	private readonly Dictionary<StringView, Variant> m_values = new .() ~ delete _;

	public ZenEnvironment Enclosing { get; }

	public this(ZenEnvironment enclosing = null)
	{
		this.Enclosing = enclosing;
	}

	public ~this()
	{
		for (var value in m_values.Values)
		{
			if (value.IsObject)
			{
				delete value.Get<Object>();
			}
			else
			{
				value.Dispose();
			}
		}
	}

	public void Define(StringView name, Variant value)
	{
		m_values[name] = value;
	}

	public Result<Variant> Get(Token name)
	{
		if (m_values.TryGetValue(name.Lexeme, let val))
		{
			return .Ok(val);
		}

		if (Enclosing != null)
		{
			return .Ok(Enclosing.Get(name));
		}

		// Error: Undefined variable
		return .Err;
	}

	public void Assign(Token name, Variant value)
	{
		if (m_values.ContainsKey(name.Lexeme))
		{
			m_values[name.Lexeme] = value;
			return;
		}

		if (Enclosing != null)
		{
			Enclosing.Assign(name, value);
			return;
		}

		// Error: Undefined variable.
	}
}