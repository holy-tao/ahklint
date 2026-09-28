Return statements in a function should be consistent. That is, if any return statement returns a value, every return
statement must return a value, and vice versa.

In AutoHotkey v2.0, a blank or implicit return always returns an empty string. However, as of AutoHotkey
[v2.1-alpha.29], the implicit return value is either [unset] or [blank-unset]. This can cause unexpected errors if
callers expect the function to return a value.

[v2.1-alpha.29]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.29
[unset]: https://www.autohotkey.com/docs/alpha/Language.htm#unset
[blank-unset]: https://www.autohotkey.com/docs/alpha/v2.1-changes.htm#blank-unset

A function that returns a value on some paths can't reach its closing brace, since that is an implicit valueless
return. To make sure every path returns, end each `if` with an `else` and give each `Switch` a `Default`. Every
branch should end in a `return` or `throw`. To *intentionally* return an unset or default value, return an explicit
empty string or `unset`.

This lint assumes that function calls return normally. If a function always throws through a helper, write
`throw` explicitly at the end of the function so the end is clearly unreachable. The lint checks functions that use
`Goto` for explicit returns only.

## Examples

### Incorrect

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

MyFunction(condition) {
    if condition {
        return "something"
    } else {
        return ;~ inconsistent-returns
    }
}
```

The end of this function is reachable when `condition` is false:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

MyFunction(condition) {
    if condition {
        return "something"
    }
} ;~ inconsistent-returns
```

A `Switch` without a `Default` may not match any case:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

Describe(n) {
    switch n {
        case 1: return "one"
        case 2: return "two"
    }
} ;~ inconsistent-returns
```

If the `try` body throws, the `catch` falls through to the end of the function:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

ReadConfig(path) {
    try {
        return FileRead(path)
    } catch OSError as e {
        OutputDebug(e.Message)
    }
} ;~ inconsistent-returns
```

A labeled `break` can exit an otherwise infinite loop:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

FindFirst(items) {
    Outer:
    loop {
        for item in items {
            if item
                return item
            break Outer
        }
    }
} ;~ inconsistent-returns
```

### Correct

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

MyFunction(condition) {
    if condition {
        return "something"
    } else if !condition {
        return "else"
    } else {
        throw ValueError("unreachable")
    }
}
```

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

MyFunction(condition) {
    DoComputation(condition)
}
```

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

Describe(n) {
    switch n {
        case 1: return "one"
        case 2:
            OutputDebug("two")
            return "two"
        ; Comments between cases are fine
        default: throw ValueError("Unexpected value", , n)
    }
}
```

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

ReadConfig(path) {
    try {
        text := FileRead(path)
    } catch OSError {
        return ""
    } else {
        return text
    } finally {
        OutputDebug("done")
    }
}
```

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

WaitFor(check) {
    loop {
        if check()
            return true
        Sleep(10)
    }
}

Quit(code) {
    if code
        return code
    ExitApp(code)
}
```

Fat-arrow functions, setters, and nested functions are checked separately:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.32

class Thing {
    Value {
        get {
            return this._value
        }
        set {
            this._value := value
        }
    }

    Double() => this.Value * 2

    Callback() {
        inner() {
            return
        }
        return inner
    }
}
```

Functions that exit the script or thread entirely are allowed:

```autohotkey test
Die(message) {
    LogError(message)
    ExitApp()
}
```
