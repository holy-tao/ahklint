Checks for comparisons that always evaluate the same way, however the program runs. A comparison like that is
almost always a mistake.

## Examples

### Incorrect

A case-sensitive comparison between a normalized string and a value it can never produce. [`StrLower`][StrLower]
never returns uppercase letters, so this is never true:

```autohotkey test
if StrLower(name) == "Bob" { ;~ constant-comparison
    ; never runs
}
```

```autohotkey test
if StrUpper(input) !== StrLower(expected) { ;~ constant-comparison
    ; runs whenever either string contains a letter
}
```

The same applies to the labels of a case-sensitive `switch`:

```autohotkey test
switch StrLower(name) {
    case "bob": ; do stuff...
    case "Alice": ;~ constant-comparison
        ; never runs
}
```

Comparing a variable with itself:

```autohotkey test
if count == count { ;~ constant-comparison
    ; always runs
}
```

Comparing something that is never negative with a negative number, or checking that it is below zero.
[`InStr`][InStr] and [`RegExMatch`][RegExMatch] return 0 rather than -1 when there's no match:

```autohotkey test
if InStr(haystack, "needle") == -1 { ;~ constant-comparison
    ; never runs
}
```

```autohotkey test
if StrLen(name) < 0 { ;~ constant-comparison
    ; never runs
}
```

```autohotkey test
if arr.Length >= 0 { ;~ constant-comparison
    ; always runs
}
```

```autohotkey test
if arr.Length < 0.0 { ;~ constant-comparison
    ; never runs
}
```

Comparing two constants:

```autohotkey test
if "a" == "a" { ;~ constant-comparison
    ; always runs
}
```

```autohotkey test
if 2 == 3 { ;~ constant-comparison
    ; never runs
}
```

Relational operators only compare numbers, so comparing constant strings with them always throws a `TypeError`:

```autohotkey test
if "apple" < "banana" { ;~ constant-comparison
    ; never runs
}
```

### Correct

```autohotkey test
if name = "Bob" {
    ; do stuff...
}
```

```autohotkey test
switch name, "Off" {
    case "bob": ; do stuff...
    case "Alice": ; do stuff...
}
```

```autohotkey test
if !InStr(haystack, "needle") {
    ; do stuff...
}
```

```autohotkey test
if arr.Length > 0 {
    ; do stuff...
}
```

`StrTitle` and `StrUpper` agree on strings whose words are all one letter long, so comparing them isn't reported:

```autohotkey test
if StrTitle(a) == StrUpper(b) {
    ; do stuff...
}
```

## Known Issues

`.Length` and `.Count` are assumed to be the built-in, never-negative properties of `Array`, `Map`, and similar. A
class that defines its own `Length` or `Count` returning a negative number will be reported incorrectly.

Only variables are checked for self-comparison. Properties and function calls are skipped, since a getter can
return a different value each time it's called. This lint is not a full expression evaluator; complex expressions
may not be caught.

[StrLower]: https://www.autohotkey.com/docs/alpha/lib/StrLower.htm
[InStr]: https://www.autohotkey.com/docs/alpha/lib/InStr.htm
[RegExMatch]: https://www.autohotkey.com/docs/alpha/lib/RegExMatch.htm
