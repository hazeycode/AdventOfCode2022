const std = @import("std");
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const testing = std.testing;
const fixedBufferStream = std.io.fixedBufferStream;
const bufferedReader = std.io.bufferedReader;
const parseInt = std.fmt.parseInt;
const ArenaAllocator = std.heap.ArenaAllocator;

const util = @import("util/util.zig");
const println = util.println;

const List = std.TailQueue(Value);

const Value = union(enum) {
    list: List,
    integer: u8,

    pub fn initWithEmptyList() @This() {
        return .{ .list = List{} };
    }

    pub fn initWithInteger(integer: u8) @This() {
        return .{ .integer = integer };
    }
};

fn parsePacket(allocator: std.mem.Allocator, bytes: []const u8) !Value {
    assert(bytes[0] == '[');
    assert(bytes[bytes.len - 1] == ']');

    var child_list_stack = try std.BoundedArray(*Value, 32).init(0);

    var root = Value.initWithEmptyList();
    try child_list_stack.append(&root);

    var i: usize = 1;
    while (i < bytes.len - 1) : (i += 1) {
        const c = bytes[i];
        if (c == '[') {
            var node = try allocator.create(List.Node);
            node.data = Value.initWithEmptyList();
            child_list_stack.slice()[child_list_stack.len - 1].list.append(node);
            try child_list_stack.append(&node.data);
        } else if (c == ']') {
            _ = child_list_stack.pop();
        } else if (c == ',') {
            // skip
        } else {
            var j = i + 1;
            while (bytes[j] != ',' and bytes[j] != ']') : (j += 1) {}
            const integer = try parseInt(u8, bytes[i..j], 10);
            var node = try allocator.create(List.Node);
            node.data = Value.initWithInteger(integer);
            child_list_stack.slice()[child_list_stack.len - 1].list.append(node);
            i = j - 1;
        }
    }

    assert(child_list_stack.len == 1);
    return root;
}

fn parseNextPair(allocator: std.mem.Allocator, reader: anytype) !?[2]Value {
    var first_line_buf = [_]u8{0} ** 256;
    const first_line = try reader.readUntilDelimiterOrEof(
        &first_line_buf,
        '\n',
    ) orelse return null;

    var second_line_buf = [_]u8{0} ** 256;
    const second_line = try reader.readUntilDelimiterOrEof(
        &second_line_buf,
        '\n',
    ) orelse return null;

    // burn empty line
    try reader.skipUntilDelimiterOrEof('\n');

    return .{
        try parsePacket(allocator, first_line),
        try parsePacket(allocator, second_line),
    };
}

fn check(allocator: std.mem.Allocator, a: Value, b: Value) !?bool {
    if (a == .integer and b == .integer) {
        if (a.integer == b.integer) return null;
        if (a.integer < b.integer) return true;
        return false;
    } else if (a == .list and b == .list) {
        var cur_a: ?*List.Node = a.list.first;
        var cur_b: ?*List.Node = b.list.first;
        while (true) {
            if (cur_a == null and cur_b == null) return null;
            if (cur_a == null) return true;
            if (cur_b == null) return false;

            if (try check(
                allocator,
                cur_a.?.data,
                cur_b.?.data,
            )) |in_order| {
                return in_order;
            }

            cur_a = cur_a.?.next;
            cur_b = cur_b.?.next;
        }
        unreachable;
    } else {
        var node = try allocator.create(List.Node);
        var wrapper = Value.initWithEmptyList();
        if (a == .integer) {
            node.data = a;
            wrapper.list.append(node);
            return try check(allocator, wrapper, b);
        } else { // b is the integer to wrap
            node.data = b;
            wrapper.list.append(node);
            return try check(allocator, a, wrapper);
        }
    }
}

pub fn main() !void {
    var input = fixedBufferStream(@embedFile("data/day13.txt"));

    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var sum: usize = 0;
    var i: usize = 1;
    while (try parseNextPair(allocator, input.reader())) |pair| {
        if ((try check(allocator, pair[0], pair[1])).?) {
            sum += i;
        }
        i += 1;
    }
    println("part one answer = {}", .{sum});
}

test {
    var test_stream = fixedBufferStream(
        \\[1,1,3,1,1]
        \\[1,1,5,1,1]
        \\
        \\[[1],[2,3,4]]
        \\[[1],4]
        \\
        \\[9]
        \\[[8,7,6]]
        \\
        \\[[4,4],4,4]
        \\[[4,4],4,4,4]
        \\
        \\[7,7,7,7]
        \\[7,7,7]
        \\
        \\[]
        \\[3]
        \\
        \\[[[]]]
        \\[[]]
        \\
        \\[1,[2,[3,[4,[5,6,7]]]],8,9]
        \\[1,[2,[3,[4,[5,6,0]]]],8,9]
    );

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    try expectNextInOrder(true, allocator, test_stream.reader());
    try expectNextInOrder(true, allocator, test_stream.reader());
    try expectNextInOrder(false, allocator, test_stream.reader());
    try expectNextInOrder(true, allocator, test_stream.reader());
    try expectNextInOrder(false, allocator, test_stream.reader());
    try expectNextInOrder(true, allocator, test_stream.reader());
    try expectNextInOrder(false, allocator, test_stream.reader());
    try expectNextInOrder(false, allocator, test_stream.reader());
}

fn expectNextInOrder(
    comptime in_order: bool,
    allocator: std.mem.Allocator,
    reader: anytype,
) !void {
    const pair = (try parseNextPair(allocator, reader)).?;
    try testing.expectEqual(
        in_order,
        (try check(allocator, pair[0], pair[1])).?,
    );
}
