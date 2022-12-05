const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const println = util.println;
const range = util.range;

const max_stacks = 32;
const max_stack_height = 64;

const CrateStack = std.BoundedArray(u8, max_stack_height);

const Instruction = struct {
    amount: usize,
    from: usize,
    to: usize,
};

const InstructionParserError = error{
    ExpectedMoveToken,
    ExpectedNumToken,
    ExpectedFromToken,
    ExpectedFromLocationToken,
    ExpectedToToken,
    ExpectedToLocationToken,
};

fn expectString(reader: anytype, expected: []const u8) !bool {
    var buf = [_]u8{0} ** 16;
    const token = try reader.readUntilDelimiter(buf[0..], ' ');
    return std.mem.eql(u8, expected, token);
}

fn readNumber(reader: anytype) !?usize {
    var buf = [_]u8{0} ** 16;
    const num_token = try reader.readUntilDelimiterOrEof(buf[0..], ' ') orelse {
        return null;
    };
    return try parseInt(usize, num_token, 10);
}

var stacks_line_buf: [max_stacks]u8 = undefined;

fn parseCrateStacksLine(num_stacks: usize, line_bytes: []const u8) ![]const u8 {
    var fbs = fixedBufferStream(line_bytes);
    const reader = fbs.reader();

    stacks_line_buf = [_]u8{' '} ** max_stacks;

    var i: usize = 0;
    while (i < num_stacks) : (i += 1) {
        try reader.skipBytes(1, .{});
        stacks_line_buf[i] = try reader.readByte();
        try reader.skipBytes(1, .{});
        reader.skipBytes(1, .{}) catch {
            if (i != num_stacks - 1) {
                return error.InvalidCrateStackLineFromat;
            }
        };
    }

    return stacks_line_buf[0..num_stacks];
}

fn readNumStacks(reader: anytype) !usize {
    var buf = [_]u8{0} ** 64;
    const line = try reader.readUntilDelimiter(buf[0..], '\n');
    return @divTrunc(line.len, 4) + 1;
}

var _stacks = [_]CrateStack{.{ .len = 0 }} ** max_stacks;

fn readCrateStacks(
    num_stacks: usize,
    reader: anytype,
) ![]CrateStack {
    var temp_stacks = [_]CrateStack{try CrateStack.init(0)} ** max_stacks;

    var buf = [_]u8{0} ** 64;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (std.mem.eql(u8, line[0..2], " 1")) {
            break;
        }
        for (try parseCrateStacksLine(num_stacks, line)) |char, i| {
            if (char >= 'A' and char <= 'Z') {
                try temp_stacks[i].append(char);
            }
        }
    }

    for (_stacks) |*stack| try stack.resize(0);

    for (temp_stacks) |*stack, i| {
        while (stack.popOrNull()) |crate| {
            try _stacks[i].append(crate);
        }
    }

    return _stacks[0..num_stacks];
}

fn parseInstruction(line_bytes: []const u8) !Instruction {
    var fbs = fixedBufferStream(line_bytes);
    const reader = fbs.reader();

    if (try expectString(reader, "move") == false) {
        return InstructionParserError.ExpectedMoveToken;
    }

    const amount = try readNumber(reader) orelse {
        return InstructionParserError.ExpectedNumToken;
    };

    if (try expectString(reader, "from") == false) {
        return InstructionParserError.ExpectedFromToken;
    }

    const from = try readNumber(reader) orelse {
        return InstructionParserError.ExpectedFromLocationToken;
    };

    if (try expectString(reader, "to") == false) {
        return InstructionParserError.ExpectedToToken;
    }

    const to = try readNumber(reader) orelse {
        return InstructionParserError.ExpectedToLocationToken;
    };

    return .{
        .amount = amount,
        .from = from,
        .to = to,
    };
}

var part_one_answer_stack = CrateStack{ .len = 0 };

fn partOne(stream: anytype) ![]const u8 {
    const num_stacks = try readNumStacks(stream.reader());

    stream.reset();

    const reader = stream.reader();

    var stacks = try readCrateStacks(num_stacks, reader);

    try reader.skipUntilDelimiterOrEof('\n');

    var buf = [_]u8{0} ** 64;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        const instruction = try parseInstruction(line);

        var i: usize = 0;
        while (i < instruction.amount) : (i += 1) {
            const crate = stacks[instruction.from - 1].popOrNull() orelse break;
            try stacks[instruction.to - 1].append(crate);
        }
    }

    for (stacks) |*stack| {
        try part_one_answer_stack.append(stack.popOrNull() orelse ' ');
    }

    return part_one_answer_stack.constSlice();
}

var part_two_answer_stack = CrateStack{ .len = 0 };

fn partTwo(stream: anytype) ![]const u8 {
    const num_stacks = try readNumStacks(stream.reader());

    stream.reset();

    const reader = stream.reader();

    var stacks = try readCrateStacks(num_stacks, reader);

    try reader.skipUntilDelimiterOrEof('\n');

    var buf = [_]u8{0} ** 64;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        const instruction = try parseInstruction(line);

        var temp_stack = try CrateStack.init(0);

        var i: usize = 0;
        while (i < instruction.amount) : (i += 1) {
            const crate = stacks[instruction.from - 1].popOrNull() orelse break;
            try temp_stack.append(crate);
        }

        while (temp_stack.len > 0) {
            const crate = temp_stack.popOrNull() orelse break;
            try stacks[instruction.to - 1].append(crate);
        }
    }

    for (stacks) |*stack| {
        try part_two_answer_stack.append(stack.popOrNull() orelse ' ');
    }

    return part_two_answer_stack.constSlice();
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day05.txt"));

    const part_one_answer = try partOne(&input_stream);
    println("part one answer = {s}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(&input_stream);
    println("part two answer = {s}", .{part_two_answer});
}

test "parse crate stack line" {
    const test_bytes = "[W]         [V]     [C] [T] [M]    ";
    const expected = "W  V CTM ";
    try testing.expectEqualSlices(
        u8,
        expected,
        (try parseCrateStacksLine(expected.len, test_bytes))[0..],
    );
}

test "read crate stacks" {
    var test_stream = std.io.fixedBufferStream(
        \\    [D]    
        \\[N] [C]    
        \\[Z] [M] [P]
        \\ 1   2   3 
    );

    const expected = [_][]const u8{
        "ZN",
        "MCD",
        "P",
    };

    const num_stacks = try readNumStacks(test_stream.reader());
    try testing.expectEqual(expected.len, num_stacks);

    test_stream.reset();

    const result = try readCrateStacks(num_stacks, test_stream.reader());

    for (expected) |stack, i| {
        try testing.expectEqualSlices(
            u8,
            stack,
            result[i].constSlice(),
        );
    }
}

test "parse instruction" {
    const test_bytes = "move 3 from 2 to 7";
    const expected_result = Instruction{
        .amount = 3,
        .from = 2,
        .to = 7,
    };
    try testing.expectEqual(
        expected_result,
        try parseInstruction(test_bytes),
    );
}

test "both parts" {
    var test_stream = std.io.fixedBufferStream(
        \\    [D]    
        \\[N] [C]    
        \\[Z] [M] [P]
        \\ 1   2   3 
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
    );

    const part_one_answer = try partOne(&test_stream);
    try testing.expectEqualSlices(u8, "CMZ", part_one_answer);

    test_stream.reset();

    const part_two_answer = try partTwo(&test_stream);
    try testing.expectEqualSlices(u8, "MCD", part_two_answer);
}
