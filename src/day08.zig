const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const tokenize = std.mem.tokenize;

fn HeightMap(comptime sz: usize) type {
    return [sz][sz]u8;
}

fn VisibiltyMap(comptime sz: usize) type {
    return [sz][sz]u1;
}

fn transpose(comptime MapType: type, map: *const MapType) MapType {
    var result: MapType = undefined;
    var y: usize = 0;
    while (y < map.len) : (y += 1) {
        var x: usize = 0;
        while (x < map.len) : (x += 1) {
            result[x][y] = map[y][x];
        }
    }
    return result;
}

fn parseHeightMap(comptime sz: usize, data: []const u8) HeightMap(sz) {
    var result: HeightMap(sz) = undefined;
    var it = tokenize(u8, data, "\n");
    var y: usize = 0;
    while (it.next()) |row| : (y += 1) {
        for (row) |c, x| result[y][x] = c;
    }
    return result;
}

fn visibiltyMap(
    comptime sz: usize,
    heightmap: *const HeightMap(sz),
    heightmap_transposed: *const HeightMap(sz),
) VisibiltyMap(sz) {
    var result: VisibiltyMap(sz) = std.mem.zeroes(VisibiltyMap(sz));

    // map horizontal visibility
    for (heightmap) |row, y| {
        var highest: u8 = 0;
        var x: usize = 0;
        while (x < sz - 1) : (x += 1) {
            const height = row[x];
            if (height > highest) {
                result[y][x] = 1;
                highest = height;
                if (height == 9) break;
            }
        }
        highest = 0;
        x = sz - 1;
        while (x > 0) : (x -= 1) {
            const height = row[x];
            if (height > highest) {
                result[y][x] = 1;
                highest = height;
                if (height == 9) break;
            }
        }
    }

    // map vertical visibility
    for (heightmap_transposed) |column, x| {
        var highest: u8 = 0;
        var y: usize = 0;
        while (y < sz - 1) : (y += 1) {
            const height = column[y];
            if (height > highest) {
                result[y][x] = 1;
                highest = height;
                if (height == 9) break;
            }
        }
        highest = 0;
        y = sz - 1;
        while (y > 0) : (y -= 1) {
            const height = column[y];
            if (height > highest) {
                result[y][x] = 1;
                highest = height;
                if (height == 9) break;
            }
        }
    }
    return result;
}

fn getScenicScore(
    comptime HeightMapType: type,
    heightmap: *const HeightMapType,
    heightmap_transposed: *const HeightMapType,
    location: struct { x: usize, y: usize },
) usize {
    const height = heightmap[location.y][location.x];

    var count_north: usize = 0;
    {
        const column = heightmap_transposed[location.x];
        var y = location.y;
        while (y > 0) : (y -= 1) {
            count_north += 1;
            if (column[y - 1] >= height) break;
        }
    }

    var count_east: usize = 0;
    {
        const row = heightmap[location.y];
        var x = location.x;
        while (x < heightmap.len - 1) : (x += 1) {
            count_east += 1;
            if (row[x + 1] >= height) break;
        }
    }

    var count_south: usize = 0;
    {
        const column = heightmap_transposed[location.x];
        var y = location.y;
        while (y < heightmap_transposed.len - 1) : (y += 1) {
            count_south += 1;
            if (column[y + 1] >= height) break;
        }
    }

    var count_west: usize = 0;
    {
        const row = heightmap[location.y];
        var x = location.x;
        while (x > 0) : (x -= 1) {
            count_west += 1;
            if (row[x - 1] >= height) break;
        }
    }

    return count_north * count_east * count_south * count_west;
}

pub fn main() !void {
    const println = @import("util/util.zig").println;

    const data = @embedFile("data/day08.txt");

    // assume square data!
    const sz: usize = @floatToInt(
        usize,
        @sqrt(@intToFloat(f32, data.len)),
    );

    const heightmap = parseHeightMap(sz, data);
    const heightmap_transposed = transpose(
        @TypeOf(heightmap),
        &heightmap,
    );

    const visibilty_map = visibiltyMap(
        sz,
        &heightmap,
        &heightmap_transposed,
    );

    var visible_count: usize = 0;
    var highest_scenic_score: usize = 0;

    var y: usize = 0;
    while (y < sz) : (y += 1) {
        var x: usize = 0;
        while (x < sz) : (x += 1) {
            const scenic_score = getScenicScore(
                @TypeOf(heightmap),
                &heightmap,
                &heightmap_transposed,
                .{ .x = x, .y = y },
            );
            if (scenic_score > highest_scenic_score) {
                highest_scenic_score = scenic_score;
            }

            visible_count += visibilty_map[y][x];
        }
    }

    println("part one answer: {}", .{visible_count});
    println("part two answer: {}", .{highest_scenic_score});
}

test {
    const data =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    // assume square data!
    const sz: usize = @floatToInt(usize, @sqrt(@intToFloat(f32, data.len)));

    const heightmap = parseHeightMap(sz, data);
    for ([_][]const u8{
        "30373",
        "25512",
        "65332",
        "33549",
        "35390",
    }) |expected, i| {
        try testing.expectEqualSlices(u8, expected, &heightmap[i]);
    }

    const heightmap_transposed = transpose(@TypeOf(heightmap), &heightmap);
    for ([_][]const u8{
        "32633",
        "05535",
        "35353",
        "71349",
        "32290",
    }) |expected, i| {
        try testing.expectEqualSlices(u8, expected, &heightmap_transposed[i]);
    }

    try testing.expectEqual(
        @as(usize, 4),
        getScenicScore(
            @TypeOf(heightmap),
            &heightmap,
            &heightmap_transposed,
            .{ .x = 2, .y = 1 },
        ),
    );

    const visibilty_map = visibiltyMap(sz, &heightmap, &heightmap_transposed);

    var visible_count: usize = 0;
    var highest_scenic_score: usize = 0;

    var y: usize = 0;
    while (y < sz) : (y += 1) {
        var x: usize = 0;
        while (x < sz) : (x += 1) {
            const scenic_score = getScenicScore(
                @TypeOf(heightmap),
                &heightmap,
                &heightmap_transposed,
                .{ .x = x, .y = y },
            );
            if (scenic_score > highest_scenic_score) {
                highest_scenic_score = scenic_score;
            }

            visible_count += visibilty_map[y][x];
        }
    }

    try testing.expectEqual(@as(usize, 21), visible_count);
    try testing.expectEqual(@as(usize, 8), highest_scenic_score);
}
