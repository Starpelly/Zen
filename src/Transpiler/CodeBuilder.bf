using System;

namespace Zen.Transpiler;

public class CodeBuilder
{
	public String Code => m_code;

	private String m_code = new .() ~ delete _;
	private int m_tabCount;
	private int m_line = 0;

	public void IncreaseTab()
	{
		m_tabCount++;
	}

	public void DecreaseTab()
	{
		m_tabCount--;
	}

	public void Append(StringView text)
	{
		m_code.Append(text);
	}

	public void AppendLine(StringView text)
	{
		AppendNewLine();
		AppendTabs();
		Append(text);
	}

	public void AppendNewLine()
	{
		if (m_line > 0) m_code.Append('\n');
		m_line++;
	}

	public void AppendLineIgnoreTabs(StringView text)
	{
		if (m_line > 0) m_code.Append('\n');
		m_code.Append(text);
		m_line++;
	}

	public void AppendEmptyLine()
	{
		AppendLine("");
	}

	public void AppendTabs()
	{
		for (let i < m_tabCount)
		{
			m_code.Append('\t');
		}
	}

	public void AppendBanner(String text)
	{
		AppendLine("// ---------------------------------------------------------------------");
		AppendLine(scope $"// {text}");
		AppendLine("// ---------------------------------------------------------------------");
	}

	public void AppendBannerAutogen()
	{
		AppendBanner("Auto-generated using the Zen compiler");
	}

	public void Clear()
	{
		m_code.Clear();
		m_line = 0;
	}
}