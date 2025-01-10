using System;

namespace Zen.Lexer;

public struct Token : IDisposable
{
	public TokenType Type { get; }
	public Variant Literal { get; set mut; }
	public StringView Lexeme { get; }
	public int Line { get; }
	public int Char { get; }

	public this(TokenType type, Variant literal, StringView lexeme, int line, int char)
	{
		this.Type = type;
		this.Literal = literal;
		this.Lexeme = lexeme;
		this.Line = line;
		this.Char = char;
	}

	public void Dispose() mut
	{
		Literal.Dispose();
	}
}