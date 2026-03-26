const std = @import("std");
const models = @import("models.zig");

const HostResponse = struct {
    ok: bool,
    accepted: ?bool = null,
    launched: ?bool = null,
    @"error": ?[]const u8 = null,

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "ok", self.ok);
        if (self.accepted) |value| try writeField(jws, "accepted", value);
        if (self.launched) |value| try writeField(jws, "launched", value);
        if (self.@"error") |value| try writeField(jws, "error", value);
        try jws.endObject();
    }
};

const max_log_bytes: u64 = 1024 * 1024;

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var stdin = std.fs.File.stdin();
    var stdout = std.fs.File.stdout();

    while (true) {
        const message = readNativeMessage(allocator, &stdin) catch |err| switch (err) {
            error.EndOfStream => return,
            else => {
                try writeNativeMessage(allocator, &stdout, .{
                    .ok = false,
                    .@"error" = @errorName(err),
                });
                return;
            },
        };
        defer allocator.free(message);

        const response = handleMessage(allocator, message) catch |err| HostResponse{
            .ok = false,
            .@"error" = @errorName(err),
        };
        try writeNativeMessage(allocator, &stdout, response);
    }
}

fn handleMessage(allocator: std.mem.Allocator, message: []const u8) !HostResponse {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, message, .{});
    defer parsed.deinit();

    const root = parsed.value;
    const object = switch (root) {
        .object => |object| object,
        else => return error.InvalidRequest,
    };
    const request_type = try getRequiredString(object, "type");

    if (std.mem.eql(u8, request_type, "append_debug_log")) {
        try handleAppendDebugLog(allocator, object);
        return .{ .ok = true };
    }

    if (!std.mem.eql(u8, request_type, "enqueue_download")) {
        try logNativeHostEvent(allocator, "unsupported_command", .{
            .type = request_type,
        });
        return error.UnsupportedCommand;
    }

    const raw_url = try getRequiredString(object, "url");
    const url = std.mem.trim(u8, raw_url, " \t\r\n");
    if (url.len == 0) {
        return error.MissingUrl;
    }
    if (!isSupportedUrl(url)) {
        try logNativeHostEvent(allocator, "unsupported_url", .{
            .url = url,
        });
        return error.UnsupportedUrl;
    }

    try logNativeHostEvent(allocator, "enqueue_received", .{
        .url = url,
        .source = getOptionalString(object, "source") orelse "firefox",
    });

    const relay_bin = try resolveRelayBinary(allocator);
    defer allocator.free(relay_bin);

    try logNativeHostEvent(allocator, "relay_resolved", .{
        .url = url,
        .relay_bin = relay_bin,
    });

    var argv = std.array_list.Managed([]const u8).init(allocator);
    defer {
        for (argv.items, 0..) |value, index| {
            if (index == 0) continue;
            allocator.free(value);
        }
        argv.deinit();
    }

    try argv.append(relay_bin);
    try argv.append(try allocator.dupe(u8, "--enqueue-download-url"));
    try argv.append(try allocator.dupe(u8, url));
    try argv.append(try allocator.dupe(u8, "--enqueue-download-source"));
    try argv.append(try allocator.dupe(u8, getOptionalString(object, "source") orelse "firefox"));

    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-filename", getOptionalString(object, "filename"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-suggested-filename", getOptionalString(object, "suggestedFilename"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-referrer", getOptionalString(object, "referrer"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-page-title", getOptionalString(object, "pageTitle"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-tab-url", getOptionalString(object, "tabUrl"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-user-agent", getOptionalString(object, "userAgent"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-request-method", getOptionalString(object, "requestMethod"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-request-type", getOptionalString(object, "requestType"));
    try appendOptionalRelayArg(allocator, &argv, "--enqueue-download-correlation-id", getOptionalString(object, "correlationId"));

    if (object.get("headers")) |value| {
        switch (value) {
            .array => |array| {
                for (array.items) |entry| {
                    switch (entry) {
                        .string => |header| {
                            if (std.mem.trim(u8, header, " \t\r\n").len == 0) continue;
                            try argv.append(try allocator.dupe(u8, "--enqueue-download-header"));
                            try argv.append(try allocator.dupe(u8, header));
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }

    var child = std.process.Child.init(argv.items, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();

    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            try logNativeHostEvent(allocator, "relay_exited", .{
                .url = url,
                .exit_code = code,
            });
            if (code != 0) {
                return error.RelayRejectedCommand;
            }
        },
        else => {
            try logNativeHostEvent(allocator, "relay_rejected", .{
                .url = url,
            });
            return error.RelayRejectedCommand;
        },
    }

    try logNativeHostEvent(allocator, "enqueue_accepted", .{
        .url = url,
    });

    return .{
        .ok = true,
        .accepted = true,
        .launched = true,
    };
}

fn handleAppendDebugLog(allocator: std.mem.Allocator, object: std.json.ObjectMap) !void {
    const component = getOptionalString(object, "component") orelse "firefox-extension";
    const event = getOptionalString(object, "event") orelse "unknown";
    const timestamp = getOptionalString(object, "timestamp");
    const data_json = if (object.get("data")) |value|
        try models.jsonStringifyAlloc(allocator, value, .{})
    else
        try allocator.dupe(u8, "{}");
    defer allocator.free(data_json);

    try appendLogLine(allocator, "extension.ndjson", component, event, timestamp, data_json);
}

fn readNativeMessage(allocator: std.mem.Allocator, stdin: *std.fs.File) ![]u8 {
    var header: [4]u8 = undefined;
    readExact(stdin, &header) catch |err| switch (err) {
        error.EndOfStream => return error.EndOfStream,
        else => return err,
    };

    const length = std.mem.readInt(u32, &header, .little);
    if (length == 0) {
        return try allocator.dupe(u8, "");
    }

    const payload = try allocator.alloc(u8, length);
    errdefer allocator.free(payload);
    try readExact(stdin, payload);
    return payload;
}

fn writeNativeMessage(allocator: std.mem.Allocator, stdout: *std.fs.File, response: HostResponse) !void {
    const payload = try models.jsonStringifyAlloc(allocator, response, .{});
    defer allocator.free(payload);

    var header: [4]u8 = undefined;
    std.mem.writeInt(u32, &header, @as(u32, @intCast(payload.len)), .little);
    try stdout.writeAll(&header);
    try stdout.writeAll(payload);
}

fn resolveRelayBinary(allocator: std.mem.Allocator) ![]u8 {
    if (try envOwned(allocator, "DYX_RELAY_BIN")) |env_bin| {
        errdefer allocator.free(env_bin);
        if (try isExecutableFile(env_bin)) {
            return env_bin;
        }
        allocator.free(env_bin);
        return error.InvalidRelayBinary;
    }

    const self_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_path);
    const self_dir = std.fs.path.dirname(self_path) orelse return error.InvalidExecutablePath;

    const candidates = [_][]const []const u8{
        &.{ self_dir, "..", "libexec", "dyx-relay" },
        &.{ self_dir, "..", "bin", "dyx-relay" },
        &.{ self_dir, "..", "..", "build", "qt", "dyx-relay" },
        &.{ self_dir, "..", "..", "zig-out", "bin", "dyx-relay" },
    };

    for (candidates) |parts| {
        const candidate = try std.fs.path.join(allocator, parts);
        errdefer allocator.free(candidate);
        if (try isExecutableFile(candidate)) {
            return candidate;
        }
        allocator.free(candidate);
    }

    return error.RelayBinaryNotFound;
}

fn resolveLogDir(allocator: std.mem.Allocator) ![]u8 {
    if (try envOwned(allocator, "XDG_DATA_HOME")) |data_home| {
        defer allocator.free(data_home);
        return std.fs.path.join(allocator, &.{ data_home, "DYX", "logs", "firefox-catcher" });
    }

    if (try envOwned(allocator, "HOME")) |home| {
        defer allocator.free(home);
        return std.fs.path.join(allocator, &.{ home, ".local", "share", "DYX", "logs", "firefox-catcher" });
    }

    return error.MissingHomeDirectory;
}

fn appendLogLine(
    allocator: std.mem.Allocator,
    file_name: []const u8,
    component: []const u8,
    event: []const u8,
    timestamp: ?[]const u8,
    data_json: []const u8,
) !void {
    const log_dir = try resolveLogDir(allocator);
    defer allocator.free(log_dir);
    try std.fs.cwd().makePath(log_dir);

    const path = try std.fs.path.join(allocator, &.{ log_dir, file_name });
    defer allocator.free(path);
    try rotateLogIfNeeded(path);

    const ts = timestamp orelse "native-host";
    const line = try std.fmt.allocPrint(
        allocator,
        "{{\"ts\":{f},\"component\":{f},\"event\":{f},\"data\":{s}}}\n",
        .{
            std.json.fmt(ts, .{}),
            std.json.fmt(component, .{}),
            std.json.fmt(event, .{}),
            data_json,
        },
    );
    defer allocator.free(line);

    const file = try std.fs.createFileAbsolute(path, .{ .truncate = false, .read = true });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writeAll(line);
}

fn rotateLogIfNeeded(path: []const u8) !void {
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const stat = try file.stat();
    if (stat.size < max_log_bytes) {
        return;
    }

    const rotated_path = try std.fmt.allocPrint(std.heap.c_allocator, "{s}.1", .{path});
    defer std.heap.c_allocator.free(rotated_path);

    std.fs.deleteFileAbsolute(rotated_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try std.fs.renameAbsolute(path, rotated_path);
}

fn logNativeHostEvent(allocator: std.mem.Allocator, event: []const u8, data: anytype) !void {
    const data_json = try models.jsonStringifyAlloc(allocator, data, .{});
    defer allocator.free(data_json);
    try appendLogLine(allocator, "native-host.ndjson", "native-host", event, null, data_json);
}

fn getRequiredString(object: std.json.ObjectMap, key: []const u8) ![]const u8 {
    return getOptionalString(object, key) orelse error.MissingField;
}

fn getOptionalString(object: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = object.get(key) orelse return null;
    return switch (value) {
        .string => |string| string,
        else => null,
    };
}

fn appendOptionalRelayArg(
    allocator: std.mem.Allocator,
    argv: *std.array_list.Managed([]const u8),
    flag: []const u8,
    value: ?[]const u8,
) !void {
    const actual = value orelse return;
    if (std.mem.trim(u8, actual, " \t\r\n").len == 0) return;
    try argv.append(try allocator.dupe(u8, flag));
    try argv.append(try allocator.dupe(u8, actual));
}

fn envOwned(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

fn isExecutableFile(path: []const u8) !bool {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        }
    else
        std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
    defer file.close();

    const stat = try file.stat();
    return stat.kind == .file;
}

fn readExact(file: *std.fs.File, buffer: []u8) !void {
    var offset: usize = 0;
    while (offset < buffer.len) {
        const bytes_read = try file.read(buffer[offset..]);
        if (bytes_read == 0) {
            return error.EndOfStream;
        }
        offset += bytes_read;
    }
}

fn isSupportedUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://");
}

fn writeField(jws: anytype, key: []const u8, value: anytype) !void {
    try jws.objectField(key);
    try jws.write(value);
}

test "handle message rejects unsupported type" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.UnsupportedCommand,
        handleMessage(allocator, "{\"type\":\"nope\"}")
    );
}

test "handle message rejects unsupported url schemes" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.UnsupportedUrl,
        handleMessage(allocator, "{\"type\":\"enqueue_download\",\"url\":\"ftp://example.com/file.zip\"}")
    );
}
