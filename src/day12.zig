const std = @import("std");
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const testing = std.testing;
const tokenize = std.mem.tokenize;
const inf_u16 = std.math.inf_u16;

const util = @import("util/util.zig");
const println = util.println;

const quicksort = @import("util/sort.zig").quicksort;

const Location = struct {
    x: usize,
    y: usize,
};

const MapTile = struct {
    height: u8,
    distance: u16,
};

const Neighbours = std.BoundedArray(Location, 4);

fn parseMap(
    comptime columns: usize,
    comptime rows: usize,
    bytes: []const u8,
) struct {
    tiles: [rows][columns]MapTile,
    width: usize,
    height: usize,
    start_location: Location,
    end_location: Location,
} {
    var tiles: [rows][columns]MapTile = undefined;
    var start_location: Location = undefined;
    var end_location: Location = undefined;

    var it = tokenize(u8, bytes, "\n");
    var y: usize = 0;
    while (it.next()) |line| : (y += 1) {
        for (line) |c, x| {
            switch (c) {
                'S' => {
                    start_location = .{ .x = x, .y = y };
                    tiles[y][x] = .{
                        .height = charToHeight('a'),
                        .distance = inf_u16,
                    };
                },
                'E' => {
                    end_location = .{ .x = x, .y = y };
                    tiles[y][x] = .{
                        .height = charToHeight('z'),
                        .distance = 0,
                    };
                },
                else => tiles[y][x].height = charToHeight(c),
            }
        }
    }

    return .{
        .tiles = tiles,
        .width = columns,
        .height = rows,
        .start_location = start_location,
        .end_location = end_location,
    };
}

fn charToHeight(c: u8) u8 {
    return c - 'a';
}

fn getTile(map: anytype, location: Location) *MapTile {
    return &map.tiles[location.y][location.x];
}

fn traversable(height: u8, from_height: u8) bool {
    return height <= from_height + 1;
}

fn traversableNeighbours(map: anytype, from: Location) !Neighbours {
    var neighbours = try Neighbours.init(0);
    if (from.x > 0) {
        const location = Location{ .x = from.x - 1, .y = from.y };
        const tile = getTile(map, location);
        if (traversable(
            map.tiles[from.y][from.x].height,
            tile.height,
        )) {
            try neighbours.append(location);
        }
    }
    if (from.x < map.width - 1) {
        const location = Location{ .x = from.x + 1, .y = from.y };
        const neighbour = getTile(map, location);
        if (traversable(
            map.tiles[from.y][from.x].height,
            neighbour.height,
        )) {
            try neighbours.append(location);
        }
    }
    if (from.y > 0) {
        const location = Location{ .x = from.x, .y = from.y - 1 };
        const neighbour = getTile(map, location);
        if (traversable(
            map.tiles[from.y][from.x].height,
            neighbour.height,
        )) {
            try neighbours.append(location);
        }
    }
    if (from.y < map.height - 1) {
        const location = Location{ .x = from.x, .y = from.y + 1 };
        const neighbour = getTile(map, location);
        if (traversable(
            map.tiles[from.y][from.x].height,
            neighbour.height,
        )) {
            try neighbours.append(location);
        }
    }
    return neighbours;
}

fn calculateDistances(map: anytype, location: Location) !void {
    const d = getTile(map, location).distance + 1;
    const possible_neighbours = try traversableNeighbours(map, location);
    for (possible_neighbours.constSlice()) |neighbour_loc| {
        const neighbour = getTile(map, neighbour_loc);
        if (d < neighbour.distance) {
            neighbour.distance = d;
            try calculateDistances(map, neighbour_loc);
        }
    }
}

pub fn main() !void {
    const input = @embedFile("data/day12.txt");

    var map = parseMap(114, 41, input);

    try calculateDistances(&map, map.end_location);

    const print_distance_field = true;
    if (print_distance_field) {
        debugPrint("\n", .{});
        for (map.tiles) |row| {
            for (row) |tile| {
                if (tile.distance == 43690) {
                    debugPrint(" -  ", .{});
                } else {
                    debugPrint("{:3} ", .{tile.distance});
                }
            }
            debugPrint("\n", .{});
        }
        debugPrint("\n", .{});
    }

    println("part one answer = {}", .{getTile(&map, map.start_location).*.distance});
}
