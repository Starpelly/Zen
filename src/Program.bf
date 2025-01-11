using System;
using System.IO;
using System.Collections;
using System.Diagnostics;
using System.Globalization;

using Zen.Compiler;
using Zen.Lexer;
using Zen.Parser;
using Zen.Transpiler;

namespace Zen;

class Program
{
	class ParsedFile
	{
		public String Name { get; } ~ delete _;
		public String Text { get; } ~ delete _;
		public List<Token> Tokens { get; } ~ DeleteContainerAndDisposeItems!(_)
		public List<Stmt> Statements { get; } ~ DeleteContainerAndItems!(_);

		public this(String name, String text, List<Token> tokens, List<Stmt> statements)
		{
			this.Name = name;
			this.Text = text;
			this.Tokens = tokens;
			this.Statements = statements;
		}
	}

	private const String testDir = "D:/Zen/test";
	private const String testInputDir = $"{testDir}/src";
	private const String testOutputDir = $"{testDir}/output/src";

	private static int g_filesWritten = 0;
	private static int g_errorCount = 0;
	private static bool g_hadErrors = false;

	private static List<ParsedFile> g_parsedFiles = new .() ~ DeleteContainerAndItems!(_);
	private static List<Stmt> g_statements = new .() ~ delete _;

	public static int Main(String[] args)
	{
		let inputSrcDir = (args.Count == 0) ? testInputDir : args[0];
		let outputSrcDir = ((args.Count < 2) ? testOutputDir : args[1]);
		let outputSrcDirProgram = Path.Combine(.. scope .(), outputSrcDir, "Program");

		// Clear output dir first
		Directory.DelTree(outputSrcDir);

		Directory.CreateDirectory(outputSrcDirProgram);

		let originalConsoleColor = Console.ForegroundColor;
		defer { Console.ForegroundColor = originalConsoleColor; }

		Console.WriteLine("Compiling...");

		let watch = scope Stopwatch();

		watch.Start(); // Parsing

		for (let file in Directory.EnumerateFiles(inputSrcDir))
		{
			let fileName = file.GetFileName(.. scope .());
			parseFile(fileName, file.GetFilePath(.. scope .()));
		}

		watch.Stop(); // Parsing
		let parseTime = watch.Elapsed.TotalSeconds;
		watch.Reset();

		watch.Start(); // Compiling

		if (!g_hadErrors)
		{
			let resolver = scope Resolver();
			if (resolver.Resolve(g_statements) case .Ok(let resolvedEnv))
			{
				let std = scope StandardLib();
				let zenHeader = std.WriteZenHeader(.. scope .());
				let programFile = std.WriteProgramFile(.. scope .());

				File.WriteAllText(Path.Combine(.. scope .(), outputSrcDir, "Zen.h"), zenHeader);
				File.WriteAllText(Path.Combine(.. scope .(), outputSrcDir, "Program.c"), programFile);

				for (let file in g_parsedFiles)
				{
					transpileEnvironment(file, resolvedEnv, outputSrcDirProgram);
				}
			}
			else
			{
				Console.ForegroundColor = .Red;
				for (let error in resolver.Errors)
				{
					Console.WriteLine(scope $"RESOLVING ERROR: {error.Message} at line {error.Token.Line}:{error.Token.Col}");

					++g_errorCount;
				}

				g_hadErrors = true;
			}
		}

		watch.Stop(); // Compiling
		let compileTime = watch.Elapsed.TotalSeconds;

		if (!g_hadErrors)
		{
			Console.WriteLine(scope $"{g_filesWritten} {(g_filesWritten > 1) ? "files" : "file" } written");

			Console.WriteLine(scope $"Zen parsing time:     {parseTime.ToString(.. scope .(),   "0.000000", CultureInfo.InvariantCulture)}s");
			Console.WriteLine(scope $"Zen compilation time: {compileTime.ToString(.. scope .(), "0.000000", CultureInfo.InvariantCulture)}s");
		}
		else
		{
			Console.WriteLine(scope $"Errors: {g_errorCount}");
			Console.WriteLine("Compile failed.");
		}

		return 0;
	}

	private static void parseFile(String fileName, String inputFilePath)
	{
		String text = new .();
		if (File.ReadAllText(inputFilePath, text) case .Ok)
		{
			let tokenizer = scope Tokenizer(text);
			let tokens = tokenizer.ScanTokens();

			let parser = scope Parser(tokens, null);
			if (parser.Parse() case .Ok(let statements))
			{
				g_statements.AddRange(statements);
				g_parsedFiles.Add(new .(new .(fileName), text, tokens, statements));

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

	private static void transpileEnvironment(ParsedFile file, ZenEnvironment env, String outputSrcDir)
	{
		let fileNameWOE = Path.GetFileNameWithoutExtension(file.Name, .. scope .());

		let outputFileH = Path.Combine(.. scope .(), outputSrcDir, scope $"{fileNameWOE}.h");
		let outputFileC = Path.Combine(.. scope .(), outputSrcDir, scope $"{fileNameWOE}.c");

		let compiler = scope Transpiler(file.Statements, env);
		let output = compiler.Compile(fileNameWOE);

		File.WriteAllText(outputFileH, output.0);
		File.WriteAllText(outputFileC, output.1);
	}
}