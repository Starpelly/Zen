using System;

namespace ZenLsp.Logging;

public class ConsoleLogger : ILogger
{
	public void Log(Message message)
	{
		Console.ForegroundColor = message.level.Color;
		Console.WriteLine(message.text);
	}
}