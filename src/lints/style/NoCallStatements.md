
[Call statements] may confuse programmers not familiar with AutoHotkey and can hurt readability, especially when they
have no arguments. Use normal function calls instead.

[call statements]: "https://www.autohotkey.com/docs/alpha/Language.htm#function-call-statements"

## Examples

### Correct

```autohotkey test
MsgBox("Hello, World!", "My First Script")
```

### Incorrect

```autohotkey test
MsgBox "Hello, World!", "My First Script" ;~ no-call-statements
```
