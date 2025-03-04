using System;
using System.Collections;

using ZenUtils;

using Zen.Compiler;
using Zen.Lexer;
using Zen.Parser;

namespace Zen.Codegen;

public class CCodegen
{
	private CodeBuilder m_Output = new .() ~ delete _;

	public readonly List<Node> Nodes { get; }
	public readonly ZenEnvironment Enviornment { get; }

	public this(List<Node> nodes, ZenEnvironment env)
	{
		this.Nodes = nodes;
		this.Enviornment = env;
	}

	public String Compile(String fileName)
	{
		m_Output.Append(Zen.Transpiler.StandardLib.WriteZenHeader(.. scope .()));

		return m_Output.Code;
	}
}