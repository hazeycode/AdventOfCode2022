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

const ItemList = std.BoundedArray(usize, 64);

const Monkey = struct {
    items: ItemList,

    operation: struct {
        operator: enum { add, multiply },
        operand: union(enum) {
            old: void,
            constant: usize,
        },
    } = undefined,

    condition: struct {
        operand: usize,
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
            try monkey.items.append(try parseInt(usize, num_token, 10));
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
            const num = try parseInt(usize, operand_token, 10);
            monkey.operation.operand = .{ .constant = num };
        }
    }
    { // fourth line
        const line = try reader.readUntilDelimiter(&buf, '\n');
        var it = tokenize(u8, line, " ");
        burn(3, &it);
        monkey.condition.operand = try parseInt(usize, it.next().?, 10);
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

fn playRound_partOne(monkeys: []Monkey, counter: anytype) !void {
    for (monkeys) |*cur_monkey, id| {
        while (cur_monkey.items.len > 0) {
            counter.increment(id);
            var item = cur_monkey.items.orderedRemove(0);

            const op = cur_monkey.operation;
            const operand = switch (op.operand) {
                .old => item,
                .constant => |num| num,
            };
            switch (op.operator) {
                .add => item += operand,
                .multiply => item *= operand,
            }

            item = @divFloor(item, 3);

            const condition = cur_monkey.condition;
            const divisor = condition.operand;

            const r = @mod(item, divisor);

            const other_monkey_id = if (r == 0)
                condition.if_true
            else
                condition.if_false;

            assert(other_monkey_id != id);

            try monkeys[other_monkey_id].items.append(item);
        }
    }
}

fn playRound_partTwo(monkeys: []Monkey, lcm: usize, counter: anytype) !void {
    for (monkeys) |*cur_monkey, id| {
        while (cur_monkey.items.len > 0) {
            counter.increment(id);
            var item = cur_monkey.items.orderedRemove(0);

            item = @mod(item, lcm);

            const op = cur_monkey.operation;
            const operand = switch (op.operand) {
                .old => item,
                .constant => |num| num,
            };
            switch (op.operator) {
                .add => item += operand,
                .multiply => item *= operand,
            }

            const condition = cur_monkey.condition;
            const divisor = condition.operand;

            const r = @mod(item, divisor);
            const other_monkey_id = if (r == 0)
                condition.if_true
            else
                condition.if_false;

            assert(other_monkey_id != id);

            try monkeys[other_monkey_id].items.append(item);
        }
    }
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day11.txt"));

    { // part one
        var monkeys = try spawnMonkeysFromNotes(8, input_stream.reader());

        var counter = struct {
            counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
            pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
                self.counts[monkey_id] += 1;
            }
        }{};

        {
            var i: usize = 0;
            while (i < 20) : (i += 1) {
                try playRound_partOne(monkeys.slice(), &counter);
            }
        }

        quicksort(&counter.counts, 0, counter.counts.len - 1, struct {
            pub fn compare(_: @This(), a: usize, b: usize) bool {
                return a > b;
            }
        }{});

        const part_one_answer = counter.counts[0] * counter.counts[1];
        println("part one answer = {}", .{part_one_answer});
    }

    input_stream.reset();

    { // part two
        var monkeys = try spawnMonkeysFromNotes(8, input_stream.reader());

        var counter = struct {
            counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
            pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
                self.counts[monkey_id] += 1;
            }
        }{};

        {
            var i: usize = 0;
            while (i < 10_000) : (i += 1) {
                try playRound_partTwo(monkeys.slice(), 9699690, &counter);
            }
        }

        quicksort(&counter.counts, 0, counter.counts.len - 1, struct {
            pub fn compare(_: @This(), a: usize, b: usize) bool {
                return a > b;
            }
        }{});

        const part_two_answer = counter.counts[0] * counter.counts[1];
        println("part two answer = {}", .{part_two_answer});
    }
}

const test_input =
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
;

test {
    var test_stream = fixedBufferStream(test_input);

    var monkey_list = try spawnMonkeysFromNotes(4, test_stream.reader());
    var monkeys = monkey_list.slice();

    var counter = struct {
        counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
        pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
            self.counts[monkey_id] += 1;
        }
    }{};

    try playRound_partOne(monkeys, &counter);

    try testing.expectEqualSlices(
        usize,
        &[_]usize{ 20, 23, 27, 26 },
        monkeys[0].items.constSlice(),
    );

    {
        var i: usize = 1;
        while (i < 20) : (i += 1) {
            try playRound_partOne(monkeys, &counter);
        }
    }

    try testing.expectEqual(@as(usize, 101), counter.counts[0]);
    try testing.expectEqual(@as(usize, 95), counter.counts[1]);
    try testing.expectEqual(@as(usize, 7), counter.counts[2]);
    try testing.expectEqual(@as(usize, 105), counter.counts[3]);
}

test {
    var test_stream = fixedBufferStream(test_input);

    var monkey_list = try spawnMonkeysFromNotes(4, test_stream.reader());
    var monkeys = monkey_list.slice();

    var counter = struct {
        counts: [max_monkeys]usize = [_]usize{0} ** max_monkeys,
        pub fn increment(self: *@This(), monkey_id: MonkeyId) void {
            self.counts[monkey_id] += 1;
        }
    }{};

    {
        var i: usize = 0;
        while (i < 10_000) : (i += 1) {
            try playRound_partTwo(monkeys, 96577, &counter);
        }
    }

    try testing.expectEqual(@as(usize, 52166), counter.counts[0]);
    try testing.expectEqual(@as(usize, 47830), counter.counts[1]);
    try testing.expectEqual(@as(usize, 1938), counter.counts[2]);
    try testing.expectEqual(@as(usize, 52013), counter.counts[3]);
}
