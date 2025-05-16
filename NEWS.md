# News

## zg v0.14.0 Release Notes

This is the first minor point release since Sam Atman (me) took over
maintenance of `zg` from the inimitable José Colon Rodriguez, aka
@dude_the_builder.  We're all grateful for everything he's done for
the Zig community.

The changes are fairly large, and most user code will need to be updated.
The result is substantially streamlined and easier to use, and updating
will mainly take place around importing, creating, and deinitializing.

### The Great Renaming

The most obvious change is on the surface API: more than half of the
modules have been renamed.  There are no user-facing modules with `Data`
in the name, and some abbreviations have been spelled in full.

### No More Separation of Data and Functionality

It is no longer necessary to separately create, for example, a
`GraphemeData` structure, in order to use the functionality provided
by the `grapheme` module.

Instead there's just `Graphemes`, and the same for a couple of other
modules which worked the same way.  This means that the cases where
functionality was provided by a wrapped pointer are now provided
directly from the struct with the necessary data.

This would make user structs larger in some cases, while eliminating a
pointer chase.  If that isn't a desirable trade off for your code,
read on.

### All Allocated Data is Unmanaged

Prior to `v0.14`, all structs which need heap allocation no longer
have a copy of their allocator.  We felt that this was redundant,
especially when several such structures were in use, and it reflects
a general trend in the standard library toward fewer managed data
structures.

Getting up to speed is a matter of passing the allocator to `deinit`.

This change comes courtesy of [lch361](https://lch361.net), in his
first contribution to the repo.  Thanks Lich!

### `code_point` Now Unicode-Compliant

The `v0.15.x` decoder used a simple, fast, but naïve method to decode
UTF-8 into codepoints.  Concerningly, this interpreted overlong
sequences, which has been forbidden by Unicode for more than 20 years
due to the security risks involved.

This has been replaced with a DFA decoder based on the work of
[Björn Höhrmann][UTF], which has proven itself fast[^1] and reliable.
This is a breaking change; sequences such as `"\xc0\xaf"` will no longer
produce the code `'/'`, nor will surrogates return their codepoint
value.

The new decoder faithfully implements §3.9.6 of the Unicode Standard,
_U+FFFD Substitution of Maximal Subparts_.  While this is itself not
required to claim Unicode conformance, it is the W3C specification for
replacement behavior.

Along with this, `code_point.decode` is deprecated, and will be removed
in a later version of `zg`.  It was basically an exposed piece of the
`Iterator` implementation, and is no longer used in that capacity.

Instead, prefer `decodeAtIndex([]const u8, u32) ?CodePoint`, or better
yet, `decodeAtCursor([]const u8, *u32)`.  The latter advances its
second argument to the next possible index for a valid codepoint, which
is good for the fetch pipeline, and more ergonomic in many cases.

[UTF]: https://bjoern.hoehrmann.de/utf-8/decoder/dfa/

[^1]: A bit more than twice as fast as the standard library for
decoding, according to my (limited) benchmarks.

### DisplayWidth and CaseFolding Can Share Data

Both of these modules use another module to get the job done,
`Graphemes` for `DisplayWidth`, and `Normalize` for `CaseFolding`.

It is now possible to initialize them with a borrowed copy of those
modules, to make it simpler to write code which also needs the base
modules.

### Grapheme Iterator Creation

This is a modest streamlining of how a grapheme iterator is created.

Before:

```zig
const gd = try grapheme.GraphemeData.init(allocator);
defer gd.deinit();
var iter = grapheme.Iterator.init("🤘🏻some rad string! 🤘🏿", &gd);
```

Now:

```zig
const graphemes = try Graphemes.init(allocator);
defer graphemes.deinit(allocator);
var iter = graphemes.iterator("🤘🏻some rad string! 🤘🏿");
```

It remains possible to use

```zig
var iter = Graphemes.Iterator.init("stri̵̢̡̡̡̨̧̡̨̡̡̡̨̫̗̗̱̳̼̖͚͉̩̬̬͚̟̣̮̬̙̖̗͇̮͓̻̫͍͎͉͎̹̩̗͖͈̙̻̭̝̭̼̙̯̪͚̙͉͎͎͖̥̹͈̫͍̹͓̘̙͎͖̝̦͎̤̼̹͕͈̪̙̪̯̯͙̝͈͕̬̪̗̭͎͖̟͚̦̣̘͙̞̮̹̙͚̼̤̟͉̭͔̩͍͔͈̯͎̘͎̭̥̖̜͙̖̖͍̼͙͎͚̦̮̹̞̺͍̳̖̹̼̲̠̩̰̳͂̌̈́̓̄͋̇̎͜͜͠ͅͅͅͅng", &graphemes);
```

If one were to prefer doing so.

### Initialization vs. Setup

Every allocating module now has both an `init` function, which
returns the created struct, and a `setup` function.  The latter
takes a mutable pointer, and an `Allocator`, returning
`Allocator.Error!void`.

So those who might prefer a single-pointer home for such modules
can allocate the struct on the heap with `allocator.create`, or
add a pointer field to some other struct, then use `setup` to
populate it.

In the process, the various spurious reader and decompression errors
have been turned `unreachable`, leaving only `error.OutOfMemory`.
Encountering any of the other errors would indicate an internal problem,
so we no longer make user code deal with that unlikely event.

### New DisplayWidth options

A `DisplayWidth` can now be compiled to treat `c0` and `c1` control codes
as having a width.  Canonically, terminals don't print them, so they
would have a width of 0.  However, some applications (`vim` for example)
need to escape control codes to make them visible.  Setting these
options will let `DisplayWidth` return the correct widths when this
is done.

### Unicode 16.0

This updates `zg` to use the latest Unicode edition.  This should be
the only change which will change behavior of user code, other than
through the use of the new `DisplayWidth` options.

### Tests

It is now possible to run all the tests, not just the `unicode-test`
subset. Accordingly, that step is removed, and `zig build test`
runs everything.

#### Allocations Tested

Every allocate-able now has a `checkAllAllocationFailures` test.  This
process turned up two bugs.  Also discovered were 8,663 allocations,
which were reduced to two, these were also being individually freed
on deinit.  So that's nice.

#### That's It!

I hope you find converting over `zg v0.13` code to be fairly painless
and straightforward.  There should be no need to make changes of this
magnitude in the future.

