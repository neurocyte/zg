const std = @import("std");
const builtin = @import("builtin");
const compress = std.compress;
const mem = std.mem;

allocator: mem.Allocator,
nfc: std.AutoHashMap([2]u21, u21),
nfd: [][]u21 = undefined,

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const decompressor = compress.flate.inflate.decompressor;
    const in_bytes = @embedFile("canon");
    var in_fbs = std.io.fixedBufferStream(in_bytes);
    var in_decomp = decompressor(.raw, in_fbs.reader());
    var reader = in_decomp.reader();

    const endian = builtin.cpu.arch.endian();
    var self = Self{
        .allocator = allocator,
        .nfc = std.AutoHashMap([2]u21, u21).init(allocator),
        .nfd = try allocator.alloc([]u21, 0x110000),
    };

    var slices: usize = 0;
    errdefer {
        self.nfc.deinit();
        for (self.nfd[0..slices]) |slice| self.allocator.free(slice);
        self.allocator.free(self.nfd);
    }

    @memset(self.nfd, &.{});

    while (true) {
        const len: u8 = try reader.readInt(u8, endian);
        if (len == 0) break;
        const cp = try reader.readInt(u24, endian);
        self.nfd[cp] = try allocator.alloc(u21, len - 1);
        slices += 1;
        for (0..len - 1) |i| {
            self.nfd[cp][i] = @intCast(try reader.readInt(u24, endian));
        }
        if (len == 3) {
            try self.nfc.put(self.nfd[cp][0..2].*, @intCast(cp));
        }
    }

    return self;
}

pub fn deinit(self: *Self) void {
    self.nfc.deinit();
    for (self.nfd) |slice| self.allocator.free(slice);
    self.allocator.free(self.nfd);
}

/// Returns canonical decomposition for `cp`.
pub fn toNfd(self: Self, cp: u21) []const u21 {
    return self.nfd[cp];
}

// Returns the primary composite for the codepoints in `cp`.
pub fn toNfc(self: Self, cps: [2]u21) ?u21 {
    return self.nfc.get(cps);
}
