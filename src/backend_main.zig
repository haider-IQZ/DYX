const std = @import("std");
const core_mod = @import("core_app.zig");
const backend_ipc = @import("backend_ipc.zig");

const OutputSink = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},

    fn emit(ctx: *anyopaque, event_name: []const u8, payload_json: []const u8) void {
        const self = @as(*OutputSink, @ptrCast(@alignCast(ctx)));
        self.writeEvent(event_name, payload_json) catch {};
    }

    fn writeEvent(self: *OutputSink, event_name: []const u8, payload_json: []const u8) !void {
        var bytes = std.array_list.Managed(u8).init(self.allocator);
        defer bytes.deinit();
        const writer = bytes.writer();
        try writer.writeAll("{\"event\":");
        try writer.print("{f}", .{std.json.fmt(event_name, .{})});
        try writer.writeAll(",\"payload\":");
        try writer.writeAll(payload_json);
        try writer.writeAll("}");
        try self.writeLine(bytes.items);
    }

    fn writeLine(self: *OutputSink, message: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const stdout_file = std.fs.File.stdout();
        try stdout_file.writeAll(message);
        try stdout_file.writeAll("\n");
    }
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var output = OutputSink{ .allocator = allocator };
    var app = try core_mod.CoreApp.init(allocator, .{ .ctx = &output, .emit = OutputSink.emit });
    defer app.deinit();
    try app.attach();

    const initial_status = try app.axelStatusJson(allocator);
    defer allocator.free(initial_status);
    try app.emitEvent("axelAvailabilityChanged", initial_status);

    var stdin_file = std.fs.File.stdin();
    var stdin_buffer: [4096]u8 = undefined;
    var reader = stdin_file.reader(&stdin_buffer);

    while (try reader.interface.takeDelimiter('\n')) |raw_line| {
        const trimmed_line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (trimmed_line.len == 0) continue;

        const request_id = requestIdFromJson(allocator, trimmed_line) catch "unknown";
        defer if (!std.mem.eql(u8, request_id, "unknown")) allocator.free(request_id);

        const response = backend_ipc.handle(&app, allocator, trimmed_line) catch |err| blk: {
            break :blk try backend_ipc.makeErrorResponse(allocator, request_id, @errorName(err));
        };
        defer allocator.free(response);

        try output.writeLine(response);
    }
}

fn requestIdFromJson(allocator: std.mem.Allocator, request_json: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, request_json, .{});
    defer parsed.deinit();

    return switch (parsed.value) {
        .object => |object| switch (object.get("id") orelse return error.InvalidRequest) {
            .string => |value| try allocator.dupe(u8, value),
            else => error.InvalidRequest,
        },
        else => error.InvalidRequest,
    };
}

test {
    _ = @import("backend_ipc.zig");
    _ = @import("core_app.zig");
}
