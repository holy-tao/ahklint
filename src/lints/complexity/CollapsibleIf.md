Checks for nested `if` statements which can be collapsed by `&&`-combining their conditions. Each `if` statement
adds a level of nesting, which can make your code look more complex than it really is.

## Examples

### Incorrect

```autohotkey test
if x { ;~ collapsible-if
    if y {
        ; ...
    }
}

if x ;~ collapsible-if
    if y
        DoSomething()
```

```autohotkey test
if x {
    ; ...
}
else if y { ;~ collapsible-if
    if z {
        ; ...
    }
}
```

By default, the lint allows collapsible if statements if the outer if statement's block contains
comments. Set `allowComments` to false, to disable this.

```autohotkey test { "allowComments": false }
if x { ;~ collapsible-if
    ; Some explanation
    if y {
        ; ...
    }
}
```

### Correct

```autohotkey test
if x && y {
    ; ...
}
```

```autohotkey test { "allowComments": true }
if x {
    ; Some comment
    if y {

    }
}
```
