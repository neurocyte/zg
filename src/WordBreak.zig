//! Word Breaking Algorithm.

const WordBreakProperty = enum(u5) {
    none,
    Double_Quote,
    Single_Quote,
    Hebrew_Letter,
    CR,
    LF,
    Newline,
    Extend,
    Regional_Indicator,
    Format,
    Katakana,
    ALetter,
    MidLetter,
    MidNum,
    MidNumLet,
    Numeric,
    ExtendNumLet,
    ZWJ,
    WSegSpace,
};

s1: []u16 = undefined,
s2: []u5 = undefined,

const WordBreak = @This();

pub fn init(allocator: Allocator) Allocator.Error!WordBreak {
    var wb: WordBreak = undefined;
    try wb.setup(allocator);
    return wb;
}

pub fn setup(wb: *WordBreak, allocator: Allocator) Allocator.Error!void {
    wb.setupImpl(allocator) catch |err| {
        switch (err) {
            error.OutOfMemory => |e| return e,
            else => unreachable,
        }
    };
}

inline fn setupImpl(wb: *WordBreak, allocator: Allocator) !void {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("wbp");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    const stage_1_len: u16 = try reader.readInt(u16, endian);
    wb.s1 = try allocator.alloc(u16, stage_1_len);
    errdefer allocator.free(wb.s1);
    for (0..stage_1_len) |i| wb.s1[i] = try reader.readInt(u16, endian);

    const stage_2_len: u16 = try reader.readInt(u16, endian);
    wb.s2 = try allocator.alloc(u5, stage_2_len);
    errdefer allocator.free(wb.s2);
    for (0..stage_2_len) |i| wb.s2[i] = @intCast(try reader.readInt(u8, endian));
    var count_0: usize = 0;
    for (wb.s2) |nyb| {
        if (nyb == 0) count_0 += 1;
    }
}

pub fn deinit(wordbreak: *const WordBreak, allocator: mem.Allocator) void {
    allocator.free(wordbreak.s1);
    allocator.free(wordbreak.s2);
}

/// Represents a Unicode word span, as an offset into the source string
/// and the length of the word.
pub const Word = struct {
    offset: u32,
    len: u32,

    /// Returns a slice of the word given the source string.
    pub fn bytes(self: Word, src: []const u8) []const u8 {
        return src[self.offset..][0..self.len];
    }
};

/// Returns the word break property type for `cp`.
pub fn breakProperty(wordbreak: *const WordBreak, cp: u21) WordBreakProperty {
    return @enumFromInt(wordbreak.s2[wordbreak.s1[cp >> 8] + (cp & 0xff)]);
}

/// Returns an iterator over words in `slice`
pub fn iterator(wordbreak: *const WordBreak, slice: []const u8) Iterator {
    return Iterator.init(wordbreak, slice);
}

const IterState = packed struct {
    mid_punct: bool, // AHLetter (MidLetter | MidNumLetQ) × AHLetter
    mid_num: bool, // Numeric (MidNum | MidNumLetQ) × Numeric
    quote_heb: bool, // Hebrew_Letter Double_Quote × Hebrew_Letter
    regional: bool, // [^RI] (RI RI)* RI × RI

    pub const initial: IterState = .{
        .mid_punct = false,
        .mid_num = false,
        .quote_heb = false,
        .regional = false,
    };
};

