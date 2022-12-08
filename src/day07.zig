const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const fixedBufferStream = std.io.fixedBufferStream;
const tokenize = std.mem.tokenize;
const eql = std.mem.eql;
const parseInt = std.fmt.parseInt;
const Wyhash = std.hash.Wyhash;

const util = @import("util/util.zig");
const println = util.println;

const FileTree = struct {
    const max_path_len = 256;
    const max_entries = 2048;

    const CwdBuffer = std.BoundedArray(u8, max_path_len);
    const EntryBuffer = std.BoundedArray(Node, max_entries);

    const Node = struct {
        const Kind = enum { file, dir };

        parent: ?*@This(),
        first_child: ?*@This() = null,
        last_child: ?*@This() = null,
        next: ?*@This() = null,
        size: usize,
        hash: u64,

        pub fn appendChild(self: *@This(), node: *@This()) void {
            node.parent = self;
            if (self.last_child == null) {
                assert(self.first_child == null);
                self.first_child = node;
                self.last_child = node;
            } else {
                assert(self.last_child.?.next == null);
                self.last_child.?.next = node;
                self.last_child = node;
            }
        }

        pub fn childIterator(self: *const @This()) struct {
            cur: ?*Node,
            pub fn next(it: *@This()) ?*Node {
                if (it.cur) |node| {
                    it.cur = node.next;
                    return node;
                }
                return null;
            }
        } {
            return .{ .cur = self.first_child };
        }

        pub fn getTotalSize(self: *const @This()) usize {
            std.debug.assert(self.size == 0);
            var total: usize = 0;
            var it = self.childIterator();
            while (it.next()) |node| {
                total += switch (node.size) {
                    0 => node.getTotalSize(),
                    else => node.size,
                };
            }
            return total;
        }
    };

    cwd_buf: CwdBuffer,
    entries: EntryBuffer,
    root: *Node,
    cur: *Node,

    pub fn init() !@This() {
        var cwd = try CwdBuffer.init(0);
        try cwd.append('/');

        var entries = try EntryBuffer.init(0);
        try entries.append(.{
            .parent = null,
            .hash = Wyhash.hash(0, "/"),
            .size = 0,
        });

        const root = &entries.slice()[0];

        return .{
            .cwd_buf = cwd,
            .entries = entries,
            .root = root,
            .cur = root,
        };
    }

    pub fn cd(self: *@This(), path: []const u8) !void {
        var it = tokenize(u8, path, "/");
        while (it.next()) |part| {
            if (eql(u8, part, ".")) {
                continue;
            }

            if (eql(u8, part, "..")) {
                self.popCwd();
            } else {
                try self.pushCwd(part);
            }
        }
    }

    pub fn addFileToCwd(self: *@This(), filename: []const u8, size: usize) !void {
        var buf: [max_path_len]u8 = undefined;
        const file_path = try std.fmt.bufPrint(
            &buf,
            "{s}{s}",
            .{ self.cwd_buf.constSlice(), filename },
        );

        const hash = Wyhash.hash(0, file_path);

        var it = self.cur.childIterator();
        while (it.next()) |node| {
            if (node.*.hash == hash) break;
        } else {
            _ = try self.createChildinCwd(hash, size);
        }
    }

    pub fn addDirToCwd(self: *@This(), name: []const u8) !void {
        var buf: [max_path_len]u8 = undefined;
        const file_path = try std.fmt.bufPrint(
            &buf,
            "{s}{s}/",
            .{ self.cwd_buf.constSlice(), name },
        );

        const hash = Wyhash.hash(0, file_path);

        var it = self.cur.childIterator();
        while (it.next()) |node| {
            if (node.*.hash == hash) break;
        } else {
            _ = try self.createChildinCwd(hash, 0);
        }
    }

    fn pushCwd(self: *@This(), dir_name: []const u8) !void {
        for (dir_name) |c| {
            if (c == '/') break;
            try self.cwd_buf.append(c);
        }
        try self.cwd_buf.append('/');

        const dir_path = self.cwd_buf.constSlice();

        const hash = Wyhash.hash(0, dir_path);

        for (self.entries.slice()) |*entry| {
            if (entry.*.hash == hash) {
                self.cur = entry;
                break;
            }
        } else return error.NoSuchDir;
    }

    fn popCwd(self: *@This()) void {
        if (self.cur.parent) |parent| {
            self.cur = parent;

            _ = self.cwd_buf.pop();
            while (self.cwd_buf.get(self.cwd_buf.len - 1) != '/') {
                _ = self.cwd_buf.pop();
            }
        }
    }

    fn createChildinCwd(
        self: *@This(),
        hash: u64,
        size: usize,
    ) !*Node {
        try self.entries.append(.{
            .parent = self.cur,
            .size = size,
            .hash = hash,
        });
        const ptr = &self.entries.slice()[self.entries.len - 1];
        self.cur.appendChild(ptr);
        return ptr;
    }
};

fn parseFileTree(reader: anytype) !FileTree {
    var fs = try FileTree.init();

    var buf = [_]u8{0} ** 64;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var tokenizer = tokenize(u8, line, " ");
        const first = tokenizer.next() orelse return error.ExpectedToken;

        if (eql(u8, first, "$")) {
            // reading a command
            const command = tokenizer.next() orelse return error.ExpectedToken;
            if (eql(u8, command, "cd")) {
                const dir_name = tokenizer.next() orelse return error.ExpectedToken;
                try fs.cd(dir_name);
            } else if (eql(u8, command, "ls")) {
                continue;
            } else return error.UnexpectedToken;
        } else if (eql(u8, first, "dir")) {
            // reading a dir entry
            const name = tokenizer.next() orelse return error.ExpectedToken;
            try fs.addDirToCwd(name);
        } else {
            // assume then reading a file entry starting with it's size
            const size = try parseInt(usize, first, 10);

            // the second token should be the filename
            const filename = tokenizer.next() orelse return error.ExpectedToken;

            try fs.addFileToCwd(filename, size);
        }
    }

    return fs;
}

