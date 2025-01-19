using System;

using ZenLsp.Connections;
using ZenLsp.Logging;

namespace ZenLsp;

public abstract class LspServer
{
	private IConnection m_connection ~ delete _;

	private int contentsSize = 0;
	private int requestId = 0;

	public void StartStdio()
	{
		Log.Info("Starting server on stdio");

		m_connection = new StdioConnection(this);
		start();
	}

	public void StartTcp(int port)
	{
		Log.AddLogger(new ConsoleLogger());
		Log.Info("Starting server on port {}", port);

		m_connection = new TcpConnection(this, port);
		start();
	}

	public void Stop()
	{
		m_connection.Stop();
	}

	public bool IsOpen => m_connection != null && m_connection.IsOpen;

	protected abstract void OnMessage(Json json);

	public void Send(Json json)
	{
		String jsonStr = new .();
		defer delete jsonStr; // For some reason using ScopedAlloc! here was causing memory leaks
		JsonWriter.Write(json, jsonStr);

		String header = scope $"Content-Length: {jsonStr.Length}\r\n\r\n";

		int size = jsonStr.Length + header.Length;
		uint8* data = new:ScopedAlloc! .[size]*;

		Internal.MemCpy(data, header.Ptr, header.Length);
		Internal.MemCpy(&data[header.Length], jsonStr.Ptr, jsonStr.Length);

		m_connection.Send(data, size).IgnoreError();
	}

	public void Send(StringView method, Json json, bool request = false)
	{
		Json notification = .Object();

		notification["jsonrpc"] = .String("2.0");
		notification["method"] = .String(method);
		notification["params"] = json;

		if (request) notification["id"] = .Number(requestId++);

		Send(notification);
		notification.Dispose();
	}

	private void start()
	{
		Log.AddLogger(new LspLogger(this));

		// Connect
		Log.Info("Waiting for a client to connect to...");

		if (m_connection.Start() == .Err)
		{
			Log.Error("Failed to start connection with the client");
			return;
		}

		Log.Info("Connected");

		run();
	}

	private void run()
	{
		while (m_connection.IsOpen)
		{
			if (m_connection.WaitForData() case .Ok(let buffer))
			{
				processBuffer(buffer);
				m_connection.ReleaseBuffer();
			}
		}
	}

	private void processBuffer(RecvBuffer buffer)
	{
		if (!m_connection.IsOpen) return;

		if (contentsSize == 0)
		{
			// Parse header      TODO: needs better detection
			if (buffer.HasEnough(50))
			{
				StringView header = .((char8*) buffer.buffer, 50);
				int i = header.IndexOf("\r\n\r\n");

				if (i == -1)
				{
					Log.Error("Failed to find \r\n\r\n ending sequence in header, something went wrong. Closing connection");
					Stop();
					return;
				}

				header = header[...(i - 1)];

				for (let field in header.Split("\r\n"))
				{
					if (field.StartsWith("Content-Length: "))
					{
						contentsSize = int.Parse(field[16...]);
						break;
					}
				}

				buffer.Skip(i + 4);
				header = .((char8*) buffer.buffer, 50);

				processBuffer(buffer);
			}
		}
		else
		{
			// Parse contents
			if (buffer.HasEnough(contentsSize))
			{
				StringView msg = .((char8*) buffer.buffer, contentsSize);

				Json json = JsonParser.ParseString(msg);
				OnMessage(json);
				json.Dispose();

				buffer.Skip(contentsSize);
				contentsSize = 0;
				
				processBuffer(buffer);
			}
		}
	}
}