pub const Iterator = struct {
    this: ?CodePoint = null,
    that: ?CodePoint = null,
    cache: ?WordBreakProperty = null,
    cp_iter: CodepointIterator,
    wb: *const WordBreak,

    /// Assumes `str` is valid UTF-8.
    pub fn init(wb: *const WordBreak, str: []const u8) Iterator {
        var wb_iter: Iterator = .{ .cp_iter = .{ .bytes = str }, .wb = wb };
        wb_iter.advance();
        return wb_iter;
    }

    pub fn next(iter: *Iterator) ?Word {
        iter.advance();

        // Done?
        if (iter.this == null) return null;
        // Last?
        if (iter.that == null) return Word{ .len = iter.this.?.len, .offset = iter.this.?.offset };

        const word_start = iter.this.?.offset;
        var word_len: u32 = 0;

        var state: IterState = .initial;

        scan: while (true) : (iter.advance()) {
            const this = iter.this.?;
            word_len += this.len;
            var ignored = false;
            if (iter.that) |that| {
                const that_p = iter.wb.breakProperty(that.code);
                const this_p = this_p: {
                    if (!isIgnorable(that_p) and iter.cache != null) {
                        // TODO: might not need these what with peekPast
                        ignored = true;
                        defer iter.cache = null;
                        // Fixup some state, apply pre-4 rules
                        const restore = iter.cache.?;
                        if (restore == .WSegSpace) break :this_p .none;
                        break :this_p restore;
                    } else {
                        break :this_p iter.wb.breakProperty(this.code);
                    }
                };
                // WB3  CR × LF
                if (this_p == .CR and that_p == .LF) continue :scan;
                // WB3a  (Newline | CR | LF) ÷
                if (isNewline(this_p)) break :scan;
                // WB3b  ÷ (Newline | CR | LF)
                if (isNewline(that_p)) break :scan;
                // WB3c  ZWJ × \p{Extended_Pictographic}
                if (this_p == .ZWJ and ext_pict.isMatch(that.bytes(iter.cp_iter.bytes))) {
                    // Invalid after ignoring
                    if (ignored) break :scan else continue :scan;
                }
                // WB3d  WSegSpace × WSegSpace
                if (this_p == .WSegSpace and that_p == .WSegSpace) continue :scan;
                // WB4  X (Extend | Format | ZWJ)* → X
                if (isIgnorable(that_p)) {
                    if (that_p == .ZWJ) {
                        const next_val = iter.peekPast();
                        if (next_val) |next_cp| {
                            if (ext_pict.isMatch(next_cp.bytes(iter.cp_iter.bytes))) {
                                continue :scan;
                            }
                        }
                    }
                    if (iter.cache == null) {
                        iter.cache = this_p;
                    }
                    continue :scan;
                }
                if (isAHLetter(this_p)) {
                    // WB5  AHLetter × AHLetter
                    if (isAHLetter(that_p)) continue :scan;
                    // WB6  AHLetter × (MidLetter | MidNumLetQ) AHLetter
                    if (isMidVal(that_p)) {
                        const next_val = iter.peekPast();
                        if (next_val) |next_cp| {
                            const next_p = iter.wb.breakProperty(next_cp.code);
                            if (isAHLetter(next_p)) {
                                state.mid_punct = true;
                                continue :scan;
                            }
                        }
                    }
                }
                // AHLetter (MidLetter | MidNumLetQ) × AHLetter
                if (state.mid_punct) {
                    // Should always be true:
                    assert(isMidVal(this_p));
                    assert(isAHLetter(that_p));
                    state.mid_punct = false;
                    continue :scan;
                }
                if (this_p == .Hebrew_Letter) {
                    // WB7a  Hebrew_Letter × Single_Quote
                    if (that_p == .Single_Quote) continue :scan;
                    // WB7b  Hebrew_Letter × Double_Quote Hebrew_Letter
                    if (that_p == .Double_Quote) {
                        const next_val = iter.peekPast();
                        if (next_val) |next_cp| {
                            const next_p = iter.wb.breakProperty(next_cp.code);
                            if (next_p == .Hebrew_Letter) {
                                state.quote_heb = true;
                                continue :scan;
                            }
                        } else break :scan;
                    }
                }
                // WB7c  Hebrew_Letter Double_Quote × Hebrew_Letter
                if (state.quote_heb) {
                    // Should always be true:
                    assert(this_p == .Double_Quote);
                    assert(that_p == .Hebrew_Letter);
                    state.quote_heb = false;
                    continue :scan;
                }
                // WB8  Numeric × Numeric
                if (this_p == .Numeric and that_p == .Numeric) continue :scan;
                // WB9  AHLetter × Numeric
                if (isAHLetter(this_p) and that_p == .Numeric) continue :scan;
                // WB10  Numeric ×  AHLetter
                if (this_p == .Numeric and isAHLetter(that_p)) continue :scan;
                // WB12  Numeric × (MidNum | MidNumLetQ) Numeric
                if (this_p == .Numeric and isMidNum(that_p)) {
                    const next_val = iter.peekPast();
                    if (next_val) |next_cp| {
                        const next_p = iter.wb.breakProperty(next_cp.code);
                        if (next_p == .Numeric) {
                            state.mid_num = true;
                            continue :scan;
                        }
                    } else break :scan;
                }
                // WB11  Numeric (MidNum | MidNumLetQ) × Numeric
                if (state.mid_num) {
                    assert(isMidNum(this_p));
                    assert(that_p == .Numeric);
                    state.mid_num = false;
                    continue :scan;
                }
                // WB13  Katakana × Katakana
                if (this_p == .Katakana and that_p == .Katakana) continue :scan;
                // WB13a  (AHLetter | Numeric | Katakana | ExtendNumLet) × ExtendNumLet
                if (isExtensible(this_p) and that_p == .ExtendNumLet) continue :scan;
                // WB13b  ExtendNumLet × (AHLetter | Numeric | Katakana)
                if (this_p == .ExtendNumLet and isExtensible(that_p)) continue :scan;
                // WB15, WB16  ([^RI] | sot) (RI RI)* RI × RI
                if (this_p == .Regional_Indicator) {
                    if (that_p == .Regional_Indicator) {
                        if (state.regional == true or this.offset == 0) {
                            state.regional = false;
                            continue :scan;
                        }
                    } else {
                        state.regional = true;
                    }
                } else if (that_p == .Regional_Indicator) {
                    state.regional = true;
                }
                // WB999  Any ÷ Any
                break :scan;
            } else { // iter.that == null
                break :scan;
            }
        }

        return Word{ .len = word_len, .offset = word_start };
    }

    fn advance(iter: *Iterator) void {
        iter.this = iter.that;
        iter.that = iter.cp_iter.next();
    }

    fn peekPast(iter: *Iterator) ?CodePoint {
        const save_cp = iter.cp_iter;
        defer iter.cp_iter = save_cp;
        while (iter.cp_iter.peek()) |peeked| {
            if (!isIgnorable(iter.wb.breakProperty(peeked.code))) return peeked;
            _ = iter.cp_iter.next();
        }
        return null;
    }
};

