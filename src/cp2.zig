const std = @import("std");

const Utf8Decoder = @import("Utf8Decoder.zig");

/// `CodePoint` represents a Unicode code point by its code,
/// length, and offset in the source bytes.
pub const CodePoint = struct {
    code: u21,
    len: u3,
    offset: u32,
};

/// `Iterator` iterates a string one `CodePoint` at-a-time.
pub const Iterator = struct {
    bytes: []const u8,
    decoder: Utf8Decoder = .{},
    i: u32 = 0,

    pub fn next(self: *Iterator) ?CodePoint {
        if (self.i >= self.bytes.len) return null;

        if (self.bytes[self.i] < 128) {
            // ASCII fast path
            defer self.i += 1;
            return .{
                .code = self.bytes[self.i],
                .len = 1,
                .offset = self.i,
            };
        }

        for (self.bytes[self.i..], 1..) |b, len| {
            var consumed = false;
            while (!consumed) {
                const res = self.decoder.next(b);
                consumed = res[1];

                if (res[0]) |code| {
                    defer self.i += @intCast(len);

                    return .{
                        .code = code,
                        .len = @intCast(len),
                        .offset = self.i,
                    };
                }
            }
        }

        unreachable;
    }

    pub fn peek(self: *Iterator) ?CodePoint {
        const saved_i = self.i;
        defer self.i = saved_i;
        return self.next();
    }
};

test "peek" {
    const src = "Hi";
    var iter = Iterator{ .bytes = src };

    try std.testing.expectEqual(@as(u21, 'H'), iter.next().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.peek().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.next().?.code);
    try std.testing.expectEqual(@as(?CodePoint, null), iter.peek());
    try std.testing.expectEqual(@as(?CodePoint, null), iter.next());
}
