const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
nfkd: [][]u21 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("compat");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{
        .allocator = allocator,
        .nfkd = try allocator.alloc([]u21, 0x110000),
    };
    errdefer self.deinit();

    @memset(self.nfkd, &.{});

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        self.nfkd[cp] = try allocator.alloc(u21, len - 1);
        for (0..len - 1) |i| {
            self.nfkd[cp][i] = @intCast(try reader.readInt(u24, endian));
        }
    }

    return self;
}

pub fn deinit(self: *const Self) void {
    for (self.nfkd) |slice| {
        if (slice.len != 0) self.allocator.free(slice);
    }
    self.allocator.free(self.nfkd);
}

/// Returns compatibility decomposition for `cp`.
pub fn toNfkd(self: Self, cp: u21) []u21 {
    return self.nfkd[cp];
}