//| Predicates

inline fn isNewline(wbp: WordBreakProperty) bool {
    return wbp == .CR or wbp == .LF or wbp == .Newline;
}

inline fn isIgnorable(wbp: WordBreakProperty) bool {
    return switch (wbp) {
        .Format, .Extend, .ZWJ => true,
        else => false,
    };
}

inline fn isAHLetter(wbp: WordBreakProperty) bool {
    return wbp == .ALetter or wbp == .Hebrew_Letter;
}

inline fn isMidVal(wbp: WordBreakProperty) bool {
    return wbp == .MidLetter or wbp == .MidNumLet or wbp == .Single_Quote;
}

inline fn isMidNum(wbp: WordBreakProperty) bool {
    return wbp == .MidNum or wbp == .MidNumLet or wbp == .Single_Quote;
}

inline fn isExtensible(wbp: WordBreakProperty) bool {
    return switch (wbp) {
        .ALetter, .Hebrew_Letter, .Katakana, .Numeric, .ExtendNumLet => true,
        else => false,
    };
}

test "Word Break Properties" {
    const wb = try WordBreak.init(testing.allocator);
    defer wb.deinit(testing.allocator);
    try testing.expectEqual(.CR, wb.breakProperty('\r'));
    try testing.expectEqual(.LF, wb.breakProperty('\n'));
    try testing.expectEqual(.Hebrew_Letter, wb.breakProperty('ש'));
    try testing.expectEqual(.Katakana, wb.breakProperty('\u{30ff}'));
}

fn testAllocations(allocator: Allocator) !void {
    const wb = try WordBreak.init(allocator);
    wb.deinit(allocator);
}

test "allocation safety" {
    try testing.checkAllAllocationFailures(testing.allocator, testAllocations, .{});
}

const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;

const code_point = @import("code_point");
const CodepointIterator = code_point.Iterator;
const CodePoint = code_point.CodePoint;

const ext_pict = @import("micro_runeset.zig").Extended_Pictographic;
