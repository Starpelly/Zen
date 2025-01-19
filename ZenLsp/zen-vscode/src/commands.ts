import * as vscode from "vscode";
import { Extension } from "./extension";

export function registerCommands(ext: Extension) {
    ext.registerCommand("zen.restart", onRestart, false);
}

async function onRestart(ext: Extension) {
    await ext.stop();
    ext.start();
}