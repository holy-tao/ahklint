Local and static variables should be read after they are assigned. A variable that is assigned but never read, or
declared and never used at all, is usually left over from a refactor or a sign of a typo elsewhere.

The rule follows AutoHotkey's scoping rules rather than just counting names: a name assigned in an [assume-global]
function is a global, a nested function shares the variables its outer function assigns, and a `static` nested function
doesn't. Updating a variable in place (`count++`, `count += 1`, `count := count + 1`) doesn't count as reading it.

Global variables are not checked, since another file may read them. Neither are functions that refer to variables
dynamically (`%name%`), or variables passed by reference (`&var`); the receiver of the reference could read through it.

## Examples

### Correct

```autohotkey test
#Requires AutoHotkey v2.0

Greet(name) {
    greeting := "Hello, " name
    MsgBox(greeting)
}
```

A variable that a nested function reads is used:

```autohotkey test
#Requires AutoHotkey v2.0

MakeCounter() {
    count := 0
    Increment() {
        return ++count
    }
    return Increment
}
```

In an [assume-global] function, and in functions nested inside one, assignments create globals:

```autohotkey test
#Requires AutoHotkey v2.0

SetDefaults() {
    global
    Width := 800
    Configure() {
        Height := 600
    }
    Configure()
}
```

Variables passed by reference and functions with dynamic references are not checked:

```autohotkey test
#Requires AutoHotkey v2.0

WindowWidth(hwnd) {
    WinGetPos(, , &width, &height, hwnd)
    return width
}

Lookup(name) {
    red := 0xFF0000
    return %name%
}
```

If a variable is intentionally unused, prefix it with an underscore:

```autohotkey test
#Requires AutoHotkey v2.0

CountItems(items) {
    count := 0
    for _item in items
        count++
    return count
}
```

### Incorrect

```autohotkey test
#Requires AutoHotkey v2.0

Process(items) {
    total := 0 ;~ unused-variable
    for item in items
        Handle(item)
}
```

Updating a variable doesn't read it:

```autohotkey test
#Requires AutoHotkey v2.0

Tally(items) {
    count := 0 ;~ unused-variable
    loop items.Length
        count += 1
}

Track() {
    static calls := 0 ;~ unused-variable
    calls := calls + 1
}
```

Declaring a variable without ever using it:

```autohotkey test
#Requires AutoHotkey v2.0

Example() {
    local unused ;~ unused-variable
}
```

`local` and `static` variables are still local in an [assume-global] function:

```autohotkey test
#Requires AutoHotkey v2.0

SetDefaults() {
    global
    local temp := 2 ;~ unused-variable
    Width := 800
}
```

A `static` nested function can't see its outer function's local variables, so its `x` is a different variable:

```autohotkey test
#Requires AutoHotkey v2.0

Outer() {
    x := "outer" ;~ unused-variable
    static Inner() {
        MsgBox(x)
    }
    Inner()
}
```

Loop and `catch` variables are variables too:

```autohotkey test
#Requires AutoHotkey v2.0

Load(path) {
    try
        return FileRead(path)
    catch OSError as err ;~ unused-variable
        return ""
}
```

[assume-global]: https://www.autohotkey.com/docs/v2/Functions.htm#AssumeGlobal
