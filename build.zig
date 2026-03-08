const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backend_exe = b.addExecutable(.{
        .name = "dyx-backend",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/backend_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    backend_exe.linkLibC();
    backend_exe.linkLibCpp();
    backend_exe.linkSystemLibrary("dl");
    backend_exe.linkSystemLibrary("pthread");
    b.installArtifact(backend_exe);
    const backend_install = b.addInstallArtifact(backend_exe, .{});
    const backend_step = b.step("backend", "Install the DYX headless backend");
    backend_step.dependOn(&backend_install.step);

    const backend_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/backend_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    const test_step = b.step("test", "Run DYX tests");
    backend_tests.linkLibC();
    backend_tests.linkLibCpp();
    backend_tests.linkSystemLibrary("dl");
    backend_tests.linkSystemLibrary("pthread");
    const backend_test_run = b.addRunArtifact(backend_tests);
    test_step.dependOn(&backend_test_run.step);
}
