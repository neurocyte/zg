const std = @import("std");
const mem = std.mem;

const gbp = @import("ziglyph").grapheme_break;

pub const Prop = enum {
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

    pub fn forCodePoint(cp: u21) Prop {
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

pub const Node = struct {
    children: [256]?*Node = [_]?*Node{null} ** 256,
    value: ?Prop = null,
};

pub const Trie = struct {
    allocator: mem.Allocator,
    root: Node,
    node_count: usize = 0,

    fn asBytes(cp: u24) []const u8 {
        const bytes: [3]u8 = @bitCast(cp);

        return if (bytes[0] < 128)
            bytes[0..1]
        else if (bytes[1] == 0)
            bytes[0..1]
        else if (bytes[2] == 0)
            bytes[0..2]
        else
            bytes[0..];
    }

    pub fn put(self: *Trie, cp: u24, v: Prop) !void {
        const s = asBytes(cp);
        var current: *Node = &self.root;

        for (s, 0..) |b, i| {
            if (current.children[b]) |n| {
                if (i == s.len - 1) {
                    n.value = v;
                    return;
                }

                current = n;
                continue;
            }

            self.node_count += 1;
            const new_node = try self.allocator.create(Node);
            new_node.* = .{ .value = if (i == s.len - 1) v else null };
            current.children[b] = new_node;
            current = new_node;
        }
    }

    pub fn get(self: Trie, cp: u24) ?Prop {
        const s = asBytes(cp);
        var current = &self.root;

        return for (s, 0..) |b, i| {
            if (current.children[b]) |n| {
                if (i == s.len - 1) break if (n.value) |v| v else null;
                current = n;
            }
        } else null;
    }
};

test "Trie works" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var trie = Trie{ .allocator = allocator, .root = .{} };

    const cp_1: u21 = '\u{10ffff}';
    const cp_2: u21 = '\u{10ff}';
    const cp_3: u21 = '\u{10}';

    try trie.put(cp_1, .control);
    try trie.put(cp_3, .zwj);
    try std.testing.expectEqual(@as(?Prop, .control), trie.get(cp_1));
    try std.testing.expectEqual(@as(?Prop, null), trie.get(cp_2));
    try std.testing.expectEqual(@as(?Prop, .zwj), trie.get(cp_3));
}
