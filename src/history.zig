const std = @import("std");
const models = @import("models.zig");
const settings = @import("settings.zig");

pub const Store = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    items: std.array_list.Managed(models.StoredHistoryItem),

    pub fn init(allocator: std.mem.Allocator) !Store {
        const path = try historyPath(allocator);
        var store = Store{
            .allocator = allocator,
            .path = path,
            .items = std.array_list.Managed(models.StoredHistoryItem).init(allocator),
        };
        try store.load();
        return store;
    }

    pub fn deinit(self: *Store) void {
        for (self.items.items) |*item| item.deinit(self.allocator);
        self.items.deinit();
        self.allocator.free(self.path);
    }

    pub fn append(self: *Store, item: models.StoredHistoryItem) !void {
        _ = self.removeByOutputPathInternal(item.item.outputPath);
        try self.items.append(try item.cloneOwned(self.allocator));
        try self.save();
    }

    pub fn removeById(self: *Store, id: []const u8) !bool {
        for (self.items.items, 0..) |*entry, index| {
            if (std.mem.eql(u8, entry.item.id, id)) {
                entry.deinit(self.allocator);
                _ = self.items.orderedRemove(index);
                try self.save();
                return true;
            }
        }
        return false;
    }

    pub fn removeByOutputPath(self: *Store, output_path: []const u8) !usize {
        const removed = self.removeByOutputPathInternal(output_path);
        if (removed > 0) {
            try self.save();
        }
        return removed;
    }

    pub fn findById(self: *Store, id: []const u8) ?*const models.StoredHistoryItem {
        for (self.items.items) |*entry| {
            if (std.mem.eql(u8, entry.item.id, id)) return entry;
        }
        return null;
    }

    pub fn toJson(self: *const Store, allocator: std.mem.Allocator) ![]u8 {
        var public_items = try allocator.alloc(models.DownloadItem, self.items.items.len);
        defer allocator.free(public_items);
        for (self.items.items, 0..) |entry, index| {
            public_items[index] = entry.item;
        }
        return models.jsonStringifyAlloc(allocator, public_items, .{});
    }

    pub fn save(self: *Store) !void {
        const parent = std.fs.path.dirname(self.path) orelse return;
        try std.fs.cwd().makePath(parent);
        const bytes = try models.jsonStringifyAlloc(self.allocator, self.items.items, .{ .whitespace = .indent_2 });
        defer self.allocator.free(bytes);
        try std.fs.cwd().writeFile(.{ .sub_path = self.path, .data = bytes });
    }

    fn load(self: *Store) !void {
        const bytes = std.fs.cwd().readFileAlloc(self.allocator, self.path, 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(bytes);

        var parsed = try std.json.parseFromSlice([]models.StoredHistoryItem, self.allocator, bytes, .{});
        defer parsed.deinit();

        var changed = false;
        for (parsed.value) |item| {
            if (self.removeByOutputPathInternal(item.item.outputPath) > 0) {
                changed = true;
            }
            try self.items.append(try item.cloneOwned(self.allocator));
        }

        if (changed) {
            try self.save();
        }
    }

    fn removeByOutputPathInternal(self: *Store, output_path: []const u8) usize {
        var removed: usize = 0;
        var index: usize = 0;
        while (index < self.items.items.len) {
            const existing = &self.items.items[index];
            if (std.mem.eql(u8, existing.item.outputPath, output_path)) {
                existing.deinit(self.allocator);
                _ = self.items.orderedRemove(index);
                removed += 1;
                continue;
            }
            index += 1;
        }
        return removed;
    }
};

fn historyPath(allocator: std.mem.Allocator) ![]u8 {
    const dir = try settings.dataDir(allocator);
    defer allocator.free(dir);
    return std.fs.path.join(allocator, &.{ dir, "history.json" });
}

test "history export hides stored request details" {
    const allocator = std.testing.allocator;
    var store = Store{
        .allocator = allocator,
        .path = try allocator.dupe(u8, "/tmp/history.json"),
        .items = std.array_list.Managed(models.StoredHistoryItem).init(allocator),
    };
    defer store.deinit();

    var item = models.StoredHistoryItem{
        .item = .{
            .id = try allocator.dupe(u8, "1"),
            .url = try allocator.dupe(u8, "https://example.com/file.iso"),
            .outputPath = try allocator.dupe(u8, "/tmp/file.iso"),
            .status = .completed,
            .progressPercent = 100,
            .startedAt = 1,
            .finishedAt = 2,
        },
        .request = .{
            .url = try allocator.dupe(u8, "https://example.com/file.iso"),
            .outputPath = try allocator.dupe(u8, "/tmp/file.iso"),
        },
    };
    defer item.deinit(allocator);

    try store.append(item);
    const json = try store.toJson(allocator);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"request\"") == null);
}
