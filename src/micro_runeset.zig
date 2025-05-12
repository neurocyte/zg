//! Minimal RuneSet implementation
//!
//! This is copied from the full RuneSet module, so that `zg` doesn't
//! depend on it.  There's one spot in the WordBreak algorithm which
//! needs to identify the emoji Extended_Pictographic property, which
//! is not otherwise used in ZG.  The Runeset is 89 words, while the
//! trie lookup used throughout ZG would be much larger.
//!
//! The RuneSet is borrowed from Runicode, which encodes Unicode things
//! in RuneSet form.  This will need updating for each version of Unicode.

pub const Extended_Pictographic = RuneSet{ .body = &.{ 0x0, 0x0, 0x1000c00000004, 0x1f, 0x420000000000, 0x30107fc8d053, 0x401, 0x80000000, 0xffff0fffafffffff, 0x2800000, 0x2001000000000000, 0x210000, 0x8000060, 0x10000000000000, 0x8001000200600000, 0x7800985090, 0x801022055ef2d, 0xedf57effffffdf57, 0xaffd75bd6f7d001f, 0xdbffffbbbff7ff7f, 0x7d7fddd76f56dfb5, 0x3800000000000001, 0x40040000000000, 0x4, 0x30bae0000008000, 0x100, 0x10004000000, 0x20001f00000, 0x200000400000000, 0x200, 0x1000000000000000, 0xfffffffffffffff7, 0xffffffffffffffff, 0xffffffffffffffff, 0x7fffffffffffbfff, 0x800000006000, 0x4001700000000000, 0xffffe00003fe4000, 0x1fffffffff, 0x73fc800004007ffa, 0xfffffffffffd7e00, 0xffffffffffffffff, 0x7fffffffffffffff, 0xffd56ff6bedfafff, 0x77ffffffffff7bff, 0xffffffff5757ffff, 0x3fafff77ff7bfef, 0xbffffdfffffab77f, 0xffffd7efffffffff, 0xff5fefffffffffff, 0xef6fd7ffffffffff, 0x1fffd7ffffefff7b, 0xfdfabf7ff7ffbac0, 0xf7faff77ffaf5dbf, 0x7dfbbf7eb7f6ffed, 0xfff7775fbfefdebf, 0x7fee, 0xbedddfddfbf7f7db, 0x6ebb6edf776b7bdf, 0x7ff0000000000000, 0x7fff77ff7fe00000, 0x7000, 0x7c007f00, 0xffffc00000007f00, 0x7fffffffffffffff, 0xb3fb7f7fbeff7000, 0x7ebef7ffbfff779f, 0x7dff5bebff7dffef, 0x7fffffbfffff7bfb, 0xffffffffffffffff, 0x6b777fffffffffff, 0xdbbf6effffdfbebb, 0x7ebf7f7fb5bf5fdb, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0x1fffffffffffffff } };

// Meaningful names for the T1 slots
const LOW = 0;
const HI = 1;
const LEAD = 2;
const T4_OFF = 3;

/// Minimum Viable Runeset.  Must be statically created, strictly boolean matching.
pub const RuneSet = struct {
    body: []const u64,

    // Returns whether the slice is a match.  This assumes the validity of the
    // string, which can be ensured by, in particular, deriving it from a CodePoint.
    pub fn isMatch(runeset: RuneSet, str: []const u8) bool {
        const set = runeset.body;
        const a = codeunit(str[0]);
        switch (a.kind) {
            .follow => return false,
            .low => {
                const mask = toMask(set[LOW]);
                if (mask.isIn(a))
                    return true
                else
                    return false;
            },
            .hi => {
                const mask = toMask(set[HI]);
                if (mask.isIn(a))
                    return true
                else
                    return false;
            },
            .lead => {
                const nB = a.nMultiBytes().?;
                const a_mask = toMask(set[LEAD]);
                if (!a_mask.isIn(a)) return false;
                const b = codeunit(str[1]);
                const b_loc = 4 + a_mask.lowerThan(a).?;
                const b_mask = toMask(set[b_loc]);
                if (!b_mask.isIn(b)) return false;
                if (nB == 2) return true;
                const t3_off = 4 + @popCount(set[LEAD]);
                const c = codeunit(str[2]);
                // Slice is safe because we know the T2 span has at least one word.
                const c_off = b_mask.higherThan(b).? + popCountSlice(set[b_loc + 1 .. t3_off]);
                const c_loc = t3_off + c_off;
                const c_mask = toMask(set[c_loc]);
                if (!c_mask.isIn(c)) return false;
                if (nB == 3) return true;
                const d_off = c_mask.lowerThan(c).? + popCountSlice(set[t3_off..c_loc]);
                const d_loc = set[T4_OFF] + d_off;
                const d = codeunit(str[3]);
                const d_mask = toMask(set[d_loc]);
                if (d_mask.isIn(d)) return true else return false;
            },
        }
    }
};

