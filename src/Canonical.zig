const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
nfd: [][2]u21 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.deflate.decompressor;
    const in_bytes = @embedFile("canon");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = try decompressor(allocator, in_fbs.reader(), null);
    defer in_decomp.deinit();
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{
        .allocator = allocator,
        .nfd = try allocator.alloc([2]u21, 0x110000),
    };

    for (0..0x110000) |i| self.nfd[i] = .{ @intCast(i), 0 };

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        self.nfd[cp][0] = @intCast(try reader.readInt(u24, endian));
        if (len == 3) self.nfd[cp][1] = @intCast(try reader.readInt(u24, endian));
    }

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.nfd);
}

/// Returns canonical decomposition for `cp`.
pub inline fn toNfd(self: Self, cp: u21) [2]u21 {
    return self.nfd[cp];
}
