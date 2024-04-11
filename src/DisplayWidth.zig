const std = @import("std");
const builtin = @import("builtin");
const ArrayList = std.ArrayList;
const mem = std.mem;
const simd = std.simd;
const testing = std.testing;

const ascii = @import("ascii");
const CodePointIterator = @import("code_point").Iterator;
const GraphemeIterator = @import("grapheme").Iterator;
pub const DisplayWidthData = @import("DisplayWidthData");

data: *const DisplayWidthData,

const Self = @This();

/// strWidth returns the total display width of `str` as the number of cells
/// required in a fixed-pitch font (i.e. a terminal screen).
pub fn strWidth(self: Self, str: []const u8) usize {
    var total: isize = 0;

    // ASCII fast path
    if (ascii.isAsciiOnly(str)) {
        for (str) |b| total += self.data.codePointWidth(b);
        return @intCast(@max(0, total));
    }

    var giter = GraphemeIterator.init(str, &self.data.g_data);

    while (giter.next()) |gc| {
        var cp_iter = CodePointIterator{ .bytes = gc.bytes(str) };
        var gc_total: isize = 0;

        while (cp_iter.next()) |cp| {
            var w = self.data.codePointWidth(cp.code);

            if (w != 0) {
                // Handle text emoji sequence.
                if (cp_iter.next()) |ncp| {
                    // emoji text sequence.
                    if (ncp.code == 0xFE0E) w = 1;
                    if (ncp.code == 0xFE0F) w = 2;
                }

                // Only adding width of first non-zero-width code point.
                if (gc_total == 0) {
                    gc_total = w;
                    break;
                }
            }
        }

        total += gc_total;
    }

    return @intCast(@max(0, total));
}

test "strWidth" {
    const data = try DisplayWidthData.init(testing.allocator);
    defer data.deinit();
    const self = Self{ .data = &data };

    try testing.expectEqual(@as(usize, 5), self.strWidth("Hello\r\n"));
    try testing.expectEqual(@as(usize, 1), self.strWidth("\u{0065}\u{0301}"));
    try testing.expectEqual(@as(usize, 2), self.strWidth("\u{1F476}\u{1F3FF}\u{0308}\u{200D}\u{1F476}\u{1F3FF}"));
    try testing.expectEqual(@as(usize, 8), self.strWidth("Hello 😊"));
    try testing.expectEqual(@as(usize, 8), self.strWidth("Héllo 😊"));
    try testing.expectEqual(@as(usize, 8), self.strWidth("Héllo :)"));
    try testing.expectEqual(@as(usize, 8), self.strWidth("Héllo 🇪🇸"));
    try testing.expectEqual(@as(usize, 2), self.strWidth("\u{26A1}")); // Lone emoji
    try testing.expectEqual(@as(usize, 1), self.strWidth("\u{26A1}\u{FE0E}")); // Text sequence
    try testing.expectEqual(@as(usize, 2), self.strWidth("\u{26A1}\u{FE0F}")); // Presentation sequence
    try testing.expectEqual(@as(usize, 1), self.strWidth("\u{2764}")); // Default text presentation
    try testing.expectEqual(@as(usize, 1), self.strWidth("\u{2764}\u{FE0E}")); // Default text presentation with VS15 selector
    try testing.expectEqual(@as(usize, 2), self.strWidth("\u{2764}\u{FE0F}")); // Default text presentation with VS16 selector
    try testing.expectEqual(@as(usize, 0), self.strWidth("A\x08")); // Backspace
    try testing.expectEqual(@as(usize, 0), self.strWidth("\x7FA")); // DEL
    try testing.expectEqual(@as(usize, 0), self.strWidth("\x7FA\x08\x08")); // never less than o

    // wcwidth Python lib tests. See: https://github.com/jquast/wcwidth/blob/master/tests/test_core.py
    const empty = "";
    try testing.expectEqual(@as(usize, 0), self.strWidth(empty));
    const with_null = "hello\x00world";
    try testing.expectEqual(@as(usize, 10), self.strWidth(with_null));
    const hello_jp = "コンニチハ, セカイ!";
    try testing.expectEqual(@as(usize, 19), self.strWidth(hello_jp));
    const control = "\x1b[0m";
    try testing.expectEqual(@as(usize, 3), self.strWidth(control));
    const balinese = "\u{1B13}\u{1B28}\u{1B2E}\u{1B44}";
    try testing.expectEqual(@as(usize, 3), self.strWidth(balinese));

    // These commented out tests require a new specification for complex scripts.
    // See: https://www.unicode.org/L2/L2023/23107-terminal-suppt.pdf
    // const jamo = "\u{1100}\u{1160}";
    // try testing.expectEqual(@as(usize, 3), strWidth(jamo));
    // const devengari = "\u{0915}\u{094D}\u{0937}\u{093F}";
    // try testing.expectEqual(@as(usize, 3), strWidth(devengari));
    // const tamal = "\u{0b95}\u{0bcd}\u{0bb7}\u{0bcc}";
    // try testing.expectEqual(@as(usize, 5), strWidth(tamal));
    // const kannada_1 = "\u{0cb0}\u{0ccd}\u{0c9d}\u{0cc8}";
    // try testing.expectEqual(@as(usize, 3), strWidth(kannada_1));
    // The following passes but as a mere coincidence.
    const kannada_2 = "\u{0cb0}\u{0cbc}\u{0ccd}\u{0c9a}";
    try testing.expectEqual(@as(usize, 2), self.strWidth(kannada_2));

    // From Rust https://github.com/jameslanska/unicode-display-width
    try testing.expectEqual(@as(usize, 15), self.strWidth("🔥🗡🍩👩🏻‍🚀⏰💃🏼🔦👍🏻"));
    try testing.expectEqual(@as(usize, 2), self.strWidth("🦀"));
    try testing.expectEqual(@as(usize, 2), self.strWidth("👨‍👩‍👧‍👧"));
    try testing.expectEqual(@as(usize, 2), self.strWidth("👩‍🔬"));
    try testing.expectEqual(@as(usize, 9), self.strWidth("sane text"));
    try testing.expectEqual(@as(usize, 9), self.strWidth("Ẓ̌á̲l͔̝̞̄̑͌g̖̘̘̔̔͢͞͝o̪̔T̢̙̫̈̍͞e̬͈͕͌̏͑x̺̍ṭ̓̓ͅ"));
    try testing.expectEqual(@as(usize, 17), self.strWidth("슬라바 우크라이나"));
    try testing.expectEqual(@as(usize, 1), self.strWidth("\u{378}"));
}

