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

/// Returns the word break property type for `cp`.
pub fn breakProperty(wordbreak: *const WordBreak, cp: u21) WordBreakProperty {
    return @enumFromInt(wordbreak.s2[wordbreak.s1[cp >> 8] + (cp & 0xff)]);
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
const testing = std.testing;