fn partOne(reader: anytype) !usize {
    const fs = try parseFileTree(reader);

    var total: usize = 0;
    for (fs.entries.constSlice()) |entry| {
        if (entry.size == 0) {
            const dir_size = entry.getTotalSize();
            if (dir_size <= 100000) {
                total += dir_size;
            }
        }
    }
    return total;
}

fn partTwo(reader: anytype) !usize {
    const fs = try parseFileTree(reader);

    const total_space = 70000000;
    const space_required = 30000000;
    const used_space = fs.root.getTotalSize();
    const free_space = total_space - used_space;
    const to_delete = space_required - free_space;

    var smallest: usize = used_space;
    for (fs.entries.constSlice()) |entry| {
        if (entry.size == 0) {
            const dir_size = entry.getTotalSize();
            if (dir_size >= to_delete and dir_size < smallest) {
                smallest = dir_size;
            }
        }
    }
    return smallest;
}

pub fn main() !void {
    var input_stream = fixedBufferStream(@embedFile("data/day07.txt"));

    const part_one_answer = try partOne(input_stream.reader());
    println("part one answer = {}", .{part_one_answer});

    input_stream.reset();

    const part_two_answer = try partTwo(input_stream.reader());
    println("part two answer = {}", .{part_two_answer});
}

test "FileTree" {
    var fs = try FileTree.init();
    try testing.expectEqual(@as(usize, 1), fs.entries.constSlice().len);

    try testing.expectEqualSlices(u8, "/", fs.cwd_buf.constSlice());

    try fs.cd("/");
    try testing.expectEqual(@as(usize, 1), fs.entries.constSlice().len);

    try fs.addFileToCwd("test.txt", 1024);
    try testing.expectEqual(@as(usize, 2), fs.entries.constSlice().len);
    try testing.expectEqual(
        @as(?*FileTree.Node, fs.root),
        fs.root.first_child.?.parent,
    );

    try fs.addDirToCwd("subfolders");
    try testing.expectEqual(@as(usize, 3), fs.entries.constSlice().len);

    try fs.cd("subfolders");
    try testing.expect(fs.root.last_child != null);
    try testing.expectEqual(
        fs.root.first_child.?.next,
        fs.root.last_child,
    );

    try fs.addFileToCwd("little.txt", 64);
    try testing.expectEqual(@as(usize, 4), fs.entries.constSlice().len);
    try testing.expect(fs.root.last_child.?.first_child != null);

    try fs.addDirToCwd("001");
    try testing.expectEqual(@as(usize, 5), fs.entries.constSlice().len);

    try fs.cd("001");
    try testing.expectEqualSlices(u8, "/subfolders/001/", fs.cwd_buf.constSlice());

    try fs.addFileToCwd("ooops.bin", 4096);
    try testing.expectEqual(@as(usize, 6), fs.entries.constSlice().len);

    try fs.cd("..");
    try testing.expectEqualSlices(u8, "/subfolders/", fs.cwd_buf.constSlice());

    const all_entries = fs.entries.constSlice();

    for ([_]u64{
        Wyhash.hash(0, "/"),
        Wyhash.hash(0, "/test.txt"),
        Wyhash.hash(0, "/subfolders/"),
        Wyhash.hash(0, "/subfolders/little.txt"),
        Wyhash.hash(0, "/subfolders/001/"),
        Wyhash.hash(0, "/subfolders/001/ooops.bin"),
    }) |expected_hash, i| {
        try testing.expectEqual(expected_hash, all_entries[i].hash);
    }

    var total_size: usize = 0;
    for (all_entries) |entry| {
        total_size += entry.size;
    }
    try testing.expectEqual(
        @as(usize, 1024 + 4096 + 64),
        total_size,
    );
}

test {
    var test_stream = fixedBufferStream(
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
    );
    const fs = try parseFileTree(test_stream.reader());
    const entries = fs.entries.constSlice();
    for ([_]u64{
        Wyhash.hash(0, "/"),
        Wyhash.hash(0, "/a/"),
        Wyhash.hash(0, "/b.txt"),
        Wyhash.hash(0, "/c.dat"),
        Wyhash.hash(0, "/d/"),
        Wyhash.hash(0, "/a/e/"),
        Wyhash.hash(0, "/a/f"),
        Wyhash.hash(0, "/a/g"),
        Wyhash.hash(0, "/a/h.lst"),
        Wyhash.hash(0, "/a/e/i"),
        Wyhash.hash(0, "/d/j"),
        Wyhash.hash(0, "/d/d.log"),
        Wyhash.hash(0, "/d/d.ext"),
        Wyhash.hash(0, "/d/k"),
    }) |expected_hash, i| {
        try testing.expectEqual(expected_hash, entries[i].hash);
    }

    try testing.expectEqual(@as(usize, 48381165), fs.root.getTotalSize());

    test_stream.reset();

    try testing.expectEqual(
        @as(usize, 95437),
        try partOne(test_stream.reader()),
    );
}
