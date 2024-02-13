const std = @import("std");

const gbp = @import("ziglyph").grapheme_break;

const Prop = enum {
    none,

    control,
    extend,
    hangul_l,
    hangul_lv,
    hangul_lvt,
    hangul_v,
    hangul_t,
    prepend,
    regional,
    spacing,
    zwj,

    fn forCodePoint(cp: u21) Prop {
        if (gbp.isControl(cp)) return .control;
        if (gbp.isExtend(cp)) return .extend;
        if (gbp.isL(cp)) return .hangul_l;
        if (gbp.isLv(cp)) return .hangul_lv;
        if (gbp.isLvt(cp)) return .hangul_lvt;
        if (gbp.isT(cp)) return .hangul_t;
        if (gbp.isV(cp)) return .hangul_v;
        if (gbp.isPrepend(cp)) return .prepend;
        if (gbp.isRegionalIndicator(cp)) return .regional;
        if (gbp.isSpacingmark(cp)) return .spacing;
        if (gbp.isZwj(cp)) return .zwj;

        return .none;
    }
};

const block_size = 256;
const Block = [block_size]u4;

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
            return std.mem.eql(u4, &a, &b);
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

    var stage2 = std.ArrayList(u4).init(allocator);
    defer stage2.deinit();

    var stage3 = std.ArrayList(Prop).init(allocator);
    defer stage3.deinit();

    var block: Block = undefined;
    var block_len: u16 = 0;

    for (0..0x10ffff + 1) |cp| {
        const prop = Prop.forCodePoint(@intCast(cp));

        const block_idx = blk: {
            for (stage3.items, 0..) |item, i| {
                if (item == prop) break :blk i;
            }

            const idx = stage3.items.len;
            try stage3.append(prop);
            break :blk idx;
        };

        block[block_len] = @intCast(block_idx);
        block_len += 1;

        if (block_len < block_size and cp != 0x10ffff) continue;
        if (block_len < block_size) @memset(block[block_len..block_size], 0);

        const gop = try blocks_map.getOrPut(block);
        if (!gop.found_existing) {
            gop.value_ptr.* = @intCast(stage2.items.len);
            try stage2.appendSlice(block[0..block_len]);
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
        \\    control,
        \\    extend,
        \\    hangul_l,
        \\    hangul_lv,
        \\    hangul_lvt,
        \\    hangul_v,
        \\    hangul_t,
        \\    prepend,
        \\    regional,
        \\    spacing,
        \\    zwj,
        \\};
        \\
    ;

    try writer.writeAll(prop_code);

    try writer.print("const stage_1 = [{}]u16{{", .{stage1.items.len});
    for (stage1.items) |v| {
        _ = try writer.print("{},", .{v});
    }
    try writer.writeAll("};\n");

    try writer.print("const stage_2 = [{}]u4{{", .{stage2.items.len});
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
        \\pub inline fn isControl(cp: u21) bool {
        \\    return getProp(cp) == .control;
        \\}
        \\
        \\pub inline fn isExtend(cp: u21) bool {
        \\    return getProp(cp) == .extend;
        \\}
        \\
        \\pub inline fn isL(cp: u21) bool {
        \\    return getProp(cp) == .hangul_l;
        \\}
        \\pub inline fn isLv(cp: u21) bool {
        \\    return getProp(cp) == .hangul_lv;
        \\}
        \\pub inline fn isLvt(cp: u21) bool {
        \\    return getProp(cp) == .hangul_lvt;
        \\}
        \\pub inline fn isV(cp: u21) bool {
        \\    return getProp(cp) == .hangul_v;
        \\}
        \\pub inline fn isT(cp: u21) bool {
        \\    return getProp(cp) == .hangul_t;
        \\}
        \\
        \\pub inline fn isPrepend(cp: u21) bool {
        \\    return getProp(cp) == .prepend;
        \\}
        \\
        \\pub inline fn isRegionalIndicator(cp: u21) bool {
        \\    return getProp(cp) == .regional;
        \\}
        \\
        \\pub inline fn isSpacingmark(cp: u21) bool {
        \\    return getProp(cp) == .spacing;
        \\}
        \\
        \\pub inline fn isZwj(cp: u21) bool {
        \\    return getProp(cp) == .zwj;
        \\}
        \\
    ;

    try writer.writeAll(code);

    try out_buf.flush();
}
