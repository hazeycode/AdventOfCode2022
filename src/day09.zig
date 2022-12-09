const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const tokenize = std.mem.tokenize;
const parseInt = std.fmt.parseInt;

const Dir = enum { up, right, down, left };

const Location = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const TailHistory = std.AutoHashMap(Location, void);

fn parseLine(line: []const u8) struct { dir: Dir, dist: u16 } {
    var it = tokenize(u8, line, " ");
    const dir: Dir = switch (it.next().?[0]) {
        'U' => .up,
        'R' => .right,
        'D' => .down,
        'L' => .left,
        else => @panic("invalid input"),
    };
    const dist = parseInt(u16, it.next().?, 10) catch @panic("invalid input");
    return .{
        .dir = dir,
        .dist = dist,
    };
}

fn recordTailHistory(allocator: std.mem.Allocator, input: []const u8) !TailHistory {
    var result = TailHistory.init(allocator);

    var head = Location{};
    var tail = Location{};

    try result.put(tail, {});

    var it = tokenize(u8, input, "\n");
    while (it.next()) |line| {
        const move = parseLine(line);

        var i: usize = 0;
        while (i < move.dist) : (i += 1) {
            switch (move.dir) {
                .up => head.y += 1,
                .right => head.x += 1,
                .down => head.y -= 1,
                .left => head.x -= 1,
            }

            { // update tail
                const dx = head.x - tail.x;
                const dy = head.y - tail.y;

                const absx = if (dx < 0) -dx else dx;
                const absy = if (dy < 0) -dy else dy;
                if (absx <= 1 and absy <= 1) {
                    continue;
                }

                if (tail.y == head.y) {
                    tail.x += if (dx < 0) -1 else 1;
                } else if (tail.x == head.x) {
                    tail.y += if (dy < 0) -1 else 1;
                } else {
                    tail.x += if (dx < 0) -1 else 1;
                    tail.y += if (dy < 0) -1 else 1;
                }

                try result.put(tail, {});
            }
        }
    }

    return result;
}

pub fn main() !void {
    const println = @import("util/util.zig").println;

    const data = @embedFile("data/day09.txt");

    var allocator = std.heap.page_allocator;

    var tail_history = try recordTailHistory(allocator, data);
    defer tail_history.deinit();

    println("part one answer: {}", .{tail_history.count()});
}

test {
    const data =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    var tail_history = try recordTailHistory(testing.allocator, data);
    defer tail_history.deinit();

    try testing.expectEqual(@as(usize, 13), tail_history.count());
}
