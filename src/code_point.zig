const std = @import("std");

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

        var cp = CodePoint{
            .code = undefined,
            .len = switch (self.bytes[self.i]) {
                0b1100_0000...0b1101_1111 => 2,
                0b1110_0000...0b1110_1111 => 3,
                0b1111_0000...0b1111_0111 => 4,
                else => {
                    defer self.i += 1;
                    // Unicode replacement code point.
                    return .{
                        .code = 0xfffd,
                        .len = 1,
                        .offset = self.i,
                    };
                },
            },
            .offset = self.i,
        };

        const cp_bytes = self.bytes[self.i..][0..cp.len];
        self.i += cp.len;

        cp.code = switch (cp.len) {
            2 => (@as(u21, (cp_bytes[0] & 0b00011111)) << 6) | (cp_bytes[1] & 0b00111111),

            3 => (((@as(u21, (cp_bytes[0] & 0b00001111)) << 6) |
                (cp_bytes[1] & 0b00111111)) << 6) |
                (cp_bytes[2] & 0b00111111),

            4 => (((((@as(u21, (cp_bytes[0] & 0b00000111)) << 6) |
                (cp_bytes[1] & 0b00111111)) << 6) |
                (cp_bytes[2] & 0b00111111)) << 6) |
                (cp_bytes[3] & 0b00111111),

            else => @panic("CodePointIterator.next invalid code point length."),
        };

        return cp;
    }

    pub fn peek(self: *Iterator) ?CodePoint {
        const saved_i = self.i;
        defer self.i = saved_i;
        return self.next();
    }
};

test "peek" {
    var iter = Iterator{ .bytes = "Hi" };

    try std.testing.expectEqual(@as(u21, 'H'), iter.next().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.peek().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.next().?.code);
    try std.testing.expectEqual(@as(?CodePoint, null), iter.peek());
    try std.testing.expectEqual(@as(?CodePoint, null), iter.next());
}
