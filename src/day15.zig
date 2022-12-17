const std = @import("std");
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const testing = std.testing;
const tokenize = std.mem.tokenize;
const parseInt = std.fmt.parseInt;
const min = std.math.min;
const max = std.math.max;

const util = @import("util/util.zig");
const println = util.println;

const quicksort = @import("util/sort.zig").quicksort;

const Location = struct { x: i64, y: i64 };

const SensorBeaconLocationPair = struct {
    sensor_location: Location,
    beacon_location: Location,
};

const LocationPairs = std.BoundedArray(SensorBeaconLocationPair, 32);

const Range = struct {
    start: i64,
    end: i64,

    fn len(self: @This()) usize {
        return @intCast(usize, self.end - self.start) + 1;
    }

    pub fn overlaps(self: @This(), other: @This()) bool {
        return self.start <= other.end and other.start <= self.end;
    }

    pub fn adjacent(self: @This(), other: @This()) bool {
        return self.end + 1 == other.start or self.start - 1 == other.end;
    }

    pub fn mergeable(self: @This(), other: @This()) bool {
        return self.overlaps(other) or self.adjacent(other);
    }

    pub fn merge(self: @This(), other: @This()) @This() {
        assert(self.mergeable(other));
        return Range{
            .start = min(self.start, other.start),
            .end = max(self.end, other.end),
        };
    }
};

const RangeList = std.BoundedArray(Range, 32);

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

fn mergeRanges(ranges: *RangeList) void {
    quicksort(
        ranges.slice(),
        0,
        @intCast(isize, ranges.len - 1),
        struct {
            pub fn compare(_: @This(), a: Range, b: Range) bool {
                return a.start < b.start;
            }
        }{},
    );
    while (true) {
        var did_merge = false;
        var i: usize = 1;
        while (i < ranges.len) : (i += 1) {
            if (ranges.get(i - 1).mergeable(ranges.get(i))) {
                ranges.set(i, ranges.get(i - 1).merge(ranges.get(i)));
                _ = ranges.orderedRemove(i - 1);
                did_merge = true;
                break;
            }
        }
        if (did_merge == false) {
            break;
        }
    }
}

fn getCoveredRangesForY(location_pairs: LocationPairs, y: i64) !RangeList {
    var res = try RangeList.init(0);
    for (location_pairs.constSlice()) |pair| {
        const beacon_dist = manhattanDistance(
            pair.sensor_location,
            pair.beacon_location,
        );
        var dy = pair.sensor_location.y - y;
        if (dy < 0) dy = -dy;
        if (dy > beacon_dist) continue; // outside sensor bounds

        const half_width = beacon_dist - dy;

        try res.append(.{
            .start = pair.sensor_location.x - half_width,
            .end = pair.sensor_location.x + half_width,
        });
    }
    mergeRanges(&res);
    return res;
}

fn sumRangeLengths(ranges: RangeList) usize {
    var sum: usize = 0;
    for (ranges.constSlice()) |range| {
        sum += range.len();
    }
    return sum;
}

fn countBeaconsWithY(
    ranges: RangeList,
    input_location_pairs: LocationPairs,
    y: i64,
) usize {
    var count: usize = 0;
    for (ranges.constSlice()) |range| {
        var x: i64 = range.start;
        while (x <= range.end) : (x += 1) {
            for (input_location_pairs.constSlice()) |pair| {
                if (pair.beacon_location.y != y) continue;
                if (pair.beacon_location.x == x) {
                    count += 1;
                    break;
                }
            }
        }
    }
    return count;
}

fn determinHiddenBeaconLocation(
    location_pairs: LocationPairs,
    max_y: i64,
) !Location {
    var y: i64 = 0;
    while (y <= max_y) : (y += 1) {
        var ranges = try getCoveredRangesForY(location_pairs, y);
        assert(ranges.len > 0);
        if (ranges.len == 1) {
            continue;
        }
        assert(ranges.len == 2);
        return .{ .x = ranges.get(0).end + 1, .y = y };
    }
    unreachable;
}

fn tuningFrequency(loc: Location) usize {
    return @intCast(usize, loc.x) * 4000000 + @intCast(usize, loc.y);
}

pub fn main() !void {
    const input_location_pairs = try parse(@embedFile("data/day15.txt"));

    { // part one
        const y = 2000000;
        const ranges = try getCoveredRangesForY(input_location_pairs, y);
        const part_one_answer = sumRangeLengths(ranges) - countBeaconsWithY(ranges, input_location_pairs, y);
        println("part one answer = {}", .{part_one_answer});
    }

    { // part two
        const beacon_location = try determinHiddenBeaconLocation(
            input_location_pairs,
            4000000,
        );
        const part_two_answer = tuningFrequency(beacon_location);
        println("part two answer = {}", .{part_two_answer});
    }
}

test {
    const input_location_pairs = try parse(
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
    );
    { // part one test
        const y = 10;
        const ranges = try getCoveredRangesForY(input_location_pairs, y);
        const beacon_count = countBeaconsWithY(ranges, input_location_pairs, y);
        try testing.expectEqual(@as(usize, 1), ranges.len);
        try testing.expectEqual(@as(usize, 26), sumRangeLengths(ranges) - beacon_count);
    }

    { // part two test
        const beacon_location = try determinHiddenBeaconLocation(
            input_location_pairs,
            20,
        );
        try testing.expectEqual(
            @as(usize, 56000011),
            tuningFrequency(beacon_location),
        );
    }
}
