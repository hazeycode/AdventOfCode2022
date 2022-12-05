const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const println = util.println;
const range = util.range;

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

fn parseCrateStacksLine(
    comptime CrateStacksLine: type,
    line_bytes: []const u8,
) !CrateStacksLine {
    var fbs = fixedBufferStream(line_bytes);
    const reader = fbs.reader();

    var res: CrateStacksLine = undefined;
    inline for (range(0, res.len - 1)) |i| {
        try reader.skipBytes(1, .{});
        res[i] = try reader.readByte();
        try reader.skipBytes(1, .{});
        reader.skipBytes(1, .{}) catch {
            if (i != res.len - 1) {
                return error.InvalidCrateStackLineFromat;
            }
        };
    }

    return res;
}

fn readCrateStacks(
    comptime num_stacks: usize,
    reader: anytype,
) ![num_stacks]CrateStack {
    var stacks = [_]CrateStack{try CrateStack.init(0)} ** num_stacks;

    var buf = [_]u8{0} ** 64;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (std.mem.eql(u8, line[0..2], " 1")) {
            break;
        }
        const stacks_line = try parseCrateStacksLine(
            [num_stacks]u8,
            line,
        );
        for (stacks_line) |char, i| {
            if (char >= 'A' and char <= 'Z') {
                try stacks[i].append(char);
            }
        }
    }

    var reversed = [_]CrateStack{try CrateStack.init(0)} ** num_stacks;
    for (stacks) |*stack, i| {
        while (stack.popOrNull()) |crate| {
            try reversed[i].append(crate);
        }
    }

    return reversed;
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

fn partOne(
    comptime num_stacks: usize,
    reader: anytype,
) ![num_stacks]u8 {
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

    var out_buf = [_]u8{0} ** num_stacks;
    for (stacks) |*stack, i| {
        out_buf[i] = stack.popOrNull() orelse ' ';
    }

    return out_buf;
}

fn partTwo(
    comptime num_stacks: usize,
    reader: anytype,
) ![num_stacks]u8 {
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

    var out_buf = [_]u8{0} ** num_stacks;
    for (stacks) |*stack, i| {
        out_buf[i] = stack.popOrNull() orelse ' ';
    }

    return out_buf;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day05.txt"));

    const part_one_answer = try partOne(9, input_stream.reader());
    println("part one answer = {s}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(9, input_stream.reader());
    println("part two answer = {s}", .{part_two_answer});
}

test "parse crate stack line" {
    const test_bytes = "[W]         [V]     [C] [T] [M]    ";
    const expected_result = "W  V CTM ";
    try testing.expectEqualSlices(
        u8,
        expected_result,
        (try parseCrateStacksLine([9]u8, test_bytes))[0..],
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

    const result = try readCrateStacks(expected.len, test_stream.reader());

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

    const part_one_answer = try partOne(3, test_stream.reader());
    try testing.expectEqualSlices(u8, "CMZ", &part_one_answer);

    test_stream.reset();

    const part_two_answer = try partTwo(3, test_stream.reader());
    try testing.expectEqualSlices(u8, "MCD", &part_two_answer);
}
