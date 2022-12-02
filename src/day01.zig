const std = @import("std");
const parseInt = std.fmt.parseInt;

const println = @import("util/util.zig").println;
const quicksort = @import("util/sort.zig").quicksort;

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

fn partTwo(input_reader: anytype) !usize {
    var largest_accs = [_]usize{0} ** 3;
    var acc: usize = 0;

    var buf = [_]u8{0} ** 16;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            for (largest_accs) |*p| {
                if (acc >= p.*) {
                    p.* = acc;
                    quicksort(&largest_accs, 0, largest_accs.len - 1, struct {
                        pub fn compare(_: @This(), a: usize, b: usize) bool {
                            return a < b;
                        }
                    }{});
                    break;
                }
            }
            acc = 0;
            continue;
        }

        acc += try parseInt(usize, line, 10);
    }

    return largest_accs[0] + largest_accs[1] + largest_accs[2];
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day01.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
