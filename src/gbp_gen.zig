const std = @import("std");

const gbp = @import("ziglyph").grapheme_break;

const Map = struct {
    store: [12]Prop = [_]Prop{.none} ** 12,
    len: u8 = 0,

    fn getOrPut(self: *Map, prop: Prop) usize {
        var index: ?usize = null;
        for (0..self.store.len) |i| {
            if (self.store[i] == prop) index = i;
        }

        if (index) |idx| {
            return idx;
        } else {
            self.store[self.len] = prop;
            self.len += 1;
            return self.len - 1;
        }
    }
};

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

pub fn main() !void {
    var stage_1: [4352]u21 = undefined;
    var stage_2: [1_114_112]u4 = undefined;
    var stage_3 = Map{};

    var current_block_offset: u21 = 0;

    for (0..0x10ffff + 1) |i| {
        const cp: u21 = @intCast(i);
        const stage_1_index = cp >> 8;
        const stage_2_index = current_block_offset + (cp & 0xff);
        const stage_3_index = stage_3.getOrPut(Prop.forCodePoint(cp));
        stage_1[stage_1_index] = current_block_offset;
        stage_2[stage_2_index] = @intCast(stage_3_index);
        if (cp & 0xff == 255) current_block_offset += 256;
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

    try writer.writeAll("const stage_1 = [_]u21{");
    for (stage_1, 0..) |v, i| {
        if (i != 0) try writer.writeByte(',');
        _ = try writer.print("{}", .{v});
    }
    try writer.writeAll("};\n");

    try writer.writeAll("const stage_2 = [_]u4{");
    for (stage_2, 0..) |v, i| {
        if (i != 0) try writer.writeByte(',');
        _ = try writer.print("{}", .{v});
    }
    try writer.writeAll("};\n");

    try writer.writeAll("const stage_3 = [_]Prop{");
    for (stage_3.store, 0..) |v, i| {
        if (i != 0) try writer.writeByte(',');
        _ = try writer.print(".{s}", .{@tagName(v)});
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
