using System;
using System.Collections;

using Zen.Builder;
using Zen.Parser;

namespace Zen.Transpiler;

public class StandardLib
{
	public void WriteZenHeader(String outString)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();

		builder.AppendLine("#pragma once");
		builder.AppendEmptyLine();

		builder.AppendLine("#include <stdint.h>");
		builder.AppendLine("#include <stdio.h>");

		builder.AppendBanner("Defines");

		// Boolean type
		builder.Append("""


		// Boolean type
		#if (defined(__STDC__) && __STDC_VERSION__ >= 199901L) || (defined(_MSC_VER) && _MSC_VER >= 1800)
			#include <stdbool.h>
		#elif !defined(__cplusplus) && !defined(bool)
			typedef enum bool { false = 0, true = !false } bool;
		#endif
		""");

		builder.Append("""


		// ------------------------------------
		// INT PRIMITIVES
		// ------------------------------------

		typedef int32_t  int32;   // Standard 32-bit signed integer
		typedef int8_t   int8;    // Standard 8-bit signed integer
		typedef int16_t  int16;   // Standard 16-bit signed integer
		typedef int64_t  int64;   // Standard 64-bit signed integer

		typedef uint32_t uint32;  // Standard 32-bit unsigned integer
		typedef uint8_t  uint8;   // Standard 8-bit unsigned integer
		typedef uint16_t uint16;  // Standard 16-bit unsigned integer
		typedef uint64_t uint64;  // Standard 64-bit unsigned integer

		typedef unsigned int uint; // Platform-dependent unsigned int

		// ------------------------------------
		// FLOAT PRIMITIVES
		// ------------------------------------

		typedef float float32;
		typedef double float64;

		// ------------------------------------
		// STRING
		// ------------------------------------

		typedef char* string_view;

		""");

		builder.Append("""


		// NOTE: MSVC C++ compiler does not support compound literals (C99 feature)
		// Plain structures in C++ (without constructors) can be initialized with { }
		// This is called aggregate initialization (C++11 feature)
		#if defined(__cplusplus)
			#define CLITERAL(type)      type
		#else
			#define CLITERAL(type)      (type)
		#endif
		""");
	}

	public void WriteProgramFile(String outString)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();

		builder.AppendLine("#include \"Zen.h\"");
		builder.AppendLine("#include \"All.h\"");
	}

	public void WriteAllFile(String outString, List<Node> nodes, List<CompiledFile> files)
	{
		let builder = scope CodeBuilder();
		defer outString.Append(builder.Code);

		builder.AppendBannerAutogen();

		builder.AppendLine("#pragma once");
		builder.AppendEmptyLine();

		builder.AppendBanner("Public types.");
		for (let node in nodes)
		{
			if (let @struct = node as Node.Struct)
			{
				let ns = Codegen.WriteNamespace(.. scope .(), @struct.Namespace);
				builder.AppendLine(scope $"typedef struct {ns}{@struct.Name.Lexeme};");
			}
		}

		builder.AppendBanner("Include the actual code.");
		for (let file in files)
		{
			builder.AppendLine(scope $"#include \"Program/{file.Name}\""..RemoveFromEnd(5)..Append(".h\""));
		}
	}
}