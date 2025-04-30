# News

## zg v0.14.0 Release Notes

This is the first minor point release since Sam Atman (me) took over
maintenance of `zg` from the inimitable José Colon, aka
@dude_the_builder.

As it's a fairly complex project, I'm adding a NEWS.md so that users
have a place to check for changes.

### Data is Unmanaged

This is the biggest change.  Prior to `v0.14`, all structs which need
heap allocation no longer have a copy of their allocator.  It was felt
that this was redundant, especially when several such structures were
in use, and it reflects a general trend in the standard library toward
fewer managed data structures.

Getting up to speed is a matter of passing the allocator to `deinit`.

This change comes courtesy of [lch361](https://lch361.net), in his
first contribution to the repo.  Thanks Lich!

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
const gd = try grapheme.GraphemeData.init(allocator);
defer gd.deinit(allocator);
var iter = gd.iterator("🤘🏻some rad string! 🤘🏿");
```

You can still make an iterator with `grapheme.Iterator.init`, but the
second argument has to be `&gd.gd`.
