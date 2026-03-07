const std = @import("std");
const models = @import("models.zig");

pub fn buildArgv(
    allocator: std.mem.Allocator,
    request: models.StartDownloadRequest,
) ![]const []const u8 {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    try argv.append("axel");
    try argv.append("-a");

    if (request.outputPath) |value| {
        try argv.append("-o");
        try argv.append(std.fs.path.basename(value));
    }
    if (request.connections) |value| {
        try appendNumberArg(&argv, allocator, "-n", value);
    }
    if (request.maxSpeedBytes) |value| {
        try appendNumberArg(&argv, allocator, "-s", value);
    }
    if (request.timeoutSeconds) |value| {
        try appendNumberArg(&argv, allocator, "-T", value);
    }
    if (request.userAgent) |value| {
        try argv.append("-U");
        try argv.append(value);
    }
    if (request.headers) |headers| {
        for (headers) |header| {
            try argv.append("-H");
            try argv.append(header);
        }
    }
    if (request.ipv4) try argv.append("-4");
    if (request.ipv6) try argv.append("-6");
    if (request.noProxy) try argv.append("-N");
    if (request.insecure) try argv.append("-k");
    if (request.noClobber) try argv.append("-c");

    try argv.append(request.url);
    return argv.toOwnedSlice();
}

pub const ProgressUpdate = struct {
    progress: u8,
    speed_text: ?[]const u8 = null,
    eta_text: ?[]const u8 = null,
};

pub fn parseTotalBytesLine(line: []const u8) ?u64 {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (!std.mem.startsWith(u8, trimmed, "File size:")) return null;

    const open_paren = std.mem.lastIndexOfScalar(u8, trimmed, '(') orelse return null;
    const bytes_suffix = " bytes)";
    if (!std.mem.endsWith(u8, trimmed, bytes_suffix)) return null;

    const digits = std.mem.trim(u8, trimmed[open_paren + 1 .. trimmed.len - bytes_suffix.len], " ");
    if (digits.len == 0) return null;
    return std.fmt.parseInt(u64, digits, 10) catch null;
}

pub fn parseProgressLine(line: []const u8) ?u8 {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return null;
    const parsed = std.fmt.parseInt(u16, trimmed, 10) catch return null;
    if (parsed > 100) return 100;
    return @intCast(parsed);
}

pub fn parseProgressUpdate(line: []const u8) ?ProgressUpdate {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return null;

    if (parseAlternateProgressLine(trimmed)) |update| return update;
    if (parseProgressLine(trimmed)) |progress| {
        return .{ .progress = progress };
    }
    return null;
}

pub fn checkAvailability(allocator: std.mem.Allocator) !models.AxelStatus {
    const which_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-c", "command -v axel" },
    });
    defer allocator.free(which_result.stdout);
    defer allocator.free(which_result.stderr);

    return switch (which_result.term) {
        .Exited => |code| if (code == 0) blk: {
            const path = try allocator.dupe(u8, std.mem.trim(u8, which_result.stdout, " \t\r\n"));
            const version = try detectVersion(allocator);
            break :blk models.AxelStatus{
                .available = true,
                .version = version,
                .path = path,
                .message = if (version) |value|
                    try std.fmt.allocPrint(allocator, "{s} via {s}", .{ value, path })
                else
                    try std.fmt.allocPrint(allocator, "Using {s}", .{path}),
            };
        } else models.AxelStatus{
            .available = false,
            .version = null,
            .path = null,
            .message = try allocator.dupe(u8, "Axel was not found in PATH"),
        },
        else => models.AxelStatus{
            .available = false,
            .version = null,
            .path = null,
            .message = try allocator.dupe(u8, "Axel availability check did not exit cleanly"),
        },
    };
}

pub fn openPath(allocator: std.mem.Allocator, path: []const u8) !void {
    var child = std.process.Child.init(&.{ "xdg-open", path }, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();
}

pub fn deleteFile(path: []const u8) !void {
    try deleteIfExists(path);

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const state_path = try std.fmt.bufPrint(&buf, "{s}.st", .{path});
    try deleteIfExists(state_path);
    try deleteLegacyStateFiles(path);
}

fn deleteIfExists(path: []const u8) !void {
    if (std.fs.deleteFileAbsolute(path)) {
        return;
    } else |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    }
}

fn deleteLegacyStateFiles(path: []const u8) !void {
    const dir_path = std.fs.path.dirname(path) orelse return;
    const base_name = std.fs.path.basename(path);

    var dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!isLegacyStateSidecar(entry.name, base_name)) continue;
        dir.deleteFile(entry.name) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
    }
}

fn isLegacyStateSidecar(entry_name: []const u8, base_name: []const u8) bool {
    if (!std.mem.startsWith(u8, entry_name, base_name)) return false;
    if (!std.mem.endsWith(u8, entry_name, ".st")) return false;
    if (entry_name.len <= base_name.len + 4) return false;
    return entry_name[base_name.len] == '?';
}

