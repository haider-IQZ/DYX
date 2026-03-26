const std = @import("std");
const core_mod = @import("core_app.zig");
const models = @import("models.zig");
const axel = @import("axel.zig");

pub fn handle(app: *core_mod.CoreApp, allocator: std.mem.Allocator, request_json: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, request_json, .{});
    defer parsed.deinit();

    const id = try getStringField(parsed.value, "id");
    const method = try getStringField(parsed.value, "method");
    const params_value = getOptionalField(parsed.value, "params");

    const result_json = try dispatch(app, allocator, method, params_value);
    defer allocator.free(result_json);
    return makeOkResponse(allocator, id, result_json);
}

fn dispatch(
    app: *core_mod.CoreApp,
    allocator: std.mem.Allocator,
    method: []const u8,
    params_value: ?std.json.Value,
) ![]u8 {
    if (std.mem.eql(u8, method, "checkAxel")) {
        try app.refreshAxelStatus();
        return app.axelStatusJson(allocator);
    }
    if (std.mem.eql(u8, method, "getSettings")) {
        return app.settingsJson(allocator);
    }
    if (std.mem.eql(u8, method, "saveSettings")) {
        const parsed = try parseOwnedAppSettings(allocator, params_value orelse return error.MissingParams);
        defer {
            var mutable = parsed;
            mutable.deinit(allocator);
        }
        try app.settings_store.set(parsed);
        const json = try app.settingsJson(allocator);
        const event_payload = try app.settingsJson(app.allocator);
        defer app.allocator.free(event_payload);
        try app.emitEvent("settingsChanged", event_payload);
        return json;
    }
    if (std.mem.eql(u8, method, "listDownloads")) {
        return app.downloads.listJson(allocator);
    }
    if (std.mem.eql(u8, method, "listHistory")) {
        return app.historyJson(allocator);
    }
    if (std.mem.eql(u8, method, "startDownload")) {
        const parsed = try parseOwnedStartDownloadRequest(allocator, params_value orelse return error.MissingParams);
        defer {
            var mutable = parsed;
            mutable.deinit(allocator);
        }
        return app.downloads.startDownload(parsed);
    }
    if (std.mem.eql(u8, method, "cancelDownload")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        const cancelled = try app.downloads.cancelDownload(request.id);
        return models.jsonStringifyAlloc(allocator, .{ .cancelled = cancelled }, .{});
    }
    if (std.mem.eql(u8, method, "pauseDownload")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        const paused = try app.downloads.pauseDownload(request.id);
        return models.jsonStringifyAlloc(allocator, .{ .paused = paused }, .{});
    }
    if (std.mem.eql(u8, method, "resumeDownload")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        const resumed = try app.downloads.resumeDownload(request.id);
        return models.jsonStringifyAlloc(allocator, .{ .resumed = resumed }, .{});
    }
    if (std.mem.eql(u8, method, "deleteDownload")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        const deleted = try app.downloads.deleteDownload(request.id);
        return models.jsonStringifyAlloc(allocator, .{ .deleted = deleted }, .{});
    }
    if (std.mem.eql(u8, method, "retryDownload")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        return app.downloads.retryDownload(request.id);
    }
    if (std.mem.eql(u8, method, "removeHistoryItem")) {
        const request = try parseOwnedIdRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.id);
        const removed = try app.history_store.removeById(request.id);
        const history_json = try app.historyJson(app.allocator);
        defer app.allocator.free(history_json);
        try app.emitEvent("historyChanged", history_json);
        return models.jsonStringifyAlloc(allocator, .{ .removed = removed }, .{});
    }
    if (std.mem.eql(u8, method, "removeHistoryByPath")) {
        const request = try parseOwnedPathRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.path);
        const removed = try app.history_store.removeByOutputPath(request.path);
        const history_json = try app.historyJson(app.allocator);
        defer app.allocator.free(history_json);
        try app.emitEvent("historyChanged", history_json);
        return models.jsonStringifyAlloc(allocator, .{ .removed = removed }, .{});
    }
    if (std.mem.eql(u8, method, "openFile")) {
        const request = try parseOwnedPathRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.path);
        try axel.openPath(app.allocator, request.path);
        return models.jsonStringifyAlloc(allocator, .{ .opened = true }, .{});
    }
    if (std.mem.eql(u8, method, "openFolder")) {
        const request = try parseOwnedPathRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.path);
        const directory = std.fs.path.dirname(request.path) orelse request.path;
        try axel.openPath(app.allocator, directory);
        return models.jsonStringifyAlloc(allocator, .{ .opened = true }, .{});
    }
    if (std.mem.eql(u8, method, "deleteFile")) {
        const request = try parseOwnedPathRequest(allocator, params_value orelse return error.MissingParams);
        defer allocator.free(request.path);
        try axel.deleteFile(request.path);
        return models.jsonStringifyAlloc(allocator, .{ .deleted = true }, .{});
    }

    return error.UnknownMethod;
}

fn parseOwnedAppSettings(allocator: std.mem.Allocator, params_value: std.json.Value) !models.AppSettings {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(models.AppSettings, allocator, encoded, .{});
    defer parsed.deinit();
    return parsed.value.cloneOwned(allocator);
}

fn parseOwnedStartDownloadRequest(allocator: std.mem.Allocator, params_value: std.json.Value) !models.StartDownloadRequest {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(models.StartDownloadRequest, allocator, encoded, .{});
    defer parsed.deinit();
    return parsed.value.cloneOwned(allocator);
}

fn parseOwnedIdRequest(allocator: std.mem.Allocator, params_value: std.json.Value) !IdRequest {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(IdRequest, allocator, encoded, .{});
    defer parsed.deinit();
    return .{ .id = try allocator.dupe(u8, parsed.value.id) };
}

fn parseOwnedPathRequest(allocator: std.mem.Allocator, params_value: std.json.Value) !PathRequest {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(PathRequest, allocator, encoded, .{});
    defer parsed.deinit();
    return .{ .path = try allocator.dupe(u8, parsed.value.path) };
}

fn getStringField(value: std.json.Value, key: []const u8) ![]const u8 {
    const field = getOptionalField(value, key) orelse return error.InvalidRequest;
    return switch (field) {
        .string => |string| string,
        else => error.InvalidRequest,
    };
}

fn getOptionalField(value: std.json.Value, key: []const u8) ?std.json.Value {
    return switch (value) {
        .object => |object| object.get(key),
        else => null,
    };
}

pub fn makeOkResponse(allocator: std.mem.Allocator, id: []const u8, result_json: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    const writer = list.writer();
    try writer.writeAll("{\"id\":");
    try writer.print("{f}", .{std.json.fmt(id, .{})});
    try writer.writeAll(",\"ok\":true,\"result\":");
    try writer.writeAll(result_json);
    try writer.writeAll("}");
    return list.toOwnedSlice();
}

pub fn makeErrorResponse(allocator: std.mem.Allocator, id: []const u8, message: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator);
    errdefer list.deinit();
    const writer = list.writer();
    try writer.writeAll("{\"id\":");
    try writer.print("{f}", .{std.json.fmt(id, .{})});
    try writer.writeAll(",\"ok\":false,\"error\":");
    try writer.print("{f}", .{std.json.fmt(message, .{})});
    try writer.writeAll("}");
    return list.toOwnedSlice();
}

const IdRequest = struct { id: []const u8 };
const PathRequest = struct { path: []const u8 };
