const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const tokenize = std.mem.tokenize;
const sqrt = std.math.sqrt;

const util = @import("util/util.zig");
const println = util.println;

fn transpose(comptime sz: usize, data: []const u8) [sz][sz]u8 {
    var result: [sz][sz]u8 = undefined;
    var it = tokenize(u8, data, "\n");
    var y: usize = 0;
    while (it.next()) |row| : (y += 1) {
        for (row) |c, x| result[x][y] = c;
    }
    return result;
}

fn countVisible(comptime data: anytype) usize {
    // assume square data!
    const sz: usize = @floatToInt(usize, @sqrt(@intToFloat(f32, data.len)));

    var vis_map: [sz][sz]u1 = std.mem.zeroes([sz][sz]u1);

    { // write horizontal visibilty map
        var it = tokenize(u8, data, "\n");
        var y: usize = 0;
        while (it.next()) |row| : (y += 1) {
            var highest: u8 = 0;
            var x: usize = 0;
            while (x < sz - 1) : (x += 1) {
                const height = row[x];
                if (height > highest) {
                    vis_map[y][x] = 1;
                    highest = height;
                    if (height == 9) break;
                }
            }
            highest = 0;
            x = sz - 1;
            while (x > 0) : (x -= 1) {
                const height = row[x];
                if (height > highest) {
                    vis_map[y][x] = 1;
                    highest = height;
                    if (height == 9) break;
                }
            }
        }
    }

    { // write vertical visibility map
        for (transpose(sz, data)) |column, x| {
            var highest: u8 = 0;
            var y: usize = 0;
            while (y < sz - 1) : (y += 1) {
                const height = column[y];
                if (height > highest) {
                    vis_map[y][x] = 1;
                    highest = height;
                    if (height == 9) break;
                }
            }
            highest = 0;
            y = sz - 1;
            while (y > 0) : (y -= 1) {
                const height = column[y];
                if (height > highest) {
                    vis_map[y][x] = 1;
                    highest = height;
                    if (height == 9) break;
                }
            }
        }
    }

    if (false) { // debug print vismap
        std.debug.print("\n", .{});
        var y: usize = 0;
        while (y < sz) : (y += 1) {
            var x: usize = 0;
            while (x < sz) : (x += 1) {
                std.debug.print("{}", .{vis_map[y][x]});
            }
            std.debug.print("\n", .{});
        }
    }

    var count: usize = 0;
    var y: usize = 0;
    while (y < vis_map.len) : (y += 1) {
        var x: usize = 0;
        while (x < vis_map[0].len) : (x += 1) {
            count += vis_map[x][y];
        }
    }

    return count;
}

pub fn main() !void {
    const data = @embedFile("data/day08.txt");

    println("part one answer: {}", .{countVisible(data)});
}

test {
    const data =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;
    const transposed = transpose(5, data);
    for ([_][]const u8{
        "32633",
        "05535",
        "35353",
        "71349",
        "32290",
    }) |expected, i| {
        try testing.expectEqualSlices(u8, expected, &transposed[i]);
    }

    try testing.expectEqual(@as(usize, 21), countVisible(data));
}