/// centers `str` in a new string of width `total_width` (in display cells) using `pad` as padding.
/// If the length of `str` and `total_width` have different parity, the right side of `str` will
/// receive one additional pad. This makes sure the returned string fills the requested width.
/// Caller must free returned bytes with `allocator`.
pub fn center(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
    total_width: usize,
    pad: []const u8,
) ![]u8 {
    const str_width = self.strWidth(str);
    if (str_width > total_width) return error.StrTooLong;
    if (str_width == total_width) return try allocator.dupe(u8, str);

    const pad_width = self.strWidth(pad);
    if (pad_width > total_width or str_width + pad_width > total_width) return error.PadTooLong;

    const margin_width = @divFloor((total_width - str_width), 2);
    if (pad_width > margin_width) return error.PadTooLong;
    const extra_pad: usize = if (total_width % 2 != str_width % 2) 1 else 0;
    const pads = @divFloor(margin_width, pad_width) * 2 + extra_pad;

    var result = try allocator.alloc(u8, pads * pad.len + str.len);
    var bytes_index: usize = 0;
    var pads_index: usize = 0;

    while (pads_index < pads / 2) : (pads_index += 1) {
        @memcpy(result[bytes_index..][0..pad.len], pad);
        bytes_index += pad.len;
    }

    @memcpy(result[bytes_index..][0..str.len], str);
    bytes_index += str.len;

    pads_index = 0;
    while (pads_index < pads / 2 + extra_pad) : (pads_index += 1) {
        @memcpy(result[bytes_index..][0..pad.len], pad);
        bytes_index += pad.len;
    }

    return result;
}

test "center" {
    const allocator = testing.allocator;
    const data = try DisplayWidthData.init(allocator);
    defer data.deinit();
    const self = Self{ .data = &data };

    // Input and width both have odd length
    var centered = try self.center(allocator, "abc", 9, "*");
    try testing.expectEqualSlices(u8, "***abc***", centered);

    // Input and width both have even length
    testing.allocator.free(centered);
    centered = try self.center(allocator, "w😊w", 10, "-");
    try testing.expectEqualSlices(u8, "---w😊w---", centered);

    // Input has even length, width has odd length
    testing.allocator.free(centered);
    centered = try self.center(allocator, "1234", 9, "-");
    try testing.expectEqualSlices(u8, "--1234---", centered);

    // Input has odd length, width has even length
    testing.allocator.free(centered);
    centered = try self.center(allocator, "123", 8, "-");
    try testing.expectEqualSlices(u8, "--123---", centered);

    // Input is the same length as the width
    testing.allocator.free(centered);
    centered = try self.center(allocator, "123", 3, "-");
    try testing.expectEqualSlices(u8, "123", centered);

    // Input is empty
    testing.allocator.free(centered);
    centered = try self.center(allocator, "", 3, "-");
    try testing.expectEqualSlices(u8, "---", centered);

    // Input is empty and width is zero
    testing.allocator.free(centered);
    centered = try self.center(allocator, "", 0, "-");
    try testing.expectEqualSlices(u8, "", centered);

    // Input is longer than the width, which is an error
    testing.allocator.free(centered);
    try testing.expectError(error.StrTooLong, self.center(allocator, "123", 2, "-"));
}

