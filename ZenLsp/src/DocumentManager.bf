using System;
using System.IO;
using System.Collections;

using Zen.Lexer;
using Zen.Parser;

namespace ZenLsp;

public enum CompilerDataType
{
	Completions,
	Navigation,
	Hover,
	GoToDefinition,
	SymbolInfo
}

public class Document
{
	public String path ~ delete _;
	public int version;
	public String contents ~ delete _;

	private Tokenizer m_lexer ~ delete _;
	private Parser m_parser ~ delete _;

	private bool charDataDirty;
	private bool charDataParse;

	[AllowAppend]
	public this(StringView path, int version, String contents)
	{
		this.path = new .(path);
		this.version = version;
		this.contents = contents;
		this.charDataDirty = true;
	}

	public void SetContents(int version, StringView contents)
	{
		this.version = version;
		this.contents.Set(contents);
		this.charDataDirty = true;
	}

	public (int, int) GetLineAndChar(int position)
	{
		Console.WriteLine(position);
		return (0, 0);
	}

	public int GetPosition(Json json, StringView name = "position")
	{
		let line = (int)(json[name]["line"].AsNumber) + 1;
		let char = (int)(json[name]["character"].AsNumber);

		var retVal = -1;

		for (let i < m_parser.Tokens.Count)
		{
			let token = m_parser.Tokens[i];

			let tokenLength = token.Lexeme.Length - 1;
			let tokenLine = token.Line;
			let tokenCol = token.Col;

			if (line == tokenLine
				&& (char >= tokenCol && char <= tokenCol + tokenLength))
			{
				retVal = i;
				break;
			}
		}

		return retVal;
	}

	public void GetCompilerData(CompilerDataType type, int character, String buffer, StringView entryName = "")
	{
		String name;
		switch (type) {
			case .Completions:    name = "GetCompilerData - Completions";
			case .Navigation:     name = "GetCompilerData - Navigation";
			case .Hover:          name = "GetCompilerData - Hover";
			case .GoToDefinition: name = "GetCompilerData - GoToDefinition";
			case .SymbolInfo:     name = "GetCompilerData - SymbolInfo";
		}

		if (character < 0) return;

		buffer.Append(":");

		let token = m_parser.Tokens[character];
		buffer.Append(ZenLspServer.GlobalWorkspace.GetHoverData(.. scope .(), token));
	}

	public void Parse()
	{
		let tokenizer = scope Tokenizer(contents, 0);
		let tokens = tokenizer.ScanTokens();

		m_parser = new Parser(tokens);
		m_parser.Parse().IgnoreError();

		ZenLspServer.GlobalWorkspace.ReplaceAST(path, m_parser.Nodes);
	}
}

public class DocumentManager : IEnumerable<Document>
{
	private Dictionary<String, Document> m_documents = new .() ~ DeleteDictionaryAndValues!(_);

	public Document Add(StringView path, int version, String contents)
	{
		Document document = new .(path, version, contents);
		m_documents[document.path] = document;

		return document;
	}

	public void Remove(StringView path)
	{
		if (m_documents.GetAndRemoveAlt(path) case .Ok(let val))
		{
			delete val.value;
		}
	}

	public Document Get(StringView path)
	{
		String key;
		Document document;

		if (!m_documents.TryGetAlt(path, out key, out document)) return null;
		return document;
	}

	public Dictionary<String, Document>.ValueEnumerator GetEnumerator()
	{
		return m_documents.Values;
	}
}