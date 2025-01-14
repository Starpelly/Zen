using System;
using System.Diagnostics;
using System.Globalization;

namespace Zen;

// IDE - Zen garden
// No royalties to Mudstep

class Program
{
	private const String g_testDir = "D:/Zen/test";
	private const String g_testInputDir = $"{g_testDir}/src";
	private const String g_testOutputCodeDir = $"{g_testDir}/build/codegen";
	private const String g_testOutputBuildDir = $"{g_testDir}/build/bin";
	private const String g_testTCCExePath = $"{g_testDir}/tcc/tcc.exe";

	public static int Main(String[] args)
	{
		// Arguments
		let inputSrcDir 	= (args.Count > 0) ? args[0] : g_testInputDir;
		let outputCodeDir 	= (args.Count > 1) ? args[1] : g_testOutputCodeDir;
		let outputBuildDir 	= (args.Count > 2) ? args[2] : g_testOutputBuildDir;
		let buildWTCC 		= (args.Count > 3) ? args[3] == "-tcc" : false;
		let runAfterTCC		= (args.Count > 4) ? args[4] == "-r"   : false;

		Console.WriteLine("Compiling...");

		let builder = scope Zen.Builder.WorkspaceBuilder(inputSrcDir, outputCodeDir, outputBuildDir);
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
			// Console.WriteLine(scope $"{builder.FilesWritten} {(builder.FilesWritten > 1) ? "files" : "file" } written");

			let lexerTime = builder.StopwatchLexer.Elapsed.TotalSeconds;
			let parserTime = builder.StopwatchParser.Elapsed.TotalSeconds;
			let compilerTime = builder.StopwatchCompiler.Elapsed.TotalSeconds;
			let codegenTime = builder.StopwatchCodegen.Elapsed.TotalSeconds;

			/*
			writeTimeOutput("Lexer    time:", lexerTime);
			writeTimeOutput("Parsing  time:", parserTime);
			writeTimeOutput("Compiler time:", compilerTime);
			writeTimeOutput("Codegen  time:", codegenTime);
			writeTimeOutput("Total    time:", lexerTime + parserTime + compilerTime + codegenTime);
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

		if (buildWTCC && !builder.HadErrors)
		{
			builder.TCC(g_testTCCExePath);
		}
		if (runAfterTCC && !builder.HadErrors)
		{
			let process = scope SpawnedProcess();
			let processInfo = scope ProcessStartInfo();

			processInfo.UseShellExecute = false;
			processInfo.SetFileName(outputBuildDir..Append("/Main.exe"));

			Console.ForegroundColor = .DarkGray;
			Console.WriteLine("============================");
			Console.ResetColor();
			Console.ForegroundColor = Console.ForegroundColor;
			process.Start(processInfo);
		}

		return (builder.HadErrors) ? 1 : 0;
	}
}