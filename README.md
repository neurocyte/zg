# zg
zg provides Unicode text processing for Zig projects.

## Unicode Version
The Unicode version supported by zg is 15.1.0.

## Zig Version
The minimum Zig version required is 0.12.0-dev.3496+a2df84d0.

## Integrating zg into your Zig Project
You first need to add zg as a dependency in your `build.zig.zon` file:

```zig
.zg = .{
    .url = "https://codeberg.org/dude_the_builder/zg/archive/v0.1.0.tar.gz",
}
```

Then instantiate the dependency in your `build.zig`:


```zig
const zg = b.dependency("zg", .{});
```

## A Modular Approach
zg is a modular library. This approach minimizes binary file size and memory
requirements by only including the Unicode data required for the specified module.
The following sections describe the various modules and their specific use case.

## Code Points
In the `code_point` module, you'll find a data structure representing a single code
point, `CodePoint`, and an `Iterator` to iterate over the code points in a string.

In your `build.zig`:

```zig
exe.root_module.addImport("code_point", zg.module("code_point"));
```

In your code:

```zig
const code_point = @import("code_point");

test "Code point iterator" {
    const str = "Hi 😊";
    var iter = code_point.Iterator{ .bytes = str };
    var i: usize = 0;

    while (iter.next()) |cp| : (i += 1) {
        // The `code` field is the actual code point scalar as a `u21`.
        if (i == 0) try expect(cp.code == 'H');
        if (i == 1) try expect(cp.code == 'i');
        if (i == 2) try expect(cp.code == ' ');

        if (i == 3) {
            try expect(cp.code == '😊');

            // The `offset` field is the byte offset in the
            // source string.
            try expect(cp.offset == 3);

            // The `len` field is the length in bytes of the
            // code point in the source string.
            try expect(cp.len == 4);
        }
    }
}
```

## Grapheme Clusters
Many characters are composed from more than one code point. These are known as
Grapheme Clusters and the `grapheme` module has a data structure to represent
them, `Grapheme`, and an `Iterator` to iterate over them in a string.

In your `build.zig`:

```zig
exe.root_module.addImport("grapheme", zg.module("grapheme"));
```

In your code:

```zig
const grapheme = @import("grapheme");

test "Grapheme cluster iterator" {
    // we need some Unicode data to process Grapheme Clusters.
    const gd = try grapheme.GraphemeData.init(allocator);
    defer gd.deinit();

    const str = "He\u{301}"; // Hé
    var iter = grapheme.Iterator.init(str, &gd);

    var i: usize = 0;

    while (iter.next()) |gc| : (i += 1) {
        // The `len` field is the length in bytes of the
        // grapheme cluster in the source string.
        if (i == 0) try expect(gc.len == 1);

        if (i == 1) {
            try expect(gc.len == 3);

            // The `offset` in bytes of the grapheme cluster
            // in the source string.
            try expect(gc.offset == 1);

            // The `bytes` method returns the slice of bytes
            // that comprise this grapheme cluster in the
            // source string `str`.
            try expectEqualStrings("e\u{301}", gc.bytes(str));
        }
    }
}
```

## Unicode General Categories
To detect the general category for a code point, use the `GenCatData` module.

In your `build.zig`:

```zig
exe.root_module.addImport("GenCatData", zg.module("GenCatData"));
```

In your code:

```zig
const GenCatData = @import("GenCatData");

test "General Category" {
    const gcd = try GenCatData.init(allocator);
    defer gcd.deinit();

    // The `gc` method returns the abbreviated General Category.
    // These abbreviations and descriptive comments can be found
    // in the source file `src/GenCatData.zig` as en enum.
    try expect(gcd.gc('A') == .Lu); // Lu: uppercase letter
    try expect(gcd.gc('3') == .Nd); // Nd: decimal number

    // The following are convenience methods for groups of General
    // Categories. For example, all letter categories start with `L`:
    // Lu, Ll, Lt, Lo.
    try expect(gcd.isControl(0));
    try expect(gcd.isLetter('z'));
    try expect(gcd.isMark('\u{301}'));
    try expect(gcd.isNumber('3'));
    try expect(gcd.isPunctuation('['));
    try expect(gcd.isSeparator(' '));
    try expect(gcd.isSymbol('©'));
}
```

