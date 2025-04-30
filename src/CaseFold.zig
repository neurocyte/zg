const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ascii = @import("ascii");
pub const FoldData = @import("FoldData");
const Normalize = @import("Normalize");

fold_data: *const FoldData,

const Self = @This();

/// Produces the case folded code points for `cps`. Caller must free returned
/// slice with `allocator`.
pub fn caseFold(
    self: Self,
    allocator: mem.Allocator,
    cps: []const u21,
) ![]const u21 {
    var cfcps = std.ArrayList(u21).init(allocator);
    defer cfcps.deinit();
    var buf: [3]u21 = undefined;

    for (cps) |cp| {
        const cf = self.fold_data.caseFold(cp, &buf);

        if (cf.len == 0) {
            try cfcps.append(cp);
        } else {
            try cfcps.appendSlice(cf);
        }
    }

    return try cfcps.toOwnedSlice();
}

fn changesWhenCaseFolded(self: Self, cps: []const u21) bool {
    return for (cps) |cp| {
        if (self.fold_data.changesWhenCaseFolded(cp)) break true;
    } else false;
}

/// Caseless compare `a` and `b` by decomposing to NFKD. This is the most
/// comprehensive comparison possible, but slower than `canonCaselessMatch`.
pub fn compatCaselessMatch(
    self: Self,
    allocator: mem.Allocator,
    normalizer: *const Normalize,
    a: []const u8,
    b: []const u8,
) !bool {
    if (ascii.isAsciiOnly(a) and ascii.isAsciiOnly(b)) return std.ascii.eqlIgnoreCase(a, b);

    // Process a
    const nfd_a = try normalizer.nfxdCodePoints(allocator, a, .nfd);
    defer allocator.free(nfd_a);

    var need_free_cf_nfd_a = false;
    var cf_nfd_a: []const u21 = nfd_a;
    if (self.changesWhenCaseFolded(nfd_a)) {
        cf_nfd_a = try self.caseFold(allocator, nfd_a);
        need_free_cf_nfd_a = true;
    }
    defer if (need_free_cf_nfd_a) allocator.free(cf_nfd_a);

    const nfkd_cf_nfd_a = try normalizer.nfkdCodePoints(allocator, cf_nfd_a);
    defer allocator.free(nfkd_cf_nfd_a);
    const cf_nfkd_cf_nfd_a = try self.caseFold(allocator, nfkd_cf_nfd_a);
    defer allocator.free(cf_nfkd_cf_nfd_a);
    const nfkd_cf_nfkd_cf_nfd_a = try normalizer.nfkdCodePoints(allocator, cf_nfkd_cf_nfd_a);
    defer allocator.free(nfkd_cf_nfkd_cf_nfd_a);

    // Process b
    const nfd_b = try normalizer.nfxdCodePoints(allocator, b, .nfd);
    defer allocator.free(nfd_b);

    var need_free_cf_nfd_b = false;
    var cf_nfd_b: []const u21 = nfd_b;
    if (self.changesWhenCaseFolded(nfd_b)) {
        cf_nfd_b = try self.caseFold(allocator, nfd_b);
        need_free_cf_nfd_b = true;
    }
    defer if (need_free_cf_nfd_b) allocator.free(cf_nfd_b);

    const nfkd_cf_nfd_b = try normalizer.nfkdCodePoints(allocator, cf_nfd_b);
    defer allocator.free(nfkd_cf_nfd_b);
    const cf_nfkd_cf_nfd_b = try self.caseFold(allocator, nfkd_cf_nfd_b);
    defer allocator.free(cf_nfkd_cf_nfd_b);
    const nfkd_cf_nfkd_cf_nfd_b = try normalizer.nfkdCodePoints(allocator, cf_nfkd_cf_nfd_b);
    defer allocator.free(nfkd_cf_nfkd_cf_nfd_b);

    return mem.eql(u21, nfkd_cf_nfkd_cf_nfd_a, nfkd_cf_nfkd_cf_nfd_b);
}

