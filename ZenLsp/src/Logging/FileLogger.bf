using System;
using System.IO;

namespace ZenLsp.Logging;

public class FileLogger : ILogger
{
	private FileStream fs ~ delete _;
	private StreamWriter writer ~ delete _;

	public this()
	{
		fs = new .();
		fs.Create(scope $"zenlsp_{DateTime.Now.ToString(.. scope .())..Replace('/', '-')..Replace(':', '-')}.log", .Write, .Read);
		
		writer = new StreamWriter(fs, .ASCII, 4096, true);
	}

	public void Log(Message message)
	{
		writer.WriteLine(message.text);
	}
}