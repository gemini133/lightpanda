const std = @import("std");
const fspath = std.fs.path;

const FileLoader = @import("fileloader.zig").FileLoader;

const parser = @import("../netsurf.zig");

const jsruntime = @import("jsruntime");
const Loop = jsruntime.Loop;
const Env = jsruntime.Env;

const Types = @import("../main_wpt.zig").Types;

// runWPT parses the given HTML file, starts a js env and run the first script
// tags containing javascript sources.
// It loads first the js libs files.
pub fn run(arena: *std.heap.ArenaAllocator, comptime dir: []const u8, f: []const u8, loader: *FileLoader) !jsruntime.JSResult {
    const alloc = arena.allocator();

    // document
    const file = try std.fs.cwd().openFile(f, .{});
    defer file.close();

    const html_doc = try parser.documentHTMLParse(file.reader(), "UTF-8");
    const doc = parser.documentHTMLToDocument(html_doc);

    const dirname = fspath.dirname(f[dir.len..]) orelse unreachable;

    // create JS env
    var loop = try Loop.init(alloc);
    defer loop.deinit();
    var js_env = try Env.init(alloc, &loop);
    defer js_env.deinit();

    // load user-defined types in JS env
    var js_types: [Types.len]usize = undefined;
    try js_env.load(&js_types);

    // start JS env
    try js_env.start(alloc);
    defer js_env.stop();

    // display console logs
    defer {
        var res = evalJS(js_env, alloc, "console.join('\\n');", "console") catch unreachable;
        defer res.deinit(alloc);
        if (res.result.len > 0) {
            std.debug.print("-- CONSOLE LOG\n{s}\n--\n", .{res.result});
        }
    }

    // setup global env vars.
    try js_env.attachObject(try js_env.getGlobal(), "self", null);
    try js_env.attachObject(try js_env.getGlobal(), "window", null);
    try js_env.addObject(html_doc, "document");

    // thanks to the arena, we don't need to deinit res.
    var res: jsruntime.JSResult = undefined;

    const init =
        \\window.listeners = [];
        \\window.document = document;
        \\window.parent = window;
        \\window.addEventListener = function (type, listener, options) {
        \\  window.listeners.push({type: type, listener: listener, options: options});
        \\};
        \\window.dispatchEvent = function (event) {
        \\  len = window.listeners.length;
        \\  for (var i = 0; i < len; i++) {
        \\      if (window.listeners[i].type == event.target) {
        \\          window.listeners[i].listener(event);
        \\      }
        \\  }
        \\  return true;
        \\};
        \\window.removeEventListener = function () {};
        \\
        \\console = [];
        \\console.log = function () {
        \\  console.push(...arguments);
        \\};
    ;
    res = try evalJS(js_env, alloc, init, "init");
    if (!res.success) {
        return res;
    }

    // loop hover the scripts.
    const scripts = try parser.documentGetElementsByTagName(doc, "script");
    const slen = try parser.nodeListLength(scripts);
    for (0..slen) |i| {
        const s = (try parser.nodeListItem(scripts, @intCast(i))).?;

        // If the script contains an src attribute, load it.
        if (try parser.elementGetAttribute(@as(*parser.Element, @ptrCast(s)), "src")) |src| {
            var path = src;
            if (!std.mem.startsWith(u8, src, "/")) {
                // no need to free path, thanks to the arena.
                path = try fspath.join(alloc, &.{ "/", dirname, path });
            }

            res = try evalJS(js_env, alloc, try loader.get(path), src);
            if (!res.success) {
                return res;
            }
        }

        // If the script as a source text, execute it.
        const src = try parser.nodeTextContent(s) orelse continue;
        res = try evalJS(js_env, alloc, src, "");

        // return the first failure.
        if (!res.success) {
            return res;
        }
    }

    // Mark tests as ready to run.
    res = try evalJS(js_env, alloc, "window.dispatchEvent({target: 'load'});", "ready");
    if (!res.success) {
        return res;
    }

    // Check the final test status.
    res = try evalJS(js_env, alloc, "report.status;", "teststatus");
    if (!res.success) {
        return res;
    }

    // return the detailed result.
    return try evalJS(js_env, alloc, "report.log", "teststatus");
}

fn evalJS(env: jsruntime.Env, alloc: std.mem.Allocator, script: []const u8, name: ?[]const u8) !jsruntime.JSResult {
    var res = jsruntime.JSResult{};
    try env.run(alloc, script, name, &res, null);
    return res;
}

// browse the path to find the tests list.
pub fn find(allocator: std.mem.Allocator, comptime path: []const u8, list: *std.ArrayList([]const u8)) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true, .no_follow = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }
        if (!std.mem.endsWith(u8, entry.basename, ".html") and !std.mem.endsWith(u8, entry.basename, ".htm")) {
            continue;
        }

        try list.append(try fspath.join(allocator, &.{ path, entry.path }));
    }
}
