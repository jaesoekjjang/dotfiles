ObjC.import("AppKit");
ObjC.import("Foundation");

function run(argv) {
    if (!argv.length) throw new Error("No file selected");
    const files = argv.map(path => $.NSURL.fileURLWithPath($(path)));
    const clipboard = $.NSPasteboard.generalPasteboard;
    if (clipboard.isNil()) {
        throw new Error("macOS clipboard is unavailable in this process");
    }
    clipboard.clearContents;
    if (!clipboard.writeObjects($(files))) {
        throw new Error("macOS rejected the file clipboard write");
    }
}
