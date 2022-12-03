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
            for (second) |y| {
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
    var sum: usize = 0;

    var group_flags: u64 = 0xFFFFFFFFFFFFFFFF;
    var group_idx: usize = 0;

    var buf = [_]u8{0} ** 64;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var flags: u64 = 0;
        for (line) |x| {
            flags |= (@as(u64, 1) << priorityOf(x));
        }

        group_flags &= flags;

        if (group_idx == 2) {
            inline for (range(1, 52)) |i| {
                if (((group_flags >> i) & 1) > 0) {
                    sum += i;
                }
            }
            group_flags = 0xFFFFFFFFFFFFFFFF;
            group_idx = 0;
        } else {
            group_idx += 1;
        }
    }

    return sum;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day03.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