/// Kinds of most significant bits in UTF-8
const RuneKind = enum(u2) {
    low,
    hi,
    follow,
    lead,
};

/// Packed `u8` struct representing one codeunit of UTF-8.
const CodeUnit = packed struct(u8) {
    body: u6,
    kind: RuneKind,

    /// Mask to check presence
    pub inline fn inMask(self: *const CodeUnit) u64 {
        return @as(u64, 1) << self.body;
    }

    // TODO consider an nMultiBytesFast, for the cases where we
    // know that invalid lead bytes are never present (such as in set)
    // operations, where we may assume that (and will assert that) the
    // LEAD mask contains no such bytes.

    /// Number of bytes in known multi-byte rune.
    ///
    /// Caller guarantees that the CodeUnit is a lead byte
    /// of a multi-byte rune: `cu.kind == .lead`.
    ///
    /// Invalid lead bytes will return null.
    pub inline fn nMultiBytes(self: *const CodeUnit) ?u8 {
        return switch (self.body) {
            // 0 and 1 are invalid for overlong reasons,
            // but RuneSet supports overlong encodings
            0...31 => 2,
            32...47 => 3,
            48...55 => 4,
            // Wasted space 56...61 is due entirely to Microsoft's
            // lack of vision and insistence on a substandard
            // and utterly inadequate encoding for Unicode
            // "64k should be enough for anyone" <spits>
            56...63 => null,
        };
    }

    /// Given a valid lead byte, return the number of bytes that should
    /// make up the code unit sequence.  Will return `null` if the lead
    /// byte is invalid.
    pub inline fn nBytes(self: *const CodeUnit) ?u8 {
        switch (self.kind) {
            .low, .hi => return 1,
            .lead => return self.nMultiBytes(),
            .follow => return null,
        }
    }

    /// Mask off all bits >= cu.body
    pub inline fn hiMask(self: *const CodeUnit) u64 {
        return (@as(u64, 1) << self.body) - 1;
    }

    /// Mask off all bits <= cu.body
    pub inline fn lowMask(self: *const CodeUnit) u64 {
        if (self.body == 63)
            return 0
        else
            return ~((@as(u64, 1) << (self.body + 1)) - 1);
    }

    /// Cast the `CodeUnit` to its backing `u8`.
    pub inline fn byte(self: *const CodeUnit) u8 {
        return @bitCast(self.*);
    }
};

/// Cast raw byte to CodeUnit
inline fn codeunit(b: u8) CodeUnit {
    return @bitCast(b);
}

inline fn toMask(w: u64) Mask {
    return Mask.toMask(w);
}

/// Bitmask for runesets
///
/// We define our own bitset, because the operations we need to
/// perform only overlap with IntegerBitSet for trivial one-liners,
/// and furthermore, we need nondestructive versions of the basic
/// operations, which aren't a part of the IntegerBitSet interface.
///
/// Note that Masks do not track which kind of byte they apply to,
/// since they will be stored as ordinary u64s.  User code must
/// ensure that CodeUnits tested against a Mask are of the appropriate
/// type, and otherwise valid for the test performed.
///
const Mask = struct {
    m: u64,

    pub fn toMask(w: u64) Mask {
        return Mask{ .m = w };
    }

    /// Test if a CodeUnit's low bytes are present in mask
    pub inline fn isIn(self: Mask, cu: CodeUnit) bool {
        return self.m | cu.inMask() == self.m;
    }

    /// Return number of bytes lower than cu.body in mask,
    /// if cu inhabits the mask.  Otherwise return null.
    pub inline fn lowerThan(self: Mask, cu: CodeUnit) ?u64 {
        if (self.isIn(cu)) {
            const m = cu.hiMask();
            return @popCount(self.m & m);
        } else {
            return null;
        }
    }

    /// Return number of bytes higher than cu.body in mask,
    /// if cu inhabits the mask.  Otherwise return null.
    pub inline fn higherThan(self: Mask, cu: CodeUnit) ?u64 {
        if (self.isIn(cu)) {
            const m = cu.lowMask();
            return @popCount(self.m & m);
        } else {
            return null;
        }
    }
};

/// Sum of @popCount of all words in region.
inline fn popCountSlice(region: []const u64) usize {
    var ct: usize = 0;
    for (region) |w| ct += @popCount(w);
    return ct;
}
