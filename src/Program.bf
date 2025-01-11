using System;
using System.IO;
using System.Diagnostics;
using System.Globalization;

using Zen.Lexer;
using Zen.Parser;
using Zen.Transpiler;

namespace Zen;

class Program
{
	private const String testDir = "D:/Zen/test";
	private const String testInputDir = $"{testDir}/src";
	private const String testOutputDir = $"{testDir}/output/src";

	private static int g_filesWritten = 0;
	private static int g_errorCount = 0;
	private static bool g_hadErrors = false;

	public static int Main(String[] args)
	{
		let inputSrcDir = (args.Count == 0) ? testInputDir : args[0];
		let outputSrcDir = Path.Combine(.. scope .(), ((args.Count < 2) ? testOutputDir : args[1]), "Program");

		Directory.CreateDirectory(outputSrcDir);

		let originalConsoleColor = Console.ForegroundColor;
		defer { Console.ForegroundColor = originalConsoleColor; }

		Console.WriteLine("Transpiling...");

		let transpilerWatch = scope Stopwatch();
		transpilerWatch.Start();

		parseFile(inputSrcDir, outputSrcDir, "Main.zen");

		transpilerWatch.Stop();

		if (!g_hadErrors)
		{
			Console.WriteLine(scope $"Zen transpilation time: {transpilerWatch.Elapsed.TotalSeconds.ToString(.. scope .(), "0.00", CultureInfo.InvariantCulture)}s");
			// Console.WriteLine(scope $"{filesWritten} {(filesWritten > 1) ? "files" : "file" } generated");
		}
		else
		{
			Console.WriteLine(scope $"Errors: {g_errorCount}");
			Console.WriteLine("Transpile failed.");
		}

		return 0;
	}

	private static void parseFile(String inputSrcDir, String outputSrcDir, String fileName)
	{
		let inputFilePath = Path.Combine(.. scope .(), inputSrcDir, fileName);
		let inputFileName = Path.GetFileNameWithoutExtension(inputFilePath, .. scope .());

		let text = scope String();
		if (File.ReadAllText(inputFilePath, text) case .Ok)
		{
			let outputFileH = Path.Combine(.. scope .(), outputSrcDir, scope $"{inputFileName}.h");
			let outputFileC = Path.Combine(.. scope .(), outputSrcDir, scope $"{inputFileName}.c");

			let tokenizer = scope Tokenizer(text);
			let tokens = tokenizer.ScanTokens();

			let parser = scope Parser(tokens);
			if (parser.Parse() case .Ok(let statements))
			{
				let compiler = scope Transpiler(statements);
				let output = compiler.Compile(inputFileName);

				File.WriteAllText(outputFileH, output.0);
				File.WriteAllText(outputFileC, output.1);

				g_filesWritten++;
			}
			else
			{
				Console.ForegroundColor = .Red;
				for (let error in parser.Errors)
				{
					Console.WriteLine(scope $"PARSING ERROR: {error.Message} at line {error.Token.Line}:{error.Token.Col}");

					++g_errorCount;
				}

				g_hadErrors = true;
			}
		}
	}
}