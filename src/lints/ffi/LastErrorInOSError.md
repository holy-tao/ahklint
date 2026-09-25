
Passing [`A_LastError`][A_LastError] when creating an [`OSError`][OSError] is redundant. Calling it with no arguments
uses `A_LastError` by default.

> Calling `OSError(Code)` where *Code* is numeric sets *Number* and *Message* based on the given OS-defined error
> code. If Code is omitted, it defaults to A_LastError.

[A_LastError]: https://www.autohotkey.com/docs/alpha/Variables.htm#LastError
[OSError]: https://www.autohotkey.com/docs/alpha/lib/Error.htm#OSError

## Examples

### Incorrect

```autohotkey test
throw OSError(A_LastError) ;~ lasterror-in-oserror
```

### Correct

```autohotkey test
throw OSError()
```
