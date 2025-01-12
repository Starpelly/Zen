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

// IDE - Zen garden
// No royalties to Mudstep

class Program
{
	public class LexedFile
	{
		public String Text { get; } ~ delete _;

		public List<StringView> Lines { get; } ~ delete _;
		public List<Token> Tokens { get; } ~ DeleteContainerAndDisposeItems!(_)

		public this(String text, List<Token> tokens)
		{
			this.Text = text;
			this.Tokens = tokens;

			let split = Text.Split('\n');
			this.Lines = new .();
			for (let line in split)
			{
				this.Lines.Add(line);
			}
		}
	}

	public class ParsedFile
	{
		public List<Stmt> Statements { get; } ~ DeleteContainerAndItems!(_);

		public this(List<Stmt> statements)
		{
			this.Statements = statements;
		}
	}

	public class CompiledFile
	{
		public String Name { get; } ~ delete _;
		public LexedFile Lexed { get; private set; } ~ delete _;
		public ParsedFile Parsed { get; private set; } ~ delete _;

		public this(String name)
		{
			this.Name = name;
		}

		public void SetLexed(LexedFile lexed)
		{
			this.Lexed = lexed;
		}

		public void SetParsed(ParsedFile parsed)
		{
			this.Parsed = parsed;
		}
	}

	private const String testDir = "D:/Zen/test";
	private const String testInputDir = $"{testDir}/src";
	private const String testOutputDir = $"{testDir}/build/codegen";

	private static int g_filesWritten = 0;
	private static int g_errorCount = 0;
	private static bool g_hadErrors = false;

	private static List<CompiledFile> g_files = new .() ~ DeleteContainerAndItems!(_);
	private static List<Stmt> g_statements = new .() ~ delete _;

	private static ConsoleColor g_originalConsoleColor;

	public static int Main(String[] args)
	{
		let inputSrcDir = (args.Count == 0) ? testInputDir : args[0];
		let outputSrcDir = ((args.Count < 2) ? testOutputDir : args[1]);
		let outputSrcDirProgram = Path.Combine(.. scope .(), outputSrcDir, "Program");

		ErrorManager.Init();

		g_originalConsoleColor = Console.ForegroundColor;
		defer { Console.ForegroundColor = g_originalConsoleColor; }

		Console.WriteLine("Compiling...");

		let watch = scope Stopwatch();

		watch.Start(); // Parsing

		let relPath = scope String();
		void recurseFiles(StringView path)
		{
			if (path != inputSrcDir)
			{
				relPath.Append(Path.GetFileName(path, .. scope .()));
				relPath.Append("/");
			}

			for (let file in Directory.EnumerateFiles(path, "*.zen"))
			{
				let fileName = file.GetFileName(.. scope .());
				let relFilePath = Path.Combine(.. scope .(), relPath, fileName);

				parseFile(relFilePath, file.GetFilePath(.. scope .()));
			}
			for (let dir in Directory.EnumerateDirectories(path))
			{
				recurseFiles(dir.GetFilePath(.. scope .()));
			}
		}
		recurseFiles(inputSrcDir);

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

				// This is quite expensive(?)
				// There should be a smarter way of generating files.
				// It's quite stupid to delete the whole source tree and recreate it every time.
				{
					// Clear output dir first
					Directory.DelTree(outputSrcDir);

					Directory.CreateDirectory(outputSrcDirProgram);
				}

				File.WriteAllText(Path.Combine(.. scope .(), outputSrcDir, "Zen.h"), zenHeader);
				File.WriteAllText(Path.Combine(.. scope .(), outputSrcDir, "Program.c"), programFile);

				for (let file in g_files)
				{
					transpileEnvironment(file, resolvedEnv, outputSrcDirProgram);
				}
			}
			else
			{
				for (let error in resolver.Errors)
				{
					writeError(g_originalConsoleColor, error);
				}
			}
		}

		watch.Stop(); // Compiling
		let compileTime = watch.Elapsed.TotalSeconds;

		if (!g_hadErrors)
		{
			Console.WriteLine(scope $"{g_filesWritten} {(g_filesWritten > 1) ? "files" : "file" } written");

			Console.WriteLine(scope $"Zen parsing time:     {parseTime.ToString(.. scope .(),   "0.000000", CultureInfo.InvariantCulture)}s");
			Console.WriteLine(scope $"Zen compilation time: {compileTime.ToString(.. scope .(), "0.000000", CultureInfo.InvariantCulture)}s");
			Console.WriteLine(scope $"Total build time:     {(parseTime + compileTime).ToString(.. scope .(), "0.000000", CultureInfo.InvariantCulture)}s");
		}
		else
		{
			Console.ForegroundColor = .Red;
			Console.WriteLine(scope $"Errors: {g_errorCount}");
			Console.WriteLine("Compile failed.");
		}

		ErrorManager.Shutdown();

		return (g_hadErrors) ? 1 : 0;
	}

	private static void parseFile(String fileName, String inputFilePath)
	{
		String text = new .();
		if (File.ReadAllText(inputFilePath, text) case .Ok)
		{
			let newFile = new CompiledFile(new .(fileName));

			g_files.Add(newFile);
			g_filesWritten++;

			// Tokenize file
			let tokenizer = scope Tokenizer(text, g_files.Count - 1);
			let tokens = tokenizer.ScanTokens();

			newFile.SetLexed(new .(text, tokens));

			// Parse file
			let parser = scope Parser(tokens);
			if (parser.Parse() case .Ok(let statements))
			{
				g_statements.AddRange(statements);
				newFile.SetParsed(new .(statements));
			}
			else
			{
				for (let error in parser.Errors)
				{
					writeError(g_originalConsoleColor, error);
				}
			}
		}
	}

	private static void transpileEnvironment(CompiledFile file, ZenEnvironment env, String outputSrcDir)
	{
		var actualFileName = default(StringView);

		let fileNameSplit = scope String(file.Name).Split('/');
		for (let split in fileNameSplit)
		{
			if (!fileNameSplit.HasMore)
			{
				actualFileName = split;
			}
		}

		// let fileNameWOE = Path.GetFileNameWithoutExtension(file.Name, .. scope .());
		let fileNameWOE = scope String(file.Name)..RemoveFromEnd(4);

		let outputFileH = Path.Combine(.. scope .(), outputSrcDir, scope $"{fileNameWOE}.h");
		let outputFileC = Path.Combine(.. scope .(), outputSrcDir, scope $"{fileNameWOE}.c");

		let compiler = scope Transpiler(file.Parsed.Statements, env);
		let output = compiler.Compile(fileNameWOE);

		Directory.CreateDirectory(Path.GetDirectoryPath(outputFileC, .. scope .()));

		File.WriteAllText(outputFileH, output.0);
		File.WriteAllText(outputFileC, output.1);
	}

	private static void writeError(ConsoleColor originalConsoleColor, ICompilerError error)
	{
		ErrorManager.WriteError(g_files[error.Token.File], error);

		++g_errorCount;
		g_hadErrors = true;
	}
}