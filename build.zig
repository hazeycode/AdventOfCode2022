const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const build_root_dir = try std.fs.openDirAbsolute(b.build_root, .{});
    const dir = try build_root_dir.openIterableDir("src", .{});
    var dir_it = dir.iterate();
    while (try dir_it.next()) |entry| {
        switch (entry.kind) {
            .File => {
                if (entry.name.len != 9 or
                    std.mem.eql(u8, entry.name[0..3], "day") == false or
                    std.mem.eql(u8, entry.name[5..], ".zig") == false)
                {
                    continue;
                }

                const name = entry.name[0..5];
                const path = try std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name});

                const exe = b.addExecutable(entry.name, path);
                exe.setTarget(target);
                exe.setBuildMode(mode);
                exe.install();

                const run_cmd = exe.run();
                run_cmd.step.dependOn(b.getInstallStep());

                const run_step = b.step(
                    try std.fmt.allocPrint(b.allocator, "run-{s}", .{name}),
                    try std.fmt.allocPrint(b.allocator, "Build and run {s}", .{name}),
                );
                run_step.dependOn(&run_cmd.step);

                const tests = b.addTest(path);
                tests.setTarget(target);
                tests.setBuildMode(mode);

                const test_step = b.step(
                    try std.fmt.allocPrint(b.allocator, "test-{s}", .{name}),
                    try std.fmt.allocPrint(b.allocator, "Run {s} tests", .{name}),
                );
                test_step.dependOn(&tests.step);
            },
            else => {},
        }
    }
}
