namespace Zen.Lexer;

public enum TokenType
{
	// Single-characters
	LeftParentheses, RightParenthesis, LeftBrace, RightBrace,
	Dot, Comma, Colon, Semicolon, Slash, Star, Bang, Equal,
	Greater, Less, Minus, Plus, Modulus,

	// Two-characters
	BangEqual, EqualEqual, GreaterEqual, LessEqual, SlashEqual,
	DoubleColon,

	// Literals
	Identifier, Char, String, IntNumber, DoubleNumber, FloatNumber, Bool,

	// Keywords
	And, Or, If, Else, Fun, Event, For, While, Null,
	Print, Return, This, True, False, Var, Let,
	Enum, Match, Struct, Switch, Namespace, Using, CEmbed, HEmbed,
	Public, Private, Const,

	EOF,
}