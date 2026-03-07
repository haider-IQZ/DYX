const std = @import("std");
const app_mod = @import("app.zig");
const models = @import("models.zig");
const axel = @import("axel.zig");

pub fn handle(app: *app_mod.App, allocator: std.mem.Allocator, request_json: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, request_json, .{});
    defer parsed.deinit();

    const request_value = try firstArrayItem(parsed.value);
    const id = try getStringField(request_value, "id");
    const method = try getStringField(request_value, "method");
    const params_value = getOptionalField(request_value, "params");

    const result_json = try dispatch(app, allocator, method, params_value);
    defer allocator.free(result_json);
    return makeOkResponse(allocator, id, result_json);
}

fn dispatch(
    app: *app_mod.App,
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
    if (std.mem.eql(u8, method, "chooseDirectory")) {
        const request = if (params_value) |value|
            try parseOwnedOptionalPathRequest(allocator, value)
        else
            OptionalPathRequest{ .path = null };
        defer if (request.path) |value| allocator.free(value);
        const selected = try app.chooseDirectory(request.path);
        defer if (selected) |value| app.allocator.free(value);
        return models.jsonStringifyAlloc(allocator, DirectoryChoiceResponse{ .path = selected }, .{});
    }

    return error.UnknownMethod;
}

fn parseParams(comptime T: type, allocator: std.mem.Allocator, params_value: std.json.Value) !T {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);
    return std.json.parseFromSliceLeaky(T, allocator, encoded, .{});
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

fn parseOwnedOptionalPathRequest(allocator: std.mem.Allocator, params_value: std.json.Value) !OptionalPathRequest {
    const encoded = try models.jsonStringifyAlloc(allocator, params_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(OptionalPathRequest, allocator, encoded, .{});
    defer parsed.deinit();
    return .{ .path = if (parsed.value.path) |value| try allocator.dupe(u8, value) else null };
}

fn firstArrayItem(value: std.json.Value) !std.json.Value {
    return switch (value) {
        .array => |array| if (array.items.len > 0) array.items[0] else error.InvalidRequest,
        else => error.InvalidRequest,
    };
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
const OptionalPathRequest = struct { path: ?[]const u8 = null };
const DirectoryChoiceResponse = struct {
    path: ?[]const u8 = null,

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("path");
        if (self.path) |value| {
            try jws.write(value);
        } else {
            try jws.write(null);
        }
        try jws.endObject();
    }
};
