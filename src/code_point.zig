/// `CodePoint` represents a Unicode code point by its code,
/// length, and offset in the source bytes.
pub const CodePoint = struct {
    code: u21,
    len: u3,
    offset: u32,
};

/// given a small slice of a string, decode the corresponding codepoint
pub fn decode(bytes: []const u8, offset: u32) ?CodePoint {
    // EOS fast path
    if (bytes.len == 0) {
        return null;
    }

    // ASCII fast path
    if (bytes[0] < 128) {
        return .{
            .code = bytes[0],
            .len = 1,
            .offset = offset,
        };
    }

    var cp = CodePoint{
        .code = undefined,
        .len = switch (bytes[0]) {
            0b1100_0000...0b1101_1111 => 2,
            0b1110_0000...0b1110_1111 => 3,
            0b1111_0000...0b1111_0111 => 4,
            else => {
                // unicode replacement code point.
                return .{
                    .code = 0xfffd,
                    .len = 1,
                    .offset = offset,
                };
            },
        },
        .offset = offset,
    };

    // Return replacement if we don' have a complete codepoint remaining. Consumes only one byte
    if (cp.len > bytes.len) {
        // Unicode replacement code point.
        return .{
            .code = 0xfffd,
            .len = 1,
            .offset = offset,
        };
    }

    const cp_bytes = bytes[0..cp.len];
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

/// `Iterator` iterates a string one `CodePoint` at-a-time.
pub const Iterator = struct {
    bytes: []const u8,
    i: u32 = 0,

    pub fn next(self: *Iterator) ?CodePoint {
        if (self.i >= self.bytes.len) return null;

        const res = decode(self.bytes[self.i..], self.i);
        if (res) |cp| {
            self.i += cp.len;
        }

        return res;
    }

    pub fn peek(self: *Iterator) ?CodePoint {
        const saved_i = self.i;
        defer self.i = saved_i;
        return self.next();
    }
};

test "decode" {
    const bytes = "🌩️";
    const res = decode(bytes, 0);

    if (res) |cp| {
        try std.testing.expectEqual(@as(u21, 0x1F329), cp.code);
        try std.testing.expectEqual(4, cp.len);
    } else {
        // shouldn't have failed to return
        try std.testing.expect(false);
    }
}

test "peek" {
    var iter = Iterator{ .bytes = "Hi" };

    try std.testing.expectEqual(@as(u21, 'H'), iter.next().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.peek().?.code);
    try std.testing.expectEqual(@as(u21, 'i'), iter.next().?.code);
    try std.testing.expectEqual(@as(?CodePoint, null), iter.peek());
    try std.testing.expectEqual(@as(?CodePoint, null), iter.next());
}

test "overlongs" {
    // Should not pass!
    const bytes = "\xC0\xAF";
    const res = decode(bytes, 0);
    if (res) |cp| {
        try testing.expectEqual(@as(u21, '/'), cp.code);
        try testing.expectEqual(2, cp.len);
    } else {
        try testing.expect(false);
    }
}

const std = @import("std");
const testing = std.testing;
