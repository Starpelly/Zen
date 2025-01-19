using System;

using ZenLsp.Logging;

namespace ZenLsp;

public class ZenLspServer : LspServer
{
	public const String VERSION = "0.1.0";

	private DocumentManager m_documents = new .() ~ delete _;

	private bool m_markdown = false;
	private bool m_documentChanges = false;

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
		case "initialize":					HandleRequest(json, OnInitialize(args));
		case "initialized":					OnInitialized();
		case "shutdown":					HandleRequest(json, OnShutdown());
		case "exit":						OnExit();

		case "textDocument/didOpen":		OnDidOpen(args);
		case "textDocument/didChange":		OnDidChange(args);
		case "textDocument/didClose":		OnDidClose(args);

		case "textDocument/hover":			HandleRequest(json, OnHover(args));
		}
	}

	private void HandleRequest(Json json, Result<Json, Error> result)
	{
		Json response = .Object();

		response["jsonrpc"] = .String("2.0");
		response["id"] = json["id"];

		switch (result) {
		case .Ok(let val):
			response["result"] = result;
		case .Err(let err):
			response["error"] = err.GetJson();
			delete err;
		}

		Send(response);
		response.Dispose();
	}

	
	private void GetClientCapabilities(Json cap)
	{
		// General
		Json general = cap["general"];

		if (general.IsObject) {
			m_markdown = general.Contains("markdown");
		}

		// Workspace
		Json workspace = cap["workspace"];

		if (workspace.IsObject)
		{
			Json workspaceEdit = workspace["workspaceEdit"];

			if (workspaceEdit.IsObject)
			{
				m_documentChanges = workspaceEdit.GetBool("documentChanges");
			}
		}
	}

	private void RefreshWorkspace(bool refreshSemanticTokens = false)
	{
		Log.Info("Refreshing workspace");
		Send("zen/classifyBegin", .Null());

		Send("zen/classifyEnd", .Null());
	}

	private Result<Json, Error> OnInitialize(Json args)
	{
		GetClientCapabilities(args["capabilities"]);

		// Response
		Json res = .Object();

		Json cap = .Object();
		res["capabilities"] = cap;

		Json documentSync = .Object();
		cap["textDocumentSync"] = documentSync;
		documentSync["openClose"] = .Bool(true);
		documentSync["change"] = .Number(1); // Full sync

		cap["foldingRangeProvider"] = .Bool(true);

		Json completionProvider = .Object();
		cap["completionProvider"] = completionProvider;
		completionProvider["triggerCharacters"] = .Array()..Add(.String("."));
		completionProvider["resolveProvider"] = .Bool(true);

		Json documentSymbolProvider = .Object();
		cap["documentSymbolProvider"] = documentSymbolProvider;
		documentSymbolProvider["label"] = .String("Zen Lsp");

		Json signatureHelpProvider = .Object();
		cap["signatureHelpProvider"] = signatureHelpProvider;
		signatureHelpProvider["triggerCharacters"] = .Array()..Add(.String("("));
		signatureHelpProvider["retriggerCharacters"] = .Array()..Add(.String(","));

		cap["hoverProvider"] = .Bool(true);
		cap["definitionProvider"] = .Bool(true);
		cap["referencesProvider"] = .Bool(true);
		cap["workspaceSymbolProvider"] = .Bool(true);
		cap["documentFormattingProvider"] = .Bool(true);

		Json renameProvider = .Object();
		cap["renameProvider"] = renameProvider;
		renameProvider["prepareProvider"] = .Bool(true);

		// Did create
		Json didCreate = .Object();
		Json workspace = cap["workspace"] = .Object();
		Json fileOperations = workspace["fileOperations"] = .Object();
		fileOperations["didCreate"] = didCreate;

		Json filters = .Array();
		didCreate["filters"] = filters;

		Json filter = .Object();
		filters.Add(filter);

		Json pattern = .Object();
		filter["pattern"] = pattern;

		pattern["glob"] = .String("**/*.zen");
		pattern["matches"] = .String("file");

		// Server Info
		Json info = .Object();
		res["serverInfo"] = info;
		info["name"] = .String("zen-lsp");
		info["version"] = .String(VERSION);

		return res;
	}

	private void OnInitialized()
	{
		// Generate initial diagnostics
		RefreshWorkspace();

		// Send zen/initialized
		Json json = .Object();
		// json["configuration"] = .String(app.mConfigName);

		Send("zen/initialized", json);
	}

	private Result<Json, Error> OnShutdown()
	{
		Log.Info("Shutting down");

		return Json.Null();
	}

	private void OnExit()
	{
		Stop();
	}

	private void OnDidOpen(Json args)
	{
		let j = args["textDocument"];

		// Get path
		let path = Utils.GetPath!(args).GetValueOrLog!("");
		if (path.IsEmpty) return;

		// Add
		String contents = new .();
		j["text"].AsString.Unescape(contents);

		let document = m_documents.Add(path, (.)j["version"].AsNumber, contents);

		// Parse
		document.Parse();
	}

	private void OnDidChange(Json args)
	{
		Log.Info("On Did Change");
	}

	private void OnDidClose(Json args)
	{
		let path = Utils.GetPath!(args).GetValueOrLog!("");
		if (path.IsEmpty) return;

		m_documents.Remove(path);
	}

	private Result<Json, Error> OnHover(Json args)
	{
		let path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

		let document = m_documents.Get(path);
		if (document == null) return Json.Null();

		// Get hover data
		let cursor = document.GetPosition(args);
		let hoverData = document.GetCompilerData(.Hover, cursor, .. scope .());

		// Parse data
		if (hoverData.IsEmpty) return Json.Null();

		StringView hover = Utils.Lines(hoverData).GetNext().Value;
		if (!hover.StartsWith(':')) return Json.Null();

		// Create json
		let json = Json.Object();

		let contents = Json.Object();
		json["contents"] = contents;
		contents["kind"] = .String("markdown");
		contents["value"] = .String("Testttt");

		return json;
	}
}