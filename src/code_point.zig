const std = @import("std");

/// `CodePoint` represents a Unicode code point by its code,
/// length, and offset in the source bytes.
pub const CodePoint = struct {
    len: u3,
    offset: u32,

    pub fn code(self: CodePoint, src: []const u8) u21 {
        const cp_bytes = src[self.offset..][0..self.len];

        return switch (self.len) {
            1 => cp_bytes[0],

            2 => (@as(u21, (cp_bytes[0] & 0b00011111)) << 6) | (cp_bytes[1] & 0b00111111),

            3 => (((@as(u21, (cp_bytes[0] & 0b00001111)) << 6) |
                (cp_bytes[1] & 0b00111111)) << 6) |
                (cp_bytes[2] & 0b00111111),

            4 => (((((@as(u21, (cp_bytes[0] & 0b00000111)) << 6) |
                (cp_bytes[1] & 0b00111111)) << 6) |
                (cp_bytes[2] & 0b00111111)) << 6) |
                (cp_bytes[3] & 0b00111111),

            else => @panic("code_point.CodePoint.code: Invalid code point length."),
        };
    }
};

/// `Iterator` iterates a string one `CodePoint` at-a-time.
pub const Iterator = struct {
    bytes: []const u8,
    i: u32 = 0,

    pub fn next(self: *Iterator) ?CodePoint {
        if (self.i >= self.bytes.len) return null;

        if (self.bytes[self.i] < 128) {
            // ASCII fast path
            defer self.i += 1;
            return .{ .len = 1, .offset = self.i };
        }

        const cp = CodePoint{
            .len = switch (self.bytes[self.i]) {
                0b1100_0000...0b1101_1111 => 2,
                0b1110_0000...0b1110_1111 => 3,
                0b1111_0000...0b1111_0111 => 4,
                else => @panic("code_point.Iterator.next: Invalid start byte."),
            },
            .offset = self.i,
        };

        self.i += cp.len;
        return cp;
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

    try std.testing.expectEqual(@as(u21, 'H'), iter.next().?.code(src));
    try std.testing.expectEqual(@as(u21, 'i'), iter.peek().?.code(src));
    try std.testing.expectEqual(@as(u21, 'i'), iter.next().?.code(src));
    try std.testing.expectEqual(@as(?CodePoint, null), iter.peek());
    try std.testing.expectEqual(@as(?CodePoint, null), iter.next());
}