/// padLeft returns a new string of width `total_width` (in display cells) using `pad` as padding
/// on the left side. Caller must free returned bytes with `allocator`.
pub fn padLeft(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
    total_width: usize,
    pad: []const u8,
) ![]u8 {
    const str_width = self.strWidth(str);
    if (str_width > total_width) return error.StrTooLong;

    const pad_width = self.strWidth(pad);
    if (pad_width > total_width or str_width + pad_width > total_width) return error.PadTooLong;

    const margin_width = total_width - str_width;
    if (pad_width > margin_width) return error.PadTooLong;

    const pads = @divFloor(margin_width, pad_width);

    var result = try allocator.alloc(u8, pads * pad.len + str.len);
    var bytes_index: usize = 0;
    var pads_index: usize = 0;

    while (pads_index < pads) : (pads_index += 1) {
        @memcpy(result[bytes_index..][0..pad.len], pad);
        bytes_index += pad.len;
    }

    @memcpy(result[bytes_index..][0..str.len], str);

    return result;
}

test "padLeft" {
    const allocator = testing.allocator;
    const data = try DisplayWidthData.init(allocator);
    defer data.deinit();
    const self = Self{ .data = &data };

    var right_aligned = try self.padLeft(allocator, "abc", 9, "*");
    defer testing.allocator.free(right_aligned);
    try testing.expectEqualSlices(u8, "******abc", right_aligned);

    testing.allocator.free(right_aligned);
    right_aligned = try self.padLeft(allocator, "w😊w", 10, "-");
    try testing.expectEqualSlices(u8, "------w😊w", right_aligned);
}

/// padRight returns a new string of width `total_width` (in display cells) using `pad` as padding
/// on the right side.  Caller must free returned bytes with `allocator`.
pub fn padRight(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
    total_width: usize,
    pad: []const u8,
) ![]u8 {
    const str_width = self.strWidth(str);
    if (str_width > total_width) return error.StrTooLong;

    const pad_width = self.strWidth(pad);
    if (pad_width > total_width or str_width + pad_width > total_width) return error.PadTooLong;

    const margin_width = total_width - str_width;
    if (pad_width > margin_width) return error.PadTooLong;

    const pads = @divFloor(margin_width, pad_width);

    var result = try allocator.alloc(u8, pads * pad.len + str.len);
    var bytes_index: usize = 0;
    var pads_index: usize = 0;

    @memcpy(result[bytes_index..][0..str.len], str);
    bytes_index += str.len;

    while (pads_index < pads) : (pads_index += 1) {
        @memcpy(result[bytes_index..][0..pad.len], pad);
        bytes_index += pad.len;
    }

    return result;
}

test "padRight" {
    const allocator = testing.allocator;
    const data = try DisplayWidthData.init(allocator);
    defer data.deinit();
    const self = Self{ .data = &data };

    var left_aligned = try self.padRight(allocator, "abc", 9, "*");
    defer testing.allocator.free(left_aligned);
    try testing.expectEqualSlices(u8, "abc******", left_aligned);

    testing.allocator.free(left_aligned);
    left_aligned = try self.padRight(allocator, "w😊w", 10, "-");
    try testing.expectEqualSlices(u8, "w😊w------", left_aligned);
}

/// Wraps a string approximately at the given number of colums per line.
/// `threshold` defines how far the last column of the last word can be
/// from the edge. Caller must free returned bytes with `allocator`.
pub fn wrap(
    self: Self,
    allocator: mem.Allocator,
    str: []const u8,
    columns: usize,
    threshold: usize,
) ![]u8 {
    var result = ArrayList(u8).init(allocator);
    defer result.deinit();

    var line_iter = mem.tokenizeAny(u8, str, "\r\n");
    var line_width: usize = 0;

    while (line_iter.next()) |line| {
        var word_iter = mem.tokenizeScalar(u8, line, ' ');

        while (word_iter.next()) |word| {
            try result.appendSlice(word);
            try result.append(' ');
            line_width += self.strWidth(word) + 1;

            if (line_width > columns or columns - line_width <= threshold) {
                try result.append('\n');
                line_width = 0;
            }
        }
    }

    // Remove trailing space and newline.
    _ = result.pop();
    _ = result.pop();

    return try result.toOwnedSlice();
}

test "wrap" {
    const allocator = testing.allocator;
    const data = try DisplayWidthData.init(allocator);
    defer data.deinit();
    const self = Self{ .data = &data };

    const input = "The quick brown fox\r\njumped over the lazy dog!";
    const got = try self.wrap(allocator, input, 10, 3);
    defer testing.allocator.free(got);
    const want = "The quick \nbrown fox \njumped \nover the \nlazy dog!";
    try testing.expectEqualStrings(want, got);
}
