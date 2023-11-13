const std = @import("std");
const curl = @import("tgz/zigcurl/curl.zig");
const zlib = @import("tgz/zigcurl/zlib.zig");
const mbedtls = @import("tgz/zigcurl/mbedtls.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const z = zlib.create(b, target);
    const tls = mbedtls.create(b, target);
    const libcurl = curl.create(b, target, optimize);
    libcurl.linkLibrary(z);
    libcurl.linkLibrary(tls);

    const tgz = b.addStaticLibrary(.{
        .name = "tgz",
        .root_source_file = .{ .path = "tgz/src/bot.zig" },
        .target = target,
        .optimize = optimize,
    });
    tgz.addIncludePath(.{ .path = "./tgz/src" });
    tgz.addCSourceFile(.{ .file = .{ .path = "tgz/src/jsmn.c" }, .flags = &.{"-std=c89"} });
    tgz.installHeader("tgz/src/jsmn.h", "jsmn.h");
    tgz.linkLibrary(libcurl);
    b.installArtifact(tgz);

    const tgzmod = b.addModule("tgz", .{
        .source_file = .{ .path = "tgz/src/bot.zig" },
    });
    const exe = b.addExecutable(.{
        .name = "telsanta",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(tgz);
    b.installArtifact(exe);
    exe.addModule("tgz", tgzmod);

    const run = b.addRunArtifact(exe);
    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run.step.dependOn(b.getInstallStep());
    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
