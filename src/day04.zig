const std = @import("std");
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const println = util.println;
const range = util.range;

fn partOne(input_reader: anytype) !usize {
    var sum: usize = 0;

    var buf = [_]u8{0} ** 64;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var fbs = fixedBufferStream(line);
        const line_reader = fbs.reader();

        var token_buf = [_]u8{0} ** 16;

        const a1 = try parseInt(
            usize,
            try line_reader.readUntilDelimiter(token_buf[0..], '-'),
            10,
        );
        const a2 = try parseInt(
            usize,
            try line_reader.readUntilDelimiter(token_buf[0..], ','),
            10,
        );
        const b1 = try parseInt(
            usize,
            try line_reader.readUntilDelimiter(token_buf[0..], '-'),
            10,
        );
        const b2 = try parseInt(
            usize,
            blk: {
                const len = try line_reader.readAll(token_buf[0..]);
                break :blk token_buf[0..len];
            },
            10,
        );

        assert(a1 <= a2);
        assert(b1 <= b2);

        if ((a1 >= b1 and a2 <= b2) or
            (b1 >= a1 and b2 <= a2))
        {
            sum += 1;
        }
    }

    return sum;
}

fn partTwo(input_reader: anytype) !usize {
    var sum: usize = 0;

    var buf = [_]u8{0} ** 64;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        _ = line;
    }

    return sum;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day04.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
