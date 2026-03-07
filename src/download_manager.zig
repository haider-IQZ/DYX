const std = @import("std");
const models = @import("models.zig");
const axel = @import("axel.zig");
const history = @import("history.zig");
const settings = @import("settings.zig");

pub const EventSink = struct {
    ctx: *anyopaque,
    emit: *const fn (ctx: *anyopaque, event_name: []const u8, payload_json: []const u8) void,
};

const DownloadRuntime = struct {
    manager: *DownloadManager,
    id: []const u8,
    pid: ?std.posix.pid_t = null,
    cancel_mutex: std.Thread.Mutex = .{},
    cancel_requested: bool = false,
    stderr_mutex: std.Thread.Mutex = .{},
    stderr_buffer: std.array_list.Managed(u8),

    fn init(allocator: std.mem.Allocator, manager: *DownloadManager, id: []const u8) DownloadRuntime {
        return .{
            .manager = manager,
            .id = id,
            .stderr_buffer = std.array_list.Managed(u8).init(allocator),
        };
    }
};

const DownloadRecord = struct {
    item: models.DownloadItem,
    request: models.StartDownloadRequest,
    runtime: ?*DownloadRuntime = null,
};

pub const DownloadManager = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    next_id: usize = 1,
    active_workers: usize = 0,
    records: std.array_list.Managed(DownloadRecord),
    history_store: *history.Store,
    settings_store: *settings.Store,
    sink: EventSink,

    pub fn init(
        allocator: std.mem.Allocator,
        history_store: *history.Store,
        settings_store: *settings.Store,
        sink: EventSink,
    ) DownloadManager {
        return .{
            .allocator = allocator,
            .records = std.array_list.Managed(DownloadRecord).init(allocator),
            .history_store = history_store,
            .settings_store = settings_store,
            .sink = sink,
        };
    }

    pub fn shutdown(self: *DownloadManager) void {
        self.writeShutdownRecoverySnapshot() catch {};
        while (true) {
            var pids = std.array_list.Managed(std.posix.pid_t).init(self.allocator);
            defer pids.deinit();

            self.mutex.lock();
            const remaining = self.records.items.len;
            const workers = self.active_workers;
            for (self.records.items) |record| {
                if (record.runtime) |runtime| {
                    runtime.cancel_mutex.lock();
                    runtime.cancel_requested = true;
                    if (runtime.pid) |process_id| {
                        pids.append(process_id) catch {};
                    }
                    runtime.cancel_mutex.unlock();
                }
            }
            self.mutex.unlock();

            if (remaining == 0 and workers == 0) break;

            for (pids.items) |process_id| {
                std.posix.kill(process_id, std.posix.SIG.TERM) catch {};
            }

            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }

    pub fn recoverShutdownRecovery(self: *DownloadManager) !void {
        const path = try shutdownRecoveryPath(self.allocator);
        defer self.allocator.free(path);

        const bytes = std.fs.cwd().readFileAlloc(self.allocator, path, 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(bytes);
        defer std.fs.deleteFileAbsolute(path) catch {};

        var parsed = try std.json.parseFromSlice([]models.StoredHistoryItem, self.allocator, bytes, .{});
        defer parsed.deinit();

        for (parsed.value) |entry| {
            if (self.history_store.findById(entry.item.id) != null) continue;

            var recovered = try entry.cloneOwned(self.allocator);
            defer recovered.deinit(self.allocator);

            recovered.item.status = .cancelled;
            recovered.item.finishedAt = models.nowMillis();

            if (recovered.item.errorMessage) |value| {
                self.allocator.free(value);
            }
            recovered.item.errorMessage = try self.allocator.dupe(u8, "Download paused when app closed");

            try self.history_store.append(recovered);
        }
    }

    pub fn deinit(self: *DownloadManager) void {
        for (self.records.items) |*record| {
            record.item.deinit(self.allocator);
            record.request.deinit(self.allocator);
            if (record.runtime) |runtime| {
                runtime.stderr_buffer.deinit();
                self.allocator.destroy(runtime);
            }
        }
        self.records.deinit();
    }

    pub fn startDownload(self: *DownloadManager, request: models.StartDownloadRequest) ![]u8 {
        var owned_request = try self.normalizeRequest(request);
        errdefer owned_request.deinit(self.allocator);

        const output_path = if (owned_request.outputPath) |value|
            try self.allocator.dupe(u8, value)
        else
            try deriveOutputPath(self.allocator, self.settings_store.get(), owned_request.url);
        errdefer self.allocator.free(output_path);

        if (owned_request.outputPath == null) {
            owned_request.outputPath = try self.allocator.dupe(u8, output_path);
        }

        self.mutex.lock();
        var lock_held = true;
        defer if (lock_held) self.mutex.unlock();

        for (self.records.items) |record| {
            if (std.mem.eql(u8, record.item.outputPath, output_path)) {
                return error.DownloadAlreadyActive;
            }
        }

        const id = try std.fmt.allocPrint(self.allocator, "dl_{d}", .{self.next_id});
        errdefer self.allocator.free(id);

        var item = models.DownloadItem{
            .id = id,
            .url = try self.allocator.dupe(u8, owned_request.url),
            .outputPath = output_path,
            .status = .queued,
            .progressPercent = 0,
            .startedAt = models.nowMillis(),
            .finishedAt = null,
        };
        errdefer item.deinit(self.allocator);

        const runtime = try self.allocator.create(DownloadRuntime);
        runtime.* = DownloadRuntime.init(self.allocator, self, id);

        const record = DownloadRecord{
            .item = item,
            .request = owned_request,
            .runtime = runtime,
        };
        self.next_id += 1;
        try self.records.append(record);
        self.active_workers += 1;

        try self.emitRecordByIdLocked(id, "downloadStateChanged");
        const thread = std.Thread.spawn(.{}, downloadThreadMain, .{runtime}) catch |err| {
            self.active_workers -= 1;
            var failed_record = self.records.pop().?;
            failed_record.item.deinit(self.allocator);
            failed_record.request.deinit(self.allocator);
            if (failed_record.runtime) |failed_runtime| {
                failed_runtime.stderr_buffer.deinit();
                self.allocator.destroy(failed_runtime);
            }
            return err;
        };
        thread.detach();
        lock_held = false;
        self.mutex.unlock();
        try self.writeShutdownRecoverySnapshot();

        return models.jsonStringifyAlloc(self.allocator, item, .{});
    }

    pub fn listJson(self: *DownloadManager, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var public_items = try allocator.alloc(models.DownloadItem, self.records.items.len);
        defer allocator.free(public_items);
        for (self.records.items, 0..) |record, index| {
            public_items[index] = record.item;
        }
        return models.jsonStringifyAlloc(allocator, public_items, .{});
    }

    pub fn cancelDownload(self: *DownloadManager, id: []const u8) !bool {
        self.mutex.lock();
        const record = self.findRecordByIdLocked(id) orelse {
            self.mutex.unlock();
            return false;
        };
        const runtime = record.runtime;
        self.mutex.unlock();

        if (runtime) |state| {
            state.cancel_mutex.lock();
            state.cancel_requested = true;
            const pid = state.pid;
            state.cancel_mutex.unlock();
            if (pid) |process_id| {
                std.posix.kill(process_id, std.posix.SIG.TERM) catch {};
            }
            return true;
        }

        return false;
    }

    pub fn retryDownload(self: *DownloadManager, id: []const u8) ![]u8 {
        if (self.history_store.findById(id)) |entry| {
            return self.startDownload(entry.request);
        }

        self.mutex.lock();
        const cloned_request = if (self.findRecordByIdLocked(id)) |record|
            try record.request.cloneOwned(self.allocator)
        else
            null;
        self.mutex.unlock();

        if (cloned_request) |request| {
            defer {
                var mutable = request;
                mutable.deinit(self.allocator);
            }
            return self.startDownload(request);
        }
        return error.NotFound;
    }

    fn normalizeRequest(self: *DownloadManager, incoming: models.StartDownloadRequest) !models.StartDownloadRequest {
        var cloned = try incoming.cloneOwned(self.allocator);
        const current_settings = self.settings_store.get();
        if (cloned.connections == null) cloned.connections = current_settings.defaultConnections;
        if (cloned.maxSpeedBytes == null) cloned.maxSpeedBytes = current_settings.defaultMaxSpeedBytes;
        if (cloned.timeoutSeconds == null) cloned.timeoutSeconds = current_settings.defaultTimeoutSeconds;
        if (!cloned.noClobber) cloned.noClobber = current_settings.defaultNoClobber;
        return cloned;
    }

    fn updateStatus(self: *DownloadManager, id: []const u8, status: models.DownloadStatus) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.findRecordByIdLocked(id)) |record| {
            record.item.status = status;
            if (status == .completed) record.item.progressPercent = 100;
            if (status == .completed or status == .failed or status == .cancelled) {
                record.item.finishedAt = models.nowMillis();
            }
            try self.emitRecordByIdLocked(id, "downloadStateChanged");
        }
    }

    fn updateProgress(self: *DownloadManager, id: []const u8, progress: axel.ProgressUpdate) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.findRecordByIdLocked(id)) |record| {
            var changed = record.item.status != .downloading or record.item.progressPercent != progress.progress;
            record.item.status = .downloading;
            record.item.progressPercent = progress.progress;
            changed = (try replaceOptionalString(self.allocator, &record.item.speedText, progress.speed_text)) or changed;
            changed = (try replaceOptionalString(self.allocator, &record.item.etaText, progress.eta_text)) or changed;
            if (changed) {
                try self.emitRecordByIdLocked(id, "downloadStateChanged");
            }
        }
    }

    fn updateTotalBytes(self: *DownloadManager, id: []const u8, total_bytes: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.findRecordByIdLocked(id)) |record| {
            var changed = record.item.totalBytes != total_bytes;
            record.item.totalBytes = total_bytes;
            if (record.item.downloadedBytes) |current| {
                const clamped = @min(current, total_bytes);
                changed = changed or current != clamped;
                record.item.downloadedBytes = clamped;
            }
            if (changed) {
                try self.emitRecordByIdLocked(id, "downloadStateChanged");
            }
        }
    }

    fn updateDownloadedBytesFromDisk(self: *DownloadManager, id: []const u8, downloaded_bytes: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.findRecordByIdLocked(id)) |record| {
            const clamped = if (record.item.totalBytes) |total_bytes|
                @min(downloaded_bytes, total_bytes)
            else
                downloaded_bytes;
            if (record.item.downloadedBytes == clamped) return;
            record.item.downloadedBytes = clamped;
            try self.emitRecordByIdLocked(id, "downloadStateChanged");
        }
    }

    fn appendStderr(_: *DownloadManager, runtime: *DownloadRuntime, chunk: []const u8) !void {
        runtime.stderr_mutex.lock();
        defer runtime.stderr_mutex.unlock();
        try runtime.stderr_buffer.appendSlice(chunk);
    }

    fn complete(self: *DownloadManager, id: []const u8, status: models.DownloadStatus, message: ?[]const u8) !void {
        var history_item: ?models.StoredHistoryItem = null;
        defer if (history_item) |*value| value.deinit(self.allocator);
        var removed_id: ?[]const u8 = null;

        self.mutex.lock();
        if (findRecordIndexByIdLocked(self, id)) |index| {
            var record = self.records.items[index];
            record.item.status = status;
            if (status == .completed) record.item.progressPercent = 100;
            if (status == .completed) {
                if (record.item.totalBytes) |total_bytes| {
                    record.item.downloadedBytes = total_bytes;
                }
            }
            record.item.finishedAt = models.nowMillis();
            if (record.item.errorMessage) |value| self.allocator.free(value);
            record.item.errorMessage = if (message) |value| try self.allocator.dupe(u8, value) else null;
            history_item = .{
                .item = try record.item.cloneOwned(self.allocator),
                .request = try record.request.cloneOwned(self.allocator),
            };
            removed_id = try self.allocator.dupe(u8, record.item.id);
            _ = self.records.orderedRemove(index);
            record.item.deinit(self.allocator);
            record.request.deinit(self.allocator);
            if (record.runtime) |runtime| {
                runtime.stderr_buffer.deinit();
                self.allocator.destroy(runtime);
            }
        }
        self.mutex.unlock();
        defer if (removed_id) |value| self.allocator.free(value);

        if (history_item) |value| {
            try self.history_store.append(value);
            try self.emitHistoryChanged();
        }
        try self.writeShutdownRecoverySnapshot();
        if (removed_id) |value| {
            const payload = try models.jsonStringifyAlloc(self.allocator, RemovePayload{ .id = value }, .{});
            defer self.allocator.free(payload);
            self.sink.emit(self.sink.ctx, "downloadRemoved", payload);
        }
    }

    fn emitHistoryChanged(self: *DownloadManager) !void {
        const json = try self.history_store.toJson(self.allocator);
        defer self.allocator.free(json);
        self.sink.emit(self.sink.ctx, "historyChanged", json);
    }

    fn emitRecordByIdLocked(self: *DownloadManager, id: []const u8, event_name: []const u8) !void {
        const record = self.findRecordByIdLocked(id) orelse return;
        const json = try models.jsonStringifyAlloc(self.allocator, record.item, .{});
        defer self.allocator.free(json);
        self.sink.emit(self.sink.ctx, event_name, json);
    }

    fn findRecordByIdLocked(self: *DownloadManager, id: []const u8) ?*DownloadRecord {
        for (self.records.items) |*record| {
            if (std.mem.eql(u8, record.item.id, id)) return record;
        }
        return null;
    }

    fn workerFinished(self: *DownloadManager) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.active_workers > 0) {
            self.active_workers -= 1;
        }
    }

    fn writeShutdownRecoverySnapshot(self: *DownloadManager) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const path = try shutdownRecoveryPath(self.allocator);
        defer self.allocator.free(path);

        if (self.records.items.len == 0) {
            std.fs.deleteFileAbsolute(path) catch {};
            return;
        }

        var snapshot = std.array_list.Managed(models.StoredHistoryItem).init(self.allocator);
        defer {
            for (snapshot.items) |*item| item.deinit(self.allocator);
            snapshot.deinit();
        }

        for (self.records.items) |record| {
            var item = try record.item.cloneOwned(self.allocator);
            item.status = .cancelled;
            item.finishedAt = models.nowMillis();
            if (item.errorMessage) |value| {
                self.allocator.free(value);
            }
            item.errorMessage = try self.allocator.dupe(u8, "Download paused when app closed");

            try snapshot.append(.{
                .item = item,
                .request = try record.request.cloneOwned(self.allocator),
            });
        }

        const parent = std.fs.path.dirname(path) orelse return;
        try std.fs.cwd().makePath(parent);
        const bytes = try models.jsonStringifyAlloc(self.allocator, snapshot.items, .{ .whitespace = .indent_2 });
        defer self.allocator.free(bytes);
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = bytes });
    }
};

