using libtcc.Bindings;

namespace libtcc;

public enum TccOutputType : int
{
	Memory = TccOutPutTypeConst.TCC_OUTPUT_MEMORY,
	Exe = TccOutPutTypeConst.TCC_OUTPUT_EXE,
	Dll = TccOutPutTypeConst.TCC_OUTPUT_DLL,
	Obj = TccOutPutTypeConst.TCC_OUTPUT_OBJ,
	Process = TccOutPutTypeConst.TCC_OUTPUT_PREPROCESS
}