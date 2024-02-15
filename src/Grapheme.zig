//! `Grapheme` represents a Unicode grapheme cluster by its length and offset in the source bytes.

const std = @import("std");
const unicode = std.unicode;

const ziglyph = @import("ziglyph");
const CodePoint = @import("CodePoint.zig");
const CodePointIterator = CodePoint.CodePointIterator;
// const emoji = ziglyph.emoji;
// const gbp = ziglyph.grapheme_break;
const gbp = @import("gbp");
const emoji = @import("emoji");
const indic = @import("indic");

pub const Grapheme = @This();

len: usize,
offset: usize,

/// `eql` comparse `str` with the bytes of this grapheme cluster in `src` for equality.
pub fn eql(self: Grapheme, src: []const u8, other: []const u8) bool {
    return std.mem.eql(u8, src[self.offset .. self.offset + self.len], other);
}

/// `slice` returns the bytes that correspond to this grapheme cluster in `src`.
pub fn slice(self: Grapheme, src: []const u8) []const u8 {
    return src[self.offset .. self.offset + self.len];
}

/// `GraphemeIterator` iterates a sting of UTF-8 encoded bytes one grapheme cluster at-a-time.
pub const GraphemeIterator = struct {
    buf: [2]?CodePoint = [_]?CodePoint{ null, null },
    cp_iter: CodePointIterator,

    const Self = @This();

    /// Assumes `src` is valid UTF-8.
    pub fn init(str: []const u8) Self {
        var self = Self{ .cp_iter = CodePointIterator{ .bytes = str } };
        self.buf[1] = self.cp_iter.next();

        return self;
    }

    fn advance(self: *Self) void {
        self.buf[0] = self.buf[1];
        self.buf[1] = self.cp_iter.next();
    }

    pub fn next(self: *Self) ?Grapheme {
        self.advance();

        // If at end
        if (self.buf[0] == null) return null;
        if (self.buf[1] == null) return Grapheme{ .len = self.buf[0].?.len, .offset = self.buf[0].?.offset };

        const gc_start = self.buf[0].?.offset;
        var gc_len: usize = self.buf[0].?.len;
        var state: u3 = 0;

        if (graphemeBreak(
            self.buf[0].?.code,
            self.buf[1].?.code,
            &state,
        )) return Grapheme{ .len = gc_len, .offset = gc_start };

        while (true) {
            self.advance();
            if (self.buf[0] == null) break;

            gc_len += self.buf[0].?.len;

            if (graphemeBreak(
                self.buf[0].?.code,
                if (self.buf[1]) |ncp| ncp.code else 0,
                &state,
            )) break;
        }

        return Grapheme{ .len = gc_len, .offset = gc_start };
    }
};

// Predicates
inline fn isBreaker(cp: u21) bool {
    return cp == '\x0d' or cp == '\x0a' or gbp.stage_3[gbp.stage_2[gbp.stage_1[cp >> 8] + (cp & 0xff)]] == .control;
}

inline fn isIgnorable(cp: u21) bool {
    const cp_gbp_prop = gbp.stage_3[gbp.stage_2[gbp.stage_1[cp >> 8] + (cp & 0xff)]];
    return cp_gbp_prop == .extend or cp_gbp_prop == .spacing or cp == '\u{200d}';
}

test "Segmentation comptime GraphemeIterator" {
    const want = [_][]const u8{ "H", "é", "l", "l", "o" };

    comptime {
        const src = "Héllo";
        var ct_iter = GraphemeIterator.init(src);
        var i = 0;
        while (ct_iter.next()) |grapheme| : (i += 1) {
            try std.testing.expect(grapheme.eql(src, want[i]));
        }
    }
}

