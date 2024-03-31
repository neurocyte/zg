const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

const allocator = testing.allocator;

const GenCatData = @import("GenCatData");

test "General Category" {
    const gcd = try GenCatData.init(allocator);
    defer gcd.deinit();

    try expect(gcd.gc('A') == .Lu); // Lu: uppercase letter
    try expect(gcd.gc('3') == .Nd); // Nd: Decimal number
    try expect(gcd.isControl(0));
    try expect(gcd.isLetter('z'));
    try expect(gcd.isMark('\u{301}'));
    try expect(gcd.isNumber('3'));
    try expect(gcd.isPunctuation('['));
    try expect(gcd.isSeparator(' '));
    try expect(gcd.isSymbol('©'));
}

const PropsData = @import("PropsData");

test "Properties" {
    const pd = try PropsData.init(allocator);
    defer pd.deinit();

    try expect(pd.isMath('+'));
    try expect(pd.isAlphabetic('Z'));
    try expect(pd.isWhitespace(' '));
    try expect(pd.isHexDigit('f'));
    try expect(!pd.isHexDigit('z'));

    try expect(pd.isDiacritic('\u{301}'));
    try expect(pd.isIdStart('Z')); // Identifier start character
    try expect(!pd.isIdStart('1'));
    try expect(pd.isIdContinue('1'));
    try expect(pd.isXidStart('\u{b33}')); // Extended identifier start character
    try expect(pd.isXidContinue('\u{e33}'));
    try expect(!pd.isXidStart('1'));

    // Note surprising Unicode numeric types!
    try expect(pd.isNumeric('\u{277f}'));
    try expect(!pd.isNumeric('3'));
    try expect(pd.isDigit('\u{2070}'));
    try expect(!pd.isDigit('3'));
    try expect(pd.isDecimal('3'));
}

const CaseData = @import("CaseData");

test "Case" {
    const cd = try CaseData.init(allocator);
    defer cd.deinit();

    try expect(cd.isUpper('A'));
    try expect('A' == cd.toUpper('a'));
    try expect(cd.isLower('a'));
    try expect('a' == cd.toLower('A'));

    try expect(cd.isCased('É'));
    try expect(!cd.isCased('3'));

    try expect(cd.isUpperStr("HELLO 123!"));
    const ucased = try cd.toUpperStr(allocator, "hello 123");
    defer allocator.free(ucased);
    try expectEqualStrings("HELLO 123", ucased);

    try expect(cd.isLowerStr("hello 123!"));
    const lcased = try cd.toLowerStr(allocator, "HELLO 123");
    defer allocator.free(lcased);
    try expectEqualStrings("hello 123", lcased);
}

const Normalize = @import("Normalize");

test "Normalization" {
    var norm_data = try Normalize.NormData.init(allocator);
    defer norm_data.deinit();
    const n = Normalize{ .norm_data = &norm_data };

    // NFD: Canonical decomposition
    const nfd_result = try n.nfd(allocator, "Héllo World! \u{3d3}");
    defer nfd_result.deinit();
    try expectEqualStrings("He\u{301}llo World! \u{3d2}\u{301}", nfd_result.slice);

    // NFKD: Compatibility decomposition
    const nfkd_result = try n.nfkd(allocator, "Héllo World! \u{3d3}");
    defer nfkd_result.deinit();
    try expectEqualStrings("He\u{301}llo World! \u{3a5}\u{301}", nfkd_result.slice);

    // NFC: Canonical composition
    const nfc_result = try n.nfc(allocator, "Complex char: \u{3D2}\u{301}");
    defer nfc_result.deinit();
    try expectEqualStrings("Complex char: \u{3D3}", nfc_result.slice);

    // NFKC: Compatibility composition
    const nfkc_result = try n.nfkc(allocator, "Complex char: \u{03A5}\u{0301}");
    defer nfkc_result.deinit();
    try expectEqualStrings("Complex char: \u{038E}", nfkc_result.slice);

    // Test for equality of two strings after normalizing to NFC.
    try expect(try n.eql(allocator, "foé", "foe\u{0301}"));
    try expect(try n.eql(allocator, "foϓ", "fo\u{03D2}\u{0301}"));
}

const CaseFold = @import("CaseFold");

