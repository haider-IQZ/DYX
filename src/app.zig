const std = @import("std");
const models = @import("models.zig");
const axel = @import("axel.zig");
const settings = @import("settings.zig");
const history = @import("history.zig");
const download_manager = @import("download_manager.zig");

pub const c = @cImport({
    @cInclude("webview/webview.h");
});

pub const App = struct {
    allocator: std.mem.Allocator,
    webview: c.webview_t,
    settings_store: settings.Store,
    history_store: history.Store,
    downloads: download_manager.DownloadManager,
    axel_status: models.AxelStatus,

    pub fn init(allocator: std.mem.Allocator, webview: c.webview_t) !App {
        var settings_store = try settings.Store.init(allocator);
        errdefer settings_store.deinit();

        var history_store = try history.Store.init(allocator);
        errdefer history_store.deinit();

        var status = try axel.checkAvailability(allocator);
        errdefer status.deinit(allocator);

        const app = App{
            .allocator = allocator,
            .webview = webview,
            .settings_store = settings_store,
            .history_store = history_store,
            .downloads = undefined,
            .axel_status = status,
        };
        return app;
    }

    pub fn attach(self: *App) !void {
        self.downloads = download_manager.DownloadManager.init(
            self.allocator,
            &self.history_store,
            &self.settings_store,
            .{ .ctx = self, .emit = emitFromManager },
        );
        self.downloads.sink = .{
            .ctx = self,
            .emit = emitFromManager,
        };
        try self.downloads.recoverShutdownRecovery();
    }

    pub fn deinit(self: *App) void {
        self.downloads.shutdown();
        self.downloads.deinit();
        self.history_store.deinit();
        self.settings_store.deinit();
        self.axel_status.deinit(self.allocator);
    }

    pub fn emitEvent(self: *App, event_name: []const u8, payload_json: []const u8) !void {
        const envelope = try buildEventEnvelope(self.allocator, event_name, payload_json);
        errdefer self.allocator.free(envelope);

        const js_source = try std.fmt.allocPrint(self.allocator, "window.__DYX__ && window.__DYX__.receive({s});", .{envelope});
        self.allocator.free(envelope);
        defer self.allocator.free(js_source);

        const js = try self.allocator.dupeZ(u8, js_source);

        const dispatch_ctx = try self.allocator.create(DispatchEval);
        dispatch_ctx.* = .{
            .allocator = self.allocator,
            .webview = self.webview,
            .js = js,
        };
        _ = c.webview_dispatch(self.webview, evalOnUiThread, dispatch_ctx);
    }

    pub fn refreshAxelStatus(self: *App) !void {
        const updated = try axel.checkAvailability(self.allocator);
        self.axel_status.deinit(self.allocator);
        self.axel_status = updated;

        const json = try models.jsonStringifyAlloc(self.allocator, self.axel_status, .{});
        defer self.allocator.free(json);
        try self.emitEvent("axelAvailabilityChanged", json);
    }

    pub fn historyJson(self: *App, allocator: std.mem.Allocator) ![]u8 {
        return self.history_store.toJson(allocator);
    }

    pub fn settingsJson(self: *App, allocator: std.mem.Allocator) ![]u8 {
        return self.settings_store.toJson(allocator);
    }

    pub fn axelStatusJson(self: *App, allocator: std.mem.Allocator) ![]u8 {
        return models.jsonStringifyAlloc(allocator, self.axel_status, .{});
    }

    pub fn chooseDirectory(self: *App, initial_path: ?[]const u8) !?[]u8 {
        const selected = chooseDirectoryWith(self.allocator, "zenity", initial_path) catch |err| switch (err) {
            error.FileNotFound => chooseDirectoryWith(self.allocator, "kdialog", initial_path) catch |next_err| switch (next_err) {
                error.FileNotFound => return null,
                else => return next_err,
            },
            else => return err,
        };
        return selected;
    }
};

const DispatchEval = struct {
    allocator: std.mem.Allocator,
    webview: c.webview_t,
    js: [:0]u8,
};

fn evalOnUiThread(_: c.webview_t, arg: ?*anyopaque) callconv(.c) void {
    const ctx = @as(*DispatchEval, @ptrCast(@alignCast(arg.?)));
    defer ctx.allocator.destroy(ctx);
    defer ctx.allocator.free(ctx.js);
    _ = c.webview_eval(ctx.webview, ctx.js.ptr);
}

fn emitNoop(_: *anyopaque, _: []const u8, _: []const u8) void {}

fn emitFromManager(ctx: *anyopaque, event_name: []const u8, payload_json: []const u8) void {
    const app = @as(*App, @ptrCast(@alignCast(ctx)));
    app.emitEvent(event_name, payload_json) catch {};
}

fn buildEventEnvelope(allocator: std.mem.Allocator, event_name: []const u8, payload_json: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    const writer = list.writer();
    try writer.writeAll("{\"event\":");
    try writer.print("{f}", .{std.json.fmt(event_name, .{})});
    try writer.writeAll(",\"payload\":");
    try writer.writeAll(payload_json);
    try writer.writeAll("}");
    return list.toOwnedSlice();
}

fn chooseDirectoryWith(allocator: std.mem.Allocator, tool: []const u8, initial_path: ?[]const u8) !?[]u8 {
    const argv = switch (std.meta.stringToEnum(ChooserTool, tool) orelse .zenity) {
        .zenity => try buildZenityArgv(allocator, initial_path),
        .kdialog => try buildKdialogArgv(allocator, initial_path),
    };
    defer allocator.free(argv);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    }) catch |err| switch (err) {
        error.FileNotFound => return error.FileNotFound,
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .Exited => |code| if (code == 0) blk: {
            const trimmed = std.mem.trim(u8, result.stdout, " \t\r\n");
            if (trimmed.len == 0) break :blk null;
            break :blk try allocator.dupe(u8, trimmed);
        } else null,
        else => null,
    };
}

const ChooserTool = enum {
    zenity,
    kdialog,
};

fn buildZenityArgv(allocator: std.mem.Allocator, initial_path: ?[]const u8) ![]const []const u8 {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    try argv.append("zenity");
    try argv.append("--file-selection");
    try argv.append("--directory");
    if (initial_path) |value| {
        try argv.append("--filename");
        try argv.append(value);
    }
    return argv.toOwnedSlice();
}

fn buildKdialogArgv(allocator: std.mem.Allocator, initial_path: ?[]const u8) ![]const []const u8 {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    try argv.append("kdialog");
    try argv.append("--getexistingdirectory");
    try argv.append(if (initial_path) |value| value else ".");
    return argv.toOwnedSlice();
}
