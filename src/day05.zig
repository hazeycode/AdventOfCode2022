const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;
const parseInt = std.fmt.parseInt;

const util = @import("util/util.zig");
const println = util.println;
const range = util.range;

const max_stacks = 8;

const Instruction = struct {
    num: usize,
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

fn expectString(input_reader: anytype, expected: []const u8) !bool {
    var buf = [_]u8{0} ** 16;
    const token = try input_reader.readUntilDelimiter(buf[0..], ' ');
    return std.mem.eql(u8, expected, token);
}

fn readNumber(input_reader: anytype) !?usize {
    var buf = [_]u8{0} ** 16;
    const num_token = try input_reader.readUntilDelimiterOrEof(buf[0..], ' ') orelse {
        return null;
    };
    return try parseInt(usize, num_token, 10);
}

fn parseInstruction(bytes: []const u8) !Instruction {
    var fbs = fixedBufferStream(bytes);
    const reader = fbs.reader();

    if (try expectString(reader, "move") == false) {
        return InstructionParserError.ExpectedMoveToken;
    }

    const num = try readNumber(reader) orelse {
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
        .num = num,
        .from = from,
        .to = to,
    };
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day05.txt"));

    // var stacks = [_].{std.BoundedArray(u8, 64).init()} ** max_stacks;

    // const part_one_answer = try partOne(input_stream.reader());
    // println("part one answer = {}", .{part_one_answer});

    input_stream.reset();
}

test "parse instruction" {
    const test_bytes = "move 3 from 2 to 7";
    const expected_result = Instruction{
        .num = 3,
        .from = 2,
        .to = 7,
    };
    try testing.expectEqual(expected_result, try parseInstruction(test_bytes));
}