test "Segmentation ZWJ and ZWSP emoji sequences" {
    const seq_1 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const seq_2 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const with_zwj = seq_1 ++ "\u{200D}" ++ seq_2;
    const with_zwsp = seq_1 ++ "\u{200B}" ++ seq_2;
    const no_joiner = seq_1 ++ seq_2;

    var ct_iter = GraphemeIterator.init(with_zwj);
    var i: usize = 0;
    while (ct_iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 1), i);

    ct_iter = GraphemeIterator.init(with_zwsp);
    i = 0;
    while (ct_iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 3), i);

    ct_iter = GraphemeIterator.init(no_joiner);
    i = 0;
    while (ct_iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 2), i);
}

// Grapheme break state.
// Extended Pictographic (emoji)
inline fn hasXpic(state: *const u3) bool {
    return state.* & 1 == 1;
}
inline fn setXpic(state: *u3) void {
    state.* |= 1;
}
inline fn unsetXpic(state: *u3) void {
    state.* ^= 1;
}
// Regional Indicatior (flags)
inline fn hasRegional(state: *const u3) bool {
    return state.* & 2 == 2;
}
inline fn setRegional(state: *u3) void {
    state.* |= 2;
}
inline fn unsetRegional(state: *u3) void {
    state.* ^= 2;
}
// Indic Conjunct
inline fn hasIndic(state: *const u3) bool {
    return state.* & 4 == 4;
}
inline fn setIndic(state: *u3) void {
    state.* |= 4;
}
inline fn unsetIndic(state: *u3) void {
    state.* ^= 4;
}

/// `graphemeBreak` returns true only if a grapheme break point is required
/// between `cp1` and `cp2`. `state` should start out as 0. If calling
/// iteratively over a sequence of code points, this function must be called
/// IN ORDER on ALL potential breaks in a string.
/// Modeled after the API of utf8proc's `utf8proc_grapheme_break_stateful`.
/// https://github.com/JuliaStrings/utf8proc/blob/2bbb1ba932f727aad1fab14fafdbc89ff9dc4604/utf8proc.h#L599-L617
pub fn graphemeBreak(
    cp1: u21,
    cp2: u21,
    state: *u3,
) bool {
    // GB11: Emoji Extend* ZWJ x Emoji
    const cp1_is_emoji = emoji.stage_2[emoji.stage_1[cp1 >> 8] + (cp1 & 0xff)];
    const cp2_is_emoji = emoji.stage_2[emoji.stage_1[cp2 >> 8] + (cp2 & 0xff)];
    if (!hasXpic(state) and cp1_is_emoji) setXpic(state);
    // GB9c: Indic Conjunct Break
    const cp1_indic_prop = indic.stage_3[indic.stage_2[indic.stage_1[cp1 >> 8] + (cp1 & 0xff)]];
    const cp2_indic_prop = indic.stage_3[indic.stage_2[indic.stage_1[cp2 >> 8] + (cp2 & 0xff)]];
    if (!hasIndic(state) and cp1_indic_prop == .Consonant) setIndic(state);

    // GB3: CR x LF
    if (cp1 == '\r' and cp2 == '\n') return false;

    // GB4: Control
    if (isBreaker(cp1)) return true;

    // GB6: Hangul L x (L|V|LV|VT)
    const cp1_gbp_prop = gbp.stage_3[gbp.stage_2[gbp.stage_1[cp1 >> 8] + (cp1 & 0xff)]];
    const cp2_gbp_prop = gbp.stage_3[gbp.stage_2[gbp.stage_1[cp2 >> 8] + (cp2 & 0xff)]];
    if (cp1_gbp_prop == .hangul_l) {
        if (cp2_gbp_prop == .hangul_l or
            cp2_gbp_prop == .hangul_v or
            cp2_gbp_prop == .hangul_lv or
            cp2_gbp_prop == .hangul_lvt) return false;
    }

    // GB7: Hangul (LV | V) x (V | T)
    if (cp1_gbp_prop == .hangul_lv or cp1_gbp_prop == .hangul_v) {
        if (cp2_gbp_prop == .hangul_v or
            cp2_gbp_prop == .hangul_t) return false;
    }

    // GB8: Hangul (LVT | T) x T
    if (cp1_gbp_prop == .hangul_lvt or cp1_gbp_prop == .hangul_t) {
        if (cp2_gbp_prop == .hangul_t) return false;
    }

    // GB9b: x (Extend | ZWJ)
    if (cp2_gbp_prop == .extend or cp2_gbp_prop == .zwj) return false;

    // GB9a: x Spacing
    if (cp2_gbp_prop == .spacing) return false;

    // GB9b: Prepend x
    if (cp1_gbp_prop == .prepend and !isBreaker(cp2)) return false;

    // GB12, GB13: RI x RI
    if (cp1_gbp_prop == .regional and cp2_gbp_prop == .regional) {
        if (hasRegional(state)) {
            unsetRegional(state);
            return true;
        } else {
            setRegional(state);
            return false;
        }
    }

    // GB11: Emoji Extend* ZWJ x Emoji
    if (hasXpic(state) and
        cp1_gbp_prop == .zwj and
        cp2_is_emoji)
    {
        unsetXpic(state);
        return false;
    }

    // GB9c: Indic Conjunct Break
    if (hasIndic(state) and
        cp1_indic_prop == .Consonant and
        cp2_indic_prop == .Extend)
    {
        return false;
    }

    if (hasIndic(state) and
        cp1_indic_prop == .Consonant and
        cp2_indic_prop == .Linker)
    {
        return false;
    }

    if (hasIndic(state) and
        cp1_indic_prop == .Extend and
        cp2_indic_prop == .Linker)
    {
        return false;
    }

    if (hasIndic(state) and
        cp1_indic_prop == .Linker and
        cp2_indic_prop == .Consonant)
    {
        unsetIndic(state);
        return false;
    }

    if (hasIndic(state) and
        cp1_gbp_prop == .zwj and
        cp2_indic_prop == .Consonant)
    {
        unsetIndic(state);
        return false;
    }

    return true;
}

