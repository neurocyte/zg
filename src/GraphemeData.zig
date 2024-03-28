const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

/// Indic syllable type.
pub const Indic = enum {
    none,

    Consonant,
    Extend,
    Linker,
};

/// Grapheme break property.
pub const Gbp = enum {
    none,
    Control,
    CR,
    Extend,
    L,
    LF,
    LV,
    LVT,
    Prepend,
    Regional_Indicator,
    SpacingMark,
    T,
    V,
    ZWJ,
};

allocator: mem.Allocator,
s1: []u16 = undefined,
s2: []u16 = undefined,
s3: []u8 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("gbp");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = try decompressor(allocator, in_fbs.reader(), null);
    defer in_decomp.deinit();
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var self = Self{ .allocator = allocator };

    const s1_len: u16 = try reader.readInt(u16, endian);
    self.s1 = try allocator.alloc(u16, s1_len);
    for (0..s1_len) |i| self.s1[i] = try reader.readInt(u16, endian);

    const s2_len: u16 = try reader.readInt(u16, endian);
    self.s2 = try allocator.alloc(u16, s2_len);
    for (0..s2_len) |i| self.s2[i] = try reader.readInt(u16, endian);

    const s3_len: u16 = try reader.readInt(u16, endian);
    self.s3 = try allocator.alloc(u8, s3_len);
    _ = try reader.readAll(self.s3);

    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
    self.allocator.free(self.s3);
}

/// Lookup the grapheme break property for a code point.
pub inline fn gbp(self: Self, cp: u21) Gbp {
    return @enumFromInt(self.s3[self.s2[self.s1[cp >> 8] + (cp & 0xff)]] >> 4);
}

/// Lookup the indic syllable type for a code point.
pub inline fn indic(self: Self, cp: u21) Indic {
    return @enumFromInt((self.s3[self.s2[self.s1[cp >> 8] + (cp & 0xff)]] >> 1) & 0x7);
}

/// Lookup the indic syllable type for a code point.
pub inline fn isEmoji(self: Self, cp: u21) bool {
    return self.s3[self.s2[self.s1[cp >> 8] + (cp & 0xff)]] & 1 == 1;
}
