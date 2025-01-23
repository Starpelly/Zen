using System;
using System.Collections;
using System.Diagnostics;
using System.Globalization;
using System.IO;

using Beefy.utils;

namespace Zen;

// IDE - Zen garden
// No royalties to Mudstep

class Program
{
	private const String g_testTCCExePath = $"tcc/tcc.exe";

	private class CLIArguments
	{
		public String InputSrcDir = new .() ~ delete _;
		public String OutputSrcDir = new .() ~ delete _;
		public String OutputBuildDir = new .() ~ delete _;
		public bool BuildWithTCC = false;
		public bool RunAfterBuild = false;
		public bool PrintAST = false;
	}

	public static mixin ToStringViewList(StringSplitEnumerator e, List<StringView> into)
	{
		for (let string in e)
		{
			into.Add(string);
		}
	}

	private class Project
	{
		public String SourceDir = new .() ~ delete _;
		public String ProjectName = new .() ~ delete _;
		public String StartupFunc = new .() ~ delete _;

		public void Load(StringView zenProjToml)
		{
			let sd = scope StructuredData();
			if (sd.LoadFromString(zenProjToml) case .Ok)
			{
				using (sd.Open("Project"))
				{
					let sourceDir = scope String();
					sd.GetString("Source", sourceDir);

					let projName = scope String();
					sd.GetString("Name", projName);

					let startupFunc = scope String();
					sd.GetString("StartupFunction", startupFunc);

					this.SourceDir.Set(sourceDir);
					this.ProjectName.Set(projName);
					this.StartupFunc.Set(startupFunc);
				}
			}
		}
	}

	public static int Main(String[] args)
	{
		var cliArgs = scope CLIArguments();
		for (let arg in args)
		{
			if (arg.StartsWith("-workspace"))
			{
				let projectFile = @"D:\Zen\test\ZenProj.toml";
				let projectTOML = scope String();

				if (File.ReadAllText(projectFile, projectTOML) case .Ok)
				{
					let project = scope Project();
					project.Load(projectTOML);

					let argSplit = scope List<StringView>();
					ToStringViewList!(arg.Split('='), argSplit);

					let projectDir = argSplit[1];
					cliArgs.InputSrcDir.Set(scope $"{projectDir}/{project.SourceDir}");
					cliArgs.OutputSrcDir.Set(scope $"{projectDir}/build/codegen");
					cliArgs.OutputBuildDir.Set(scope $"{projectDir}/build/bin");
				}
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
			case "-ast":
				cliArgs.PrintAST = true;
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
		}
		else
		{
			Console.ForegroundColor = .Red;
			Console.WriteLine(scope $"Errors: {builder.ErrorCount}");
			Console.WriteLine("Compile failed.");
		}

		if (cliArgs.BuildWithTCC && !builder.HadErrors)
		{
#if DEBUG
			builder.TCC("D:/Zen/vendor/libtcc/vendor/tcc/tcc.exe");
#else
			builder.TCC(g_testTCCExePath);
#endif
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
			process.Start(processInfo);
		}

		if (cliArgs.PrintAST)
		{
			Console.WriteLine("AST:");
			builder.PrintAST();
		}

		return (builder.HadErrors) ? 1 : 0;
	}
}