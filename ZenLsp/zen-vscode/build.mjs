import esbuild from "esbuild";
import fs from "fs";

/**
 * @param {esbuild.BuildOptions} options 
 */
function build(options) {
    let start = new Date();

    esbuild.build(options).then(() => {
        let duration = (new Date() - start) / 1000;
        console.log("Built " + options.entryPoints[0] + " in " + duration + "s");
    });
}

function watch(path, callback) {
    chokidar.watch(path).on("change", callback);
}

fs.rmSync("out", { recursive: true, force: true });

// Extension
function buildExtension() {
    build({
        entryPoints: [ "src/extension.ts" ],
        outdir: "out",
        bundle: true,
        minify: process.argv.includes("-p"),
        external: [ "vscode" ],
        format: "cjs",
        platform: "node",
        sourcemap: process.argv.includes("-p") ? undefined : "linked"
    });
}

// Build
buildExtension();

// Watch
if (process.argv.includes("-w")) {
    watch("src", buildExtension);
}