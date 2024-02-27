const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

/// General Category
pub const Gc = enum {
    Cc,
    Cf,
    Cn,
    Co,
    Cs,
    Ll,
    Lm,
    Lo,
    Lt,
    Lu,
    Mc,
    Me,
    Mn,
    Nd,
    Nl,
    No,
    Pc,
    Pd,
    Pe,
    Pf,
    Pi,
    Po,
    Ps,
    Sc,
    Sk,
    Sm,
    So,
    Zl,
    Zp,
    Zs,
};

allocator: mem.Allocator,
s1: []u16 = undefined,
s2: []u5 = undefined,
s3: []u5 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("gencat");
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
    self.s2 = try allocator.alloc(u5, s2_len);
    for (0..s2_len) |i| self.s2[i] = @intCast(try reader.readInt(u8, endian));

    const s3_len: u16 = try reader.readInt(u8, endian);
    self.s3 = try allocator.alloc(u5, s3_len);
    for (0..s3_len) |i| self.s3[i] = @intCast(try reader.readInt(u8, endian));

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.s1);
    self.allocator.free(self.s2);
    self.allocator.free(self.s3);
}

/// Lookup the General Category for `cp`.
pub inline fn gc(self: Self, cp: u21) Gc {
    return @enumFromInt(self.s3[self.s2[self.s1[cp >> 8] + (cp & 0xff)]]);
}
