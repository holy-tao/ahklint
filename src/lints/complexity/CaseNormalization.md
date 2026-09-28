Checks for expressions that use [`StrLower`][StrLower], [`StrUpper`][StrUpper], or [`StrTitle`][StrTitle] to
normalize string casing in equality or inequality comparisons and `switch` statements.

Case-insensitive string comparisons can be done more simply and more efficiently using the built-in
[case-insensitive equality operators][eq], which avoid a function call and the creation of a temporary string.

[StrLower]: https://www.autohotkey.com/docs/alpha/lib/StrLower.htm
[StrUpper]: https://www.autohotkey.com/docs/alpha/lib/StrLower.htm
[StrTitle]: https://www.autohotkey.com/docs/alpha/lib/StrLower.htm
[eq]: https://www.autohotkey.com/docs/alpha/Variables.htm#equal

## Examples

### Incorrect

```autohotkey test
if StrLower(name) == "bob" { ;~ case-normalization
    ; do stuff...
}
```

```autohotkey test
if StrUpper(name) == "ALICE" { ;~ case-normalization
    ; do stuff...
}
```

```autohotkey test
if StrUpper(input) !== StrUpper(expected) { ;~ case-normalization
    ; do stuff...
}
```

The normalization is redundant when the comparison is already case-insensitive:

```autohotkey test
if StrLower(name) = "bob" { ;~ case-normalization
    ; do stuff...
}
```

The lint can drill through concatenation, parentheses, and functions that don't change case, like `Trim` and
`SubStr`:

```autohotkey test
if Trim(StrUpper(name)) == "SMITH" { ;~ case-normalization
    ; do stuff...
}
```

```autohotkey test
if "on" StrTitle(eventName) = "onClick" { ;~ case-normalization
    ; do stuff...
}
```

In switch statements, set [CaseSense](https://www.autohotkey.com/docs/alpha/lib/Switch.htm#Parameters) to `"Off"`
instead of coercing the string value:

```autohotkey test
switch StrLower(name) { ;~ case-normalization
    case "bob": ; do stuff...
    case "alice": ; do stuff...
}
```

### Correct

```autohotkey test
if name = "bob" {
    ; do stuff...
}
```

```autohotkey test
switch name, "Off" {
    case "bob": ; do stuff...
    case "Alice": ; do stuff...
}
```

`Trim` with an *OmitChars* argument is not drilled through, since the characters it trims are case-sensitive:

```autohotkey test
if Trim(StrLower(name), "xyz") == "bob" {
    ; do stuff...
}
```

A case-sensitive comparison whose result is fixed by the normalization, like comparing a lowercased string with one
that has uppercase letters, is almost certainly a bug rather than an unneeded normalization. This lint doesn't report
it, because switching to `=` would change what the code does. [`constant-comparison`](../constant-comparison/)
reports it instead:

```autohotkey test
if StrLower(name) == "Bob" {
    ; never true
}
```

## Known Issues

The fix is a suggestion rather than automatic because `StrLower` and its siblings change the case of non-ASCII
letters, but `=` only treats the ASCII letters A-Z as equal to their lowercase counterparts.
`StrLower(a) == "é"` matches `"É"`, but `a = "é"` does not.

This lint also won't catch more complex scenarios, particularly those involving [`Format`][Format] or more complex
concatenations.

[Format]: https://www.autohotkey.com/docs/alpha/lib/Format.htm
