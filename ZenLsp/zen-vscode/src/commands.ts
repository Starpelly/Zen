import * as vscode from "vscode";
import { Extension } from "./extension";

export function registerCommands(ext: Extension) {

}

async function onRestart(ext: Extension) {
    await ext.stop();
    ext.start();
}