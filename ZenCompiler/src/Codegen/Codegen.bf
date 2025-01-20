using System;
using System.Collections;

using Zen.Compiler;
using Zen.Lexer;
using Zen.Parser;

namespace Zen.Transpiler;

public class Codegen
{
	private CodeBuilder m_outputH = new .() ~ delete _;
	private CodeBuilder m_outputC = new .() ~ delete _;

	public readonly List<Node> Nodes { get; }
	public readonly ZenEnvironment Enviornment { get; }

	public this(List<Node> nodes, ZenEnvironment env)
	{
		this.Nodes = nodes;
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

		m_outputH.AppendLine("#pragma once");
		m_outputH.AppendEmptyLine();

		for (let node in Nodes)
		{
			if (node != null)
			{
				if (let @const = node as Node.Const)
				{
					let val = expressionToString(.. scope .(), @const.Initializer);
					let name = scope String();
					WriteNamespace(name, @const.Namespace);
					name.Append(@const.Name.Lexeme);

					m_outputH.AppendLine(scope $"#define {name} {val}");
				}

				if (let @struct = node as Node.Struct)
				{
					let ns = WriteNamespace(.. scope .(), @struct.Namespace);

					m_outputH.AppendLine(scope $"typedef struct \{");
					m_outputH.IncreaseTab();

					// Structs in C can only have fields.
					for (let node in @struct.Body.Nodes)
					{
						if (let variable = node as Node.Variable)
						{
							stmtToString(ref m_outputH, variable);
						}
					}

					m_outputH.DecreaseTab();
					m_outputH.AppendLine("}");
					m_outputH.Append(scope $" {ns}{@struct.Name.Lexeme};");

					// Struct methods
					for (let node in @struct.Body.Nodes)
					{
						if (let fun = node as Node.Function)
						{
							stmtToStringHeader(ref m_outputH, fun);
						}
					}

					if (node != Nodes.Back) // @Speed - slow probably...
						m_outputH.AppendEmptyLine();
				}

				if (node.GetType() == .Function)
				{
					stmtToStringHeader(ref m_outputH, node);
				}
			}
		}

		m_outputC.AppendBannerAutogen();
		m_outputC.AppendLine(scope $"#include {zenHeaderPath}");
		m_outputC.AppendBanner("Code");

		// m_outputC.AppendLine(scope $"#include \"{fileName}.h\"");
		// m_outputC.AppendEmptyLine();

		for (let node in Nodes)
		{
			if (node != null)
			{
				stmtToString(ref m_outputC, node);
			}
		}

		return (m_outputH.Code, m_outputC.Code);
	}

	public static void WriteNamespace(String outStr, Node.Namespace ns)
	{
		if (ns == null) return;

		WriteNamespace(outStr, ns.List);
	}

	public static void WriteNamespace(String outStr, NamespaceList tokens)
	{
		if (tokens == null) return;
		for (let token in tokens)
		{
			outStr.Append(scope $"{token.Lexeme}_");
		}
	}

	public static void WriteType(String outStr, DataType type)
	{
		if (let nonPrim = type as NonPrimitiveDataType)
			WriteNamespace(outStr, nonPrim.Namespace);

		outStr.Append(type.Name);
	}

	private void stmtToStringHeader(ref CodeBuilder outLexeme, Node stmt)
	{
		if (let fun = stmt as Node.Function)
		{
			let funcName = scope String();
			if (fun.Kind == .Main)
			{
				return;
				// funcName.Append("main");
			}
			else
			{
				if (fun.Namespace != null && fun.Kind != .Main)
				{
					let ns = WriteNamespace(.. scope .(), fun.Namespace);
					funcName.Append(ns);
				}
				funcName.Append(fun.Name.Lexeme);
			}

			let line = scope String();

			line.Append(scope $"{WriteType(.. scope .(), fun.Type)} {funcName}");
			line.Append("(");
			for (let param in fun.Parameters)
			{
				if (!param.Mutable)
					line.Append("const ");

				// let ns = WriteNamespace(.. scope .(), param.Type)
				line.Append(scope $"{WriteType(.. scope .(), param.Type)} {param.Name.Lexeme}");
				if (param != fun.Parameters.Back)
					line.Append(", ");
			}
			line.Append(");");
			m_outputH.AppendLine(line);
		}
	}

