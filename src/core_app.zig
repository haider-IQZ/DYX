const std = @import("std");
const models = @import("models.zig");
const axel = @import("axel.zig");
const settings = @import("settings.zig");
const history = @import("history.zig");
const download_manager = @import("download_manager.zig");

pub const EventSink = struct {
    ctx: *anyopaque,
    emit: *const fn (ctx: *anyopaque, event_name: []const u8, payload_json: []const u8) void,
};

pub const CoreApp = struct {
    allocator: std.mem.Allocator,
    settings_store: settings.Store,
    history_store: history.Store,
    downloads: download_manager.DownloadManager,
    axel_status: models.AxelStatus,
    sink: EventSink,

    pub fn init(allocator: std.mem.Allocator, sink: EventSink) !CoreApp {
        var settings_store = try settings.Store.init(allocator);
        errdefer settings_store.deinit();

        var history_store = try history.Store.init(allocator);
        errdefer history_store.deinit();

        var status = try axel.checkAvailability(allocator);
        errdefer status.deinit(allocator);

        return .{
            .allocator = allocator,
            .settings_store = settings_store,
            .history_store = history_store,
            .downloads = undefined,
            .axel_status = status,
            .sink = sink,
        };
    }

    pub fn attach(self: *CoreApp) !void {
        self.downloads = download_manager.DownloadManager.init(
            self.allocator,
            &self.history_store,
            &self.settings_store,
            .{ .ctx = self, .emit = emitFromManager },
        );
        try self.downloads.recoverShutdownRecovery();
    }

    pub fn deinit(self: *CoreApp) void {
        self.downloads.shutdown();
        self.downloads.deinit();
        self.history_store.deinit();
        self.settings_store.deinit();
        self.axel_status.deinit(self.allocator);
    }

    pub fn emitEvent(self: *CoreApp, event_name: []const u8, payload_json: []const u8) !void {
        self.sink.emit(self.sink.ctx, event_name, payload_json);
    }

    pub fn refreshAxelStatus(self: *CoreApp) !void {
        const updated = try axel.checkAvailability(self.allocator);
        self.axel_status.deinit(self.allocator);
        self.axel_status = updated;

        const json = try models.jsonStringifyAlloc(self.allocator, self.axel_status, .{});
        defer self.allocator.free(json);
        try self.emitEvent("axelAvailabilityChanged", json);
    }

    pub fn historyJson(self: *CoreApp, allocator: std.mem.Allocator) ![]u8 {
        return self.history_store.toJson(allocator);
    }

    pub fn settingsJson(self: *CoreApp, allocator: std.mem.Allocator) ![]u8 {
        return self.settings_store.toJson(allocator);
    }

    pub fn axelStatusJson(self: *CoreApp, allocator: std.mem.Allocator) ![]u8 {
        return models.jsonStringifyAlloc(allocator, self.axel_status, .{});
    }
};

fn emitFromManager(ctx: *anyopaque, event_name: []const u8, payload_json: []const u8) void {
    const app = @as(*CoreApp, @ptrCast(@alignCast(ctx)));
    app.emitEvent(event_name, payload_json) catch {};
}
