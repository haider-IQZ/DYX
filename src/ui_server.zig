const std = @import("std");

pub const UiServer = struct {
    allocator: std.mem.Allocator,
    root_path: []u8,
    server: std.net.Server,
    thread: ?std.Thread = null,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn create(allocator: std.mem.Allocator, root_relative_path: []const u8) !*UiServer {
        const self = try allocator.create(UiServer);
        errdefer allocator.destroy(self);

        const root_path = try std.fs.cwd().realpathAlloc(allocator, root_relative_path);
        errdefer allocator.free(root_path);

        var server = try (try std.net.Address.parseIp4("127.0.0.1", 0)).listen(.{ .reuse_address = true });
        errdefer server.deinit();

        self.* = .{
            .allocator = allocator,
            .root_path = root_path,
            .server = server,
        };
        self.thread = try std.Thread.spawn(.{}, serverMain, .{self});
        return self;
    }

    pub fn deinit(self: *UiServer) void {
        self.stop_requested.store(true, .seq_cst);
        self.server.deinit();
        if (self.thread) |thread| thread.join();
        self.allocator.free(self.root_path);
        self.allocator.destroy(self);
    }

    pub fn url(self: *const UiServer, allocator: std.mem.Allocator) ![:0]u8 {
        const value = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/", .{self.server.listen_address.getPort()});
        defer allocator.free(value);
        return allocator.dupeZ(u8, value);
    }
};

fn serverMain(self: *UiServer) void {
    while (!self.stop_requested.load(.seq_cst)) {
        const connection = self.server.accept() catch {
            if (self.stop_requested.load(.seq_cst)) break;
            continue;
        };
        handleConnection(self, connection) catch {};
    }
}

fn handleConnection(self: *UiServer, connection: std.net.Server.Connection) !void {
    defer connection.stream.close();

    var request_buffer: [8192]u8 = undefined;
    var total_read: usize = 0;

    while (total_read < request_buffer.len) {
        const bytes_read = try connection.stream.read(request_buffer[total_read..]);
        if (bytes_read == 0) break;
        total_read += bytes_read;
        if (std.mem.indexOf(u8, request_buffer[0..total_read], "\r\n\r\n") != null or
            std.mem.indexOf(u8, request_buffer[0..total_read], "\n\n") != null)
        {
            break;
        }
    }

    if (total_read == 0) return;

    const request = request_buffer[0..total_read];
    const request_line_end = std.mem.indexOf(u8, request, "\r\n") orelse std.mem.indexOfScalar(u8, request, '\n') orelse return;
    const request_line = request[0..request_line_end];

    var parts = std.mem.tokenizeScalar(u8, request_line, ' ');
    const method = parts.next() orelse return;
    const target = parts.next() orelse return;
    const headers_only = std.mem.eql(u8, method, "HEAD");

    if (!std.mem.eql(u8, method, "GET") and !headers_only) {
        try writeResponse(connection.stream, "405 Method Not Allowed", "text/plain; charset=utf-8", "Method Not Allowed", false);
        return;
    }

    const relative_path = sanitizePath(target) orelse {
        try writeResponse(connection.stream, "400 Bad Request", "text/plain; charset=utf-8", "Bad Request", headers_only);
        return;
    };

    const body_path = resolveBodyPath(self.allocator, self.root_path, relative_path) catch {
        try writeResponse(connection.stream, "404 Not Found", "text/plain; charset=utf-8", "Not Found", headers_only);
        return;
    };
    defer self.allocator.free(body_path);

    const file = std.fs.openFileAbsolute(body_path, .{}) catch {
        try writeResponse(connection.stream, "404 Not Found", "text/plain; charset=utf-8", "Not Found", headers_only);
        return;
    };
    defer file.close();

    const body = try file.readToEndAlloc(self.allocator, 8 * 1024 * 1024);
    defer self.allocator.free(body);

    try writeResponse(connection.stream, "200 OK", contentTypeForPath(body_path), body, headers_only);
}

fn sanitizePath(raw_target: []const u8) ?[]const u8 {
    const before_query = if (std.mem.indexOfScalar(u8, raw_target, '?')) |index|
        raw_target[0..index]
    else
        raw_target;
    if (!std.mem.startsWith(u8, before_query, "/")) return null;
    if (std.mem.eql(u8, before_query, "/")) return "index.html";

    const trimmed = std.mem.trimLeft(u8, before_query, "/");
    if (trimmed.len == 0) return "index.html";
    if (std.mem.indexOf(u8, trimmed, "..") != null) return null;
    if (std.mem.indexOfScalar(u8, trimmed, '\\') != null) return null;
    return trimmed;
}

fn resolveBodyPath(allocator: std.mem.Allocator, root_path: []const u8, relative_path: []const u8) ![]u8 {
    const joined = try std.fs.path.join(allocator, &.{ root_path, relative_path });
    errdefer allocator.free(joined);

    if (std.fs.openFileAbsolute(joined, .{})) |file| {
        file.close();
        return joined;
    } else |_| {
        allocator.free(joined);
    }

    const fallback = try std.fs.path.join(allocator, &.{ root_path, "index.html" });
    errdefer allocator.free(fallback);
    const fallback_file = try std.fs.openFileAbsolute(fallback, .{});
    fallback_file.close();
    return fallback;
}

fn writeResponse(
    stream: std.net.Stream,
    status: []const u8,
    content_type: []const u8,
    body: []const u8,
    headers_only: bool,
) !void {
    var buffer: [512]u8 = undefined;
    var fixed = std.io.fixedBufferStream(&buffer);
    try fixed.writer().print(
        "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
        .{ status, content_type, body.len },
    );
    try stream.writeAll(fixed.getWritten());
    if (!headers_only) {
        try stream.writeAll(body);
    }
}

fn contentTypeForPath(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".css")) return "text/css; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".js")) return "application/javascript; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".svg")) return "image/svg+xml";
    if (std.mem.endsWith(u8, path, ".json")) return "application/json; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".png")) return "image/png";
    if (std.mem.endsWith(u8, path, ".jpg") or std.mem.endsWith(u8, path, ".jpeg")) return "image/jpeg";
    if (std.mem.endsWith(u8, path, ".ico")) return "image/x-icon";
    return "application/octet-stream";
}
