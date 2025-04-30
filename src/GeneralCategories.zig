const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

/// General Category
pub const Gc = enum {
    Cc, // Other, Control
    Cf, // Other, Format
    Cn, // Other, Unassigned
    Co, // Other, Private Use
    Cs, // Other, Surrogate
    Ll, // Letter, Lowercase
    Lm, // Letter, Modifier
    Lo, // Letter, Other
    Lu, // Letter, Uppercase
    Lt, // Letter, Titlecase
    Mc, // Mark, Spacing Combining
    Me, // Mark, Enclosing
    Mn, // Mark, Non-Spacing
    Nd, // Number, Decimal Digit
    Nl, // Number, Letter
    No, // Number, Other
    Pc, // Punctuation, Connector
    Pd, // Punctuation, Dash
    Pe, // Punctuation, Close
    Pf, // Punctuation, Final quote (may behave like Ps or Pe depending on usage)
    Pi, // Punctuation, Initial quote (may behave like Ps or Pe depending on usage)
    Po, // Punctuation, Other
    Ps, // Punctuation, Open
    Sc, // Symbol, Currency
    Sk, // Symbol, Modifier
    Sm, // Symbol, Math
    So, // Symbol, Other
    Zl, // Separator, Line
    Zp, // Separator, Paragraph
    Zs, // Separator, Space
};

s1: []u16 = undefined,
s2: []u5 = undefined,
s3: []u5 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("gencat");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();

    var self = Self{};

    const s1_len: u16 = try reader.readInt(u16, endian);
    self.s1 = try allocator.alloc(u16, s1_len);
    errdefer allocator.free(self.s1);
    for (0..s1_len) |i| self.s1[i] = try reader.readInt(u16, endian);

    const s2_len: u16 = try reader.readInt(u16, endian);
    self.s2 = try allocator.alloc(u5, s2_len);
    errdefer allocator.free(self.s2);
    for (0..s2_len) |i| self.s2[i] = @intCast(try reader.readInt(u8, endian));

    const s3_len: u16 = try reader.readInt(u8, endian);
    self.s3 = try allocator.alloc(u5, s3_len);
    errdefer allocator.free(self.s3);
    for (0..s3_len) |i| self.s3[i] = @intCast(try reader.readInt(u8, endian));

    return self;
}

pub fn deinit(self: *const Self, allocator: mem.Allocator) void {
    allocator.free(self.s1);
    allocator.free(self.s2);
    allocator.free(self.s3);
}

/// Lookup the General Category for `cp`.
pub fn gc(self: Self, cp: u21) Gc {
    return @enumFromInt(self.s3[self.s2[self.s1[cp >> 8] + (cp & 0xff)]]);
}

/// True if `cp` has an C general category.
pub fn isControl(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Cc,
        .Cf,
        .Cn,
        .Co,
        .Cs,
        => true,
        else => false,
    };
}

/// True if `cp` has an L general category.
pub fn isLetter(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Ll,
        .Lm,
        .Lo,
        .Lu,
        .Lt,
        => true,
        else => false,
    };
}

/// True if `cp` has an M general category.
pub fn isMark(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Mc,
        .Me,
        .Mn,
        => true,
        else => false,
    };
}

/// True if `cp` has an N general category.
pub fn isNumber(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Nd,
        .Nl,
        .No,
        => true,
        else => false,
    };
}

/// True if `cp` has an P general category.
pub fn isPunctuation(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Pc,
        .Pd,
        .Pe,
        .Pf,
        .Pi,
        .Po,
        .Ps,
        => true,
        else => false,
    };
}

/// True if `cp` has an S general category.
pub fn isSymbol(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Sc,
        .Sk,
        .Sm,
        .So,
        => true,
        else => false,
    };
}

/// True if `cp` has an Z general category.
pub fn isSeparator(self: Self, cp: u21) bool {
    return switch (self.gc(cp)) {
        .Zl,
        .Zp,
        .Zs,
        => true,
        else => false,
    };
}
