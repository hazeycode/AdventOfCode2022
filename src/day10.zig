const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const fixedBufferStream = std.io.fixedBufferStream;
const tokenize = std.mem.tokenize;
const eql = std.mem.eql;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const print = util.print;
const println = util.println;

const Instruction = struct {
    kind: Kind,
    arg: i32,

    pub const Kind = enum {
        noop,
        addx,

        pub fn numCycles(self: @This()) usize {
            return switch (self) {
                .noop => 1,
                .addx => 2,
            };
        }
    };
};

fn readInstruction(reader: anytype) !?Instruction {
    var buf = [_]u8{0} ** 16;
    if (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = tokenize(u8, line, " ");
        const first = it.next() orelse return error.InvalidInput;
        return Instruction{
            .kind = parseKind: {
                inline for (std.meta.fields(Instruction.Kind)) |f, i| {
                    if (eql(u8, first, f.name)) {
                        break :parseKind @intToEnum(Instruction.Kind, i);
                    }
                }
                return error.InvalidInput;
            },
            .arg = if (it.next()) |second| try parseInt(i32, second, 10) else 0,
        };
    }
    return null;
}

fn generateSignal(reader: anytype, buffer: []i32) ![]const i32 {
    var cur: usize = 0;
    var cycle: usize = 0;
    while (try readInstruction(reader)) |instruction| {
        cur += instruction.kind.numCycles();
        switch (instruction.kind) {
            .noop => {},
            .addx => std.mem.set(
                i32,
                buffer[cur..],
                buffer[cur] + instruction.arg,
            ),
        }
        cycle += 1;
    }
    return buffer[0..(cur + 1)];
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day10.txt"));

    var buffer = [_]i32{1} ** 2048;
    const samples = try generateSignal(input_stream.reader(), &buffer);

    { // part one
        var signal_strength_sum: i32 = 0;
        var cycle: usize = 20;
        while (cycle <= samples.len) : (cycle += 40) {
            signal_strength_sum += samples[cycle - 1] * @intCast(i32, cycle);
        }

        println("part one answer: {}", .{signal_strength_sum});
    }

    input_stream.reset();

    { // part two
        print("part two answer:\n", .{});
        for (samples) |x, i| {
            const crt_x = @mod(i, 40) + 1;
            if (crt_x == 1) {
                print("\n", .{});
            }
            const lit = (crt_x >= x) and (crt_x < x + 3);
            if (lit) print("#", .{}) else print(".", .{});
        }
        print("\n", .{});
        util.flushStdOut();
    }
}

test {
    var test_stream = fixedBufferStream(
        \\noop
        \\addx 3
        \\addx -5
        \\noop
        \\addx 10
        \\addx -2
        \\addx 3
    );

    var buffer = [_]i32{1} ** 2048;
    const samples = try generateSignal(test_stream.reader(), &buffer);

    try testing.expectEqualSlices(
        i32,
        &[_]i32{ 1, 1, 1, 4, 4, -1, -1, -1, 9, 9, 7, 7, 10 },
        samples,
    );
}

test {
    var test_stream = fixedBufferStream(@embedFile("data/day10_test.txt"));

    var buffer = [_]i32{1} ** 2048;
    const samples = try generateSignal(test_stream.reader(), &buffer);

    try testing.expectEqual(@as(i32, 21), samples[20 - 1]);
    try testing.expectEqual(@as(i32, 19), samples[60 - 1]);
    try testing.expectEqual(@as(i32, 18), samples[100 - 1]);
    try testing.expectEqual(@as(i32, 21), samples[140 - 1]);
    try testing.expectEqual(@as(i32, 16), samples[180 - 1]);
    try testing.expectEqual(@as(i32, 18), samples[220 - 1]);
}

test {
    var test_stream = fixedBufferStream(@embedFile("data/day10_test.txt"));

    var buffer = [_]i32{1} ** 2048;
    const samples = try generateSignal(test_stream.reader(), &buffer);

    for (samples) |x, i| {
        const crt_x = @mod(i, 40) + 1;
        if (crt_x == 1) {
            debugPrint("\n", .{});
        }
        const lit = (crt_x >= x) and (crt_x < x + 3);
        if (lit) debugPrint("#", .{}) else debugPrint(".", .{});
    }
    debugPrint("\n", .{});
}
