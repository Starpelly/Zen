using System;
using System.Collections;

using Zen.Compiler;
using Zen.Parser;

namespace Zen.Transpiler;

public class Transpiler
{
	private CodeBuilder m_outputH = new .() ~ delete _;
	private CodeBuilder m_outputC = new .() ~ delete _;

	public readonly List<Stmt> Statements { get; }
	public readonly ZenEnvironment Enviornment { get; }

	public this(List<Stmt> statements, ZenEnvironment env)
	{
		this.Statements = statements;
		this.Enviornment = env;
	}

	/// 1. .h file, 2. .c file
	public (String, String) Compile(String fileName)
	{
		m_outputH.AppendBannerAutogen();
		m_outputH.AppendEmptyLine();

		m_outputH.AppendLine("#pragma once");
		m_outputH.AppendEmptyLine();

		for (let statement in Statements)
		{
			if (statement != null)
			{
				if (statement.GetType() == typeof(Stmt.Function))
				{
					let fun = ((Stmt.Function)statement);
					let defNamespace = scope String();

					if (Enviornment.Get(fun.Name) case .Ok(let val) && fun.Kind != .Main)
					{
						let ns = (val.Get<ZenFunction>()).Declaration.Namespace;
						writeNamespace(defNamespace, ns);
					}

					let funcName = scope String();
					if (fun.Namespace != null && fun.Kind != .Main)
					{
						let ns = writeNamespace(.. scope .(), fun.Namespace);
						funcName.Append(ns);
					}
					funcName.Append(fun.Name.Lexeme);

					m_outputH.Append(scope $"{fun.Type.Lexeme} {funcName}");
					m_outputH.Append("(");
					for (let param in fun.Parameters)
					{
						m_outputH.Append(scope $"{param.Type.Lexeme} {param.Name.Lexeme}");
						if (param != fun.Parameters.Back)
							m_outputH.Append(", ");
					}
					m_outputH.Append(");");
					m_outputH.AppendEmptyLine();
				}
				else if (statement.GetType() == typeof(Stmt.Struct))
				{
					let @struct = ((Stmt.Struct)statement);
					Console.WriteLine(@struct.Name.Lexeme);
				}
			}
		}

		m_outputC.AppendBannerAutogen();
		m_outputC.AppendEmptyLine();

		m_outputC.AppendLine("#include \"../Zen.h\"");
		m_outputC.AppendEmptyLine();

		m_outputC.AppendLine(scope $"#include \"{fileName}.h\"");
		m_outputC.AppendEmptyLine();

		for (let statement in Statements)
		{
			if (statement != null)
			{
				stmtToString(ref m_outputC, statement);
			}
		}

		return (m_outputH.Code, m_outputC.Code);
	}

	[Inline]
	private static void writeNamespace(String outStr, Stmt.Namespace ns)
	{
		if (ns == null) return;

		writeNamespace(outStr, ns.Parent);
		outStr.Append(scope $"{ns.Name.Lexeme}_");
	}

	[Inline]
	private void stmtToString(ref CodeBuilder outLexeme, Stmt stmt)
	{
		// outLexeme.AppendTabs();

		if (let fun = stmt as Stmt.Function)
		{
			let parameters = scope String();

			for (let param in fun.Parameters)
			{
				parameters.Append(scope $"{param.Type.Lexeme} {param.Name.Lexeme}");
				if (param != fun.Parameters.Back)
					parameters.Append(", ");
			}

			let funcName = scope String();
			if (fun.Namespace != null && fun.Kind != .Main)
			{
				let ns = writeNamespace(.. scope .(), fun.Namespace);
				funcName.Append(ns);
			}
			funcName.Append(fun.Name.Lexeme);

			outLexeme.AppendLine(scope $"{fun.Type.Lexeme} {funcName}({parameters})");
			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			{
				for (let bodyStatement in fun.Body.Statements)
				{
					stmtToString(ref outLexeme, bodyStatement);
				}
			}
			outLexeme.DecreaseTab();
			outLexeme.AppendLine("}");

			// outLexeme.AppendEmptyLine();
		}

		if (let block = stmt as Stmt.Block)
		{
			for (let blockStatement in block.Statements)
			{
				stmtToString(ref outLexeme, blockStatement);
			}
		}

		if (let expr = stmt as Stmt.Expression)
		{
			let line = expressionToString(.. scope .(), expr.InnerExpression);
			outLexeme.AppendLine(scope $"{line};");
		}

		if (let ret = stmt as Stmt.Return)
		{
			let lexeme = expressionToString(..scope .(), ret.Value);
			outLexeme.AppendLine(scope $"return {lexeme};");
		}

		if (let @if = stmt as Stmt.If)
		{
			let args = expressionToString(.. scope .(), @if.Condition);
			outLexeme.AppendLine(scope $"if ({args})");

			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			{
				stmtToString(ref outLexeme, @if.ThenBranch);
			}
			outLexeme.DecreaseTab();
			outLexeme.AppendLine("}");
		}

		if (let @while = stmt as Stmt.While)
		{
			let args = expressionToString(.. scope .(), @while.Condition);
			outLexeme.AppendLine(scope $"while ({args})");

			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			{
				stmtToString(ref outLexeme, @while.Body);
			}
			outLexeme.DecreaseTab();
			outLexeme.AppendLine("}");
		}
	}

	[Inline]
	private void expressionToString(String outLexeme, Expr expr)
	{
		if (let variable = expr as Expr.Variable)
		{
			outLexeme.Append(variable.Name.Lexeme);
		}

		if (let call = expr as Expr.Call)
		{
			var callNamespace = scope $"";

			let callee = Enviornment.Get(((Expr.Variable)call.Callee).Name);
			if (callee case .Ok(let val))
			{
				let ns = (val.Get<ZenFunction>()).Declaration.Namespace;
				writeNamespace(callNamespace, ns);
			}

			let name = scope $"{callNamespace}{expressionToString(.. scope .(), call.Callee)}";

			let arguments = scope String();

			for (let argument in call.Arguments)
			{
				arguments.Append(expressionToString(.. scope .(), argument));

				if (argument != call.Arguments.Back)
					arguments.Append(", ");
			}

			outLexeme.Append(scope $"{name}({arguments})");
		}

		if (let literal = expr as Expr.Literal)
		{
			switch (literal.Value.VariantType)
			{
			case typeof(int):
				outLexeme.Append(literal.Value.Get<int>());
				break;
			case typeof(bool):
				outLexeme.Append(literal.Value.Get<bool>() ? "true" : "false");
				break;
			case typeof(StringView):
				let str = scope String();
				str.Append('"');
				str.Append(literal.Value.Get<StringView>());
				str.Append('"');
				outLexeme.Append(str);
				break;
			}
		}

		if (let binary = expr as Expr.Binary)
		{
			let left = expressionToString(.. scope .(), binary.Left);
			let op = binary.Operator.Lexeme;
			let right = expressionToString(.. scope .(), binary.Right);

			outLexeme.Append(scope $"{left} {op} {right}");
		}
	}
}