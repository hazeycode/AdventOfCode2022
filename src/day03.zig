const std = @import("std");
const assert = std.debug.assert;

const util = @import("util/util.zig");
const println = util.println;
const range = util.range;

fn priorityOf(char: u8) u6 {
    return @intCast(u6, switch (char) {
        'a'...'z' => char - 'a' + 1,
        'A'...'Z' => char - 'A' + 27,
        else => unreachable,
    });
}

fn partOne(input_reader: anytype) !usize {
    var sum: usize = 0;

    var buf = [_]u8{0} ** 64;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        const half_len = line.len / 2;
        const first = line[0..half_len];
        const second = line[half_len..];

        var flags: u64 = 0;

        for (first) |x| {
            if (((flags >> priorityOf(x)) & 1) > 0) {
                continue;
            }
            for (second) |y| {
                if (((flags >> priorityOf(y)) & 1) > 0) {
                    continue;
                }
                if (x == y) {
                    flags |= (@as(u64, 1) << priorityOf(x));
                    break;
                }
            }
        }

        inline for (range(1, 52)) |i| {
            if (((flags >> i) & 1) > 0) {
                sum += i;
            }
        }
    }

    return sum;
}

fn partTwo(input_reader: anytype) !usize {
    _ = input_reader;
    return 0;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day03.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
