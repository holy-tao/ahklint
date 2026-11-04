A [local variable][local] appears to be constant and can be made [`static`][static]. `static` local variables are only
assigned to once and are effectively cached for free. Making local constants `static` improves performance, especially
when they are computed using expensive functions.

[local]: https://www.autohotkey.com/docs/v2/Functions.htm#Local
[static]: https://www.autohotkey.com/docs/v2/Functions.htm#static

## Examples

### Incorrect

```autohotkey test
Example() {
    message := "This string is created on every call" ;~ local-can-be-static
    MsgBox(message)
}
```

```autohotkey test
Example() {
    FLAGS := 0x1 | 0x12 | 0x4 ;~ local-can-be-static
    ; ...
}
```

```autohotkey test
Example() {
    FLAGS := 0x1 ;~ local-can-be-static
    ; ...
}
```

```autohotkey test
Example() {
    FLAGS := (0x1)  ;~ local-can-be-static
    ; ...
}
```

Calls to built-in functions that only compute a value from their arguments, such as `Format` and `StrReplace`, are
constant when every argument is:

```autohotkey test
Example(name) {
    header := Format("{1:-20}|{2:10}", "Name", "Score") ;~ local-can-be-static
    MsgBox(header "`n" name)
}
```

```autohotkey test
Example() {
    local sep := StrReplace("a-b", "-", "|") ;~ local-can-be-static
    MsgBox(sep)
}
```

### Correct

A call is not constant if an argument isn't, or if the function returns a new object that the caller could change:

```autohotkey test
Example(name) {
    greeting := Format("Hello, {1}", name)
    parts := StrSplit("a,b,c", ",")
    parts.Push(greeting)
}
```

A function the script defines itself may do anything, even if it shares a built-in's name:

```autohotkey test
Example() {
    label := Format("{1}", "x")
    MsgBox(label)
}

Format(fmt, args*) {
    static calls := 0
    return fmt (++calls)
}
```

A variable assigned in a branch, loop or short-circuit may be unset afterwards, which `static` would change:

```autohotkey test
Example(verbose) {
    if verbose
        prefix := "[debug] "
    verbose && suffix := "!"
    MsgBox(IsSet(prefix) ? prefix : "")
}
```

A dynamic reference can read or assign any variable in the function:

```autohotkey test
Example(which) {
    red := "#FF0000"
    MsgBox(%which%)
}
```

```autohotkey test
Example() {
    static message := "This string is cached"
    MsgBox(message)
}
```