fn findRecordIndexByIdLocked(self: *DownloadManager, id: []const u8) ?usize {
    for (self.records.items, 0..) |record, index| {
        if (std.mem.eql(u8, record.item.id, id)) return index;
    }
    return null;
}

fn downloadThreadMain(runtime: *DownloadRuntime) void {
    const manager = runtime.manager;
    defer manager.workerFinished();
    runDownload(runtime) catch |err| {
        manager.complete(runtime.id, .failed, @errorName(err)) catch {};
    };
}

fn runDownload(runtime: *DownloadRuntime) !void {
    const manager = runtime.manager;

    var request: ?models.StartDownloadRequest = null;
    manager.mutex.lock();
    if (manager.findRecordByIdLocked(runtime.id)) |record| {
        request = try record.request.cloneOwned(manager.allocator);
    }
    manager.mutex.unlock();

    var owned_request = request orelse return error.DownloadNotFound;
    defer owned_request.deinit(manager.allocator);

    try manager.updateStatus(runtime.id, .starting);

    const argv = try axel.buildArgv(manager.allocator, owned_request);
    defer {
        for (argv) |value| {
            if (std.mem.eql(u8, value, "axel")) continue;
            if (std.mem.eql(u8, value, "-a")) continue;
            if (std.mem.eql(u8, value, "-o")) continue;
            if (std.mem.eql(u8, value, "-n")) continue;
            if (std.mem.eql(u8, value, "-s")) continue;
            if (std.mem.eql(u8, value, "-T")) continue;
            if (std.mem.eql(u8, value, "-U")) continue;
            if (std.mem.eql(u8, value, "-H")) continue;
            if (std.mem.eql(u8, value, "-4")) continue;
            if (std.mem.eql(u8, value, "-6")) continue;
            if (std.mem.eql(u8, value, "-N")) continue;
            if (std.mem.eql(u8, value, "-k")) continue;
            if (std.mem.eql(u8, value, "-c")) continue;
            if (std.mem.eql(u8, value, owned_request.url)) continue;
            if (owned_request.outputPath) |output_path| {
                if (std.mem.eql(u8, value, output_path)) continue;
                if (std.mem.eql(u8, value, std.fs.path.basename(output_path))) continue;
            }
            if (owned_request.userAgent != null and std.mem.eql(u8, value, owned_request.userAgent.?)) continue;
            if (owned_request.headers) |headers| {
                var skip = false;
                for (headers) |header| {
                    if (std.mem.eql(u8, value, header)) {
                        skip = true;
                        break;
                    }
                }
                if (skip) continue;
            }
            manager.allocator.free(value);
        }
        manager.allocator.free(argv);
    }

    var child = std.process.Child.init(argv, manager.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = std.fs.path.dirname(owned_request.outputPath.?) orelse null;

    try child.spawn();
    runtime.cancel_mutex.lock();
    runtime.pid = child.id;
    const cancel_requested = runtime.cancel_requested;
    runtime.cancel_mutex.unlock();
    if (cancel_requested) {
        std.posix.kill(child.id, std.posix.SIG.TERM) catch {};
    }

    const stdout_file = child.stdout orelse return error.MissingStdoutPipe;
    const stderr_file = child.stderr orelse return error.MissingStderrPipe;

    const stdout_thread = try std.Thread.spawn(.{}, stdoutReaderMain, .{ runtime, stdout_file });
    const stderr_thread = try std.Thread.spawn(.{}, stderrReaderMain, .{ runtime, stderr_file });
    const size_thread = try std.Thread.spawn(.{}, sizePollerMain, .{ runtime, owned_request.outputPath.? });

    const term = try child.wait();
    runtime.cancel_mutex.lock();
    runtime.pid = null;
    runtime.cancel_mutex.unlock();
    stdout_thread.join();
    stderr_thread.join();
    size_thread.join();

    runtime.cancel_mutex.lock();
    const cancelled = runtime.cancel_requested;
    runtime.cancel_mutex.unlock();

    const stderr_text = blk: {
        runtime.stderr_mutex.lock();
        defer runtime.stderr_mutex.unlock();
        if (runtime.stderr_buffer.items.len == 0) break :blk null;
        break :blk std.mem.trim(u8, runtime.stderr_buffer.items, " \t\r\n");
    };

    switch (term) {
        .Exited => |code| {
            if (cancelled) {
                try manager.complete(runtime.id, .cancelled, "Download cancelled");
            } else if (code == 0) {
                try manager.complete(runtime.id, .completed, null);
            } else {
                try manager.complete(runtime.id, .failed, stderr_text orelse "Axel exited with a non-zero status");
            }
        },
        else => {
            if (cancelled) {
                try manager.complete(runtime.id, .cancelled, "Download cancelled");
            } else {
                try manager.complete(runtime.id, .failed, stderr_text orelse "Axel terminated unexpectedly");
            }
        },
    }
}

fn stdoutReaderMain(runtime: *DownloadRuntime, file: std.fs.File) void {
    consumePipe(file, runtime, handleStdoutLine);
}

fn stderrReaderMain(runtime: *DownloadRuntime, file: std.fs.File) void {
    consumePipe(file, runtime, handleStderrLine);
}

fn sizePollerMain(runtime: *DownloadRuntime, output_path: []const u8) void {
    while (true) {
        refreshDownloadedBytes(runtime.manager, runtime.id, output_path) catch {};

        runtime.cancel_mutex.lock();
        const done = runtime.pid == null;
        runtime.cancel_mutex.unlock();
        if (done) break;

        std.Thread.sleep(250 * std.time.ns_per_ms);
    }
}

fn consumePipe(
    file: std.fs.File,
    runtime: *DownloadRuntime,
    handler: *const fn (*DownloadRuntime, []const u8) void,
) void {
    var read_buffer: [4096]u8 = undefined;
    var pending = std.array_list.Managed(u8).init(runtime.manager.allocator);
    defer pending.deinit();

    while (true) {
        const bytes_read = file.read(&read_buffer) catch break;
        if (bytes_read == 0) break;
        pending.appendSlice(read_buffer[0..bytes_read]) catch break;

        while (findLineBreak(pending.items)) |break_info| {
            const line = pending.items[0..break_info.index];
            handler(runtime, std.mem.trimRight(u8, line, "\r"));

            const remaining = pending.items[break_info.index + break_info.skip ..];
            std.mem.copyForwards(u8, pending.items[0..remaining.len], remaining);
            pending.items.len = remaining.len;
        }
    }

    if (pending.items.len > 0) {
        handler(runtime, std.mem.trimRight(u8, pending.items, "\r"));
    }
}

fn handleStdoutLine(runtime: *DownloadRuntime, line: []const u8) void {
    if (axel.parseTotalBytesLine(line)) |total_bytes| {
        runtime.manager.updateTotalBytes(runtime.id, total_bytes) catch {};
    }
    if (axel.parseProgressUpdate(line)) |progress| {
        runtime.manager.updateProgress(runtime.id, progress) catch {};
    }
}

fn handleStderrLine(runtime: *DownloadRuntime, line: []const u8) void {
    runtime.manager.appendStderr(runtime, line) catch {};
    runtime.manager.appendStderr(runtime, "\n") catch {};
}

fn refreshDownloadedBytes(self: *DownloadManager, id: []const u8, output_path: []const u8) !void {
    const file = std.fs.openFileAbsolute(output_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();
    const stat = try file.stat();
    const posix_stat = try std.posix.fstat(file.handle);
    const allocated_bytes = @as(u64, @intCast(posix_stat.blocks)) * 512;
    try self.updateDownloadedBytesFromDisk(id, @min(stat.size, allocated_bytes));
}

fn deriveOutputPath(
    allocator: std.mem.Allocator,
    app_settings: models.AppSettings,
    url: []const u8,
) ![]u8 {
    const safe_name = filenameFromUrl(url);
    return std.fs.path.join(allocator, &.{ app_settings.defaultDownloadDir, safe_name });
}

fn shutdownRecoveryPath(allocator: std.mem.Allocator) ![]u8 {
    const dir = try settings.dataDir(allocator);
    defer allocator.free(dir);
    return std.fs.path.join(allocator, &.{ dir, "shutdown-recovery.json" });
}

fn filenameFromUrl(url: []const u8) []const u8 {
    const without_fragment = if (std.mem.indexOfScalar(u8, url, '#')) |index| url[0..index] else url;
    const without_query = if (std.mem.indexOfScalar(u8, without_fragment, '?')) |index|
        without_fragment[0..index]
    else
        without_fragment;

    const filename = std.fs.path.basename(without_query);
    if (filename.len == 0 or std.mem.eql(u8, filename, "/") or std.mem.eql(u8, filename, ".")) {
        return "download.bin";
    }
    return filename;
}

const LineBreak = struct {
    index: usize,
    skip: usize,
};

fn findLineBreak(buffer: []const u8) ?LineBreak {
    for (buffer, 0..) |char, index| {
        switch (char) {
            '\r' => {
                if (index + 1 < buffer.len and buffer[index + 1] == '\n') {
                    return .{ .index = index, .skip = 2 };
                }
                return .{ .index = index, .skip = 1 };
            },
            '\n' => {
                if (index + 1 < buffer.len and buffer[index + 1] == '\r') {
                    return .{ .index = index, .skip = 2 };
                }
                return .{ .index = index, .skip = 1 };
            },
            else => {},
        }
    }
    return null;
}

fn replaceOptionalString(allocator: std.mem.Allocator, destination: *?[]const u8, next_value: ?[]const u8) !bool {
    const current = destination.*;
    if (optionalStringEql(current, next_value)) return false;

    if (current) |existing| allocator.free(existing);
    destination.* = if (next_value) |value| try allocator.dupe(u8, value) else null;
    return true;
}

fn optionalStringEql(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null and right == null) return true;
    if (left == null or right == null) return false;
    return std.mem.eql(u8, left.?, right.?);
}

const RemovePayload = struct {
    id: []const u8,

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("id");
        try jws.write(self.id);
        try jws.endObject();
    }
};
