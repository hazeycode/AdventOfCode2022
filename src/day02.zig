const std = @import("std");
const assert = std.debug.assert;

const println = @import("util/util.zig").println;

const Move = enum { rock, paper, scissors };

const Outcome = enum(u8) {
    lose = 0,
    draw = 3,
    win = 6,
};

fn mapOpponentMove(sym: u8) Move {
    return switch (sym) {
        'A' => .rock,
        'B' => .paper,
        'C' => .scissors,
        else => unreachable,
    };
}

fn play(opponent_move: Move, response: Move) Outcome {
    return switch (opponent_move) {
        .rock => switch (response) {
            .rock => .draw,
            .paper => .win,
            .scissors => .lose,
        },
        .paper => switch (response) {
            .rock => .lose,
            .paper => .draw,
            .scissors => .win,
        },
        .scissors => switch (response) {
            .rock => .win,
            .paper => .lose,
            .scissors => .draw,
        },
    };
}

fn score(opponent_move: Move, response: Move) usize {
    return (@enumToInt(response) + 1) + @enumToInt(play(opponent_move, response));
}

fn partOne(input_reader: anytype) !usize {
    var acc: usize = 0;

    var buf = [_]u8{0} ** 16;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        assert(line.len == 3);
        acc += score(
            mapOpponentMove(line[0]),
            switch (line[2]) {
                'X' => .rock,
                'Y' => .paper,
                'Z' => .scissors,
                else => unreachable,
            },
        );
    }

    return acc;
}

fn partTwo(input_reader: anytype) !usize {
    var acc: usize = 0;

    var buf = [_]u8{0} ** 16;
    while (try input_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        assert(line.len == 3);

        const opponent_move = mapOpponentMove(line[0]);

        acc += score(
            opponent_move,
            switch (line[2]) {
                'X' => switch (opponent_move) {
                    .rock => .scissors,
                    .paper => .rock,
                    .scissors => .paper,
                },
                'Y' => switch (opponent_move) {
                    .rock => .rock,
                    .paper => .paper,
                    .scissors => .scissors,
                },
                'Z' => switch (opponent_move) {
                    .rock => .paper,
                    .paper => .scissors,
                    .scissors => .rock,
                },
                else => unreachable,
            },
        );
    }

    return acc;
}

pub fn main() !void {
    var input_stream = std.io.fixedBufferStream(@embedFile("data/day02.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}
