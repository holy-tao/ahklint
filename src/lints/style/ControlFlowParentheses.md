
Parentheses in [control flow] statements are optional in AutoHotkey. This lint allows you to require or for bid their
use and provides an autofix for violations.

This doesn't affect the functionality of your script, but can make it more or less readable and may be preferable
depending on which language(s) you use most often.

[control flow]: https://www.autohotkey.com/docs/alpha/Language.htm#control-flow

## Examples

### Incorrect

```autohotkey test { "style": "required" }
while true { ;~ control-flow-parentheses
    ; Do stuff...
}
```

```autohotkey test { "style": "required" }
for item in arr { ;~ control-flow-parentheses
    ; Do stuff...
}
```

```autohotkey test { "style": "forbidden" }
if (2 + 2 == 5) { ;~ control-flow-parentheses
    ; Do stuff...
}
```

```autohotkey test { "style": "forbidden" }
for (key, value in dict) { ;~ control-flow-parentheses
    ; Do stuff...
}
```

```autohotkey test { "style": "forbidden" }
try {
    FileOpen("might/not/exist.txt")
    ; <...>
} catch (Error as err) { ;~ control-flow-parentheses
    ; <...>
}
```

### Correct

```autohotkey test { "style": "forbidden" }
while condition == true {
    ; do stuff...
}
```

```autohotkey test { "style": "required" }
for (i, item in arr) {
    ; do stuff...
}
```

```autohotkey test { "style": "required" }
if(condition) {
    ; do stuff...
}
```

```autohotkey test { "style": "forbidden" }
try {
    Fallible()
} catch Error as err {
    ; do stuff...
}
```

```autohotkey test { "style": "forbidden" }
try {
    Fallible()
} catch {
    ; ignore errors
}
```
