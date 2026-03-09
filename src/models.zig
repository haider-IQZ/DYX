const std = @import("std");

pub const Theme = enum {
    system,
    light,
    dark,
};

pub const DownloadStatus = enum {
    queued,
    starting,
    downloading,
    completed,
    failed,
    cancelled,
};

pub const StartDownloadRequest = struct {
    url: []const u8,
    outputPath: ?[]const u8 = null,
    connections: ?u32 = null,
    maxSpeedBytes: ?u64 = null,
    headers: ?[]const []const u8 = null,
    userAgent: ?[]const u8 = null,
    ipv4: bool = false,
    ipv6: bool = false,
    noProxy: bool = false,
    insecure: bool = false,
    noClobber: bool = false,
    timeoutSeconds: ?u32 = null,

    pub fn cloneOwned(self: StartDownloadRequest, allocator: std.mem.Allocator) !StartDownloadRequest {
        var cloned = StartDownloadRequest{
            .url = try allocator.dupe(u8, self.url),
            .outputPath = if (self.outputPath) |value| try allocator.dupe(u8, value) else null,
            .connections = self.connections,
            .maxSpeedBytes = self.maxSpeedBytes,
            .headers = null,
            .userAgent = if (self.userAgent) |value| try allocator.dupe(u8, value) else null,
            .ipv4 = self.ipv4,
            .ipv6 = self.ipv6,
            .noProxy = self.noProxy,
            .insecure = self.insecure,
            .noClobber = self.noClobber,
            .timeoutSeconds = self.timeoutSeconds,
        };

        if (self.headers) |headers| {
            var duped = try allocator.alloc([]const u8, headers.len);
            for (headers, 0..) |header, index| {
                duped[index] = try allocator.dupe(u8, header);
            }
            cloned.headers = duped;
        }

        return cloned;
    }

    pub fn deinit(self: *StartDownloadRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        if (self.outputPath) |value| allocator.free(value);
        if (self.userAgent) |value| allocator.free(value);
        if (self.headers) |headers| {
            for (headers) |header| allocator.free(header);
            allocator.free(headers);
        }
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "url", self.url);
        try writeOptionalStringField(jws, "outputPath", self.outputPath);
        try writeOptionalField(jws, "connections", self.connections);
        try writeOptionalField(jws, "maxSpeedBytes", self.maxSpeedBytes);
        try writeOptionalStringArrayField(jws, "headers", self.headers);
        try writeOptionalStringField(jws, "userAgent", self.userAgent);
        try writeField(jws, "ipv4", self.ipv4);
        try writeField(jws, "ipv6", self.ipv6);
        try writeField(jws, "noProxy", self.noProxy);
        try writeField(jws, "insecure", self.insecure);
        try writeField(jws, "noClobber", self.noClobber);
        try writeOptionalField(jws, "timeoutSeconds", self.timeoutSeconds);
        try jws.endObject();
    }
};

pub const AppSettings = struct {
    defaultDownloadDir: []const u8,
    defaultConnections: u32 = 32,
    defaultMaxSpeedBytes: ?u64 = null,
    defaultNoClobber: bool = false,
    defaultTimeoutSeconds: u32 = 30,
    maxConcurrentDownloads: u32 = 0,
    autoRetryOnFail: bool = true,
    theme: Theme = .system,

    pub fn cloneOwned(self: AppSettings, allocator: std.mem.Allocator) !AppSettings {
        return .{
            .defaultDownloadDir = try allocator.dupe(u8, self.defaultDownloadDir),
            .defaultConnections = self.defaultConnections,
            .defaultMaxSpeedBytes = self.defaultMaxSpeedBytes,
            .defaultNoClobber = self.defaultNoClobber,
            .defaultTimeoutSeconds = self.defaultTimeoutSeconds,
            .maxConcurrentDownloads = self.maxConcurrentDownloads,
            .autoRetryOnFail = self.autoRetryOnFail,
            .theme = self.theme,
        };
    }

    pub fn deinit(self: *AppSettings, allocator: std.mem.Allocator) void {
        allocator.free(self.defaultDownloadDir);
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "defaultDownloadDir", self.defaultDownloadDir);
        try writeField(jws, "defaultConnections", self.defaultConnections);
        try writeOptionalField(jws, "defaultMaxSpeedBytes", self.defaultMaxSpeedBytes);
        try writeField(jws, "defaultNoClobber", self.defaultNoClobber);
        try writeField(jws, "defaultTimeoutSeconds", self.defaultTimeoutSeconds);
        try writeField(jws, "maxConcurrentDownloads", self.maxConcurrentDownloads);
        try writeField(jws, "autoRetryOnFail", self.autoRetryOnFail);
        try writeField(jws, "theme", self.theme);
        try jws.endObject();
    }
};

pub const AxelStatus = struct {
    available: bool,
    version: ?[]const u8 = null,
    path: ?[]const u8 = null,
    message: ?[]const u8 = null,

    pub fn cloneOwned(self: AxelStatus, allocator: std.mem.Allocator) !AxelStatus {
        return .{
            .available = self.available,
            .version = if (self.version) |value| try allocator.dupe(u8, value) else null,
            .path = if (self.path) |value| try allocator.dupe(u8, value) else null,
            .message = if (self.message) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: *AxelStatus, allocator: std.mem.Allocator) void {
        if (self.version) |value| allocator.free(value);
        if (self.path) |value| allocator.free(value);
        if (self.message) |value| allocator.free(value);
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "available", self.available);
        try writeOptionalStringField(jws, "version", self.version);
        try writeOptionalStringField(jws, "path", self.path);
        try writeOptionalStringField(jws, "message", self.message);
        try jws.endObject();
    }
};

