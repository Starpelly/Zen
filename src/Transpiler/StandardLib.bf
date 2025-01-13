using System;

namespace Zen.Transpiler;

public class StandardLib
{
	public void WriteZenHeader(String outString)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();
		builder.AppendEmptyLine();

		builder.AppendLine("#pragma once");
		builder.AppendEmptyLine();

		builder.AppendLine("#include <stdio.h>");
		builder.AppendEmptyLine();

		builder.AppendLine("#define true  (1 == 1)");
		builder.AppendLine("#define false (!true)");
		builder.AppendLine("#define bool _Bool");
		builder.AppendLine("#define string const char*"); // TEMP!!!, we want them to be actual strings in the future!
		builder.AppendLine("#define string_view const char*"); // TEMP!!!, we want them to be actual strings in the future!
	}

	public void WriteProgramFile(String outString)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();
	}
}