fn appendNumberArg(
    argv: *std.array_list.Managed([]const u8),
    allocator: std.mem.Allocator,
    flag: []const u8,
    value: anytype,
) !void {
    try argv.append(flag);
    try argv.append(try std.fmt.allocPrint(allocator, "{}", .{value}));
}

fn detectVersion(allocator: std.mem.Allocator) !?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "axel", "--version" },
    }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .Exited => |code| if (code == 0) blk: {
            const first_line = std.mem.trim(u8, result.stdout, " \t\r\n");
            const end_index = std.mem.indexOfScalar(u8, first_line, '\n') orelse first_line.len;
            const version_line = std.mem.trim(u8, first_line[0..end_index], " \t\r\n");
            if (version_line.len == 0) break :blk null;
            break :blk try allocator.dupe(u8, version_line);
        } else null,
        else => null,
    };
}

test "build argv includes machine-friendly output" {
    const allocator = std.testing.allocator;
    const request = models.StartDownloadRequest{
        .url = "https://example.com/file.bin",
        .outputPath = "/tmp/file.bin",
        .connections = 4,
        .noProxy = true,
    };
    const argv = try buildArgv(allocator, request);
    defer {
        for (argv) |value| {
            if (std.mem.startsWith(u8, value, "https://")) continue;
            if (std.mem.eql(u8, value, "axel")) continue;
            if (std.mem.eql(u8, value, "-a")) continue;
            if (std.mem.eql(u8, value, "-o")) continue;
            if (std.mem.eql(u8, value, "file.bin")) continue;
            if (std.mem.eql(u8, value, "-n")) continue;
            if (std.mem.eql(u8, value, "4")) allocator.free(value);
        }
        allocator.free(argv);
    }
    try std.testing.expectEqualStrings("axel", argv[0]);
    try std.testing.expectEqualStrings("-a", argv[1]);
}

test "parse progress line handles simple percentages" {
    try std.testing.expectEqual(@as(?u8, 42), parseProgressLine("42\n"));
    try std.testing.expectEqual(@as(?u8, null), parseProgressLine("[ 42%]"));
    try std.testing.expectEqual(@as(?u8, 100), parseProgressLine("150"));
}

test "parse alternate progress line handles speed and eta" {
    const parsed = parseProgressUpdate("[ 61%] [....] [   4.4MB/s] [00:03]") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u8, 61), parsed.progress);
    try std.testing.expectEqualStrings("4.4MB/s", parsed.speed_text.?);
    try std.testing.expectEqualStrings("00:03", parsed.eta_text.?);
}

test "parse alternate progress line ignores malformed input" {
    try std.testing.expectEqual(@as(?ProgressUpdate, null), parseProgressUpdate("Initializing download"));
}

test "parse file size line extracts bytes" {
    try std.testing.expectEqual(@as(?u64, 5242880), parseTotalBytesLine("File size: 5 Megabyte(s) (5242880 bytes)"));
    try std.testing.expectEqual(@as(?u64, null), parseTotalBytesLine("Opening output file sample.iso"));
}

test "legacy state sidecar detection matches old query-string filenames" {
    try std.testing.expect(isLegacyStateSidecar(
        "video.mp4?response-content-disposition=attachment%3B%20filename%3D%22video.mp4%22.st",
        "video.mp4",
    ));
    try std.testing.expect(!isLegacyStateSidecar("video.mp4.st", "video.mp4"));
    try std.testing.expect(!isLegacyStateSidecar("video.mp4.tmp", "video.mp4"));
}

fn parseAlternateProgressLine(line: []const u8) ?ProgressUpdate {
    const progress_group = nthBracketContent(line, 0) orelse return null;
    const progress_trimmed = std.mem.trim(u8, progress_group, " ");
    if (progress_trimmed.len == 0 or progress_trimmed[progress_trimmed.len - 1] != '%') return null;

    const progress_value = std.fmt.parseInt(u16, std.mem.trim(u8, progress_trimmed[0 .. progress_trimmed.len - 1], " "), 10) catch return null;

    return .{
        .progress = if (progress_value > 100) 100 else @intCast(progress_value),
        .speed_text = if (nthBracketContent(line, 2)) |speed_group| nonEmptyTrimmed(speed_group) else null,
        .eta_text = if (nthBracketContent(line, 3)) |eta_group| nonEmptyTrimmed(eta_group) else null,
    };
}

fn nthBracketContent(line: []const u8, target_index: usize) ?[]const u8 {
    var search_from: usize = 0;
    var bracket_index: usize = 0;

    while (std.mem.indexOfScalarPos(u8, line, search_from, '[')) |open_index| {
        const close_index = std.mem.indexOfScalarPos(u8, line, open_index + 1, ']') orelse return null;
        if (bracket_index == target_index) {
            return line[open_index + 1 .. close_index];
        }
        bracket_index += 1;
        search_from = close_index + 1;
    }

    return null;
}

fn nonEmptyTrimmed(value: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, value, " ");
    if (trimmed.len == 0) return null;
    return trimmed;
}