pub const DownloadItem = struct {
    id: []const u8,
    url: []const u8,
    outputPath: []const u8,
    status: DownloadStatus,
    progressPercent: u8 = 0,
    downloadedBytes: ?u64 = null,
    totalBytes: ?u64 = null,
    speedText: ?[]const u8 = null,
    etaText: ?[]const u8 = null,
    errorMessage: ?[]const u8 = null,
    startedAt: i64,
    finishedAt: ?i64 = null,

    pub fn cloneOwned(self: DownloadItem, allocator: std.mem.Allocator) !DownloadItem {
        return .{
            .id = try allocator.dupe(u8, self.id),
            .url = try allocator.dupe(u8, self.url),
            .outputPath = try allocator.dupe(u8, self.outputPath),
            .status = self.status,
            .progressPercent = self.progressPercent,
            .downloadedBytes = self.downloadedBytes,
            .totalBytes = self.totalBytes,
            .speedText = if (self.speedText) |value| try allocator.dupe(u8, value) else null,
            .etaText = if (self.etaText) |value| try allocator.dupe(u8, value) else null,
            .errorMessage = if (self.errorMessage) |value| try allocator.dupe(u8, value) else null,
            .startedAt = self.startedAt,
            .finishedAt = self.finishedAt,
        };
    }

    pub fn deinit(self: *DownloadItem, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.url);
        allocator.free(self.outputPath);
        if (self.speedText) |value| allocator.free(value);
        if (self.etaText) |value| allocator.free(value);
        if (self.errorMessage) |value| allocator.free(value);
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "id", self.id);
        try writeField(jws, "url", self.url);
        try writeField(jws, "outputPath", self.outputPath);
        try writeField(jws, "status", self.status);
        try writeField(jws, "progressPercent", self.progressPercent);
        try writeOptionalField(jws, "downloadedBytes", self.downloadedBytes);
        try writeOptionalField(jws, "totalBytes", self.totalBytes);
        try writeOptionalStringField(jws, "speedText", self.speedText);
        try writeOptionalStringField(jws, "etaText", self.etaText);
        try writeOptionalStringField(jws, "errorMessage", self.errorMessage);
        try writeField(jws, "startedAt", self.startedAt);
        try writeOptionalField(jws, "finishedAt", self.finishedAt);
        try jws.endObject();
    }
};

pub const StoredHistoryItem = struct {
    item: DownloadItem,
    request: StartDownloadRequest,

    pub fn cloneOwned(self: StoredHistoryItem, allocator: std.mem.Allocator) !StoredHistoryItem {
        return .{
            .item = try self.item.cloneOwned(allocator),
            .request = try self.request.cloneOwned(allocator),
        };
    }

    pub fn deinit(self: *StoredHistoryItem, allocator: std.mem.Allocator) void {
        self.item.deinit(allocator);
        self.request.deinit(allocator);
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try writeField(jws, "item", self.item);
        try writeField(jws, "request", self.request);
        try jws.endObject();
    }
};

pub fn nowMillis() i64 {
    return @divTrunc(std.time.milliTimestamp(), 1);
}

pub fn jsonStringifyAlloc(
    allocator: std.mem.Allocator,
    value: anytype,
    options: std.json.Stringify.Options,
) ![]u8 {
    return std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(value, options)});
}

fn writeField(jws: anytype, key: []const u8, value: anytype) !void {
    try jws.objectField(key);
    try jws.write(value);
}

fn writeOptionalField(jws: anytype, key: []const u8, value: anytype) !void {
    try jws.objectField(key);
    try jws.write(value);
}

fn writeOptionalStringField(jws: anytype, key: []const u8, value: ?[]const u8) !void {
    try jws.objectField(key);
    if (value) |string| {
        try jws.write(string);
    } else {
        try jws.write(null);
    }
}

fn writeOptionalStringArrayField(jws: anytype, key: []const u8, value: ?[]const []const u8) !void {
    try jws.objectField(key);
    if (value) |items| {
        try jws.beginArray();
        for (items) |item| {
            try jws.write(item);
        }
        try jws.endArray();
    } else {
        try jws.write(null);
    }
}

test "app settings stringify uses JSON strings for paths" {
    const allocator = std.testing.allocator;
    var settings_value = AppSettings{
        .defaultDownloadDir = try allocator.dupe(u8, "/home/test/Downloads"),
        .defaultConnections = 8,
        .defaultMaxSpeedBytes = null,
        .defaultNoClobber = false,
        .defaultTimeoutSeconds = 30,
        .theme = .system,
    };
    defer settings_value.deinit(allocator);

    const encoded = try jsonStringifyAlloc(allocator, settings_value, .{});
    defer allocator.free(encoded);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"defaultDownloadDir\":\"/home/test/Downloads\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "[47,104,111") == null);
}
