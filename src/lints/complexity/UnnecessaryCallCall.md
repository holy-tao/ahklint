Calling an object with `()` implicitly invokes its `Call` method (if it has one); there is no need to retrieve
the `Call` property explicitly.

## Examples

### Correct

```autohotkey test
Callable()
```

### Incorrect

```autohotkey test
Callable.Call() ;~ unnecessary-call-call
```
