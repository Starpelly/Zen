using System;

using ZenLsp.Logging;

namespace ZenLsp;

public class ZenLspServer : LspServer
{
	public const String VERSION = "0.1.0";

	private bool m_markdown = false;

	public void Start(String[] args)
	{
		int port = -1;

		for (let arg in args)
		{
			if (arg.StartsWith("--port="))
			{
				if (int.Parse(arg[7...]) case .Ok(let val))
					port = val;
			}
		}

		if (port == -1)
			StartStdio();
		else
			StartTcp(port);
	}

	protected override void OnMessage(Json json)
	{
		StringView method = json["method"].AsString;
		if (method.IsEmpty) return;

		Log.Debug("Received: {}", method);

		Json args = json["params"];

		switch (method)
		{
		case "initialize":		handleRequest(json, onInitialize(args));
		case "initialized":		onInitialized();
		case "shutdown":		handleRequest(json, onShutdown());
		case "exit":			onExit();
		}
	}

	private void GetClientCapabilities(Json cap) {
		// General
		Json general = cap["general"];

		if (general.IsObject) {
			m_markdown = general.Contains("markdown");
		}
	}

	private void handleRequest(Json json, Result<Json, Error> result)
	{
		Json response = .Object();

		response["jsonrpc"] = .String("2.0");
		response["id"] = json["id"];

		switch (result) {
		case .Ok(let val):
			response["result"] = result;
		case .Err(let err):
			// response["error"] = err.GetJson();
			// delete err;
		}

		Send(response);
		response.Dispose();
	}

	private Result<Json, Error> onInitialize(Json args)
	{
		// Response
		Json res = .Object();

		Json cap = .Object();
		res["capabilities"] = cap;

		// Server Info
		Json info = .Object();
		res["serverInfo"] = info;
		info["name"] = .String("zen-lsp");
		info["version"] = .String(VERSION);

		return res;
	}

	private void onInitialized()
	{
		// Send zen/initialized
		Json json = .Object();
		// json["configuration"] = .String(app.mConfigName);

		Send("zen/initialized", json);
	}

	private Result<Json, Error> onShutdown()
	{
		Log.Info("Shutting down");

		return Json.Null();
	}

	private void onExit()
	{
		Stop();
	}
}