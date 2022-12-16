const std = @import("std");
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const testing = std.testing;
const tokenize = std.mem.tokenize;
const parseInt = std.fmt.parseInt;
const eql = std.meta.eql;

const util = @import("util/util.zig");
const println = util.println;

const Location = struct { x: i64, y: i64 };

const SensorBeaconLocationPair = struct {
    sensor_location: Location,
    beacon_location: Location,
};

const LocationPairs = std.BoundedArray(SensorBeaconLocationPair, 32);

const LocationSet = std.AutoHashMap(Location, void);

fn manhattanDistance(a: Location, b: Location) i64 {
    var dx = b.x - a.x;
    var dy = b.y - a.y;
    if (dx < 0) dx = -dx;
    if (dy < 0) dy = -dy;
    return dx + dy;
}

fn parseLocation(bytes: []const u8) !Location {
    var it = tokenize(u8, bytes, ",");

    var x_part_it = tokenize(u8, it.next().?, "=");
    _ = x_part_it.next();
    const x = try parseInt(i64, x_part_it.next().?, 10);

    var y_part_it = tokenize(u8, it.next().?, "=");
    _ = y_part_it.next();
    const y = try parseInt(i64, y_part_it.next().?, 10);

    return .{ .x = x, .y = y };
}

fn parseLine(bytes: []const u8) !SensorBeaconLocationPair {
    var it = tokenize(u8, bytes, ":");
    return .{
        .sensor_location = try parseLocation(it.next().?),
        .beacon_location = try parseLocation(it.next().?),
    };
}

fn parse(bytes: []const u8) !LocationPairs {
    var res = try LocationPairs.init(0);
    var it = tokenize(u8, bytes, "\n");
    while (it.next()) |line| {
        try res.append(try parseLine(line));
    }
    return res;
}

fn countLocationsForY(
    allocator: std.mem.Allocator,
    input_bytes: []const u8,
    y: i64,
) !usize {
    var location_set = LocationSet.init(allocator);
    defer location_set.deinit();

    for ((try parse(input_bytes)).constSlice()) |pair| {
        const beacon_dist = manhattanDistance(
            pair.sensor_location,
            pair.beacon_location,
        );
        const mid_x = pair.sensor_location.x;
        var i: i64 = 0;
        while (true) : (i += 1) {
            var test_location = Location{ .x = mid_x - i, .y = y };
            if (manhattanDistance(pair.sensor_location, test_location) > beacon_dist) {
                break;
            }
            if (eql(test_location, pair.beacon_location)) {
                continue;
            }
            try location_set.put(test_location, {});
            test_location.x = mid_x + i;
            if (eql(test_location, pair.beacon_location)) {
                continue;
            }
            try location_set.put(test_location, {});
        }
    }

    return location_set.count();
}

pub fn main() !void {
    const input = @embedFile("data/day15.txt");
    const part_one_answer = try countLocationsForY(
        std.heap.page_allocator,
        input,
        2000000,
    );
    println("part one answer = {}", .{part_one_answer});
}

test {
    const test_input =
        \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
        \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
        \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
        \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
        \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
        \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
        \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
        \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
        \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
        \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
        \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
        \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
        \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
        \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
    ;
    try testing.expectEqual(
        @as(usize, 26),
        try countLocationsForY(testing.allocator, test_input, 10),
    );
}
