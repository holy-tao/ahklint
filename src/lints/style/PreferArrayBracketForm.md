Don't use the [`Array(...)`] constructor to intialize arrays - just use a literal `[...]`.

[`Array(...)`]: https://www.autohotkey.com/docs/alpha/lib/Array.htm#Call

## Examples

### Correct

```autohotkey test
primaryColors := ["Red", "Yellow", "Blue"]
```

### Incorrect

```autohotkey test
primaryColors := Array("Red", "Yellow", "Blue") ;~ prefer-array-bracket-form
```
