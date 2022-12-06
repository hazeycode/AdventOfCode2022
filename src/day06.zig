const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;

const util = @import("util/util.zig");
const println = util.println;

fn findMarker(comptime marker_len: usize, reader: anytype) !usize {
    var count: usize = 0;

    var buf = [_]u8{0} ** marker_len;
    var cur_write: usize = 0;

    while (true) {
        buf[cur_write] = try reader.readByte();
        cur_write = @mod(cur_write + 1, buf.len);

        count += 1;

        var bitset = std.StaticBitSet(256).initEmpty();
        for (buf) |c| bitset.set(c);

        if (count >= buf.len and bitset.count() == buf.len) {
            return count;
        }
    }

    unreachable;
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day06.txt"));

    const part_one_answer = try findMarker(4, input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try findMarker(14, input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
