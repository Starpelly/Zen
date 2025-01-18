using System;

namespace ZenLsp;

public class Program
{
	public static void Main(String[] args)
	{
		for (let arg in args)
		{

		}

		scope ZenLspServer().Start(args);
	}
}