test "compatCaselessMatch" {
    const allocator = testing.allocator;

    const n = try Normalize.init(allocator);
    defer n.deinit(allocator);

    const fold_data = try FoldData.init(allocator);
    defer fold_data.deinit(allocator);
    const caser = Self{ .fold_data = &fold_data };

    try testing.expect(try caser.compatCaselessMatch(allocator, &n, "ascii only!", "ASCII Only!"));

    const a = "Héllo World! \u{3d3}";
    const b = "He\u{301}llo World! \u{3a5}\u{301}";
    try testing.expect(try caser.compatCaselessMatch(allocator, &n, a, b));

    const c = "He\u{301}llo World! \u{3d2}\u{301}";
    try testing.expect(try caser.compatCaselessMatch(allocator, &n, a, c));
}

/// Performs canonical caseless string matching by decomposing to NFD. This is
/// faster than `compatCaselessMatch`, but less comprehensive.
pub fn canonCaselessMatch(
    self: Self,
    allocator: mem.Allocator,
    normalizer: *const Normalize,
    a: []const u8,
    b: []const u8,
) !bool {
    if (ascii.isAsciiOnly(a) and ascii.isAsciiOnly(b)) return std.ascii.eqlIgnoreCase(a, b);

    // Process a
    const nfd_a = try normalizer.nfxdCodePoints(allocator, a, .nfd);
    defer allocator.free(nfd_a);

    var need_free_cf_nfd_a = false;
    var cf_nfd_a: []const u21 = nfd_a;
    if (self.changesWhenCaseFolded(nfd_a)) {
        cf_nfd_a = try self.caseFold(allocator, nfd_a);
        need_free_cf_nfd_a = true;
    }
    defer if (need_free_cf_nfd_a) allocator.free(cf_nfd_a);

    var need_free_nfd_cf_nfd_a = false;
    var nfd_cf_nfd_a = cf_nfd_a;
    if (!need_free_cf_nfd_a) {
        nfd_cf_nfd_a = try normalizer.nfdCodePoints(allocator, cf_nfd_a);
        need_free_nfd_cf_nfd_a = true;
    }
    defer if (need_free_nfd_cf_nfd_a) allocator.free(nfd_cf_nfd_a);

    // Process b
    const nfd_b = try normalizer.nfxdCodePoints(allocator, b, .nfd);
    defer allocator.free(nfd_b);

    var need_free_cf_nfd_b = false;
    var cf_nfd_b: []const u21 = nfd_b;
    if (self.changesWhenCaseFolded(nfd_b)) {
        cf_nfd_b = try self.caseFold(allocator, nfd_b);
        need_free_cf_nfd_b = true;
    }
    defer if (need_free_cf_nfd_b) allocator.free(cf_nfd_b);

    var need_free_nfd_cf_nfd_b = false;
    var nfd_cf_nfd_b = cf_nfd_b;
    if (!need_free_cf_nfd_b) {
        nfd_cf_nfd_b = try normalizer.nfdCodePoints(allocator, cf_nfd_b);
        need_free_nfd_cf_nfd_b = true;
    }
    defer if (need_free_nfd_cf_nfd_b) allocator.free(nfd_cf_nfd_b);

    return mem.eql(u21, nfd_cf_nfd_a, nfd_cf_nfd_b);
}

test "canonCaselessMatch" {
    const allocator = testing.allocator;

    const n = try Normalize.init(allocator);
    defer n.deinit(allocator);

    const fold_data = try FoldData.init(allocator);
    defer fold_data.deinit(allocator);
    const caser = Self{ .fold_data = &fold_data };

    try testing.expect(try caser.canonCaselessMatch(allocator, &n, "ascii only!", "ASCII Only!"));

    const a = "Héllo World! \u{3d3}";
    const b = "He\u{301}llo World! \u{3a5}\u{301}";
    try testing.expect(!try caser.canonCaselessMatch(allocator, &n, a, b));

    const c = "He\u{301}llo World! \u{3d2}\u{301}";
    try testing.expect(try caser.canonCaselessMatch(allocator, &n, a, c));
}
