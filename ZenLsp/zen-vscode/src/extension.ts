import * as vscode from "vscode";
import * as net from "net";
import { LanguageClient, LanguageClientOptions, ServerOptions, StreamInfo, TransportKind } from "vscode-languageclient/node";
import { InitializedArgs } from "./types.ts";
import { execFile } from "child_process";
import { registerCommands } from "./commands.ts";

const devTcp = true;

export class Extension {
    private context: vscode.ExtensionContext;
    private client: LanguageClient;
    private initialized: boolean;

    private barItem: vscode.StatusBarItem;

    private configuration: string;

    constructor(context: vscode.ExtensionContext) {
        this.context = context;
        this.initialized = false;

        // Bar Item
        this.barItem = vscode.window.createStatusBarItem("zen-lsp", vscode.StatusBarAlignment.Left, 2);
        this.barItem.name = "Zen Lsp Status";

        // Register
        registerCommands(this);
    }

    start() {
        // TODO: Always use TCP transport since currently the STDIO one does not close properly
        let serverOptions: ServerOptions = {
            command: "D:/Zen/build/Debug_Win64/ZenLsp/ZenLsp.exe"
        };

        execFile("D:/Zen/build/Debug_Win64/ZenLsp/ZenLsp.exe", [ "--port=5556" ]);
        setTimeout(() => {
            if (true) {
                serverOptions = () => {
                    let socket = net.createConnection({
                        port: 5556
                    });
            
                    let result: StreamInfo = {
                        writer: socket,
                        reader: socket
                    };
            
                    return Promise.resolve(result);
                };
            }
        
            let clientOptions: LanguageClientOptions = {
                documentSelector: [{ scheme: "file", language: "zen" }]
            };
        
            this.client = new LanguageClient(
                "zen",
                "zen-language",
                serverOptions,
                clientOptions
            );

            this.setBarItem("Starting", true);
            this.barItem.show();

            this.client.start().then(this.onReady.bind(this));
        }, 1000);
    }

    private onReady() {
        this.client.onNotification("zen/initialized", (args: InitializedArgs) => {
            vscode.commands.executeCommand("setContext", "zen.isActive", true);

            this.initialized = true;
        });

        this.client.onNotification("zen/classifyBegin", () => this.setBarItem("Classifying", true));
        this.client.onNotification("zen/classifyEnd", () => this.setBarItem("Running", false));
    }

    setBarItem(status: string, spin: boolean) {
        this.barItem.text = "$(" + (spin ? "loading~spin" : "check") + ") Zen Lsp";
        this.barItem.tooltip = "Status: " + status;
    }

    sendLspRequest<T>(method: string, param?: any): Promise<T> {
        return this.onlyIfRunningPromise(() => this.client.sendRequest<T>(method, param));
    }

    sendLspNotification(method: string, param: any) {
        this.onlyIfRunning(() => this.client.sendNotification(method, param));
    }

    private onlyIfRunning(callback: () => void) {
        if (this.initialized && this.client.isRunning()) callback.bind(this)();
        else vscode.window.showInformationMessage("Zen LSP server is not running");
    }

    private onlyIfRunningPromise<T>(callback: () => Promise<T>): Promise<T> {
        if (this.initialized && this.client.isRunning()) return callback.bind(this)();

        vscode.window.showInformationMessage("Zen LSP server is not running");
        return Promise.reject("Zen LSP server is not running");
    }

    registerCommand(command: string, callback: (ext: Extension) => void, onlyIfRunning = true) {
        this.context.subscriptions.push(vscode.commands.registerCommand(command, () => {
            if (onlyIfRunning) this.onlyIfRunning(() => callback(this));
            else callback(this);
        }, this));
    }

    async stop() {
        if (this.client && this.client.isRunning()) {
            await this.client.dispose();
        }

        this.barItem.hide();
        this.initialized = false;
    }
}

let extension: Extension;

export function activate(context: vscode.ExtensionContext) {
    extension = new Extension(context);
    extension.start();
}

export async function deactivate() {
    await extension.stop();
}