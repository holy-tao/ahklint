Don't call `ToString` on an object directly. If you need to convert something to a String, call [`String`][String]
instead. The builtin will correctly handle primitives, which `.ToString()` will not.

[String]: https://www.autohotkey.com/docs/v2/lib/String.htm

## Examples

### Incorrect

```autohotkey test
repr := obj.ToString() ;~ direct-tostring-call
```

### Correct

```autohotkey test
repr := String(obj)
```

Calling `ToString` with arguments is allowed

```autohotkey test
repr := obj.ToString("ASCII")
```
