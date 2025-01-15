using System;
using System.Collections;

using Zen.Lexer;

namespace Zen.Builder;

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
		private ConsoleColor m_codeColor;

		public this(Dictionary<int, CodeError> errors, ConsoleColor codeColor)
		{
			this.Errors = errors;
			this.m_codeColor = codeColor;
		}

		public void AppendLine(int line, StringView lineText)
		{
			let lineNumStr = line.ToString(.. scope .());

			Console.ForegroundColor = m_codeColor;
			Console.WriteLine(lineWithNumberBar(lineNumStr, lineText, .. scope .()));

			if (Errors.TryGetValue(line, let error))
			{
				Console.ForegroundColor = .Red;
				defer { Console.ForegroundColor = m_codeColor; }

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

	private ConsoleColor m_CodeColor;

	public this(ConsoleColor codeColor)
	{
		this.m_CodeColor = codeColor;
	}

	public void WriteError(CompiledFile compiledFile, ICompilerError error)
	{
		Console.ForegroundColor = .Red;
		defer { Console.ForegroundColor = m_CodeColor; }

		Console.Write(scope $"ERROR: ");
		Console.WriteLine(scope $"{error.Message}");

		Console.ForegroundColor = .Cyan;

		Console.WriteLine(scope $"{compiledFile.Name}:{error.Token.Line}:{error.Token.Col + 1}");
		// Console.WriteLine();

		Console.ForegroundColor = m_CodeColor;

		let errors = new Dictionary<int, CodeError>();
		errors.Add(error.Token.Line, .(error.Token.ColReal, error.Token.Lexeme.Length));

		let codeLine = scope CodeWriter(errors, m_CodeColor);
		codeLine.AppendLine(error.Token.Line, compiledFile.Lexed.Lines[error.Token.Line - 1]);
	}
}