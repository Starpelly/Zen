using System;

namespace libtcc.Bindings;

[CRepr]
public struct TCCState {}

typealias libtcc_int = int;

public static class TccOutPutTypeConst
{
	// I don't know why, but for some reason, '1' doesn't work correctly on Win64????
#if TEST
	public const libtcc_int TCC_OUTPUT_MEMORY 		= 1; // output will be run in memory (default)
	public const libtcc_int TCC_OUTPUT_EXE 			= 2; // executable file
	public const libtcc_int TCC_OUTPUT_DLL 			= 3; // dynamic library
	public const libtcc_int TCC_OUTPUT_OBJ 			= 4; // object file
	public const libtcc_int TCC_OUTPUT_PREPROCESS 	= 5; // only preprocess (used internally)
#else
	public const libtcc_int TCC_OUTPUT_MEMORY 		= 0; // output will be run in memory (default)
	public const libtcc_int TCC_OUTPUT_EXE 			= 1; // executable file
	public const libtcc_int TCC_OUTPUT_DLL 			= 2; // dynamic library
	public const libtcc_int TCC_OUTPUT_OBJ 			= 3; // object file
	public const libtcc_int TCC_OUTPUT_PREPROCESS 	= 4; // only preprocess (used internally)
#endif
}

public static class TccRealocateConst
{
	public static void* TCC_RELOCATE_AUTO = (void*)1;
	public static void* TCC_RELOCATE_NULL = (void*)null;
}

static
{
	public const String DLL = "libtcc.dll";

	/// Creates a new TCC compilation context.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern TCCState* tcc_new();

	/// Free a TCC compilation context.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_delete(TCCState* state);

	/// Set CONFIG_TCCDIR at runtime.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_set_lib_path(TCCState* state, char8* path);

	function void errorCallback(void* opaque, char8* msg);

	/// Set error/warning display callback.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_set_error_func(TCCState* state, void* error_opaque, errorCallback error_func);

	/// Set options as from command line (multiple supported).
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_set_options(TCCState* state, char8* str);

	// ----------------------------------------------------
	// Preprocessor
	// ----------------------------------------------------

	/// Add include path.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_include_path(TCCState* state, char8* pathname);

	/// Add in system include path.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_sysinclude_path(TCCState* state, char8* pathname);

	/// Define preprocessor symbol 'sym'. Can put optional value
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_define_symbol(TCCState* state, char8* sym, char8* value);

	/// Undefine preprocess symbol 'sym'.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void tcc_undefine_symbol(TCCState* state, char8* sym);

	// ----------------------------------------------------
	// Compiling
	// ----------------------------------------------------

	/// Add a file (C file, dll, object, library, ld script). Returns -1 if error.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_file(TCCState* state, char8* filename);

	/// Compile a string containing a C source. Returns -1 if error.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_compile_string(TCCState* state, char8* buf);

	// ----------------------------------------------------
	// Linking
	// ----------------------------------------------------

	/// Set output type. MUST BE CALLED before any compilation.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_set_output_type(TCCState* state, libtcc_int output_type);

	/// equivalent to -Lpath option.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_library_path(TCCState* state, char8* pathname);

	/// The library name is the same as the argument of the '-l' option.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_library(TCCState* state, char8* libraryname);

	/// Adds a symbol to the compiled program.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_add_symbol(TCCState* state, char8* name, void* val);

	/// Output an executable, library, or object file. DO NOT call
	/// tcc_relocate() before.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_output_file(TCCState* state, char8* filename);

	/// Link and run main() function and return its value. DO NOT call
	/// tcc_relocate() before.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_run(TCCState* state, libtcc_int argc, char8** argv);

	/// Do all relocations (needed before using tcc_get_symbol()
	/// Returns -1 if error.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern libtcc_int tcc_relocate(TCCState* state, void* ptr);

	/// Returns symbol value or NULL if not found.
	[CLink, CallingConvention(.Stdcall), Import(DLL)]
	public static extern void* tcc_get_symbol(TCCState* state, char8* name);
}