const std = @import("std");
const parseInt = std.fmt.parseInt;

var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());

fn println(comptime fmt: []const u8, args: anytype) void {
    const writer = stdout.writer();
    writer.print(fmt, args) catch unreachable;
    writer.print("\n", .{}) catch unreachable;
    stdout.flush() catch unreachable;
}

fn partOne(input_reader: anytype) !usize {
    var largest_acc: usize = 0;
    var acc: usize = 0;

    var buf = [_]u8{0} ** 16;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            if (acc >= largest_acc) {
                largest_acc = acc;
            }
            acc = 0;
            continue;
        }

        acc += try parseInt(usize, line, 10);
    }

    return largest_acc;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day01.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});
}
