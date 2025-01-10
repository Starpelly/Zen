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
	private const String testInputFile = $"{testDir}/src/Player.zen";
	private const String testOutputDir = $"{testDir}/output/src";

	public static int Main(String[] args)
	{
		let transpilerWatch = scope Stopwatch();
		var hadErrors = false;
		var errorCount = 0;
		var filesWritten = 0;

		let inputFile = (args.Count == 0) ? testInputFile : args[0];
		let outputSrcPath = (args.Count < 2) ? testOutputDir : args[1];

		let inputFileName = Path.GetFileNameWithoutExtension(inputFile, .. scope .());

		let outputFileH = Path.Combine(.. scope .(), outputSrcPath, scope $"{inputFileName}.h");
		let outputFileC = Path.Combine(.. scope .(), outputSrcPath, scope $"{inputFileName}.c");

		let originalConsoleColor = Console.ForegroundColor;
		defer { Console.ForegroundColor = originalConsoleColor; }

		Console.WriteLine("Transpiling...");
		transpilerWatch.Start();

		let text = scope String();
		if (File.ReadAllText(inputFile, text) case .Ok)
		{
			let tokenizer = scope Tokenizer(text);
			let tokens = tokenizer.ScanTokens();

			let parser = scope Parser(tokens);
			if (parser.Parse() case .Ok(let statements))
			{
				let compiler = scope Transpiler(statements);
				let output = compiler.Compile();

				File.WriteAllText(outputFileH, output.0);
				File.WriteAllText(outputFileC, output.1);

				filesWritten++;
			}
			else
			{
				Console.ForegroundColor = .Red;
				for (let error in parser.Errors)
				{
					Console.WriteLine(scope $"PARSING ERROR: {error.Message} at line {error.Token.Line}:{error.Token.Char}");

					++errorCount;
				}

				hadErrors = true;
			}
		}

		transpilerWatch.Stop();

		if (!hadErrors)
		{
			Console.WriteLine(scope $"Zen transpilation time: {transpilerWatch.Elapsed.TotalSeconds.ToString(.. scope .(), "0.00", CultureInfo.InvariantCulture)}s");
			// Console.WriteLine(scope $"{filesWritten} {(filesWritten > 1) ? "files" : "file" } generated");
		}
		else
		{
			Console.WriteLine(scope $"Errors: {errorCount}");
			Console.WriteLine("Transpile failed.");
		}

		return 0;
	}
}