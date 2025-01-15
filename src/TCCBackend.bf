using System;
using System.IO;

using libtcc;

namespace Zen;

public class TCCBackend
{
	public static int RunTest()
	{
		// C code to be compiled.
		let code = """
			int add(int a, int b)
			{
				return a + b;
			}
			int mul(int a, int b)
			{
				return a * b;
			}
			const char *message = "Hello from dynamically compiled code!";
			""";

		let compiler = scope TCCCompiler(Path.Combine(.. scope .(), Path.GetDirectoryPath(Environment.GetExecutableFilePath(.. scope .()), .. scope .()), "tcc"));

		let comp = compiler.CompileString(code);
		let real = compiler.Reallocate(libtcc.Bindings.TccRealocateConst.TCC_RELOCATE_AUTO);

		let addSymbol = compiler.GetSymbol("add");
		let mulSymbol = compiler.GetSymbol("mul");
		let messageSymbol = compiler.GetSymbol("message");

		function int(int a, int b) add_func = (.)addSymbol;
		function int(int a, int b) mul_func = (.)mulSymbol;
		char8* msg_func = *(char8**)messageSymbol;

		Console.WriteLine(add_func(4, 2));
		Console.WriteLine(mul_func(4, 2));
		Console.WriteLine(scope String(msg_func));

		return 0;
	}
}