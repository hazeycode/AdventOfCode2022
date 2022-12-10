const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const fixedBufferStream = std.io.fixedBufferStream;
const tokenize = std.mem.tokenize;
const eql = std.mem.eql;
const parseInt = std.fmt.parseInt;

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

fn generateSignal(reader: anytype, sample_buf: []isize) ![]const isize {
    var cycle: usize = 0;
    var cur: usize = 0;

    std.mem.set(isize, sample_buf, 1);

    while (cycle <= cur) : (cycle += 1) {
        var buf = [_]u8{0} ** 16;
        if (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const instruction = parseInstruction: {
                var it = tokenize(u8, line, " ");
                const first = it.next() orelse return error.InvalidInput;
                break :parseInstruction .{
                    .kind = parseKind: {
                        inline for (std.meta.fields(Instruction.Kind)) |f, i| {
                            if (eql(u8, first, f.name)) {
                                break :parseKind @intToEnum(Instruction.Kind, i);
                            }
                        }
                        return error.InvalidInput;
                    },
                    .arg = if (it.next()) |second| try parseInt(isize, second, 10) else 0,
                };
            };

            cur += instruction.kind.numCycles();

            switch (instruction.kind) {
                .noop => {},
                .addx => std.mem.set(
                    isize,
                    sample_buf[cur..],
                    sample_buf[cur] + instruction.arg,
                ),
            }
        }
    }

    return sample_buf[0 .. cur + 1];
}

pub fn main() !void {
    const println = @import("util/util.zig").println;

    var input = fixedBufferStream(@embedFile("data/day10.txt"));

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var sample_buf = try arena.allocator().alloc(isize, 4096);
    const samples = try generateSignal(input.reader(), sample_buf);

    var signal_strength_sum: isize = 0;
    var cycle: usize = 20;
    while (cycle < samples.len) : (cycle += 40) {
        signal_strength_sum += samples[cycle - 1] * @intCast(isize, cycle);
    }

    println("part one answer: {}", .{signal_strength_sum});
}

test {
    var sample_buf = try testing.allocator.alloc(isize, 4096);
    defer testing.allocator.free(sample_buf);

    var test_stream = fixedBufferStream(
        \\noop
        \\addx 3
        \\addx -5
        \\noop
        \\addx 10
        \\addx -2
        \\addx 3
    );

    const samples = try generateSignal(test_stream.reader(), sample_buf);
    try testing.expectEqualSlices(
        isize,
        &[_]isize{ 1, 1, 1, 4, 4, -1, -1, -1, 9, 9, 7, 7, 10 },
        samples,
    );
}

test {
    var sample_buf = try testing.allocator.alloc(isize, 4096);
    defer testing.allocator.free(sample_buf);

    var test_stream = fixedBufferStream(@embedFile("data/day10_test.txt"));

    const samples = try generateSignal(test_stream.reader(), sample_buf);

    try testing.expectEqual(@as(isize, 21), samples[20 - 1]);
    try testing.expectEqual(@as(isize, 19), samples[60 - 1]);
    try testing.expectEqual(@as(isize, 18), samples[100 - 1]);
    try testing.expectEqual(@as(isize, 21), samples[140 - 1]);
    try testing.expectEqual(@as(isize, 16), samples[180 - 1]);
    try testing.expectEqual(@as(isize, 18), samples[220 - 1]);
}
