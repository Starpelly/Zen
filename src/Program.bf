using System;
using System.Collections;
using System.Diagnostics;
using System.Globalization;

namespace Zen;

// IDE - Zen garden
// No royalties to Mudstep

class Program
{
	private const String g_testTCCExePath = $"tcc/tcc.exe";

	private class CLIArguments
	{
		public String InputSrcDir = null ~ delete _;
		public String OutputSrcDir = null ~ delete _;
		public String OutputBuildDir = null ~ delete _;
		public bool BuildWithTCC;
		public bool RunAfterBuild;
	}

	public static mixin ToStringViewList(StringSplitEnumerator e, List<StringView> into)
	{
		for (let string in e)
		{
			into.Add(string);
		}
	}

	public static int Main(String[] args)
	{
		var cliArgs = scope CLIArguments();
		for (let arg in args)
		{
			if (arg.StartsWith("-workspace"))
			{
				let argSplit = scope List<StringView>();
				ToStringViewList!(arg.Split('='), argSplit);
				cliArgs.InputSrcDir = new $"{argSplit[1]}/src";
				cliArgs.OutputSrcDir = new $"{argSplit[1]}/build/codegen";
				cliArgs.OutputBuildDir = new $"{argSplit[1]}/build/bin";
				continue;
			}
			switch (arg)
			{
			case "-tcc":
				cliArgs.BuildWithTCC = true;
				break;
			case "-run":
				cliArgs.RunAfterBuild = true;
				break;
			}
		}

		Console.WriteLine("Compiling...");

		let builder = scope Zen.Builder.WorkspaceBuilder(cliArgs.InputSrcDir, cliArgs.OutputSrcDir, cliArgs.OutputBuildDir);
		builder.Run();

		if (!builder.HadErrors)
		{
			void writeTimeOutput(StringView title, double seconds)
			{
				let secondsFormat = "0.00000";

				Console.ForegroundColor = .White;

				Console.Write(title);

				Console.ForegroundColor = .DarkGray;

				Console.Write(scope $" {seconds.ToString(.. scope .(), secondsFormat, CultureInfo.InvariantCulture)}s \n");
			}

			Console.ForegroundColor = .DarkGray;
			Console.WriteLine(scope $"{builder.FilesWritten} {(builder.FilesWritten > 1) ? "files" : "file" } written");

			let lexerTime = builder.StopwatchLexer.Elapsed.TotalSeconds;
			let parserTime = builder.StopwatchParser.Elapsed.TotalSeconds;
			let compilerTime = builder.StopwatchCompiler.Elapsed.TotalSeconds;
			let codegenTime = builder.StopwatchCodegen.Elapsed.TotalSeconds;

			/*
			writeTimeOutput("Lexing    time:", lexerTime);
			writeTimeOutput("Parsing   time:", parserTime);
			writeTimeOutput("Compiling time:", compilerTime);
			writeTimeOutput("Codegen   time:", codegenTime);
			writeTimeOutput("Total     time:", lexerTime + parserTime + compilerTime + codegenTime);
			*/

			writeTimeOutput("Compiler time:", lexerTime + parserTime + compilerTime);
			writeTimeOutput("Codegen  time:", codegenTime);
			writeTimeOutput("Total    time:", lexerTime + parserTime + compilerTime + codegenTime);

			Console.ResetColor();
			Console.ForegroundColor = Console.ForegroundColor;
		}
		else
		{
			Console.ForegroundColor = .Red;
			Console.WriteLine(scope $"Errors: {builder.ErrorCount}");
			Console.WriteLine("Compile failed.");
		}

		if (cliArgs.BuildWithTCC && !builder.HadErrors)
		{
			builder.TCC(g_testTCCExePath);
		}
		if (cliArgs.RunAfterBuild && !builder.HadErrors)
		{
			let process = scope SpawnedProcess();
			let processInfo = scope ProcessStartInfo();

			processInfo.UseShellExecute = false;
			processInfo.SetFileName(cliArgs.OutputBuildDir..Append("/Main.exe"));

			Console.ForegroundColor = .DarkGray;
			Console.WriteLine("============================");
			Console.ResetColor();
			Console.ForegroundColor = Console.ForegroundColor;
			process.Start(processInfo);
		}

		return (builder.HadErrors) ? 1 : 0;
	}
}