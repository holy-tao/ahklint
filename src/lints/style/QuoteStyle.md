
AutoHotkey v2 [strings] can be quoted with either double quotes (`"`) or single quotes (`'`); the two are equivalent.
Mixing them in one codebase is harmless but noisy. This lint enforces one style, configured with the `style` option.

By default, a string may use the other quote character if it contains the preferred one, since switching would mean
escaping it. Set `avoidEscape` to `false` to enforce the style everywhere.

[strings]: https://www.autohotkey.com/docs/v2/Language.htm#strings

## Examples

### Correct

``` autohotkey test
MsgBox("Hello, World!")
MsgBox('Say "hello"')
```

`avoidEscape` allows you to use the other quoting style if it would avoid the need to escape a character. The
following two examples are legal in single-quote mode. Note how `It's a string` is allowed to be double-quoted,
because the `'` in `it's` would otherwise need to be escaped.

``` autohotkey test {"style": "single"}
MsgBox('Hello, World!')
MsgBox("It's a string")
```

Escaped quotes don't count - switching quote style wouldn't add an escape:

``` autohotkey test
MsgBox("Say `"hello`"")
```

This lint also applies to [continuation sections]. Note that quotes never need to be escaped string continuation
sections, so `avoidEscape` has no effect on these.

[continuation sections]: https://www.autohotkey.com/docs/alpha/Scripts.htm#continuation-section

``` autohotkey test
Var := "
(
A line of text.
By default, the hard carriage return (Enter) between the previous line and this one will be stored.
    This line is indented with a tab; by default, that tab will also be stored.
Additionally, "quote marks" are automatically escaped when appropriate.
)"
```

### Incorrect

``` autohotkey test
MsgBox('Hello, World!')     ;~ quote-style
MsgBox('Say `'hello`'')     ;~ quote-style
```

``` autohotkey test {"style": "single"}
MsgBox("Hello, World!")     ;~ quote-style
```

``` autohotkey test {"avoidEscape": false}
MsgBox('Say "hello"')       ;~ quote-style
```

``` autohotkey test {"style": "single"}
Var := " ;~ quote-style
(
This section uses the "wrong quote style".
)"
```