## Unicode Properties
You can detect common properties of a code point with the `PropsData` module.

In your `build.zig`:

```zig
exe.root_module.addImport("PropsData", zg.module("PropsData"));
```

In your code:

```zig
const PropsData = @import("PropsData");

test "Properties" {
    const pd = try PropsData.init(allocator);
    defer pd.deinit();

    // Mathematical symbols and letters.
    try expect(pd.isMath('+'));
    // Alphabetic only code points.
    try expect(pd.isAlphabetic('Z'));
    // Space, tab, and other separators.
    try expect(pd.isWhitespace(' '));
    // Hexadecimal digits and variations thereof.
    try expect(pd.isHexDigit('f'));
    try expect(!pd.isHexDigit('z'));

    // Accents, dieresis, and other combining marks.
    try expect(pd.isDiacritic('\u{301}'));

    // Unicode has a specification for valid identifiers like 
    // the ones used in programming and regular expressions.
    try expect(pd.isIdStart('Z')); // Identifier start character
    try expect(!pd.isIdStart('1'));
    try expect(pd.isIdContinue('1'));

    // The `X` versions add some code points that can appear after
    // normalizing a string.
    try expect(pd.isXidStart('\u{b33}')); // Extended identifier start character
    try expect(pd.isXidContinue('\u{e33}'));
    try expect(!pd.isXidStart('1'));

    // Note surprising Unicode numeric type properties!
    try expect(pd.isNumeric('\u{277f}'));
    try expect(!pd.isNumeric('3')); // 3 is not numeric!
    try expect(pd.isDigit('\u{2070}'));
    try expect(!pd.isDigit('3')); // 3 is not a digit!
    try expect(pd.isDecimal('3')); // 3 is a decimal digit
}
```

## Letter Case Detection and Conversion
To detect and convert to and from different letter cases, use the `CaseData`
module.

In your `build.zig`:

```zig
exe.root_module.addImport("CaseData", zg.module("CaseData"));
```

In your code:

```zig
const CaseData = @import("CaseData");

test "Case" {
    const cd = try CaseData.init(allocator);
    defer cd.deinit();

    // Upper and lower case.
    try expect(cd.isUpper('A'));
    try expect('A' == cd.toUpper('a'));
    try expect(cd.isLower('a'));
    try expect('a' == cd.toLower('A'));

    // Code points that have case.
    try expect(cd.isCased('É'));
    try expect(!cd.isCased('3'));

    // Case detection and conversion for strings.
    try expect(cd.isUpperStr("HELLO 123!"));
    const ucased = try cd.toUpperStr(allocator, "hello 123");
    defer allocator.free(ucased);
    try expectEqualStrings("HELLO 123", ucased);

    try expect(cd.isLowerStr("hello 123!"));
    const lcased = try cd.toLowerStr(allocator, "HELLO 123");
    defer allocator.free(lcased);
    try expectEqualStrings("hello 123", lcased);
}
```

## Normalization
Unicode normalization is the process of converting a string into a uniform 
representation that can guarantee a known structure by following a strict set
of rules. There are four normalization forms:

Canonical Composition (NFC)
: The most compact representation obtained by first
decomposing to Canonical Decomposition and then composing to NFC.

Compatibility Composition (NFKC)
: The most comprehensive composition obtained
by first decomposing to Compatibility Decomposition and then composing to NFKC.

Canonical Decomposition (NFD)
: Only code points with canonical decompositions
are decomposed. This is a more compact and faster decomposition but will not 
provide the most comprehensive normalization possible.

Compatibility Decomposition (NFKD)
: The most comprehensive decomposition method
where both canonical and compatibility decompositions are performed recursively.

