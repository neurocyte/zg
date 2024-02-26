const std = @import("std");
const mem = std.mem;

const CanonData = @import("CanonicalData");
const CccData = @import("CombiningClassData");

canon_data: CanonData,
ccc_data: CccData,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .canon_data = try CanonData.init(allocator),
        .ccc_data = try CccData.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.canon_data.deinit();
    self.ccc_data.deinit();
}
