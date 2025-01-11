using System;

namespace Zen.Lexer;

public struct Token : IDisposable
{
	public TokenType Type { get; }
	public Variant Literal { get; set mut; }
	public StringView Lexeme { get; }
	public int File { get; }
	public int Line { get; }
	public int Col { get; }
	public int ColReal { get; } // Doesn't count tabs as 4 characters

	public this(TokenType type, Variant literal, StringView lexeme, int file, int line, int col, int colReal)
	{
		this.Type = type;
		this.Literal = literal;
		this.Lexeme = lexeme;
		this.File = file;
		this.Line = line;
		this.Col = col;
		this.ColReal = colReal;
	}

	public void Dispose() mut
	{
		Literal.Dispose();
	}
}