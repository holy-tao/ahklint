When invoking [`CallbackCreate`] and *not* receiving parameters by address, `ParamSpec`, its third argument, must use
the array or enumerable form. This allows the interpreter to automatically convert incoming values into typed structs,
which improves performance and type safety and communicates intent clearly to readers of your code.

[`CallbackCreate`]: https://www.autohotkey.com/docs/alpha/lib/CallbackCreate.htm

## Examples

### Correct

`ParamSpec` should be an array or enumerable value:

```autohotkey test
#Requires AutoHotkey v2.1-alpha.24+

callback := CallbackCreate(EnumWindowsProc, "Fast", [IntPtr, IntPtr, UInt32])
callback := CallbackCreate(MyCallback, "Fast", GetParamSpec(MyCallback))
```

If [receiving parameters by address](https://www.autohotkey.com/docs/alpha/lib/CallbackCreate.htm#Indirect), this rule
does not apply. However, the interpreter enforces that `ParamSpec` is a non-negative Integer.

```autohotkey test
#Requires AutoHotkey v2.0

callback := CallbackCreate(MyCallback, "&F", 4)
```

### Incorrect

In v2.0, `ParamSpec` could only be a number. This old style is an error:

```autohotkey test
#Requires AutoHotkey v2.0

callback := CallbackCreate(EnumWindowsProc, "Fast", 3) ;~ use-typed-callbacks
```

It is also an error to omit `ParamSpec` or `options` entirely:

```autohotkey test
#Requires AutoHotkey v2.0

callback := CallbackCreate(EnumWindowsProc, "Fast") ;~ use-typed-callbacks
callback := CallbackCreate(EnumWindowsProc) ;~ use-typed-callbacks
```
