const std = @import("std");
const mem = std.mem;

const CanonData = @import("CanonData");
const CccData = @import("CombiningData");
const CompatData = @import("CompatData");

canon_data: CanonData,
ccc_data: CccData,
compat_data: CompatData,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .canon_data = try CanonData.init(allocator),
        .ccc_data = try CccData.init(allocator),
        .compat_data = try CompatData.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.canon_data.deinit();
    self.ccc_data.deinit();
    self.compat_data.deinit();
}
