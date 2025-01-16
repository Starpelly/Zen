using System;
using System.Collections;

using Zen.Builder;

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

		builder.AppendBanner("Defines");
		// builder.AppendLine("#include <stdio.h>");

		builder.AppendLine("#define true  (1 == 1)");
		builder.AppendLine("#define false (!true)");
		builder.AppendLine("#define bool _Bool");
		// builder.AppendLine("#define string const char*"); // TEMP!!!, we want them to be actual strings in the future!
		builder.AppendLine("#define string_view char*"); // TEMP!!!, we want them to be actual strings in the future!
	}

	public void WriteProgramFile(String outString)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();

		builder.AppendLine("#include \"Zen.h\"");
		builder.AppendLine("#include \"All.h\"");
	}

	public void WriteAllFile(String outString, List<CompiledFile> files)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();
		builder.AppendEmptyLine();

		builder.AppendLine("#pragma once");
		builder.AppendEmptyLine();

		builder.AppendBanner("Include the actual code.");
		for (let file in files)
		{
			builder.AppendLine(scope $"#include \"Program/{file.Name}\""..RemoveFromEnd(5)..Append(".h\""));
		}
	}
}