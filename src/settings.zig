const std = @import("std");
const models = @import("models.zig");

pub const Store = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    settings: models.AppSettings,

    pub fn init(allocator: std.mem.Allocator) !Store {
        const path = try dataFilePath(allocator, "settings.json");
        var loaded = loadSettings(allocator, path) catch try defaultSettings(allocator);
        const repaired = try sanitizeSettings(allocator, &loaded);

        var store = Store{
            .allocator = allocator,
            .path = path,
            .settings = loaded,
        };
        if (repaired) {
            try store.save();
        }
        return store;
    }

    pub fn deinit(self: *Store) void {
        self.settings.deinit(self.allocator);
        self.allocator.free(self.path);
    }

    pub fn get(self: *const Store) models.AppSettings {
        return self.settings;
    }

    pub fn set(self: *Store, incoming: models.AppSettings) !void {
        const replacement = try incoming.cloneOwned(self.allocator);
        self.settings.deinit(self.allocator);
        self.settings = replacement;
        try self.save();
    }

    pub fn toJson(self: *const Store, allocator: std.mem.Allocator) ![]u8 {
        return models.jsonStringifyAlloc(allocator, self.settings, .{});
    }

    pub fn save(self: *Store) !void {
        try ensureParentDir(self.path);
        const bytes = try models.jsonStringifyAlloc(self.allocator, self.settings, .{ .whitespace = .indent_2 });
        defer self.allocator.free(bytes);
        try std.fs.cwd().writeFile(.{ .sub_path = self.path, .data = bytes });
    }
};

fn loadSettings(allocator: std.mem.Allocator, path: []const u8) !models.AppSettings {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 64);
    defer allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(models.AppSettings, allocator, bytes, .{});
    defer parsed.deinit();
    return parsed.value.cloneOwned(allocator);
}

fn defaultSettings(allocator: std.mem.Allocator) !models.AppSettings {
    const home = try envOwned(allocator, "HOME");
    defer allocator.free(home);
    const default_dir = try std.fs.path.join(allocator, &.{ home, "Downloads" });
    return .{
        .defaultDownloadDir = default_dir,
        .defaultConnections = 8,
        .defaultMaxSpeedBytes = null,
        .defaultNoClobber = false,
        .defaultTimeoutSeconds = 30,
        .maxConcurrentDownloads = 0,
        .autoRetryOnFail = true,
        .theme = .system,
    };
}

pub fn dataDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "XDG_DATA_HOME")) |xdg| {
        defer allocator.free(xdg);
        return std.fs.path.join(allocator, &.{ xdg, "dyx" });
    } else |_| {}

    const home = try envOwned(allocator, "HOME");
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".local", "share", "dyx" });
}

fn dataFilePath(allocator: std.mem.Allocator, file_name: []const u8) ![]u8 {
    const dir = try dataDir(allocator);
    defer allocator.free(dir);
    return std.fs.path.join(allocator, &.{ dir, file_name });
}

fn ensureParentDir(path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    try std.fs.cwd().makePath(parent);
}

fn envOwned(allocator: std.mem.Allocator, key: []const u8) ![]u8 {
    return std.process.getEnvVarOwned(allocator, key) catch error.MissingEnvironmentVariable;
}

fn sanitizeSettings(allocator: std.mem.Allocator, settings_value: *models.AppSettings) !bool {
    if (isValidDirectoryValue(settings_value.defaultDownloadDir)) {
        return false;
    }

    allocator.free(settings_value.defaultDownloadDir);
    settings_value.defaultDownloadDir = try defaultDownloadDir(allocator);
    return true;
}

fn isValidDirectoryValue(value: []const u8) bool {
    if (value.len == 0) return false;
    if (!std.unicode.utf8ValidateSlice(value)) return false;
    return std.fs.path.isAbsolute(value);
}

fn defaultDownloadDir(allocator: std.mem.Allocator) ![]u8 {
    const home = try envOwned(allocator, "HOME");
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, "Downloads" });
}

test "settings can round-trip" {
    const allocator = std.testing.allocator;
    var settings_value = models.AppSettings{
        .defaultDownloadDir = try allocator.dupe(u8, "/tmp/downloads"),
        .defaultConnections = 12,
        .defaultMaxSpeedBytes = 1234,
        .defaultNoClobber = true,
        .defaultTimeoutSeconds = 60,
        .maxConcurrentDownloads = 3,
        .autoRetryOnFail = false,
        .theme = .dark,
    };
    defer settings_value.deinit(allocator);

    const encoded = try models.jsonStringifyAlloc(allocator, settings_value, .{});
    defer allocator.free(encoded);

    var parsed = try std.json.parseFromSlice(models.AppSettings, allocator, encoded, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("/tmp/downloads", parsed.value.defaultDownloadDir);
    try std.testing.expectEqual(@as(u32, 12), parsed.value.defaultConnections);
    try std.testing.expect(parsed.value.defaultNoClobber);
    try std.testing.expectEqual(@as(u32, 3), parsed.value.maxConcurrentDownloads);
    try std.testing.expect(!parsed.value.autoRetryOnFail);
}
