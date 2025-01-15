using System;
using System.IO;

using libtcc.Bindings;

namespace libtcc;

public class TCCCompiler
{
	private TCCState* m_state = null;
	// public delegate String Compile

	public this(StringView tccSDKDir)
	{
		m_state = tcc_new();

		SetOutputType(.Memory);

		let DIR_PATH = tccSDKDir;
		let DEFAULT_LIB_PATH = Path.Combine(.. scope .(), tccSDKDir, "lib");
		let DEFAULT_INCLUDE_PATH = Path.Combine(.. scope .(), tccSDKDir, "include");
		let DEFAULT_TCC_INCLUDE_PATH = Path.Combine(.. scope .(), tccSDKDir, "libtcc");

#if BF_PLATFORM_WINDOWS
		let DEFAULT_INCLUDE_WINDOWS = Path.Combine(.. scope .(), DIR_PATH, "libtcc/winapi");
#endif

		tcc_add_include_path(m_state, DEFAULT_INCLUDE_PATH);
		tcc_add_include_path(m_state, DEFAULT_TCC_INCLUDE_PATH);
#if BF_PLATFORM_WINDOWS
		tcc_add_include_path(m_state, DEFAULT_INCLUDE_WINDOWS);
#endif
		tcc_add_library_path(m_state, DEFAULT_LIB_PATH);
	}

	public ~this()
	{
		tcc_delete(m_state);
	}

	/// Returns whether you are using the 64 bit version.
	public bool IsX64
	{
		get => sizeof(int) == 8;
	}

	/// Set the library path.
	public void SetLibPath(StringView path)
	{
		tcc_set_lib_path(m_state, path.Ptr);
	}

	public libtcc_int CompileFileTo(StringView fileName, TccOutputType outputType, StringView destinationFile)
	{
		String text = null;
		if (File.ReadAllText(fileName, text) case .Err)
			return -1;

		return CompileSourceTo(text, outputType, destinationFile);
	}

	public libtcc_int CompileSourceTo(String source, TccOutputType outputType, StringView destinationFile)
	{
		SetOutputType(outputType);
		let compileResult = CompileString(source);
		if (compileResult == -1)
		{
			return -1;
		}

		return CreateOutputFile(destinationFile);
	}

	public libtcc_int Run(StringView sourceFile, params String[] args)
	{
		SetOutputType(.Memory);
		let source = File.ReadAllText(sourceFile, .. scope .());

		let compileResult = CompileString(source);
		if (compileResult == -1)
		{
			return -1;
		}

		return this.Run(args);
	}

	/// Set options as from command line (multiple supported).
	public void SetOptions(StringView option)
	{
		tcc_set_options(m_state, option.Ptr);
	}

	/// Add include path.
	public libtcc_int AddIncludePath(StringView path)
	{
		return tcc_add_include_path(m_state, path.Ptr);
	}

	/// Add system include path.
	public libtcc_int AddSystemIncludePath(StringView path)
	{
		return tcc_add_sysinclude_path(m_state, path.Ptr);
	}

	/// Define preprocess symbol 'sym'. Can put optional 'value'.
	public void DefineSymbol(StringView sym, StringView value)
	{
		tcc_define_symbol(m_state, sym.Ptr, value.Ptr);
	}

	/// Undefine preprocess symbol 'sym'.
	public void UndefineSymbol(StringView sym)
	{
		tcc_undefine_symbol(m_state, sym.Ptr);
	}

	/// Add a file (C file, dll, object, library, ld script).
	public libtcc_int AddFile(StringView fileName)
	{
		return tcc_add_file(m_state, fileName.Ptr);
	}

	/// Compiles a string containing a C source.
	public libtcc_int CompileString(String buffer)
	{
		return tcc_compile_string(m_state, buffer);
	}

	/// Set output type. MUST BE CALLED before any compilation.
	public libtcc_int SetOutputType(TccOutputType type)
	{
		return tcc_set_output_type(m_state, (libtcc_int)type);
	}

	/// Equivalent to -Lpath option of TCC.
	public libtcc_int AddLibraryPath(StringView path)
	{
		return tcc_add_library_path(m_state, path.Ptr);
	}

	public libtcc_int AddSymbol(StringView name, void* value)
	{
		return tcc_add_symbol(m_state, name.Ptr, value);
	}

	public libtcc_int AddSymbol(StringView name, Delegate del)
	{
		return AddSymbol(name, del.GetFuncPtr());
	}

	/// Output an executable, library, or object file.
	/// DO NOT call Deallocate() before.
	public libtcc_int CreateOutputFile(StringView fileName)
	{
		return tcc_output_file(m_state, fileName.Ptr);
	}

	/// Link and run main() function and return its value.
	/// DO NOT call Deallocate() before.
	public libtcc_int Run(String[] args)
	{
		int argc = args.Count;
		let nativeArgs = scope char8*[argc];
		for (let i < argc)
		{
			nativeArgs[i] = args[i].Ptr;
		}
		return tcc_run(m_state, (libtcc_int)argc, nativeArgs.Ptr);
	}

	/// Do all reallocations (needed before using GetSymbol())
	public libtcc_int Reallocate(void* ptr)
	{
		return tcc_relocate(m_state, ptr);
	}

	/// Return symbol pointer or null if not found.
	public void* GetSymbol(StringView name)
	{
		return tcc_get_symbol(m_state, name.Ptr);
	}
}