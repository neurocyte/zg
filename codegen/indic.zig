const std = @import("std");

const Prop = enum {
    none,

    Consonant,
    Extend,
    Linker,
};

const block_size = 256;
const Block = [block_size]u3;

const BlockMap = std.HashMap(
    Block,
    u16,
    struct {
        pub fn hash(_: @This(), k: Block) u64 {
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, k, .DeepRecursive);
            return hasher.final();
        }

        pub fn eql(_: @This(), a: Block, b: Block) bool {
            return std.mem.eql(u3, &a, &b);
        }
    },
    std.hash_map.default_max_load_percentage,
);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var prop_map = std.AutoHashMap(u21, Prop).init(allocator);
    defer prop_map.deinit();

    var in_file = try std.fs.cwd().openFile("unicode/DerivedCoreProperties.txt", .{});
    defer in_file.close();
    var in_buf = std.io.bufferedReader(in_file.reader());
    const reader = in_buf.reader();

    var line_buf: [4096]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        if (std.mem.indexOf(u8, line, "InCB") == null) continue;
        const no_comment = if (std.mem.indexOfScalar(u8, line, '#')) |octo| line[0..octo] else line;

        var field_iter = std.mem.tokenizeAny(u8, no_comment, "; ");
        var current_code: [2]u21 = undefined;

        var i: usize = 0;
        while (field_iter.next()) |field| : (i += 1) {
            switch (i) {
                0 => {
                    // Code point(s)
                    if (std.mem.indexOf(u8, field, "..")) |dots| {
                        current_code = .{
                            try std.fmt.parseInt(u21, field[0..dots], 16),
                            try std.fmt.parseInt(u21, field[dots + 2 ..], 16),
                        };
                    } else {
                        const code = try std.fmt.parseInt(u21, field, 16);
                        current_code = .{ code, code };
                    }
                },
                2 => {
                    // Prop
                    const prop = std.meta.stringToEnum(Prop, field) orelse return error.InvalidPorp;
                    for (current_code[0]..current_code[1] + 1) |cp| try prop_map.put(@intCast(cp), prop);
                },
                else => {},
            }
        }
    }

    var blocks_map = BlockMap.init(allocator);
    defer blocks_map.deinit();

    var stage1 = std.ArrayList(u16).init(allocator);
    defer stage1.deinit();

    var stage2 = std.ArrayList(u3).init(allocator);
    defer stage2.deinit();

    var stage3 = std.ArrayList(Prop).init(allocator);
    defer stage3.deinit();

    var block: Block = [_]u3{0} ** block_size;
    var block_len: u16 = 0;

    for (0..0x110000) |i| {
        const cp: u21 = @intCast(i);
        const prop = prop_map.get(cp) orelse .none;

        const block_idx = blk: {
            for (stage3.items, 0..) |item, j| {
                if (item == prop) break :blk j;
            }

            const idx = stage3.items.len;
            try stage3.append(prop);
            break :blk idx;
        };

        block[block_len] = @intCast(block_idx);
        block_len += 1;

        if (block_len < block_size and cp != 0x10ffff) continue;

        const gop = try blocks_map.getOrPut(block);
        if (!gop.found_existing) {
            gop.value_ptr.* = @intCast(stage2.items.len);
            try stage2.appendSlice(&block);
        }

        try stage1.append(gop.value_ptr.*);
        block_len = 0;
    }

    var args_iter = std.process.args();
    _ = args_iter.skip();
    const output_path = args_iter.next() orelse @panic("No output file arg!");

    var out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    var out_buf = std.io.bufferedWriter(out_file.writer());
    const writer = out_buf.writer();

    const prop_code =
        \\const Prop = enum {
        \\    none,
        \\
        \\    Consonant,
        \\    Extend,
        \\    Linker,
        \\};
        \\
    ;

    try writer.writeAll(prop_code);

    try writer.print("const stage_1 = [{}]u16{{", .{stage1.items.len});
    for (stage1.items) |v| {
        _ = try writer.print("{},", .{v});
    }
    try writer.writeAll("};\n");

    try writer.print("const stage_2 = [{}]u3{{", .{stage2.items.len});
    for (stage2.items) |v| {
        _ = try writer.print("{},", .{v});
    }
    try writer.writeAll("};\n");

    try writer.print("const stage_3 = [{}]Prop{{", .{stage3.items.len});
    for (stage3.items) |v| {
        _ = try writer.print(".{s},", .{@tagName(v)});
    }
    try writer.writeAll("};\n");

    const code =
        \\inline fn getProp(cp: u21) Prop {
        \\    const stage_1_index = cp >> 8;
        \\    const stage_2_index = stage_1[stage_1_index] + (cp & 0xff);
        \\    const stage_3_index = stage_2[stage_2_index];
        \\    return stage_3[stage_3_index];
        \\}
        \\
        \\pub inline fn isConsonant(cp: u21) bool {
        \\    return getProp(cp) == .Consonant;
        \\}
        \\
        \\pub inline fn isExtend(cp: u21) bool {
        \\    return getProp(cp) == .Extend;
        \\}
        \\
        \\pub inline fn isLinker(cp: u21) bool {
        \\    return getProp(cp) == .Linker;
        \\}
        \\
    ;

    try writer.writeAll(code);

    try out_buf.flush();
}
