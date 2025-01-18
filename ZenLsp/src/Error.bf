using System;
using System.IO;
using System.Collections;

namespace ZenLsp;

public class Error
{
	public int code;
	public String message;

	[AllowAppend]
	public this(int code, StringView messageFormat, params Object[] args)
	{
		String _message = append .(messageFormat.Length);

		this.code = code;
		this.message = _message..AppendF(messageFormat, params args);
	}

	public Json GetJson()
	{
		Json json = .Object();

		json["code"] = .Number(code);
		json["message"] = .String(message);

		return json;
	}
}

public static class Utils
{
	public static mixin GetPath(Json json)
	{
		GetPath(json, scope:mixin .())
	}

	public static Result<String, Error> GetPath(Json json, String buffer)
	{
		return GetPath(json["textDocument"]["uri"].AsString, buffer);
	}

	public static Result<String, Error> GetPath(StringView uri, String buffer)
	{
#if !BF_PLATFORM_WINDOWS
		StringView prefix = "file://";
#else
		StringView prefix = "file:///";
#endif

		if (!uri.StartsWith(prefix))
		{
			return .Err(new .(0, "Invalid URI, only file:/// URIs are supported: {}", uri));
		}
		
		buffer.Set(uri[prefix.Length...]);
		buffer.Replace("%3A", ":");
		buffer.Replace("%20", " ");

		return buffer;
	}

	public static mixin GetUri(StringView path)
	{
		GetUri(path, scope:mixin .())
	}
	
	public static Result<String, Error> GetUri(StringView path, String buffer)
	{
		if (!Path.IsPathRooted(path))
		{
			return .Err(new .(1, "Invalid path, only rooted paths are supported: {}", path));
		}

#if !BF_PLATFORM_WINDOWS
		buffer.AppendF($"file://{path}");
#else
		buffer.AppendF($"file:///{path}");
#endif

		return buffer;
	}

	public static void CleanDocumentation(StringView docs, String buffer)
	{
		int i = 0;

		for (var line in docs.Split('\x03', .RemoveEmptyEntries))
		{
			line.Trim();
			if (line.StartsWith("///") || line.StartsWith("/**")) line.Adjust(3);
			else if (line.StartsWith("*/")) line.Adjust(2);
			else if (line.StartsWith('*')) line.Adjust(1);
			line.Trim();

			if (!line.IsEmpty)
			{
				if (i > 0) buffer.Append('\n');

				buffer.Append(line);
				i++;
			}
		}
	}

	public static LineEnumerator Lines(StringView string)
	{
		return .(string.Split('\n', .RemoveEmptyEntries));
	}

	public struct LineEnumerator : IEnumerator<StringView>
	{
		private StringSplitEnumerator enumerator;

		public this(StringSplitEnumerator enumerator)
		{
			this.enumerator = enumerator;
		}

		public bool HasMore => enumerator.HasMore;

		public Result<StringView> GetNext() mut
		{
			switch (enumerator.GetNext())
			{
				case .Ok(let val): return val.EndsWith('\r') ? val[...^2] : val;
				case .Err:         return .Err;
			}
		}
	}
}