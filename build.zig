const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Watch mode option
    const enable_watch = b.option(
        bool,
        "watch",
        "Enable watch mode for hot reloading",
    ) orelse false;

    // Watch configuration options
    const watch_path = b.option(
        []const u8,
        "watch-path",
        "Path to watch for changes",
    ) orelse "src";

    const watch_delay = b.option(
        u32,
        "watch-delay",
        "Delay in ms between rebuilds",
    ) orelse 1000;

    // Create executable
    const exe = b.addExecutable(.{
        .name = "zig_interpreter",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install artifact
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Pass arguments if any
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Watch step
    const watch_step = b.step("watch", "Watch for changes and rebuild");
    if (enable_watch) {
        var watch_args = std.ArrayList([]const u8).init(b.allocator);
        watch_args.appendSlice(&[_][]const u8{
            "zig",
            "build",
            "run",
            "--watch-path",
            watch_path,
            "--watch-delay",
        }) catch unreachable;

        // Convert watch_delay to string
        var delay_buf: [10]u8 = undefined;
        const delay_str = std.fmt.bufPrint(&delay_buf, "{d}", .{watch_delay}) catch unreachable;
        watch_args.append(delay_str) catch unreachable;

        const watch_cmd = b.addSystemCommand(watch_args.items);
        watch_step.dependOn(&watch_cmd.step);
    } else {
        watch_step.dependOn(&run_cmd.step);
    }

    // Test configuration
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
