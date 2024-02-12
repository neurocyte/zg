const std = @import("std");
const mem = std.mem;

pub const Color = enum { red, blue };

pub const Node = struct {
    children: [256]?*Node = [_]?*Node{null} ** 256,
    value: ?Color = null,
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

    pub fn put(self: *Trie, cp: u24, v: Color) !void {
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

    pub fn get(self: Trie, cp: u24) ?Color {
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

    try trie.put(cp_1, .red);
    try trie.put(cp_3, .blue);
    try std.testing.expectEqual(@as(?Color, .red), trie.get(cp_1));
    try std.testing.expectEqual(@as(?Color, null), trie.get(cp_2));
    try std.testing.expectEqual(@as(?Color, .blue), trie.get(cp_3));
}
