
Require that your project uses implicit or explicit [concatenation][concat].

Note that explicit concatenation is required when the expression spans more than one line due to AutoHotkey's
[line continuation rules].

[concat]: https://www.autohotkey.com/docs/alpha/Variables.htm#concat
[line continuation rules]: https://www.autohotkey.com/docs/alpha/Scripts.htm#continuation

## Examples

### Incorrect

```autohotkey test { "style": "explicit" }
MsgBox("Hello, " name "!") ;~ concat-style 2
```

```autohotkey test { "style": "implicit" }
MsgBox("Hello, " . name . "!") ;~ concat-style 2
```

Inside parentheses, brackets, or braces, lines continue by [enclosure][line continuation rules], so the operator
is not needed at a line break.

```autohotkey test { "style": "implicit" }
MsgBox("first line" ;~ concat-style
    . "second line")
```

If the right operand starts with an operator, the lint reports the concatenation but does not fix it, because
removing the `.` would change the meaning. For example, `"n" -1` is a subtraction.

```autohotkey test { "style": "implicit" }
result := "n" . -1 ;~ concat-style
```

Implicit concatenation can be hard to scan if neither operand is a string literal. You can require explicit
concatenation in this case with the `requireExplicitForNonLiteral` option.

```autohotkey test { "style": "implicit", "requireExplicitForNonLiteral": true }
fullName := GetFirstName() GetLastName() ;~ concat-style
```

### Correct

```autohotkey test { "style": "implicit" }
MsgBox("Hello, " name "!")
```

```autohotkey test { "style": "explicit" }
MsgBox("Hello, " . name . "!")
```

Explicit concatenation is allowed even if `style` is `implicit` if it is required for operator
[continuation][line continuation rules].

```autohotkey test { "style": "implicit" }
greeting := "Hello, " 
    . name "!"
```

```autohotkey test { "style": "implicit", "requireExplicitForNonLiteral": true }
fullName := GetFirstName() . GetLastName()
```

```autohotkey test { "style": "implicit" }
fullName := GetFirstName() GetLastName()
```

The option looks at the operands next to each operator, so a literal between two variables satisfies it.

```autohotkey test { "style": "implicit", "requireExplicitForNonLiteral": true }
label := first " " last
```
