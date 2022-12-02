const std = @import("std");

var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());

pub fn println(comptime fmt: []const u8, args: anytype) void {
    const writer = stdout.writer();
    writer.print(fmt, args) catch unreachable;
    writer.print("\n", .{}) catch unreachable;
    stdout.flush() catch unreachable;
}
