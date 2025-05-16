const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

const allocator = testing.allocator;

const GeneralCategories = @import("GeneralCategories");

test GeneralCategories {
    const gen_cat = try GeneralCategories.init(allocator);
    defer gen_cat.deinit(allocator);

    try expect(gen_cat.gc('A') == .Lu); // Lu: uppercase letter
    try expect(gen_cat.gc('3') == .Nd); // Nd: Decimal number
    try expect(gen_cat.isControl(0));
    try expect(gen_cat.isLetter('z'));
    try expect(gen_cat.isMark('\u{301}'));
    try expect(gen_cat.isNumber('3'));
    try expect(gen_cat.isPunctuation('['));
    try expect(gen_cat.isSeparator(' '));
    try expect(gen_cat.isSymbol('©'));
}

const Properties = @import("Properties");

test Properties {
    const props = try Properties.init(allocator);
    defer props.deinit(allocator);

    try expect(props.isMath('+'));
    try expect(props.isAlphabetic('Z'));
    try expect(props.isWhitespace(' '));
    try expect(props.isHexDigit('f'));
    try expect(!props.isHexDigit('z'));

    try expect(props.isDiacritic('\u{301}'));
    try expect(props.isIdStart('Z')); // Identifier start character
    try expect(!props.isIdStart('1'));
    try expect(props.isIdContinue('1'));
    try expect(props.isXidStart('\u{b33}')); // Extended identifier start character
    try expect(props.isXidContinue('\u{e33}'));
    try expect(!props.isXidStart('1'));

    // Note surprising Unicode numeric types!
    try expect(props.isNumeric('\u{277f}'));
    try expect(!props.isNumeric('3'));
    try expect(props.isDigit('\u{2070}'));
    try expect(!props.isDigit('3'));
    try expect(props.isDecimal('3'));
}

const LetterCasing = @import("LetterCasing");

test LetterCasing {
    const case = try LetterCasing.init(allocator);
    defer case.deinit(allocator);

    try expect(case.isUpper('A'));
    try expect('A' == case.toUpper('a'));
    try expect(case.isLower('a'));
    try expect('a' == case.toLower('A'));

    try expect(case.isCased('É'));
    try expect(!case.isCased('3'));

    try expect(case.isUpperStr("HELLO 123!"));
    const ucased = try case.toUpperStr(allocator, "hello 123");
    defer allocator.free(ucased);
    try expectEqualStrings("HELLO 123", ucased);

    try expect(case.isLowerStr("hello 123!"));
    const lcased = try case.toLowerStr(allocator, "HELLO 123");
    defer allocator.free(lcased);
    try expectEqualStrings("hello 123", lcased);
}

const Normalize = @import("Normalize");

test Normalize {
    const normalize = try Normalize.init(allocator);
    defer normalize.deinit(allocator);

    // NFD: Canonical decomposition
    const nfd_result = try normalize.nfd(allocator, "Héllo World! \u{3d3}");
    defer nfd_result.deinit(allocator);
    try expectEqualStrings("He\u{301}llo World! \u{3d2}\u{301}", nfd_result.slice);

    // NFKD: Compatibility decomposition
    const nfkd_result = try normalize.nfkd(allocator, "Héllo World! \u{3d3}");
    defer nfkd_result.deinit(allocator);
    try expectEqualStrings("He\u{301}llo World! \u{3a5}\u{301}", nfkd_result.slice);

    // NFC: Canonical composition
    const nfc_result = try normalize.nfc(allocator, "Complex char: \u{3D2}\u{301}");
    defer nfc_result.deinit(allocator);
    try expectEqualStrings("Complex char: \u{3D3}", nfc_result.slice);

    // NFKC: Compatibility composition
    const nfkc_result = try normalize.nfkc(allocator, "Complex char: \u{03A5}\u{0301}");
    defer nfkc_result.deinit(allocator);
    try expectEqualStrings("Complex char: \u{038E}", nfkc_result.slice);

    // Test for equality of two strings after normalizing to NFC.
    try expect(try normalize.eql(allocator, "foé", "foe\u{0301}"));
    try expect(try normalize.eql(allocator, "foϓ", "fo\u{03D2}\u{0301}"));
}

const CaseFolding = @import("CaseFolding");

test CaseFolding {
    const case_fold = try CaseFolding.init(allocator);
    defer case_fold.deinit(allocator);

    // compatCaselessMatch provides the deepest level of caseless
    // matching because it decomposes and composes fully to NFKC.
    const a = "Héllo World! \u{3d3}";
    const b = "He\u{301}llo World! \u{3a5}\u{301}";
    try expect(try case_fold.compatCaselessMatch(allocator, a, b));

    const c = "He\u{301}llo World! \u{3d2}\u{301}";
    try expect(try case_fold.compatCaselessMatch(allocator, a, c));

    // canonCaselessMatch isn't as comprehensive as compatCaselessMatch
    // because it only decomposes and composes to NFC. But it's faster.
    try expect(!try case_fold.canonCaselessMatch(allocator, a, b));
    try expect(try case_fold.canonCaselessMatch(allocator, a, c));
}

const DisplayWidth = @import("DisplayWidth");

test DisplayWidth {
    const dw = try DisplayWidth.init(allocator);
    defer dw.deinit(allocator);

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

const Graphemes = @import("Graphemes");

test "Grapheme cluster iterator" {
    const graphemes = try Graphemes.init(allocator);
    defer graphemes.deinit(allocator);
    const str = "He\u{301}"; // Hé
    var iter = graphemes.iterator(str);
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

const Scripts = @import("Scripts");

test Scripts {
    const scripts = try Scripts.init(allocator);
    defer scripts.deinit(allocator);

    try expect(scripts.script('A') == .Latin);
    try expect(scripts.script('Ω') == .Greek);
    try expect(scripts.script('צ') == .Hebrew);
}
