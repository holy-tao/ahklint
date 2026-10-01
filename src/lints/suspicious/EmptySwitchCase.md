A switch `case` or `default` clause contained no statements. AutoHotkey switch statement cases don't fall through,
so a value that matches this case will do nothing. This likely indicates a mistake.

## Examples

### Correct

To have a case match more than one value, separate the values with commas:

```autohotkey test
switch name {
    case "Bob", "Alice":
        DoSomething(true)
    case "Jane":
        DoSomething(false)
    default:
        throw ValueError("Unrecognized name: " name)
}
```

### Incorrect

```autohotkey test
switch name {
    case "Alice": ;~ empty-switch-case
    case "Bob":
        DoSomething(true)
    case "Jane":
        DoSomething(false)
    default:
        throw ValueError("Unrecognized name: " name)
}
```

```autohotkey test
switch name {
    case "Alice", "Bob":
        DoSomething(true)
    case "Jane":
        DoSomething(false)
    default: ;~ empty-switch-case
        ; Empty default case
}
```
