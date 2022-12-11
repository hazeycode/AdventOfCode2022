const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const debugPrint = std.debug.print;
const fixedBufferStream = std.io.fixedBufferStream;
const tokenize = std.mem.tokenize;
const eql = std.mem.eql;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const print = util.print;
const println = util.println;

const quicksort = @import("util/sort.zig").quicksort;

const max_monkeys = 16;

const MonkeyId = usize;

const ItemList = std.BoundedArray(isize, 64);

const Monkey = struct {
    items: ItemList,

    operation: struct {
        operator: enum { add, multiply },
        operand: union(enum) {
            old: void,
            constant: isize,
        },
    } = undefined,

    condition: struct {
        operand: isize,
        if_true: MonkeyId,
        if_false: MonkeyId,
    } = undefined,

    pub fn init() !@This() {
        return .{
            .items = try ItemList.init(0),
        };
    }
};

const MonkeyList = std.BoundedArray(Monkey, max_monkeys);

fn burn(comptime num: usize, iterator: anytype) void {
    comptime var i: usize = 0;
    inline while (i < num) : (i += 1) _ = iterator.next();
}

fn spawnMonkeyFromNote(reader: anytype) !Monkey {
    var monkey = try Monkey.init();
    var buf = [_]u8{0} ** 64;

    // skip first line
    _ = try reader.readUntilDelimiter(&buf, '\n');

    { // second line
        const line = try reader.readUntilDelimiter(&buf, '\n');
        var it = tokenize(u8, line, ":");
        _ = it.next();
        var list_it = tokenize(u8, it.next().?, ", ");
        while (list_it.next()) |num_token| {
            try monkey.items.append(try parseInt(isize, num_token, 10));
        }
    }
    { // third line
        const line = try reader.readUntilDelimiter(&buf, '\n');
        var it = tokenize(u8, line, " ");
        burn(4, &it);
        monkey.operation.operator = switch (it.next().?[0]) {
            '+' => .add,
            '*' => .multiply,
            else => @panic("Unhandled input"),
        };
        const operand_token = it.next().?;
        if (eql(u8, operand_token, "old")) {
            monkey.operation.operand = .old;
        } else {
            const num = try parseInt(isize, operand_token, 10);
            monkey.operation.operand = .{ .constant = num };
        }
    }
    { // fourth line
        const line = try reader.readUntilDelimiter(&buf, '\n');
        var it = tokenize(u8, line, " ");
        burn(3, &it);
        monkey.condition.operand = try parseInt(isize, it.next().?, 10);
    }
    { // fifth line
        const line = try reader.readUntilDelimiter(&buf, '\n');
        var it = tokenize(u8, line, " ");
        burn(5, &it);
        monkey.condition.if_true = try parseInt(MonkeyId, it.next().?, 10);
    }
    { // sixth line
        const line = (try reader.readUntilDelimiterOrEof(&buf, '\n')).?;
        var it = tokenize(u8, line, " ");
        burn(5, &it);
        monkey.condition.if_false = try parseInt(MonkeyId, it.next().?, 10);
    }
    { // last line (empty)
        _ = reader.readUntilDelimiter(&buf, '\n') catch {};
    }

    return monkey;
}

fn spawnMonkeysFromNotes(
    comptime num_monkeys: usize,
    reader: anytype,
) !MonkeyList {
    var monkeys = try MonkeyList.init(0);
    comptime var i: usize = 0;
    inline while (i < num_monkeys) : (i += 1) {
        try monkeys.append(try spawnMonkeyFromNote(reader));
    }
    return monkeys;
}

fn playRound(monkeys: []Monkey, counter: anytype) !void {
    for (monkeys) |*cur_monkey, id| {
        std.debug.print("Monkey: {}\n", .{id});
        while (cur_monkey.items.len > 0) {
            counter.increment(id);
            var worry = cur_monkey.items.orderedRemove(0);
            std.debug.print("  Inspect item with worry level {}\n", .{worry});
            const op = cur_monkey.operation;
            const operand = switch (op.operand) {
                .old => worry,
                .constant => |num| num,
            };
            switch (op.operator) {
                .add => worry += operand,
                .multiply => worry *= operand,
            }
            std.debug.print("    Worry level increased to {}\n", .{worry});
            worry = @floatToInt(
                isize,
                @floor(@intToFloat(f32, worry) / 3),
            );
            std.debug.print("    Worry level divided by 3 = {}\n", .{worry});
            const other_monkey_id = blk: {
                if (@mod(worry, cur_monkey.condition.operand) == 0) {
                    std.debug.print(
                        "    {} is divisible by 3\n",
                        .{worry},
                    );
                    break :blk cur_monkey.condition.if_true;
                } else {
                    std.debug.print(
                        "    {} is NOT divisible by 3\n",
                        .{worry},
                    );
                    break :blk cur_monkey.condition.if_false;
                }
            };
            assert(other_monkey_id != id);
            try monkeys[other_monkey_id].items.append(worry);
            std.debug.print(
                "    Item with worry level thrown to monkey {}\n",
                .{other_monkey_id},
            );
        }
    }
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day11.txt"));

    var monkeys = try spawnMonkeysFromNotes(8, input_stream.reader());

    var counter = struct {
        counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
        pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
            self.counts[monkey_id] += 1;
        }
    }{};

    comptime var i: comptime_int = 0;
    inline while (i < 20) : (i += 1) {
        try playRound(monkeys.slice(), &counter);
    }

    quicksort(&counter.counts, 0, counter.counts.len - 1, struct {
        pub fn compare(_: @This(), a: usize, b: usize) bool {
            return a > b;
        }
    }{});

    const part_one_answer = counter.counts[0] * counter.counts[1];
    println("part one answer = {}", .{part_one_answer});
}

test {
    var test_stream = fixedBufferStream(
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
        \\
        \\Monkey 1:
        \\  Starting items: 54, 65, 75, 74
        \\  Operation: new = old + 6
        \\  Test: divisible by 19
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 0
        \\
        \\Monkey 2:
        \\  Starting items: 79, 60, 97
        \\  Operation: new = old * old
        \\  Test: divisible by 13
        \\    If true: throw to monkey 1
        \\    If false: throw to monkey 3
        \\
        \\Monkey 3:
        \\  Starting items: 74
        \\  Operation: new = old + 3
        \\  Test: divisible by 17
        \\    If true: throw to monkey 0
        \\    If false: throw to monkey 1
    );

    var monkey_list = try spawnMonkeysFromNotes(4, test_stream.reader());
    var monkeys = monkey_list.slice();

    var counter = struct {
        counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
        pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
            self.counts[monkey_id] += 1;
        }
    }{};

    try playRound(monkeys, &counter);

    try testing.expectEqualSlices(
        isize,
        &[_]isize{ 20, 23, 27, 26 },
        monkeys[0].items.constSlice(),
    );

    comptime var i: comptime_int = 1;
    inline while (i < 20) : (i += 1) {
        try playRound(monkeys, &counter);
    }

    try testing.expectEqual(@as(usize, 101), counter.counts[0]);
    try testing.expectEqual(@as(usize, 95), counter.counts[1]);
    try testing.expectEqual(@as(usize, 7), counter.counts[2]);
    try testing.expectEqual(@as(usize, 105), counter.counts[3]);
}
