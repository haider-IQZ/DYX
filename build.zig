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

    const native_host_exe = b.addExecutable(.{
        .name = "dyx-native-host",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/native_host_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    native_host_exe.linkLibC();
    native_host_exe.linkLibCpp();
    native_host_exe.linkSystemLibrary("dl");
    native_host_exe.linkSystemLibrary("pthread");
    b.installArtifact(native_host_exe);
    const native_host_install = b.addInstallArtifact(native_host_exe, .{});

    const backend_step = b.step("backend", "Install the DYX headless backend");
    backend_step.dependOn(&backend_install.step);
    backend_step.dependOn(&native_host_install.step);

    const native_host_step = b.step("native-host", "Install the DYX native messaging host");
    native_host_step.dependOn(&native_host_install.step);

    const register_host_install = b.addInstallFileWithDir(
        b.path("scripts/register-firefox-native-host.sh"),
        .bin,
        "dyx-register-firefox-host",
    );
    const unregister_host_install = b.addInstallFileWithDir(
        b.path("scripts/unregister-firefox-native-host.sh"),
        .bin,
        "dyx-unregister-firefox-host",
    );
    const host_template_install = b.addInstallFileWithDir(
        b.path("packaging/native-messaging/firefox/app.dyx.native_host.json.in"),
        .{ .custom = "share/dyx/native-messaging/firefox" },
        "app.dyx.native_host.json.in",
    );
    const chmod_register = b.addSystemCommand(&.{
        "chmod",
        "+x",
        b.getInstallPath(.bin, "dyx-register-firefox-host"),
        b.getInstallPath(.bin, "dyx-unregister-firefox-host"),
    });
    chmod_register.step.dependOn(&register_host_install.step);
    chmod_register.step.dependOn(&unregister_host_install.step);
    backend_step.dependOn(&register_host_install.step);
    backend_step.dependOn(&unregister_host_install.step);
    backend_step.dependOn(&host_template_install.step);
    backend_step.dependOn(&chmod_register.step);
    native_host_step.dependOn(&register_host_install.step);
    native_host_step.dependOn(&unregister_host_install.step);
    native_host_step.dependOn(&host_template_install.step);
    native_host_step.dependOn(&chmod_register.step);

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

    const native_host_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/native_host_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    native_host_tests.linkLibC();
    native_host_tests.linkLibCpp();
    native_host_tests.linkSystemLibrary("dl");
    native_host_tests.linkSystemLibrary("pthread");
    const native_host_test_run = b.addRunArtifact(native_host_tests);
    test_step.dependOn(&native_host_test_run.step);
}
