using System;
using System.IO;

using libtcc;
using libtcc.Bindings;

namespace libtcc.Tests;

static
{
#if TEST
	static let C_CODE_TO_COMPILE = """
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

	[Test]
	static void BasicBindings()
	{
		let projectDir = Directory.GetCurrentDirectory(.. scope .());

		let dirPath = Path.Combine(.. scope .(), projectDir, "/vendor/tcc");

		let defaultLibPath = Path.Combine(..scope .(), dirPath, "lib");
		let defaultIncludePath = Path.Combine(..scope .(), dirPath, "include");
		let defaultTccInludePath = Path.Combine(..scope .(), dirPath, "libtcc");
		let defaultIncludeWindows = Path.Combine(..scope .(), dirPath, "libtcc/winapi");

		// Create TCC state.
		let tcc = tcc_new();
		// defer tcc_delete(tcc);

		Test.Assert(tcc != null);

		// Set TCC output type to memory.
		tcc_set_output_type(tcc, 1);

		tcc_add_include_path(tcc, defaultIncludePath);
		tcc_add_include_path(tcc, defaultTccInludePath);
		tcc_add_include_path(tcc, defaultIncludeWindows);
		tcc_add_library_path(tcc, defaultLibPath);

		// Compile the code.
		Test.Assert(tcc_compile_string(tcc, C_CODE_TO_COMPILE) == 0);

		// Relocate the code to make it executable.
		Test.Assert(tcc_relocate(tcc, TccRealocateConst.TCC_RELOCATE_AUTO) == 0);

		// Get a pointer to the compiled function.
		let addSymbol = tcc_get_symbol(tcc, "add");
		let mulSymbol = tcc_get_symbol(tcc, "mul");
		let messageSymbol = tcc_get_symbol(tcc, "message");

		Test.Assert(addSymbol != null);
		Test.Assert(mulSymbol != null);

		function int(int a, int b) add_func = (.)addSymbol;
		function int(int a, int b) mul_func = (.)mulSymbol;
		char8* msg_func = *(char8**)messageSymbol;

		Test.Assert(add_func(4, 2) == 6);
		Test.Assert(mul_func(4, 2) == 8);
		Test.Assert(scope String(msg_func) == "Hello from dynamically compiled code!");
	}
	[Test]
	static void BasicInterface()
	{
		let projectDir = Directory.GetCurrentDirectory(.. scope .());
		let dirPath = Path.Combine(.. scope .(), projectDir, "/vendor/tcc");

		let compiler = scope TCCCompiler(dirPath);

		// Compile the code.
		Test.Assert(compiler.CompileString(C_CODE_TO_COMPILE) == 0);

		// Relocate the code to make it executable.
		Test.Assert(compiler.Reallocate(TccRealocateConst.TCC_RELOCATE_AUTO) == 0);

		// Get a pointer to the compiled function.
		let addSymbol = compiler.GetSymbol("add");
		let mulSymbol = compiler.GetSymbol("mul");
		let messageSymbol = compiler.GetSymbol("message");

		Test.Assert(addSymbol != null);
		Test.Assert(mulSymbol != null);

		function int(int a, int b) add_func = (.)addSymbol;
		function int(int a, int b) mul_func = (.)mulSymbol;
		char8* msg_func = *(char8**)messageSymbol;

		Test.Assert(add_func(4, 2) == 6);
		Test.Assert(mul_func(4, 2) == 8);
		Test.Assert(scope String(msg_func) == "Hello from dynamically compiled code!");
	}
#endif
}