using System;
using System.IO;
using System.Threading;

namespace ZenLsp.Connections;

public class StdioConnection : IConnection
{
	private LspServer m_server;

	private Thread m_thread ~ delete _;
	private bool m_open;

	private WaitEvent m_waitEvent ~ delete _;
	private Monitor m_bufferMonitor ~ delete _;
	private RecvBuffer m_buffer ~ delete _;

	public this(LspServer server)
	{
		this.m_server = server;

		this.m_waitEvent = new .();
		this.m_bufferMonitor = new .();
		this.m_buffer = new .();
	}

	public bool IsOpen => m_open;

	public Result<void> Start()
	{
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
	}

	public Result<RecvBuffer> WaitForData()
	{
		m_waitEvent.WaitFor();
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
		if (Console.Out.Write(Span<uint8>((.) data, size)) == .Err) return .Err;
		return .Ok;
	}

	private void run()
	{
		uint8* data = new:ScopedAlloc! .[4096]*;

		while (m_open) {
			// TODO: Find a way to not block the thread infinitely while reading, eg a timeout
			switch (Console.In.BaseStream.TryRead(.(data, 4096))) {
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