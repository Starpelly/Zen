using System;
using System.Collections;

using Zen.Lexer;

namespace Zen;

public interface ICompilerError
{
	public String Message { get; }
	public Token Token { get; }
}

public class ErrorManager
{
	private struct CodeError
	{
		public StringView Message { get; } = "";
		public int Col { get; }
		public int Length { get; }

		public this(int col, int length)
		{
			this.Col = col;
			this.Length = length;
		}
	}

	private class CodeWriter
	{
		public Dictionary<int, CodeError> Errors { get; } ~ delete _;

		public this(Dictionary<int, CodeError> errors)
		{
			this.Errors = errors;
		}

		public void AppendLine(int line, StringView lineText)
		{
			let lineNumStr = line.ToString(.. scope .());

			Console.WriteLine(lineWithNumberBar(lineNumStr, lineText, .. scope .()));

			if (Errors.TryGetValue(line, let error))
			{
				Console.ForegroundColor = .Red;
				defer { Console.ForegroundColor = g_originalConsoleColor; }

				let arrowLine = scope String(error.Col + error.Length);
				for (let i < error.Col)
				{
					let char = lineText[i];
					switch (char)
					{
					case '\t':
						arrowLine.Append('\t');
						break;
					default:
						arrowLine.Append(' ');
						break;
					}
				}
				for (let i < error.Length)
				{
					arrowLine.Append('^');
				}
				let pad = scope String()..PadLeft(lineNumStr.Length);
				Console.WriteLine(lineWithNumberBar(pad, arrowLine, .. scope .()));
			}
		}

		private void lineWithNumberBar(StringView number, StringView text, String outString)
		{
			outString.Append(scope $"{number} | {text}");
		}
	}

	private static ConsoleColor g_originalConsoleColor;

	public static void Init()
	{
		g_originalConsoleColor = Console.ForegroundColor;
	}

	public static void Shutdown()
	{
		Console.ForegroundColor = g_originalConsoleColor;
	}

	public static void WriteError(Program.CompiledFile compiledFile, ICompilerError error)
	{
		Console.ForegroundColor = .Red;
		defer { Console.ForegroundColor = g_originalConsoleColor; }

		Console.Write(scope $"ERROR: ");
		Console.WriteLine(scope $"{error.Message}");

		Console.ForegroundColor = .Cyan;

		Console.WriteLine(scope $"{compiledFile.Name}:{error.Token.Line}:{error.Token.Col + 1}");
		// Console.WriteLine();

		Console.ForegroundColor = g_originalConsoleColor;

		let errors = new Dictionary<int, CodeError>();
		errors.Add(error.Token.Line, .(error.Token.ColReal, error.Token.Lexeme.Length));

		let codeLine = scope CodeWriter(errors);
		codeLine.AppendLine(error.Token.Line, compiledFile.Lexed.Lines[error.Token.Line - 1]);
	}
}