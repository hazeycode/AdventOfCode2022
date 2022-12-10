const std = @import("std");

var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());

pub fn print(comptime fmt: []const u8, args: anytype) void {
    stdout.writer().print(fmt, args) catch unreachable;
}

pub fn flushStdOut() void {
    stdout.flush() catch unreachable;
}

pub fn println(comptime fmt: []const u8, args: anytype) void {
    const writer = stdout.writer();
    writer.print(fmt, args) catch unreachable;
    writer.print("\n", .{}) catch unreachable;
    stdout.flush() catch unreachable;
}

/// Returns a slice of integers from start to end (inclusive) that can be iterated over
pub fn range(comptime start: comptime_int, comptime end: comptime_int) []comptime_int {
    const d: isize = end - start;
    const d_norm = if (d < 0) -1 else if (d > 0) 1 else 0;
    const len = (try std.math.absInt(d)) + 1;
    comptime var i = 0;
    comptime var n = start;
    comptime var res: [len]comptime_int = .{undefined} ** len;
    inline while (i < len) : (i += 1) {
        res[i] = n;
        n += d_norm;
    }
    return res[0..len];
}

test "range" {
    try std.testing.expectEqual(1, range(5, 5).len);

    try std.testing.expectEqual(11, range(-5, 5).len);

    try std.testing.expectEqual(11, range(5, -5).len);

    { // reduce 5..7
        var res: usize = 0;
        inline for (range(5, 7)) |n, i| {
            try std.testing.expectEqual(@as(usize, 5 + i), n);
            res += n;
        }
        try std.testing.expectEqual(@as(usize, 18), res);
    }

    { // reduce 1..-3
        var res: isize = 0;
        inline for (range(1, -3)) |n, i| {
            try std.testing.expectEqual(@as(isize, 1) - i, n);
            res += n;
        }
        try std.testing.expectEqual(@as(isize, -5), res);
    }
}
