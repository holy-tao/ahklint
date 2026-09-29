Checks for malformed [`Format`][Format] placeholders, like those with unknown types, non-positive indices, and
so forth.

Malformed placeholders are copied literally into the output string and do not consume an input value.

[Format]: https://www.autohotkey.com/docs/v2/lib/Format.htm

## Example

### Incorrect

The index must be a positive integer with no sign:

```autohotkey test
Format("{0}", value) ;~ invalid-format-placeholder
Format("{-1}", value) ;~ invalid-format-placeholder
Format("{+1}", value) ;~ invalid-format-placeholder
```

A format specifier must be preceded by `:`, even when the index is given:

```autohotkey test
Format("{1d}", value) ;~ invalid-format-placeholder
```

Whitespace is only permitted as a flag:

```autohotkey test
Format("{ 1}", value) ;~ invalid-format-placeholder
Format("{:d }", value) ;~ invalid-format-placeholder
```

Unknown types, including printf-style size specifiers, which `Format` doesn't support:

```autohotkey test
Format("{:q}", value) ;~ invalid-format-placeholder
Format("{:D}", value) ;~ invalid-format-placeholder
Format("{:ld}", value) ;~ invalid-format-placeholder
Format("{:I64d}", value) ;~ invalid-format-placeholder
```

Components must appear in the order `Flags Width .Precision ULT Type`:

```autohotkey test
Format("{:5-d}", value) ;~ invalid-format-placeholder
Format("{:5.2.3f}", value) ;~ invalid-format-placeholder
Format("{:U.2s}", value) ;~ invalid-format-placeholder
```

Case transformations (`U`, `L`, `T`) only apply to strings, and only one may be given:

```autohotkey test
Format("{:Ud}", value) ;~ invalid-format-placeholder
Format("{:UL}", value) ;~ invalid-format-placeholder
```

### Correct

```autohotkey test
Format("{} {1} {01} {:} {1:}", value)
Format("{:d} {:i} {:u} {:x} {:X} {:o} {:p} {:c}", a, b, c, d, e, f, g, h)
Format("{:f} {:e} {:E} {:g} {:G} {:a} {:A}", a, b, c, d, e, f, g)
Format("{:-10} {:+d} {:010} {: d} {:#x} {:-+ #0d}", a, b, c, d, e, f)
Format("{:.2f} {:05.2f} {:.} {:5.}", a, b, c, d)
Format("{:U} {:.20Ts} {:ls} {:ts}", a, b, c, d)
Format("{{}literal braces{}}")
```
