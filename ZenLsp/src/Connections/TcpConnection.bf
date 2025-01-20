using System;
using System.Net;
using System.Threading;

using ZenLsp.Logging;

namespace ZenLsp.Connections;

public class TcpConnection : IConnection
{
	private LspServer m_server;
	private int32 m_port;

	private Thread m_thread ~ delete _;
	private bool m_open;

	private Socket m_listener ~ delete _;
	private Socket m_client ~ delete _;

	private WaitEvent m_waitEvent ~ delete _;
	private Monitor m_bufferMonitor ~ delete _;
	private RecvBuffer m_buffer ~ delete _;

	public this(LspServer server, int32 port)
	{
		this.m_server = server;
		this.m_port = port;

		this.m_waitEvent = new .();
		this.m_bufferMonitor = new .();
		this.m_buffer = new .();
	}

	public bool IsOpen => m_open;

	public Result<void> Start()
	{
		// Create sockets
		Socket.Init();

		m_listener = new .();
		m_listener.Blocking = true;

		m_client = new .();
		m_client.Blocking = false;

		// Connection
		if (m_listener.Listen(m_port) case .Err)
		{
			Log.Error("Error on listen.");
			return .Err;
		}
		if (m_client.AcceptFrom(m_listener) case .Err)
		{
			Log.Error("Error on accept.");
			return .Err;
		}

		// Start thread
		m_thread = new .(new => run);

		m_open = true;
		m_thread.Start(false);

		return .Ok;
	}

	public void Stop()
	{
		m_open = false;
		m_waitEvent.Set(true);
		
		m_thread.Join();

		m_listener.Close();
		m_client.Close();
	}

	public Result<RecvBuffer> WaitForData()
	{
		// Log.Info("Waittt");
		m_waitEvent.WaitFor(10);
		if (!m_open) return .Err;

		m_bufferMonitor.Enter();
		return m_buffer;
	}

	public void ReleaseBuffer()
	{
		m_bufferMonitor.Exit();
	}

	public Result<void> Send(void* data, int size)
	{
		if (m_client.Send(data, size) == .Err) return .Err;
		return .Ok;
	}

	private void run()
	{
		uint8* data = new:ScopedAlloc! .[4096]*;

		while (m_open)
		{
			Socket.FDSet readSet = .();
			readSet.Add(m_client.NativeSocket);

			int32 count = Socket.Select(&readSet, null, null, 1000);
			if (count <= 0) continue;

			switch (m_client.Recv(data, 4096))
			{
			case .Ok(let received):
				if (received <= 0) continue;

				m_bufferMonitor.Enter();
				m_buffer.Add(data, received);
				m_bufferMonitor.Exit();

				m_waitEvent.Set();

			case .Err:
				m_open = false;
				m_waitEvent.Set(true);
			}
		}
	}
}