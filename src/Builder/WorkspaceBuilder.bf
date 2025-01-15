using System;
using System.Collections;
using System.Diagnostics;
using System.IO;

using Zen.Compiler;
using Zen.Lexer;
using Zen.Parser;
using Zen.Transpiler;

namespace Zen.Builder;

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

public class WorkspaceBuilder
{
	// -----------------------------------------------------------------------
	// Private variables
	// -----------------------------------------------------------------------

	private const ConsoleColor CONSOLE_CODE_COLOR = .Gray;

	private String m_workspaceDir ~ delete _;
	private String m_outCodeDir ~ delete _;
	private String m_outBuildDir ~ delete _;

	private List<CompiledFile> m_parsedFiles = new .() ~ DeleteContainerAndItems!(_);
	private List<Stmt> m_statements = new .() ~ delete _;

	private List<String> m_writtenFiles = new .() ~ DeleteContainerAndItems!(_);
	private int m_filesParsed = 0;

	private ErrorManager m_ErrorManager = new .(CONSOLE_CODE_COLOR) ~ delete _;
	private bool m_hadErrors = false;
	private int m_errorCount = 0;

	// -----------------------------------------------------------------------
	// Public variables
	// -----------------------------------------------------------------------

	public int FilesParsed => m_filesParsed;
	public int FilesWritten => m_writtenFiles.Count;

	public List<String> WrittenFiles => m_writtenFiles;

	public bool HadErrors => m_hadErrors;
	public int ErrorCount => m_errorCount;

	public Stopwatch StopwatchLexer { get; } = new .() ~ delete _;
	public Stopwatch StopwatchParser { get; } = new .() ~ delete _;
	public Stopwatch StopwatchCompiler { get; } = new .() ~ delete _;
	public Stopwatch StopwatchCodegen { get; } = new .() ~ delete _;

	// -----------------------------------------------------------------------
	// Public Functions
	// -----------------------------------------------------------------------

	public this(StringView workspaceDir, StringView outputCodeDir, StringView outBuildDir)
	{
		this.m_workspaceDir = new .(workspaceDir);
		this.m_outCodeDir = new .(outputCodeDir);
		this.m_outBuildDir = new .(outBuildDir);
	}

	public ~this()
	{
		// This is a corlib bug...
		Console.ResetColor();
		Console.ForegroundColor = Console.ForegroundColor;
	}

	/// Main compilation function for a Zen Workspace.
	public void Run()
	{
		// Lexing + Parsing
		let relPath = scope String();
		void recurseParseFiles(StringView path)
		{
			if (path != m_workspaceDir)
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
				recurseParseFiles(dir.GetFilePath(.. scope .()));
			}
		}
		recurseParseFiles(m_workspaceDir);

		if (m_hadErrors) return;

		// Compiling
		let resolver = scope Resolver();
		if (compileStep(resolver) case .Ok(let env))
		{
			let outputSrcDirProgram = Path.Combine(.. scope .(), m_outCodeDir, "Program");
			codegenStep(env, m_outCodeDir, outputSrcDirProgram);
		}
	}

	/// TinyC compiler
	public void TCC(StringView tccExePath)
	{
		Directory.CreateDirectory(m_outBuildDir);

		mixin getTCCArgs()
		{
			let tccArgs = scope::String();
			for (let file in m_writtenFiles)
			{
				tccArgs.Append(file);
				tccArgs.Append(" ");
			}
			tccArgs.Append("-g ");
			tccArgs.Append("-w ");
			tccArgs.Append("-luser32 ");
			tccArgs.Append(scope $"-o {m_outBuildDir}/Main.exe");

			tccArgs
		}

		let process = scope SpawnedProcess();
		let processInfo = scope ProcessStartInfo();

		processInfo.CreateNoWindow = false;
		processInfo.UseShellExecute = false;
		processInfo.RedirectStandardOutput = false;

		processInfo.SetFileName(tccExePath);
		processInfo.SetArguments(getTCCArgs!());

		if (process.Start(processInfo) case .Ok)
		{
			// Wait until tcc finishes
			while (!process.HasExited) {}

			if (process.ExitCode != 0)
			{
				m_hadErrors = true;
			}
		}
		else
		{
			Console.ForegroundColor = .Red;
			Console.WriteLine("TCC failed to start for some reason!");
			m_hadErrors = true;
		}
	}

	// -----------------------------------------------------------------------
	// Private Functions
	// -----------------------------------------------------------------------

	private void parseFile(String fileName, String inputFilePath)
	{
		String text = new .();
		if (File.ReadAllText(inputFilePath, text) case .Ok)
		{
			let newFile = new CompiledFile(new .(fileName));

			m_parsedFiles.Add(newFile);
			m_filesParsed++;

			// Tokenize file
			StopwatchLexer.Start();

			let tokenizer = scope Tokenizer(text, m_parsedFiles.Count - 1);
			let tokens = tokenizer.ScanTokens();

			StopwatchLexer.Stop();

			newFile.SetLexed(new .(text, tokens));

			// Parse file
			StopwatchParser.Start();

			let parser = scope Parser(tokens);
			if (parser.Parse() case .Ok(let statements))
			{
				m_statements.AddRange(statements);
				newFile.SetParsed(new .(statements));
			}
			else
			{
				for (let error in parser.Errors)
				{
					writeError(error);
				}
			}

			StopwatchParser.Stop();
		}
	}
	
	private Result<ZenEnvironment> compileStep(Resolver resolver)
	{
		StopwatchCompiler.Start();

		if (resolver.Resolve(m_statements) case .Ok(let resolvedEnv))
		{
			StopwatchCompiler.Stop();
			return .Ok(resolvedEnv);
		}
		else
		{
			StopwatchCompiler.Stop();
			for (let error in resolver.Errors)
			{
				writeError(error);
			}

			return .Err;
		}
	}

	private void codegenStep(ZenEnvironment resolvedEnv, StringView outputSrcDir, StringView outputSrcDirProgram)
	{
		StopwatchCodegen.Start();
		defer StopwatchCodegen.Stop();

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

		for (let file in m_parsedFiles)
		{
			transpileEnvironment(file, resolvedEnv, outputSrcDirProgram);
		}
	}

	private void transpileEnvironment(CompiledFile file, ZenEnvironment env, StringView outputCodeDir)
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
		let fileNameWOE = scope String(actualFileName)..RemoveFromEnd(4);
		let fullFileNameWOE = scope String(file.Name)..RemoveFromEnd(4);

		let outputFileH = Path.Combine(.. scope .(), outputCodeDir, scope $"{fullFileNameWOE}.h");
		let outputFileC = Path.Combine(.. scope .(), outputCodeDir, scope $"{fullFileNameWOE}.c");

		let compiler = scope Transpiler(file.Parsed.Statements, env);
		let output = compiler.Compile(fileNameWOE, fullFileNameWOE);

		Directory.CreateDirectory(Path.GetDirectoryPath(outputFileC, .. scope .()));

		File.WriteAllText(outputFileH, output.0);
		File.WriteAllText(outputFileC, output.1);

		m_writtenFiles.Add(new .(outputFileC..Replace('\\', '/')));
	}

	private void writeError(ICompilerError error)
	{
		m_ErrorManager.WriteError(m_parsedFiles[error.Token.File], error);

		++m_errorCount;
		m_hadErrors = true;
	}
}
