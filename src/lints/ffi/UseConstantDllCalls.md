
Prefer using string literals to identify [`DllCall`] targets. If `DllCall`'s first parameter is a string literal and
the DLL containing the function is [standard] or loaded via [`#DllLoad`], the rutime resolves it to its address at
load time.

If the first parameter is *not* constant, invoking the `DllCall` may result in the dll being loaded and then immediately
unloaded repeatedly, causing significant performance slowdowns.

> [!IMPORTANT]
> Invoking `DllCall` with a pointer does not have the same performance considerations, but the linter cannot
> know what the value of a variable is statically, so will still warn in these cases.

[`DllCall`]: https://www.autohotkey.com/docs/v2/lib/DllCall.htm
[standard]: https://www.autohotkey.com/docs/v2/lib/DllCall.htm#std
[`#DllLoad`]: https://www.autohotkey.com/docs/v2/lib/_DllLoad.htm

## Examples

## Correct

```autohotkey test
#Requires AutoHotkey v2.0

addr := DllCall("GetModuleHandle", "Str", "kernel32", "Ptr")
```

```autohotkey test
#Requires AutoHotkey v2.1-alpha

A_PtrSize == 64 
   ? DllCall("RtlCopyMemory", IntPtr, dest, IntPtr, source, UInt32, length, "void")
   : DllCall("RtlMoveMemory", IntPtr, dest, IntPtr, source, UInt32, length, "void")
```

### Incorrect

```autohotkey test
#Requires AutoHotkey v2.1-alpha

fn := A_PtrSize == 64 ? "RtlCopyMemory" : "RtlMoveMemory"
DllCall(fn, IntPtr, dest, IntPtr, source, UInt32, length, "void") ;~ use-const-dllcalls
```