zg has methods to produce all four normalization forms in the `Normalize` module. 

In your `build.zig`:

```zig
exe.root_module.addImport("Normalize", zg.module("Normalize"));
```

In your code:

```zig
const Normalize = @import("Normalize");

test "Normalization" {
    // We need lots of Unicode dta for normalization.
    var norm_data = try Normalize.NormData.init(allocator);
    defer norm_data.deinit();

    // The `Normalize` structure takes a pointer to the data.
    const n = Normalize{ .norm_data = &norm_data };

    // NFC: Canonical composition
    const nfc_result = try n.nfc(allocator, "Complex char: \u{3D2}\u{301}");
    defer nfc_result.deinit();
    try expectEqualStrings("Complex char: \u{3D3}", nfc_result.slice);

    // NFKC: Compatibility composition
    const nfkc_result = try n.nfkc(allocator, "Complex char: \u{03A5}\u{0301}");
    defer nfkc_result.deinit();
    try expectEqualStrings("Complex char: \u{038E}", nfkc_result.slice);

    // NFD: Canonical decomposition
    const nfd_result = try n.nfd(allocator, "Héllo World! \u{3d3}");
    defer nfd_result.deinit();
    try expectEqualStrings("He\u{301}llo World! \u{3d2}\u{301}", nfd_result.slice);

    // NFKD: Compatibility decomposition
    const nfkd_result = try n.nfkd(allocator, "Héllo World! \u{3d3}");
    defer nfkd_result.deinit();
    try expectEqualStrings("He\u{301}llo World! \u{3a5}\u{301}", nfkd_result.slice);

    // Test for equality of two strings after normalizing to NFC.
    try expect(try n.eql(allocator, "foé", "foe\u{0301}"));
    try expect(try n.eql(allocator, "foϓ", "fo\u{03D2}\u{0301}"));
}
```

## Caseless Matching via Case Folding
Unicode provides a more efficient way of comparing strings while ignoring letter
case differences: case folding. When you case fold a string, it's converted into a
normalized case form suitable for efficient matching. Use the `CaseFold` module
for this.

In your `build.zig`:

```zig
exe.root_module.addImport("Normalize", zg.module("Normalize"));
exe.root_module.addImport("CaseFold", zg.module("CaseFold"));
```

In your code:

```zig
const Normalize = @import("Normalize");
const CaseFold = @import("CaseFold");

test "Caseless matching" {
    // We need to normalize during the matching process.
    var norm_data = try Normalize.NormData.init(allocator);
    defer norm_data.deinit();
    const n = Normalize{ .norm_data = &norm_data };

    // We need Unicode case fold data.
    const cfd = try CaseFold.FoldData.init(allocator);
    defer cfd.deinit();

    // The `CaseFold` structure takes a pointer to the data.
    const cf = CaseFold{ .fold_data = &cfd };

    // `compatCaselessMatch` provides the deepest level of caseless
    // matching because it decomposes fully to NFKD.
    const a = "Héllo World! \u{3d3}";
    const b = "He\u{301}llo World! \u{3a5}\u{301}";
    try expect(try cf.compatCaselessMatch(allocator, &n, a, b));

    const c = "He\u{301}llo World! \u{3d2}\u{301}";
    try expect(try cf.compatCaselessMatch(allocator, &n, a, c));

    // `canonCaselessMatch` isn't as comprehensive as `compatCaselessMatch`
    // because it only decomposes to NFD. Naturally, it's faster because of this.
    try expect(!try cf.canonCaselessMatch(allocator, &n, a, b));
    try expect(try cf.canonCaselessMatch(allocator, &n, a, c));
}
```

## Display Width of Characters and Strings
When displaying text with a fixed-width font on a terminal screen, it's very
important to know exactly how many columns or cells each character should take.
Most characters will use one column, but there are many, like emoji and East-
Asian ideographs that need more space. The `DisplayWidth` module provides 
methods for this purpose. It also has methods that use the display width calculation
to `center`, `padLeft`, `padRight`, and `wrap` text.