	private void stmtToString(ref CodeBuilder outLexeme, Node stmt)
	{
		// outLexeme.AppendTabs();

		if (let @struct = stmt as Node.Struct)
		{
			for (let node in @struct.Body.Nodes)
			{
				if (let fun = node as Node.Function)
				{
					stmtToString(ref outLexeme, fun);
				}
			}
		}
		if (let fun = stmt as Node.Function)
		{
			let parameters = scope String();

			for (let param in fun.Parameters)
			{
				if (!param.Mutable)
				{
					parameters.Append("const ");
				}

				parameters.Append(scope $"{WriteType(.. scope .(), param.Type)} {param.Name.Lexeme}");
				if (param != fun.Parameters.Back)
					parameters.Append(", ");
			}

			let funcName = scope String();
			if (fun.Namespace != null && fun.Kind != .Main)
			{
				let ns = WriteNamespace(.. scope .(), fun.Namespace);
				funcName.Append(ns);
			}
			funcName.Append(fun.Name.Lexeme);

			// Shitty code to check for local functions because C doesn't support local functions...
			var localVars = scope List<Node.Variable>(); // This should probably be stored when compiling?
			for (let bodyNode in fun.Body.Nodes)
			{
				if (var localFun = bodyNode as Node.Function)
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

						stmtToString(ref outLexeme, bodyNode);
						// m_outputH.AppendLine();
					}
				}
				if (var @var = bodyNode as Node.Variable)
				{
					localVars.Add(@var);
				}
			}

			if (fun.Kind == .Main)
			{
				funcName.Clear();
				funcName.Append("main");
			}
			outLexeme.AppendLine(scope $"{WriteType(.. scope .(), fun.Type)} {funcName}({parameters})");
			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			{
				for (let bodyNode in fun.Body.Nodes)
				{
					if (let localFun = bodyNode as Node.Function)
					{
						if (localFun.Kind == .LocalFunction)
							continue;
					}
					stmtToString(ref outLexeme, bodyNode);
				}
			}
			outLexeme.DecreaseTab();
			outLexeme.AppendLine("}");
		}

		if (let block = stmt as Node.Block)
		{
			outLexeme.AppendLine("{");
			outLexeme.IncreaseTab();
			for (let blockNode in block.Nodes)
			{
				stmtToString(ref outLexeme, blockNode);
			}
			outLexeme.DecreaseTab();
			outLexeme.AppendLine("}");
		}

		if (let expr = stmt as Node.Expression)
		{
			let line = expressionToString(.. scope .(), expr.InnerExpression);
			outLexeme.AppendLine(scope $"{line};");
		}

		if (let @var = stmt as Node.Variable)
		{
			let outStr = scope String();
			let initializerStr = expressionToString(.. scope .(), @var.Initializer);

			if (!@var.Mutable)
			{
				outStr.Append("const ");
			}

			WriteType(outStr, @var.Type);
			// outStr.Append(@var.Type.Name);
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

		if (let ret = stmt as Node.Return)
		{
			let lexeme = expressionToString(..scope .(), ret.Value);
			outLexeme.AppendLine(scope $"return {lexeme};");
		}

		if (let @if = stmt as Node.If)
		{
			let args = expressionToString(.. scope .(), @if.Condition);
			outLexeme.AppendLine(scope $"if ({args})");

			stmtToString(ref outLexeme, @if.ThenBranch);

			if (@if.ElseBranch != null)
			{
				outLexeme.AppendLine(scope $"else");

				stmtToString(ref outLexeme, @if.ElseBranch);
			}
		}

		if (let @while = stmt as Node.While)
		{
			let args = expressionToString(.. scope .(), @while.Condition);
			outLexeme.AppendLine(scope $"while ({args})");

			stmtToString(ref outLexeme, @while.Body);
		}

		if (let cembed = stmt as Node.CEmbed)
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

	private void expressionToString(String outLexeme, Expr expr)
	{
		if (let variable = expr as Expr.Variable)
		{
			if (variable.Namespaces != null)
				WriteNamespace(outLexeme, variable.Namespaces);
			outLexeme.Append(variable.Name.Lexeme);
		}

		if (let call = expr as Expr.Call)
		{
			let callNamespace = WriteNamespace(.. scope .(), call.Namespaces);

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
			let identity = expressionToString(.. scope .(), assign.Name);
			let value = expressionToString(.. scope .(), assign.Value);

			outLexeme.Append(scope $"{identity} = {value}");
		}

		if (let unary = expr as Expr.Unary)
		{
			let right = expressionToString(.. scope .(), unary.Right);
			outLexeme.Append(scope $"{unary.Operator.Lexeme}{right}");
		}

		if (let get = expr as Expr.Get)
		{
			let object = expressionToString(.. scope .(), get.Object);
			let name = get.Name.Lexeme;
			outLexeme.Append(scope $"{object}.{name}");
		}
	}
}