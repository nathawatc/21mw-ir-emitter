const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    if (target.result.os.tag != .linux) @panic("21mw-ir-emitter requires Linux");
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const exe = b.addExecutable(.{
        .name = "21mw-ir-emitter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    if (optimize != .Debug) exe.lto = .full;
    const install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "lib/udev" } },
    });
    b.getInstallStep().dependOn(&install.step);
    b.installFile("udev/61-21mw-ir-emitter.rules", "lib/udev/rules.d/61-21mw-ir-emitter.rules");

    const test_step = b.step("test", "Check failure paths without accessing a camera");
    for ([_][]const []const u8{ &.{}, &.{ "", "extra" }, &.{""}, &.{"/dev/null"} }) |args| {
        const run = b.addRunArtifact(exe);
        run.addArgs(args);
        run.expectExitCode(1);
        run.expectStdOutEqual("");
        _ = run.captureStdErr(.{});
        test_step.dependOn(&run.step);
    }
}