test "Segmentation GraphemeIterator" {
    const allocator = std.testing.allocator;
    var file = try std.fs.cwd().openFile("GraphemeBreakTest.txt", .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var input_stream = buf_reader.reader();

    var buf: [4096]u8 = undefined;
    var line_no: usize = 1;

    while (try input_stream.readUntilDelimiterOrEof(&buf, '\n')) |raw| : (line_no += 1) {
        // Skip comments or empty lines.
        if (raw.len == 0 or raw[0] == '#' or raw[0] == '@') continue;

        // Clean up.
        var line = std.mem.trimLeft(u8, raw, "÷ ");
        if (std.mem.indexOf(u8, line, " ÷\t#")) |octo| {
            line = line[0..octo];
        }
        // Iterate over fields.
        var want = std.ArrayList(Grapheme).init(allocator);
        defer want.deinit();

        var all_bytes = std.ArrayList(u8).init(allocator);
        defer all_bytes.deinit();

        var graphemes = std.mem.split(u8, line, " ÷ ");
        var bytes_index: usize = 0;

        while (graphemes.next()) |field| {
            var code_points = std.mem.split(u8, field, " ");
            var cp_buf: [4]u8 = undefined;
            var cp_index: usize = 0;
            var gc_len: usize = 0;

            while (code_points.next()) |code_point| {
                if (std.mem.eql(u8, code_point, "×")) continue;
                const cp: u21 = try std.fmt.parseInt(u21, code_point, 16);
                const len = try unicode.utf8Encode(cp, &cp_buf);
                try all_bytes.appendSlice(cp_buf[0..len]);
                cp_index += len;
                gc_len += len;
            }

            try want.append(Grapheme{ .len = gc_len, .offset = bytes_index });
            bytes_index += cp_index;
        }

        // std.debug.print("\nline {}: {s}\n", .{ line_no, all_bytes.items });
        var iter = GraphemeIterator.init(all_bytes.items);

        // Chaeck.
        for (want.items) |w| {
            const g = (iter.next()).?;
            try std.testing.expect(w.eql(all_bytes.items, all_bytes.items[g.offset .. g.offset + g.len]));
        }
    }
}
