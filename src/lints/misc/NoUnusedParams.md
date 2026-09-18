
Function parameters should be used, or explicitly marked as unused if they must be present.

## Examples

### Correct

```autohotkey test
#Requires AutoHotkey v2.0

MyFunction(param) {
    MsgBox(param.prop)
}
```

If a parameter is intentionally unused (if, for example, it exists to conform to an interface), use `_` or prefix it
with an underscore:

```autohotkey test
#Requires AutoHotkey v2.0

MyFunction(param, _) {
    MsgBox(param.prop)
}

MyFunction(param, _unused, &_out := 0) {
    MsgBox(param.prop)
}

```

In AHK [v2.1-alpha.3] and later, this rule also applies to [function definition expressions]:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.3

MyFunc := (param) {
    MsgBox(param.prop)
}

MyFunc := (_) {
    MsgBox("Function definition example!")
}
```

### Incorrect

```autohotkey test
#Requires AutoHotkey v2.0

MyFunction(param) { ;~ no-unused-params
    ; Doesn't use param
}
```

The rule also applies to methods:

```autohotkey test
#Requires AutoHotkey v2.0

class Example {
    static Method(unused) { ;~ no-unused-params

    }
}
```

And [fat-arrow functions](https://www.autohotkey.com/docs/alpha/Variables.htm#fat-arrow):

```autohotkey test
#Requires AutoHotkey v2.0

class Example {
    static Method(unused) => "example" ;~ no-unused-params
}
```

And [function definition expressions] statements in AHK [v2.1-alpha.3] and later.

```autohotkey test
#Requires AutoHotkey v2.1-alpha.3

funcRef := Function(unused) { ;~ no-unused-params

}

funcRef := (unused) { ;~ no-unused-params

}
```

[v2.1-alpha.3]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.3
[function definition expressions]: https://www.autohotkey.com/docs/alpha/Functions.htm#funcexpr
