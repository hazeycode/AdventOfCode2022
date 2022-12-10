const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const tokenize = std.mem.tokenize;
const TokenIterator = std.mem.TokenIterator;
const parseInt = std.fmt.parseInt;

const Dir = enum { up, right, down, left };

const Location = struct {
    x: i32 = 0,
    y: i32 = 0,
};

const Visited = std.AutoArrayHashMap(Location, void);

const Move = struct { dir: Dir, dist: u16 };

fn parseMoves(input: []const u8) struct {
    it: TokenIterator(u8),

    pub fn next(self: *@This()) ?Move {
        if (self.it.next()) |line| {
            var line_it = tokenize(u8, line, " ");
            const dir: Dir = switch (line_it.next().?[0]) {
                'U' => .up,
                'R' => .right,
                'D' => .down,
                'L' => .left,
                else => @panic("invalid input"),
            };
            const dist = parseInt(u16, line_it.next().?, 10) catch {
                @panic("invalid input");
            };
            return .{
                .dir = dir,
                .dist = dist,
            };
        }
        return null;
    }
} {
    return .{
        .it = tokenize(u8, input, "\n"),
    };
}

fn applyMove(dir: Dir, head: *Location, tail: []Location) void {
    switch (dir) {
        .up => head.y += 1,
        .right => head.x += 1,
        .down => head.y -= 1,
        .left => head.x -= 1,
    }
    if (updateKnot(&tail[0], head.*)) {
        for (tail[1..]) |*knot, j| {
            if (updateKnot(knot, tail[j]) == false) {
                break;
            }
        }
    }
}

fn updateKnot(knot: *Location, prev: Location) bool {
    const dx = prev.x - knot.x;
    const dy = prev.y - knot.y;
    const absx = if (dx < 0) -dx else dx;
    const absy = if (dy < 0) -dy else dy;

    assert(absx <= 2 and absy <= 2);

    if (absx <= 1 and absy <= 1) return false;

    if (knot.y == prev.y) {
        knot.x += if (dx < 0) -1 else 1;
    } else if (knot.x == prev.x) {
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

    var it = parseMoves(input);
    while (it.next()) |move| {
        var i: usize = 0;
        while (i < move.dist) : (i += 1) {
            applyMove(move.dir, &head, &tail);
            try history.put(tail[tail.len - 1], {});
        }
    }
}

pub fn main() !void {
    const println = @import("util/util.zig").println;

    const input = @embedFile("data/day09.txt");

    var allocator = std.heap.page_allocator;
    var tail_history = Visited.init(allocator);
    defer tail_history.deinit();

    { // part one
        try recordTailHistory(1, input, &tail_history);
        println("part one answer: {}", .{tail_history.count()});
    }

    tail_history.clearRetainingCapacity();

    { // part two
        try recordTailHistory(9, input, &tail_history);
        println("part two answer: {}", .{tail_history.count()});
    }
}

test {
    const test_input =
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

    try recordTailHistory(1, test_input, &tail_history);
    try testing.expectEqual(@as(usize, 13), tail_history.count());

    tail_history.clearRetainingCapacity();

    try recordTailHistory(9, test_input, &tail_history);
    try testing.expectEqual(@as(usize, 1), tail_history.count());

    tail_history.clearRetainingCapacity();
}

test {
    const test_input =
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

    try recordTailHistory(9, test_input, &tail_history);
    try testing.expectEqual(@as(usize, 36), tail_history.count());

    const expected = &[_]Location{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 2 },
        .{ .x = 1, .y = 3 },
        .{ .x = 2, .y = 4 },
        .{ .x = 3, .y = 5 },
        .{ .x = 4, .y = 5 },
        .{ .x = 5, .y = 5 },
        .{ .x = 6, .y = 4 },
        .{ .x = 7, .y = 3 },
        .{ .x = 8, .y = 2 },
        .{ .x = 9, .y = 1 },
        .{ .x = 10, .y = 0 },
        .{ .x = 9, .y = -1 },
        .{ .x = 8, .y = -2 },
        .{ .x = 7, .y = -3 },
        .{ .x = 6, .y = -4 },
        .{ .x = 5, .y = -5 },
        .{ .x = 4, .y = -5 },
        .{ .x = 3, .y = -5 },
        .{ .x = 2, .y = -5 },
        .{ .x = 1, .y = -5 },
        .{ .x = 0, .y = -5 },
        .{ .x = -1, .y = -5 },
        .{ .x = -2, .y = -5 },
        .{ .x = -3, .y = -4 },
        .{ .x = -4, .y = -3 },
        .{ .x = -5, .y = -2 },
        .{ .x = -6, .y = -1 },
        .{ .x = -7, .y = 0 },
        .{ .x = -8, .y = 1 },
        .{ .x = -9, .y = 2 },
        .{ .x = -10, .y = 3 },
        .{ .x = -11, .y = 4 },
        .{ .x = -11, .y = 5 },
        .{ .x = -11, .y = 6 },
    };

    for (tail_history.keys()) |location, i| {
        try testing.expectEqual(expected[i], location);
    }
}
