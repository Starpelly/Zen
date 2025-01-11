using System;
using System.Collections;

namespace Zen.Lexer;

public class Tokenizer
{
	private static Dictionary<String, TokenType> KeywordsMap = new .()
	{
		("and", .And),
		("or", .Or),
		("if", .If),
		("else", .Else),
		("for", .For),
		("while", .While),
		("null", .Null),
		// ("print", .Print),
		("return", .Return),
		("this", .This),
		("event", .Event),
		("true", .True),
		("false", .False),
		("var", .Var),
		("let", .Let),
		("fun", .Fun),
		("switch", .Switch),
		("match", .Match),
		("enum", .Enum),
		("struct", .Struct),
		("namespace", .Namespace),
		("using", .Using),
	} ~ delete _;

	private readonly List<Token> m_tokens { get; } = new .();
	private int m_start = 0;
	private int m_current = 0;
	private int m_line = 1;
	private int m_lineCol = 0;
	private int m_lineColReal = 0;
	private readonly int m_fileIndex = 0;

	private readonly String Source { get; }

	public this(String source, int file)
	{
		Source = source;
		m_fileIndex = file;
	}

	public List<Token> ScanTokens()
	{
		while (!isAtEnd())
		{
			// We are at the beginning of the next lexeme.
			m_start = m_current;
			scanToken();
		}

		m_tokens.Add(.(.EOF, Variant.Create<int>(0), "", m_fileIndex, m_line, 0, 0));
		return m_tokens;
	}

	private void scanToken()
	{
		let c = peek();
		advance();

		switch (c)
		{
		case '(' : addToken(.LeftParentheses); break;
		case ')' : addToken(.RightParenthesis); break;
		case '{' : addToken(.LeftBrace); break;
		case '}' : addToken(.RightBrace); break;
		case ',' : addToken(.Comma); break;
		case '.' : addToken(.Dot); break;
		case '-' : addToken(.Minus); break;
		case '+' : addToken(.Plus); break;
		case ';' : addToken(.Semicolon); break;
		case '*' : addToken(.Star); break;
		case '%' : addToken(.Modulus); break;
		case '!' : addToken(match('=', true) ? .BangEqual : .Bang); break;
		case '=' : addToken(match('=', true) ? .EqualEqual : .Equal); break;
		case '<' : addToken(match('=', true) ? .LessEqual : .Less); break;
		case '>' : addToken(match('=', true) ? .GreaterEqual : .Greater); break;
		case '/' :
			if (match('/', true))
			{
				// A comment goes until the end of the line.
				while (peek() != '\n' && !isAtEnd()) advance();
			}
			else if (match('*', true))
			{
				// Walks over a multi-line comment, it increments the line number each time a new line break is found and ignores
				// every sequence of characters contained in the comment. The common execution of the scanner takes place
				// once the '*/' characters are found.
				while (!isAtEnd())
				{
					if (peek() == '\n')
					{
						m_line++;
						m_lineCol = 0;
						m_lineColReal = 0;
					}
					if (match('*', true) && peek() == '/')
					{
						advance();
						return;
					}
					advance();
				}
			}
			else if (match('=', true))
			{
				addToken(.SlashEqual);
			}
			else
			{
				addToken(.Slash);
			}
			break;
		case ':':
			if (match(':', true))
			{
				addToken(.DoubleColon);
			}
			else
			{
				addToken(.Colon);
			}
			break;

		case ' ':
		case '\r':
			// Ignore white-space.
			break;
		case '\t':
			// Ignore white-space.
			m_lineCol += 3;
			break;

		case '\n':
			m_line++;
			m_lineCol = 0;
			m_lineColReal = 0;
			break;

		case '"': scanString(); break;

		default:
			if (isDigit(c))
			{
				scanNumber();
			}
			else if (isAlpha(c))
			{
				scanIdentifier();
			}
			else
			{
				// Unexpected character error.
			}
			break;
		}
	}

	private void addToken(TokenType type)
	{
		addToken(type, Variant.Create<int>(0));
	}

	private void addToken(TokenType type, Variant literal)
	{
		let text = substring(m_start, m_current);
		m_tokens.Add(.(type, literal, text, m_fileIndex, m_line, m_lineCol - (m_current - m_start), m_lineColReal - (m_current - m_start)));
	}

	private void scanString()
	{
		while (peek() != '"' && !isAtEnd())
		{
			if (peek() == '\n') m_line++;
			advance();
		}

		if (isAtEnd())
		{
			// Un-terminated string.
			// Lexer error here.
			return;
		}

		// Closing ".
		advance();

		// Trim the surrounding quotes.
		let value = substring(m_start + 1, m_current - 1);
		addToken(.String, Variant.Create<StringView>(value));
	}

	private void scanNumber()
	{
		mixin peekWhileIsDigit()
		{
			while (isDigit(peek())) advance();
		}

		peekWhileIsDigit!();

		// Look for a fractional part.
		if (peek() == '.' && isDigit(peekNext()))
		{
			// Consume the "."
			advance();

			peekWhileIsDigit!();
		}

		let substring = substring(m_start, m_current);

		// let literal = double.Parse(substring(m_start, m_current));
		let literal = int.Parse(substring);
		addToken(.Integer, Variant.Create<int>(literal));
	}

	private void scanIdentifier()
	{
		while (isAlphaNumeric(peek()))
		{
			advance();
		}
		// Check if the identifer is a reserved keyword.
		let text = substring(m_start, m_current);

		if (KeywordsMap.TryGetValue(scope .(text), let type))
		{
			addToken(type);
		}
		else
		{
			addToken(.Identifier, Variant.Create<StringView>(text));
		}
	}

	private bool match(char8 expected, bool advance)
	{
		if (isAtEnd()) return false;
		if (Source[m_current] != expected) return false;

		if (advance) m_current++;
		return true;
	}

	/// Returns the current character in the text.
	private char8 peek()
	{
		if (isAtEnd()) return '\0';
		return Source[m_current];
	}

	/// Returns the next character in the text.
	private char8 peekNext()
	{
		if (m_current + 1 >= Source.Length) return '\0';
		return Source[m_current + 1];
	}

	/// Moves the character in the text forward by one.
	private void advance()
	{
		m_current++;
		m_lineCol++;
		m_lineColReal++;
		// return Source[m_current - 1];
	}

	private bool isAlpha(char8 c)
	{
		return c.IsLetter;
	}

	private bool isAlphaNumeric(char8 c)
	{
		return (c >= 'a' && c <= 'z') ||
			(c >= 'A' && c <= 'Z') ||
			c == '_';
	}

	private bool isDigit(char8 c)
	{
		return c.IsDigit;
	}

	private bool isAtEnd()
	{
		return m_current >= Source.Length;
	}

	private StringView substring(int start, int end)
	{
		return Source.Substring(start, end - start);
	}
}