test "Caseless matching" {
    var norm_data = try Normalize.NormData.init(allocator);
    defer norm_data.deinit();
    const n = Normalize{ .norm_data = &norm_data };

    const cfd = try CaseFold.FoldData.init(allocator);
    defer cfd.deinit();
    const cf = CaseFold{ .fold_data = &cfd };

    // compatCaselessMatch provides the deepest level of caseless
    // matching because it decomposes and composes fully to NFKC.
    const a = "Héllo World! \u{3d3}";
    const b = "He\u{301}llo World! \u{3a5}\u{301}";
    try expect(try cf.compatCaselessMatch(allocator, &n, a, b));

    const c = "He\u{301}llo World! \u{3d2}\u{301}";
    try expect(try cf.compatCaselessMatch(allocator, &n, a, c));

    // canonCaselessMatch isn't as comprehensive as compatCaselessMatch
    // because it only decomposes and composes to NFC. But it's faster.
    try expect(!try cf.canonCaselessMatch(allocator, &n, a, b));
    try expect(try cf.canonCaselessMatch(allocator, &n, a, c));
}

const DisplayWidth = @import("DisplayWidth");

test "Display width" {
    const dwd = try DisplayWidth.DisplayWidthData.init(allocator);
    defer dwd.deinit();
    const dw = DisplayWidth{ .data = &dwd };

    // String display width
    try expectEqual(@as(usize, 5), dw.strWidth("Hello\r\n"));
    try expectEqual(@as(usize, 8), dw.strWidth("Hello 😊"));
    try expectEqual(@as(usize, 8), dw.strWidth("Héllo 😊"));
    try expectEqual(@as(usize, 9), dw.strWidth("Ẓ̌á̲l͔̝̞̄̑͌g̖̘̘̔̔͢͞͝o̪̔T̢̙̫̈̍͞e̬͈͕͌̏͑x̺̍ṭ̓̓ͅ"));
    try expectEqual(@as(usize, 17), dw.strWidth("슬라바 우크라이나"));

    // Centering text
    const centered = try dw.center(allocator, "w😊w", 10, "-");
    defer allocator.free(centered);
    try expectEqualStrings("---w😊w---", centered);

    // Pad left
    const right_aligned = try dw.padLeft(allocator, "abc", 9, "*");
    defer allocator.free(right_aligned);
    try expectEqualStrings("******abc", right_aligned);

    // Pad right
    const left_aligned = try dw.padRight(allocator, "abc", 9, "*");
    defer allocator.free(left_aligned);
    try expectEqualStrings("abc******", left_aligned);

    // Wrap text
    const input = "The quick brown fox\r\njumped over the lazy dog!";
    const wrapped = try dw.wrap(allocator, input, 10, 3);
    defer allocator.free(wrapped);
    const want =
        \\The quick 
        \\brown fox 
        \\jumped 
        \\over the 
        \\lazy dog!
    ;
    try expectEqualStrings(want, wrapped);
}

const code_point = @import("code_point");

test "Code point iterator" {
    const str = "Hi 😊";
    var iter = code_point.Iterator{ .bytes = str };
    var i: usize = 0;

    while (iter.next()) |cp| : (i += 1) {
        if (i == 0) try expect(cp.code == 'H');
        if (i == 1) try expect(cp.code == 'i');
        if (i == 2) try expect(cp.code == ' ');

        if (i == 3) {
            try expect(cp.code == '😊');
            try expect(cp.offset == 3);
            try expect(cp.len == 4);
        }
    }
}

const grapheme = @import("grapheme");

test "Grapheme cluster iterator" {
    const gd = try grapheme.GraphemeData.init(allocator);
    defer gd.deinit();
    const str = "He\u{301}"; // Hé
    var iter = grapheme.Iterator.init(str, &gd);
    var i: usize = 0;

    while (iter.next()) |gc| : (i += 1) {
        if (i == 0) try expect(gc.len == 1);

        if (i == 1) {
            try expect(gc.len == 3);
            try expect(gc.offset == 1);
            try expectEqualStrings("e\u{301}", gc.bytes(str));
        }
    }
}

const ScriptsData = @import("ScriptsData");

test "Scripts" {
    const sd = try ScriptsData.init(allocator);
    defer sd.deinit();

    try expect(sd.script('A') == .Latin);
    try expect(sd.script('Ω') == .Greek);
    try expect(sd.script('צ') == .Hebrew);
}
