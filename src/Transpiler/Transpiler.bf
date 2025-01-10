using System;
using System.Collections;

using Zen.Parser;

namespace Zen.Transpiler;

public class Transpiler
{
	private CodeBuilder m_outputH = new .() ~ delete _;
	private CodeBuilder m_outputC = new .() ~ delete _;

	public List<Stmt> Statements { get; }

	public this(List<Stmt> statements)
	{
		this.Statements = statements;
	}

	/// 1. .h file, 2. .c file
	public (String, String) Compile()
	{
		m_outputH.AppendBanner("Auto-generated using the Zen compiler");
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

					m_outputH.Append(scope $"{fun.Type.Lexeme} {fun.Name.Lexeme}");
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

		m_outputC.AppendBanner("Auto-generated using the Zen compiler");
		m_outputC.AppendEmptyLine();

		m_outputC.AppendLine("#include <stdio.h>");
		m_outputC.AppendLine("#include \"Player.h\"");
		m_outputC.AppendEmptyLine();

		for (let statement in Statements)
		{
			if (statement != null)
			{
				if (statement.GetType() == typeof(Stmt.Function))
				{
					let fun = ((Stmt.Function)statement);

					// if (fun.Kind == .Main)
					{
						let parameters = scope String();

						for (let param in fun.Parameters)
						{
							parameters.Append(scope $"{param.Type.Lexeme} {param.Name.Lexeme}");
							if (param != fun.Parameters.Back)
								parameters.Append(", ");
						}

						m_outputC.AppendLine(scope $"{fun.Type.Lexeme} {fun.Name.Lexeme}({parameters})");
						m_outputC.AppendLine("{");
						m_outputC.IncreaseTab();
						{
							for (let bodyStatement in fun.Body)
							{
								if (bodyStatement.GetType() == typeof(Stmt.Print))
								{
									let print = ((Stmt.Print)bodyStatement);
									let expr = ((Expr.Call)print.InnerExpression);

									let str = (Expr.StringLiteral)expr.Arguments[0];
									m_outputC.AppendLine(scope $"printf({str.Value});");
								}

								if (bodyStatement.GetType() == typeof(Stmt.Expression))
								{
									let expr = (Stmt.Expression)bodyStatement;

									if (expr.InnerExpression.GetType() == typeof(Expr.Call))
									{
										let call = (Expr.Call)expr.InnerExpression;

										let arguments = scope String();

										for (let argument in call.Arguments)
										{
											// arguments.Append(scope $"{((Expr.StringLiteral)argument).Value}");

											let lexeme = expressionToString(..scope .(), argument);

											arguments.Append(scope $"{lexeme}");
											if (argument != call.Arguments.Back)
												arguments.Append(", ");
										}

										m_outputC.AppendLine(scope $"{call.Callee.Lexeme}({arguments});");
									}
								}

								if (bodyStatement.GetType() == typeof(Stmt.Return))
								{
									let ret = (Stmt.Return)bodyStatement;
									let lexeme = expressionToString(..scope .(), ret.Value);
									m_outputC.AppendLine(scope $"return {lexeme};");
								}
							}
						}
						m_outputC.DecreaseTab();
						m_outputC.AppendLine("}");
					}

					if (fun != Statements.Back)
						m_outputC.AppendEmptyLine();
				}
			}
		}

		return (m_outputH.Code, m_outputC.Code);
	}

	[Inline]
	private void expressionToString(String outLexeme, Expr expr)
	{
		switch (expr.GetType())
		{
		case typeof(Expr.StringLiteral):
			outLexeme.Append(((Expr.StringLiteral)expr).Value);
			break;
		case typeof(Expr.IntegerLiteral):
			outLexeme.Append(((Expr.IntegerLiteral)expr).Value.ToString(.. scope .()));
			break;
		}

	}
}