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

pub fn main() !void {
    var a = [_]?Prop{null} ** 1_114_112;

    // for ('\u{0}'..'\u{10ffff}') |i| {
    for ('\u{0}'..'\u{10}') |i| {
        const cp: u21 = @intCast(i);
        const prop = Prop.forCodePoint(cp);
        if (prop == .none) continue;
        a[cp] = prop;
    }

    const cp = '\u{10ffff}';
    const prop = Prop.forCodePoint(cp);
    if (prop != .none) a[cp] = prop;

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

    try writer.writeAll("const array = [_]?Prop{");
    for (&a, 0..) |v, i| {
        if (i != 0) try writer.writeByte(',');
        if (v) |p| {
            _ = try writer.print(".{s}", .{@tagName(p)});
        } else {
            try writer.writeAll("null");
        }
    }
    try writer.writeAll("};\n");

    const code =
        \\inline fn getProp(cp: u21) Prop {
        \\    return if (array[cp]) |prop| prop else .none;
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
