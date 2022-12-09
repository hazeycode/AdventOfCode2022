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

const Visited = std.AutoHashMap(Location, void);

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

fn updateKnot(knot: *Location, prev_knot: *const Location) bool {
    const dx = prev_knot.x - knot.x;
    const dy = prev_knot.y - knot.y;

    const absx = if (dx < 0) -dx else dx;
    const absy = if (dy < 0) -dy else dy;
    if (absx <= 1 and absy <= 1) {
        return false;
    }

    if (knot.y == prev_knot.y) {
        knot.x += if (dx < 0) -1 else 1;
    } else if (knot.x == prev_knot.x) {
        knot.y += if (dy < 0) -1 else 1;
    } else {
        knot.x += if (dx < 0) -1 else 1;
        knot.y += if (dy < 0) -1 else 1;
    }

    return true;
}

fn recordTailHistory(
    comptime tail_len: usize,
    input: []const u8,
    history: *Visited,
) !void {
    comptime assert(tail_len > 0);

    var head = Location{};
    var tail = [_]Location{.{}} ** tail_len;

    try history.put(tail[tail.len - 1], {});

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

            if (updateKnot(&tail[0], &head)) {
                var j: usize = 1;
                while (j < tail.len) : (j += 1) {
                    if (updateKnot(&tail[j], &tail[j - 1]) == false) {
                        break;
                    }
                }
            }

            try history.put(tail[tail.len - 1], {});
        }
    }
}

pub fn main() !void {
    const println = @import("util/util.zig").println;

    const data = @embedFile("data/day09.txt");

    var allocator = std.heap.page_allocator;
    var tail_history = Visited.init(allocator);
    defer tail_history.deinit();

    { // part one
        try recordTailHistory(1, data, &tail_history);
        println("part one answer: {}", .{tail_history.count()});
    }

    tail_history.clearRetainingCapacity();

    { // part two
        try recordTailHistory(10, data, &tail_history);
        println("part two answer: {}", .{tail_history.count()});
    }
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

    var tail_history = Visited.init(testing.allocator);
    defer tail_history.deinit();

    try recordTailHistory(1, data, &tail_history);
    try testing.expectEqual(@as(usize, 13), tail_history.count());
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

    var tail_history = Visited.init(testing.allocator);
    defer tail_history.deinit();

    try recordTailHistory(9, data, &tail_history);
    try testing.expectEqual(@as(usize, 1), tail_history.count());
}

test {
    const data =
        \\R 5
        \\U 8
        \\L 8
        \\D 3
        \\R 17
        \\D 10
        \\L 25
        \\U 20
    ;

    var tail_history = Visited.init(testing.allocator);
    defer tail_history.deinit();

    try recordTailHistory(9, data, &tail_history);
    try testing.expectEqual(@as(usize, 36), tail_history.count());
}