In your `build.zig`:

```zig
exe.root_module.addImport("DisplayWidth", zg.module("DisplayWidth"));
```

In your code:

```zig
const DisplayWidth = @import("DisplayWidth");

test "Display width" {
    // We need Unicode data for display width calculation.
    const dwd = try DisplayWidth.DisplayWidthData.init(allocator);
    defer dwd.deinit();

    // The `DisplayWidth` structure takes a pointer to the data.
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
```

## Scripts
Unicode categorizes code points by the Script in which they belong. A Script 
collects letters and other symbols that belong to a particular writing system.
You can detect the Script for a code point with the `ScriptsData` module.

In your `build.zig`:

```zig
exe.root_module.addImport("ScriptsData", zg.module("ScriptsData"));
```

In your code:

```zig
const ScriptsData = @import("ScriptsData");

test "Scripts" {
    const sd = try ScriptsData.init(allocator);
    defer sd.deinit();

    // To see the full list of Scripts, look at the
    // `src/ScriptsData.zig` file. They are list in an enum.
    try expect(sd.script('A') == .Latin);
    try expect(sd.script('Ω') == .Greek);
    try expect(sd.script('צ') == .Hebrew);
}
```

## Relation to Ziglyph
zg is a total re-write of some of the components of Ziglyph. The idea was to
reduce binary size and improve performance. These goals were achieved by using
trie-like data structures instead of generated functions. Where Ziglyph uses a 
function call, zg uses an array lookup, which is quite faster. In addition, all
these data structures in zg are loaded at runtime from compressed versions in the
binary. This allows for smaller binary sizes at the expense of increased memory 
footprint at runtime.

Benchmarks demonstrate the above stated goals have been met:

```plain
Binary sizes =======

149K ziglyph_case
87K zg_case

275K ziglyph_caseless
168K zg_caseless

68K ziglyph_codepoint
68K zg_codepoint

101K ziglyph_grapheme
86K zg_grapheme

185K ziglyph_normalizer
152K zg_normalize

101K ziglyph_width
86K zg_width

Benchmarks ==========

Ziglyph toUpperStr/toLowerStr: result: 7911596, took: 80
Ziglyph isUpperStr/isLowerStr: result: 110959, took: 17
zg toUpperStr/toLowerStr: result: 7911596, took: 62
zg isUpperStr/isLowerStr: result: 110959, took: 7

Ziglyph Normalizer.eqlCaseless: result: 625, took: 500
zg CaseFold.canonCaselessMatch: result: 625, took: 385
zg CaseFold.compatCaselessMatch: result: 625, took: 593

Ziglyph CodePointIterator: result: 3769314, took: 2
zg CodePointIterator: result: 3769314, took: 3

Ziglyph GraphemeIterator: result: 3691806, took: 48
zg GraphemeIterator: result: 3691806, took: 16

Ziglyph Normalizer.nfkc: result: 3934162, took: 416
zg Normalize.nfkc: result: 3934162, took: 182

Ziglyph Normalizer.nfc: result: 3955798, took: 57
zg Normalize.nfc: result: 3955798, took: 28

Ziglyph Normalizer.nfkd: result: 4006398, took: 172
zg Normalize.nfkd: result: 4006398, took: 104

Ziglyph Normalizer.nfd: result: 4028034, took: 169
zg Normalize.nfd: result: 4028034, took: 104

Ziglyph Normalizer.eql: result: 625, took: 337
Zg Normalize.eql: result: 625, took: 53

Ziglyph display_width.strWidth: result: 3700914, took: 71
zg DisplayWidth.strWidth: result: 3700914, took: 24
```

These results were obtained on an M1 Mac with 16 GiB of RAM.

In contrast to Ziglyph, zg does not have:

- Word segmentation
- Sentence segmentation
- Collation

It's possible that any missing functionality will be added in future versions,
but only if enough demand is present in the community.

