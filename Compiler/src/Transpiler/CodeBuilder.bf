using System;

namespace Zen.Transpiler;

public class CodeBuilder
{
	public String Code => m_code;

	private String m_code = new .() ~ delete _;
	private int m_tabCount;

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
		AppendTabs();
		m_code.Append(text);
		m_code.Append('\n');
	}

	public void AppendLineIgnoreTabs(StringView text)
	{
		m_code.Append(text);
		m_code.Append('\n');
	}

	public void AppendEmptyLine()
	{
		m_code.Append('\n');
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
	}
}