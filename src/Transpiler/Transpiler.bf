using System;
using System.Collections;

using Zen.Compiler;
using Zen.Lexer;
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
	public (String, String) Compile(String fileName, String fullFileName)
	{
		var zenHeaderPath = scope String();
		zenHeaderPath.Append('"');
		for (let i in fullFileName.Split('/'))
		{
			zenHeaderPath.Append("../");
		}
		zenHeaderPath.Append("Program.h");
		zenHeaderPath.Append('"');

		// ----------------------------------

		m_outputH.AppendBannerAutogen();
		m_outputH.AppendEmptyLine();

		m_outputH.AppendLine("#pragma once");
		m_outputH.AppendEmptyLine();

		for (let statement in Statements)
		{
			if (statement != null)
			{
				if (let @const = statement as Stmt.Const)
				{
					let val = expressionToString(.. scope .(), @const.Initializer);
					let name = scope String();
					writeNamespace(name, @const.Namespace);
					name.Append(@const.Name.Lexeme);

					m_outputH.AppendLine(scope $"#define {name} {val}");
				}

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
					if (fun.Kind == .Main)
					{
						continue;
						// funcName.Append("main");
					}
					else
					{
						if (fun.Namespace != null && fun.Kind != .Main)
						{
							let ns = writeNamespace(.. scope .(), fun.Namespace);
							funcName.Append(ns);
						}
						funcName.Append(fun.Name.Lexeme);
					}

					m_outputH.Append(scope $"{fun.Type.Name} {funcName}");
					m_outputH.Append("(");
					for (let param in fun.Parameters)
					{
						if (!param.Mutable)
							m_outputH.Append("const ");
						m_outputH.Append(scope $"{param.Type.Name} {param.Name.Lexeme}");
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

		m_outputC.AppendLine(scope $"#include {zenHeaderPath}");
		m_outputC.AppendEmptyLine();

		// m_outputC.AppendLine(scope $"#include \"{fileName}.h\"");
		// m_outputC.AppendEmptyLine();

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

		writeNamespace(outStr, ns.List);
	}

	[Inline]
	private static void writeNamespace(String outStr, NamespaceList tokens)
	{
		for (let token in tokens)
		{
			outStr.Append(scope $"{token.Lexeme}_");
		}
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
				if (!param.Mutable)
				{
					parameters.Append("const ");
				}

				parameters.Append(scope $"{param.Type.Name} {param.Name.Lexeme}");
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

			// Shitty code to check for local functions because C doesn't support local functions...
			var localVars = scope List<Stmt.Variable>(); // This should probably be stored when compiling?
			for (let bodyStatement in fun.Body.Statements)
			{
				if (var localFun = bodyStatement as Stmt.Function)
				{
					if (localFun.Kind == .LocalFunction)
					{
						// let localFunName = scope $"{funcName}_{localFun.Name.Lexeme}";
						/*
						outLexeme.AppendLine("typedef struct {");
						{
							outLexeme.IncreaseTab();
							{
								for (let variable in localVars)
								{
									outLexeme.AppendLine(scope $"{variable.Type.Name} {variable.Name.Lexeme};");
								}
							}
							outLexeme.DecreaseTab();
						}
						outLexeme.Append("}");
						outLexeme.AppendLine(scope $" {localFunName}_Context;");
						*/

						stmtToString(ref outLexeme, bodyStatement);
						// m_outputH.AppendLine();
					}
				}
				if (var @var = bodyStatement as Stmt.Variable)
				{
					localVars.Add(@var);
				}
			}

			if (fun.Kind == .Main)
			{
				funcName.Clear();
				funcName.Append("main");
			}
			outLexeme.AppendLine(scope $"{fun.Type.Name} {funcName}({parameters})");
			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			{
				for (let bodyStatement in fun.Body.Statements)
				{
					if (let localFun = bodyStatement as Stmt.Function)
					{
						if (localFun.Kind == .LocalFunction)
							continue;
					}
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

		if (let @var = stmt as Stmt.Variable)
		{
			let outStr = scope String();
			let initializerStr = expressionToString(.. scope .(), @var.Initializer);

			if (!@var.Mutable)
			{
				outStr.Append("const ");
			}

			outStr.Append(@var.Type.Name);
			outStr.Append(' ');
			outStr.Append(@var.Name.Lexeme);

			if (@var.HasInitializer)
			{
				outStr.Append(" = ");
				outStr.Append(initializerStr);
			}
			outStr.Append(';');

			outLexeme.AppendLine(outStr);
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

		if (let cembed = stmt as Stmt.CEmbed)
		{
			let bodyText = cembed.Code;
			for (let line in bodyText.Split('\n'))
			{
				var outLine = line;
				outLine.TrimEnd('\n');
				// outLine.TrimStart();

				if (outLine.IsWhiteSpace || outLine.IsNull || outLine.IsEmpty) continue;
			   	outLexeme.AppendLine(outLine);
			}
		}
	}

	[Inline]
	private void expressionToString(String outLexeme, Expr expr)
	{
		if (let variable = expr as Expr.Variable)
		{
			if (variable.Namespaces != null)
				writeNamespace(outLexeme, variable.Namespaces);
			outLexeme.Append(variable.Name.Lexeme);
		}

		if (let call = expr as Expr.Call)
		{
			let callNamespace = writeNamespace(.. scope .(), call.Namespaces);

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
			case typeof(double):
				outLexeme.Append(literal.Token.Lexeme);
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
			default:
				Runtime.FatalError(scope $"Unknown literal case ({literal.Value.VariantType}).");
			}
		}

		if (let binary = expr as Expr.Binary)
		{
			let left = expressionToString(.. scope .(), binary.Left);
			let op = binary.Operator.Lexeme;
			let right = expressionToString(.. scope .(), binary.Right);

			outLexeme.Append(scope $"{left} {op} {right}");
		}

		if (let assign = expr as Expr.Assign)
		{
			let identity = assign.Name.Lexeme;
			let value = expressionToString(.. scope .(), assign.Value);

			outLexeme.Append(scope $"{identity} = {value}");
		}
	}
}