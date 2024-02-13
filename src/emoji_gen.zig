const std = @import("std");

const emoji = @import("ziglyph").emoji;

const block_size = 256;
const Block = [block_size]bool;

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
            return std.mem.eql(bool, &a, &b);
        }
    },
    std.hash_map.default_max_load_percentage,
);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var blocks_map = BlockMap.init(allocator);
    defer blocks_map.deinit();

    var stage1 = std.ArrayList(u16).init(allocator);
    defer stage1.deinit();

    var stage2 = std.ArrayList(bool).init(allocator);
    defer stage2.deinit();

    var block: Block = [_]bool{false} ** block_size;
    var block_len: u16 = 0;

    for (0..0x10ffff + 1) |cp| {
        const isEmoji = emoji.isExtendedPictographic(@intCast(cp));

        block[block_len] = isEmoji;
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

    try writer.print("const stage_1 = [{}]u16{{", .{stage1.items.len});
    for (stage1.items) |v| {
        _ = try writer.print("{},", .{v});
    }
    try writer.writeAll("};\n");

    try writer.print("const stage_2 = [{}]bool{{", .{stage2.items.len});
    for (stage2.items) |v| {
        _ = try writer.print("{},", .{v});
    }
    try writer.writeAll("};\n");

    const code =
        \\pub inline fn isExtendedPictographic(cp: u21) bool {
        \\    const stage_1_index = cp >> 8;
        \\    const stage_2_index = stage_1[stage_1_index] + (cp & 0xff);
        \\    return stage_2[stage_2_index];
        \\}
        \\
    ;

    try writer.writeAll(code);

    try out_buf.flush();
}
