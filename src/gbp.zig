const std = @import("std");
const mem = std.mem;

const gbp = @import("ziglyph").grapheme_break;
const Trie = @import("trie.zig").Trie;
const Prop = @import("trie.zig").Prop;

var trie: Trie = undefined;

pub fn init(allocator: mem.Allocator) !void {
    trie = .{ .allocator = allocator, .root = .{} };

    for ('\u{0}'..'\u{10ffff}') |i| {
        const cp: u21 = @intCast(i);
        const prop = Prop.forCodePoint(cp);
        if (prop == .none) continue;
        try trie.put(cp, prop);
    }

    const prop = Prop.forCodePoint('\u{10ffff}');
    if (prop == .none) return;
    try trie.put('\u{10ffff}', prop);
}

inline fn getProp(cp: u21) Prop {
    return if (trie.get(cp)) |prop| prop else .none;
}

pub inline fn isControl(cp: u21) bool {
    return getProp(cp) == .control;
}

pub inline fn isExtend(cp: u21) bool {
    return getProp(cp) == .extend;
}

pub inline fn isL(cp: u21) bool {
    return getProp(cp) == .hangul_l;
}
pub inline fn isLv(cp: u21) bool {
    return getProp(cp) == .hangul_lv;
}
pub inline fn isLvt(cp: u21) bool {
    return getProp(cp) == .hangul_lvt;
}
pub inline fn isV(cp: u21) bool {
    return getProp(cp) == .hangul_v;
}
pub inline fn isT(cp: u21) bool {
    return getProp(cp) == .hangul_t;
}

pub inline fn isPrepend(cp: u21) bool {
    return getProp(cp) == .prepend;
}

pub inline fn isRegionalIndicator(cp: u21) bool {
    return getProp(cp) == .regional;
}

pub inline fn isSpacingmark(cp: u21) bool {
    return getProp(cp) == .spacing;
}

pub inline fn isZwj(cp: u21) bool {
    return getProp(cp) == .zwj;
}
