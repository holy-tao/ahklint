Reports [regular expressions][regex] that don't compile. These are always runtime errors.

This lint only checks strings that it can prove are used as patterns:

- The pattern argument of [`RegExMatch`][RegExMatch] and [`RegExReplace`][RegExReplace]
- The right-hand sides of the `~=` and `!~=` opperators

[regex]: https://www.autohotkey.com/docs/v2/misc/RegEx-QuickRef.htm
[RegExMatch]: https://www.autohotkey.com/docs/v2/lib/RegExMatch.htm
[RegExReplace]: https://www.autohotkey.com/docs/v2/lib/RegExReplace.htm

## Examples

### Incorrect

A pattern written where it is used:

```autohotkey test
if RegExMatch(line, "i)^(\w+") ;~ invalid-regex
    MsgBox("Matched")

isHex := value ~= "^[0-9a-f+$" ;~ invalid-regex
path := RegExReplace(path, "C:\Users\", "~\") ;~ invalid-regex
```

A pattern stored in a variable. Every string assigned to the variable is checked:

```autohotkey test
ParseVersion(text) {
    static PATTERN := "^v(?<major>\d+)\.(?<minor>\d+" ;~ invalid-regex
    return RegExMatch(text, PATTERN, &version) ? version : ""
}

FindNumber(text, hex) {
    pattern := "\d+)" ;~ invalid-regex
    if hex
        pattern := "0x[[:xdigit:]]+"
    return RegExMatch(text, pattern)
}
```

Global variables, including ones only read by the function that uses them:

```autohotkey test
DATE_PATTERN := "(\d{4})-(\d{2}-(\d{2})" ;~ invalid-regex 1

IsDate(text) => text ~= DATE_PATTERN
```

```autohotkey test
DATE_PATTERN := "(\d{4})-(\d{2}-(\d{2})" ;~ invalid-regex 1

IsDate(text) => text !~= DATE_PATTERN
```

Constant concatenations are resolved:

```autohotkey test
DIGITS := "(\d+"
VERSION := "^" DIGITS "\." DIGITS "$" ;~ invalid-regex

RegExMatch(A_AhkVersion, VERSION)
```

Continuation sections are handled as well, as long as they do not contain any options.

```autohotkey test
KEY_VALUE := " ;~ invalid-regex
(
    x)
    (\w+)   # key
    \s*=\s*
    (.*     # value
)"

RegExMatch(line, KEY_VALUE, &pair)
```

### Correct

```autohotkey test
static EMAIL := "i)^[\w.+-]+@[\w-]+\.[a-z]+$"
if RegExMatch(address, EMAIL)
    MsgBox("Looks like an email address")
```

Strings that aren't used as a pattern aren't checked:

```autohotkey test
MsgBox("Unbalanced (parentheses")
files := "*.ahk"
home := "C:\Users\" A_UserName
```

Neither is anything that can't be known in full. A piece of a pattern doesn't have to compile by itself, so a variable
is skipped if it is a parameter, is appended to, is passed by reference, or is assigned anything that isn't a
constant string:

```autohotkey test
AnyOf(text, words*) {
    pattern := "("
    for word in words
        pattern .= (A_Index > 1 ? "|" : "") word
    pattern .= ")"
    return RegExMatch(text, pattern)
}

Wrap(text, inner) {
    open := "("
    return RegExMatch(text, open inner ")")
}

Matches(text, pattern := "(") => text ~= pattern
```

A nested function assigning to a variable of its outer function counts as an assignment to that variable:

```autohotkey test
Search(text) {
    pattern := "("
    Finish() {
        pattern := pattern "\d+)"
    }
    Finish()
    return RegExMatch(text, pattern)
}
```

## Limitations

- A variable is treated as one thing for the whole file. If the same variable holds a pattern in one place and an
  unrelated string in another, the unrelated string is checked too.
- Assignments in other files aren't seen. A global variable is judged by the assignments in the file being linted.
- Patterns containing a [callout][callouts] (`(?C...)`) are skipped.
- Continuation sections with options, such as `(Join|`, are skipped.

[callouts]: https://www.autohotkey.com/docs/v2/misc/RegExCallout.htm
