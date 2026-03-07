const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const exe = b.addExecutable(.{
        .name = "dyx",
        .root_module = root_module,
    });

    exe.linkLibC();
    exe.linkLibCpp();
    exe.root_module.addCMacro("WEBVIEW_STATIC", "1");
    exe.root_module.addIncludePath(b.path("vendor/webview/core/include"));
    exe.addCSourceFile(.{
        .file = b.path("vendor/webview/core/src/webview.cc"),
        .flags = &.{"-std=c++11"},
    });
    exe.linkSystemLibrary("dl");
    exe.linkSystemLibrary("pthread");

    applyPkgConfig(b, exe, &.{ "gtk+-3.0", "webkit2gtk-4.1" }) catch {
        applyPkgConfig(b, exe, &.{ "gtk4", "webkitgtk-6.0" }) catch |err| {
            std.log.err("failed to resolve GTK/WebKit flags with pkg-config: {s}", .{@errorName(err)});
            return;
        };
    };

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const experimental_wayland = std.process.getEnvVarOwned(b.allocator, "DYX_EXPERIMENTAL_WAYLAND") catch null;
    defer if (experimental_wayland) |value| b.allocator.free(value);
    run_cmd.setEnvironmentVariable("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    if (experimental_wayland == null or !std.mem.eql(u8, experimental_wayland.?, "1")) {
        run_cmd.setEnvironmentVariable("GDK_BACKEND", "x11");
    }
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the DYX desktop app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    exe_tests.linkLibC();
    exe_tests.linkLibCpp();
    exe_tests.root_module.addCMacro("WEBVIEW_STATIC", "1");
    exe_tests.root_module.addIncludePath(b.path("vendor/webview/core/include"));
    exe_tests.addCSourceFile(.{
        .file = b.path("vendor/webview/core/src/webview.cc"),
        .flags = &.{"-std=c++11"},
    });
    exe_tests.linkSystemLibrary("dl");
    exe_tests.linkSystemLibrary("pthread");
    applyPkgConfig(b, exe_tests, &.{ "gtk+-3.0", "webkit2gtk-4.1" }) catch {
        applyPkgConfig(b, exe_tests, &.{ "gtk4", "webkitgtk-6.0" }) catch {};
    };

    const test_run = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run DYX tests");
    test_step.dependOn(&test_run.step);
}

fn applyPkgConfig(
    b: *std.Build,
    compile: *std.Build.Step.Compile,
    modules: []const []const u8,
) !void {
    const allocator = b.allocator;
    const argv = try buildPkgConfigArgv(allocator, modules);
    defer allocator.free(argv);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| if (code != 0) return error.PkgConfigFailed,
        else => return error.PkgConfigFailed,
    }

    var tokens = std.mem.tokenizeAny(u8, result.stdout, " \n\r\t");
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "-I")) {
            compile.root_module.addIncludePath(.{ .cwd_relative = token[2..] });
        } else if (std.mem.startsWith(u8, token, "-D")) {
            const define = token[2..];
            if (std.mem.indexOfScalar(u8, define, '=')) |index| {
                compile.root_module.addCMacro(define[0..index], define[index + 1 ..]);
            } else {
                compile.root_module.addCMacro(define, "1");
            }
        } else if (std.mem.startsWith(u8, token, "-L")) {
            compile.addLibraryPath(.{ .cwd_relative = token[2..] });
        } else if (std.mem.startsWith(u8, token, "-l")) {
            compile.linkSystemLibrary(token[2..]);
        } else if (std.mem.eql(u8, token, "-pthread")) {
            compile.linkSystemLibrary("pthread");
        }
    }
}

fn buildPkgConfigArgv(
    allocator: std.mem.Allocator,
    modules: []const []const u8,
) ![]const []const u8 {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    try argv.append("pkg-config");
    try argv.append("--cflags");
    try argv.append("--libs");
    try argv.appendSlice(modules);
    return argv.toOwnedSlice();
}
