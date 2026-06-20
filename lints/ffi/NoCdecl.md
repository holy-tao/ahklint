Specifying `Cdecl` has no effect even on 32-bit builds, and can always be omitted.

Prior versions used the Cdecl option only to determine whether to check the stack pointer (ESP) after the call. This
is now done unconditionally, but functions which do not accept parameters are assumed to be Cdecl (as either call would
not change ESP).

On 32-bit builds of AutoHotkey prior to [v2.1-alpha.3], `cdecl` was sometimes used in [`DllCall`] return type strings
to indicate that the call should use the "C" calling convention instead of [`stdcall`].

[v2.1-alpha.3]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.3
[`DllCall`]: https://www.autohotkey.com/docs/v2/lib/DllCall.htm
[`stdcall`]: https://learn.microsoft.com/en-us/cpp/cpp/stdcall?view=msvc-170

## Examples

### Correct

Simply omit the calling convention from your return type string

```autohotkey test
#Requires AutoHotkey v2.1-alpha.23

grammarType := DllCall("tree-sitter\ts_node_grammar_type", Node.Ptr, this, "astr")
DllCall("ntdll\RtlCopyMemory", Point.Ptr, this, "ptr", ptrOrRow, "uint", 8, "void")
```

Or use a struct class as the return type for automatic marshalling

``` autohotkey test
#Requires AutoHotkey v2.1-alpha.23

grammarType := DllCall("tree-sitter\ts_node_grammar_type", Node.Ptr, this, AStr.Ptr)
```

### Incorrect

```autohotkey test
#Requires AutoHotkey v2.1-alpha.23

grammarType := DllCall("tree-sitter\ts_node_grammar_type", Node.Ptr, this, "cdecl astr") ;~ no-cdecl
```
