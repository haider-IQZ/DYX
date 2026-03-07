const std = @import("std");
const app_mod = @import("app.zig");
const ipc = @import("ipc.zig");
const ui_server = @import("ui_server.zig");

const c = app_mod.c;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const webview = c.webview_create(1, null) orelse return error.WebviewCreateFailed;
    defer _ = c.webview_destroy(webview);

    _ = c.webview_set_title(webview, "DYX");
    _ = c.webview_set_size(webview, 1360, 900, c.WEBVIEW_HINT_NONE);
    _ = c.webview_init(webview, bootstrap_script);

    var app = try app_mod.App.init(allocator, webview);
    defer app.deinit();
    try app.attach();

    _ = c.webview_bind(webview, "dyxInvoke", handleInvoke, &app);

    var static_server: ?*ui_server.UiServer = null;
    defer if (static_server) |server| server.deinit();

    const target_url = try resolveUiUrl(allocator, &static_server);
    defer allocator.free(target_url);
    _ = c.webview_navigate(webview, target_url.ptr);

    const initial_status = try app.axelStatusJson(allocator);
    defer allocator.free(initial_status);
    try app.emitEvent("axelAvailabilityChanged", initial_status);

    _ = c.webview_run(webview);
}

fn resolveUiUrl(allocator: std.mem.Allocator, server_slot: *?*ui_server.UiServer) ![:0]u8 {
    if (std.process.getEnvVarOwned(allocator, "DYX_UI_DEV_URL")) |dev_url| {
        defer allocator.free(dev_url);
        return allocator.dupeZ(u8, dev_url);
    } else |_| {}

    const ui_root = std.process.getEnvVarOwned(allocator, "DYX_UI_DIST") catch try allocator.dupe(u8, "ui/dist");
    defer allocator.free(ui_root);

    const server = try ui_server.UiServer.create(allocator, ui_root);
    server_slot.* = server;
    return server.url(allocator);
}

fn handleInvoke(id: [*c]const u8, req: [*c]const u8, arg: ?*anyopaque) callconv(.c) void {
    const app = @as(*app_mod.App, @ptrCast(@alignCast(arg.?)));
    const allocator = app.allocator;

    const request_json = std.mem.span(req);
    const request_id = std.mem.span(id);

    const response = ipc.handle(app, allocator, request_json) catch |err| blk: {
        break :blk ipc.makeErrorResponse(allocator, request_id, @errorName(err)) catch return;
    };
    defer allocator.free(response);

    const response_z = allocator.dupeZ(u8, response) catch return;
    defer allocator.free(response_z);

    _ = c.webview_return(app.webview, id, 0, response_z.ptr);
}

const bootstrap_script =
    \\window.__DYX__ = window.__DYX__ || {};
    \\window.__DYX__.backend = true;
    \\window.__DYX__.__listeners = window.__DYX__.__listeners || new Set();
    \\window.__DYX__.invoke = function(request) {
    \\  return window.dyxInvoke(request);
    \\};
    \\window.__DYX__.onEvent = function(handler) {
    \\  window.__DYX__.__listeners.add(handler);
    \\  return function() {
    \\    window.__DYX__.__listeners.delete(handler);
    \\  };
    \\};
    \\window.__DYX__.receive = function(message) {
    \\  const payload = typeof message === "string" ? JSON.parse(message) : message;
    \\  window.__DYX__.__listeners.forEach(function(handler) { handler(payload); });
    \\  window.dispatchEvent(new CustomEvent("dyx:event", { detail: payload }));
    \\};
;

test {
    _ = @import("axel.zig");
    _ = @import("settings.zig");
    _ = @import("history.zig");
    _ = @import("ui_server.zig");
}
