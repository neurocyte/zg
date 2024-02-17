const std = @import("std");
const simd = std.simd;
const testing = std.testing;

const CodePointIterator = @import("CodePoint").CodePointIterator;
const GraphemeIterator = @import("Grapheme").GraphemeIterator;
const dwp = @import("dwp");

/// codePointWidth returns the number of cells `cp` requires when rendered
/// in a fixed-pitch font (i.e. a terminal screen). This can range from -1 to
/// 3, where BACKSPACE and DELETE return -1 and 3-em-dash returns 3. C0/C1
/// control codes return 0. If `cjk` is true, ambiguous code points return 2,
/// otherwise they return 1.
pub fn codePointWidth(cp: u21) i3 {
    return dwp.stage_2[dwp.stage_1[cp >> 8] + (cp & 0xff)];
}

fn isAsciiOnly(str: []const u8) bool {
    const vec_len = simd.suggestVectorLength(u8) orelse @panic("No SIMD support.");
    const Vec = @Vector(vec_len, u8);
    var i: usize = 0;

    while (i < str.len) : (i += vec_len) {
        if (str[i..].len < vec_len) return for (str[i..]) |b| {
            if (b > 127) break false;
        } else true;

        const v1 = str[i..].ptr[0..vec_len].*;
        const v2: Vec = @splat(127);
        if (@reduce(.Or, v1 > v2)) return false;
    }

    return true;
}

/// strWidth returns the total display width of `str` as the number of cells
/// required in a fixed-pitch font (i.e. a terminal screen).
pub fn strWidth(str: []const u8) usize {
    var total: isize = 0;

    if (isAsciiOnly(str)) {
        for (str) |b| {
            // Backspace and delete
            if (b == 0x8 or b == 0x7f) {
                total -= 1;
            } else if (b >= 0x20) {
                total += 1;
            }
        }

        return if (total > 0) @intCast(total) else 0;
    }

    var giter = GraphemeIterator.init(str);

    while (giter.next()) |gc| {
        var cp_iter = CodePointIterator{ .bytes = str[gc.offset..][0..gc.len] };
        var gc_total: isize = 0;

        while (cp_iter.next()) |cp| {
            var w = codePointWidth(cp.code);

            if (w != 0) {
                // Handle text emoji sequence.
                if (cp_iter.next()) |ncp| {
                    // emoji text sequence.
                    if (ncp.code == 0xFE0E) w = 1;
                }

                // Only adding width of first non-zero-width code point.
                if (gc_total == 0) gc_total = w;
            }
        }

        total += gc_total;
    }

    return if (total > 0) @intCast(total) else 0;
}

test "display_width Width" {
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0000)); // null
    try testing.expectEqual(@as(i3, -1), codePointWidth(0x8)); // \b
    try testing.expectEqual(@as(i3, -1), codePointWidth(0x7f)); // DEL
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0005)); // Cf
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x0007)); // \a BEL
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000A)); // \n LF
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000B)); // \v VT
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000C)); // \f FF
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000D)); // \r CR
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000E)); // SQ
    try testing.expectEqual(@as(i3, 0), codePointWidth(0x000F)); // SI

    try testing.expectEqual(@as(i3, 0), codePointWidth(0x070F)); // Cf
    try testing.expectEqual(@as(i3, 1), codePointWidth(0x0603)); // Cf Arabic

    try testing.expectEqual(@as(i3, 1), codePointWidth(0x00AD)); // soft-hyphen
    try testing.expectEqual(@as(i3, 2), codePointWidth(0x2E3A)); // two-em dash
    try testing.expectEqual(@as(i3, 3), codePointWidth(0x2E3B)); // three-em dash

    try testing.expectEqual(@as(i3, 1), codePointWidth(0x00BD)); // ambiguous halfwidth

    try testing.expectEqual(@as(i3, 1), codePointWidth('é'));
    try testing.expectEqual(@as(i3, 2), codePointWidth('😊'));
    try testing.expectEqual(@as(i3, 2), codePointWidth('统'));

    try testing.expectEqual(@as(usize, 5), strWidth("Hello\r\n"));
    try testing.expectEqual(@as(usize, 1), strWidth("\u{0065}\u{0301}"));
    try testing.expectEqual(@as(usize, 2), strWidth("\u{1F476}\u{1F3FF}\u{0308}\u{200D}\u{1F476}\u{1F3FF}"));
    try testing.expectEqual(@as(usize, 8), strWidth("Hello 😊"));
    try testing.expectEqual(@as(usize, 8), strWidth("Héllo 😊"));
    try testing.expectEqual(@as(usize, 8), strWidth("Héllo :)"));
    try testing.expectEqual(@as(usize, 8), strWidth("Héllo 🇪🇸"));
    try testing.expectEqual(@as(usize, 2), strWidth("\u{26A1}")); // Lone emoji
    try testing.expectEqual(@as(usize, 1), strWidth("\u{26A1}\u{FE0E}")); // Text sequence
    try testing.expectEqual(@as(usize, 2), strWidth("\u{26A1}\u{FE0F}")); // Presentation sequence
    try testing.expectEqual(@as(usize, 0), strWidth("A\x08")); // Backspace
    try testing.expectEqual(@as(usize, 0), strWidth("\x7FA")); // DEL
    try testing.expectEqual(@as(usize, 0), strWidth("\x7FA\x08\x08")); // never less than o

    // wcwidth Python lib tests. See: https://github.com/jquast/wcwidth/blob/master/tests/test_core.py
    const empty = "";
    try testing.expectEqual(@as(usize, 0), strWidth(empty));
    const with_null = "hello\x00world";
    try testing.expectEqual(@as(usize, 10), strWidth(with_null));
    const hello_jp = "コンニチハ, セカイ!";
    try testing.expectEqual(@as(usize, 19), strWidth(hello_jp));
    const control = "\x1b[0m";
    try testing.expectEqual(@as(usize, 3), strWidth(control));
    const balinese = "\u{1B13}\u{1B28}\u{1B2E}\u{1B44}";
    try testing.expectEqual(@as(usize, 3), strWidth(balinese));

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
    try testing.expectEqual(@as(usize, 2), strWidth(kannada_2));
}
