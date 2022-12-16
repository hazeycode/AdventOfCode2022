const std = @import("std");
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const testing = std.testing;
const fixedBufferStream = std.io.fixedBufferStream;
const tokenize = std.mem.tokenize;
const parseInt = std.fmt.parseInt;
const eql = std.meta.eql;

const util = @import("util/util.zig");
const println = util.println;

const Coord = struct { x: i32, y: i32 };

const RockPath = std.BoundedArray(Coord, 32);

const Tile = enum(u2) { empty, rock, sand };

const TileMap = [200][700]Tile;

fn parseRockPath(bytes: []const u8) !RockPath {
    var path = try RockPath.init(0);
    var it = tokenize(u8, bytes, " -> ");
    while (it.next()) |part| {
        var part_it = tokenize(u8, part, ",");
        const x = try parseInt(i32, part_it.next().?, 10);
        const y = try parseInt(i32, part_it.next().?, 10);
        assert(part_it.next() == null);
        try path.append(.{ .x = x, .y = y });
    }
    return path;
}

fn mapFillRockPath(tile_map: *TileMap, path: *const RockPath) void {
    assert(path.len > 1);
    var i: usize = 1;
    while (i < path.len) : (i += 1) {
        const start = path.constSlice()[i - 1];
        const end = path.constSlice()[i];
        assert(start.x == end.x or start.y == end.y);
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        var cur = start;
        assert(dx == 0 or dy == 0);
        if (dx > 0) {
            var j: isize = 0;
            while (j <= dx) : (j += 1) {
                tile_map[@intCast(usize, cur.y)][@intCast(usize, cur.x)] = .rock;
                cur.x += 1;
            }
        } else if (dx < 0) {
            var j: isize = 0;
            while (j >= dx) : (j -= 1) {
                tile_map[@intCast(usize, cur.y)][@intCast(usize, cur.x)] = .rock;
                cur.x -= 1;
            }
        } else if (dy > 0) {
            var j: isize = 0;
            while (j <= dy) : (j += 1) {
                tile_map[@intCast(usize, cur.y)][@intCast(usize, cur.x)] = .rock;
                cur.y += 1;
            }
        } else if (dy < 0) {
            var j: isize = 0;
            while (j >= dy) : (j -= 1) {
                tile_map[@intCast(usize, cur.y)][@intCast(usize, cur.x)] = .rock;
                cur.y -= 1;
            }
        }
    }
}

fn tickPartOne(tile_map: *TileMap, cur_sand: *Coord) bool {
    const cur_x = @intCast(usize, cur_sand.x);
    const cur_y = @intCast(usize, cur_sand.y);
    if (cur_y + 1 >= tile_map.len) {
        return false;
    }
    switch (tile_map[cur_y + 1][cur_x]) {
        .empty => cur_sand.y += 1,
        else => switch (tile_map[cur_y + 1][cur_x - 1]) {
            .empty => {
                cur_sand.x -= 1;
                cur_sand.y += 1;
            },
            else => switch (tile_map[cur_y + 1][cur_x + 1]) {
                .empty => {
                    cur_sand.x += 1;
                    cur_sand.y += 1;
                },
                else => {
                    tile_map[cur_y][cur_x] = .sand;
                    if (cur_y == 0 and cur_x == 500) {
                        return false;
                    }
                    cur_sand.* = .{ .x = 500, .y = 0 };
                },
            },
        },
    }
    return true;
}

fn tickPartTwo(tile_map: *TileMap, cur_sand: *Coord, floor_y: usize) bool {
    const cur_x = @intCast(usize, cur_sand.x);
    const cur_y = @intCast(usize, cur_sand.y);
    if (cur_y + 1 == floor_y) {
        tile_map[cur_y][cur_x] = .sand;
        cur_sand.* = .{ .x = 500, .y = 0 };
    }
    switch (tile_map[cur_y + 1][cur_x]) {
        .empty => cur_sand.y += 1,
        else => switch (tile_map[cur_y + 1][cur_x - 1]) {
            .empty => {
                cur_sand.x -= 1;
                cur_sand.y += 1;
            },
            else => switch (tile_map[cur_y + 1][cur_x + 1]) {
                .empty => {
                    cur_sand.x += 1;
                    cur_sand.y += 1;
                },
                else => {
                    tile_map[cur_y][cur_x] = .sand;
                    if (cur_y == 0 and cur_x == 500) {
                        return false;
                    }
                    cur_sand.* = .{ .x = 500, .y = 0 };
                },
            },
        },
    }
    return true;
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day14.txt"));
    const reader = input_stream.reader();

    { // part one
        var tile_map: TileMap = undefined;
        for (tile_map) |*row| {
            std.mem.set(Tile, row, .empty);
        }

        var buf: [256]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const rock_path = try parseRockPath(line);
            mapFillRockPath(&tile_map, &rock_path);
        }

        var sand = Coord{ .x = 500, .y = 0 };

        while (tickPartOne(&tile_map, &sand)) {}

        var count: usize = 0;
        for (tile_map) |row| {
            for (row) |tile| {
                if (tile == .sand) count += 1;
            }
        }

        println("part one anwser = {}", .{count});
    }

    input_stream.reset();

    { // part two
        var tile_map: TileMap = undefined;
        for (tile_map) |*row| {
            std.mem.set(Tile, row, .empty);
        }

        var floor_y: usize = 0;
        var buf: [256]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const rock_path = try parseRockPath(line);
            for (rock_path.constSlice()) |coord| {
                if (floor_y < coord.y) floor_y = @intCast(usize, coord.y);
            }
            mapFillRockPath(&tile_map, &rock_path);
        }
        floor_y += 2;

        var sand = Coord{ .x = 500, .y = 0 };

        while (tickPartTwo(&tile_map, &sand, floor_y)) {}

        var count: usize = 0;
        for (tile_map) |row| {
            for (row) |tile| {
                if (tile == .sand) count += 1;
            }
        }

        println("part two anwser = {}", .{count});
    }
}

test {
    var test_stream = fixedBufferStream(
        \\498,4 -> 498,6 -> 496,6
        \\503,4 -> 502,4 -> 502,9 -> 494,9
    );
    const reader = test_stream.reader();

    var tile_map: TileMap = undefined;
    for (tile_map) |*row| {
        std.mem.set(Tile, row, .empty);
    }

    var temp_buf: [256]u8 = undefined;

    const first_line = (try reader.readUntilDelimiterOrEof(&temp_buf, '\n')).?;
    const first_path = try parseRockPath(first_line);

    try testing.expectEqualSlices(
        Coord,
        &[_]Coord{
            .{ .x = 498, .y = 4 },
            .{ .x = 498, .y = 6 },
            .{ .x = 496, .y = 6 },
        },
        first_path.constSlice(),
    );

    const second_line = (try reader.readUntilDelimiterOrEof(&temp_buf, '\n')).?;
    const second_path = try parseRockPath(second_line);

    try testing.expectEqualSlices(
        Coord,
        &[_]Coord{
            .{ .x = 503, .y = 4 },
            .{ .x = 502, .y = 4 },
            .{ .x = 502, .y = 9 },
            .{ .x = 494, .y = 9 },
        },
        second_path.constSlice(),
    );

    mapFillRockPath(&tile_map, &first_path);
    mapFillRockPath(&tile_map, &second_path);

    var sand = Coord{ .x = 500, .y = 0 };

    while (tickPartOne(&tile_map, &sand)) {}

    var count: usize = 0;
    for (tile_map) |row| {
        for (row) |tile| {
            if (tile == .sand) count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 24), count);
}
