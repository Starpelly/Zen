using System;
using System.Collections;

using Zen.Compiler;
using Zen.Lexer;
using Zen.Parser;

namespace Zen.IDEHelper;

public class Workspace
{
	private Dictionary<String, List<Node>> m_ASTs = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	private Resolver m_resolver ~ delete _;
	private ZenEnvironment m_environment ~ delete _;

	public void ReplaceAST(StringView fileName, List<Node> nodes)
	{
		let key = new String(fileName);
		if (m_ASTs.ContainsKey(key))
		{
			delete m_ASTs[key];
			m_ASTs.Remove(key);
		}

		m_ASTs.Add(key, nodes);

		delete m_resolver;
		m_resolver = new Resolver();
		m_environment = m_resolver.Resolve(nodes).GetValueOrDefault();
	}

	public void GetHoverData(String buffer, Token token)
	{
		for (let ast in m_ASTs.Values)
		{
			for (let node in ast)
			{
				if (let fun = node as Node.Function)
				{
					if (fun.Name.Lexeme == token.Lexeme)
					{
						buffer.Append(scope $"{fun.Namespace.List.NamespaceListToString(.. scope .())}::{token.Lexeme}");
						buffer.Append(scope $" | function");
					}
				}
			}
		}
	}
}