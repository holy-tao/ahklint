
Prefer using struct or type classes over bare strings to specify [`DllCall`] and [`ComCall`] argument and return types
wherever possible.

Type classes and especially structs improve type safety and performance, especially when working with [structs], because
the interpreter handles marshalling accross the [`DllCall`] boundary.

Additionally, you can use [abstract types] to further improve type safety by automatically coercing values to [`DllCall`]-
compatible values or erroring when passed invalid values.

Using descriptive struct types also improves readability; for example, by using a `BOOL` type over the bare string "uint".
Using the `StructClass.Ptr` not only gives performance improvements, but signals to readers that the parameter is of a
particular type, not just an arbitrary pointer-sized integer.

[`DllCall`]: https://www.autohotkey.com/docs/alpha/lib/DllCall.htm
[`ComCall`]: https://www.autohotkey.com/docs/alpha/lib/ComCall.htm
[structs]: https://www.autohotkey.com/docs/alpha/Structs.htm
[abstract types]: https://www.autohotkey.com/docs/alpha/Structs.htm#abstract

# Examples

## Correct

Use numeric types or struct classes in [`DllCall`]:

``` autohotkey test
#Requires AutoHotkey v2.1-alpha.23

DllCall("user32\GetMonitorInfo", IntPtr, hMonitor, MONITORINFO.Ptr, MI := MONITORINFO())
```

However, some identifiers (notably `astr`, `wstr`, `str`, and `hresult`) do not have struct class equivalents. The lint
does not warn in this case:

``` autohotkey test
#Requires AutoHotkey v2.1-alpha.23

ComCall(this, 2, Int32, num, "hresult")
DllCall("tree-sitter\ts_node_type", Node.Ptr, this, "astr")
```

## Incorrect

```autohotkey test
#Requires AutoHotkey v2.0

DllCall("user32\GetMonitorInfo", "ptr", hMonitor, "ptr", MI := MONITORINFO()) ;~ use-type-classes 2
ComCall(this, 2, "int", num, "hresult") ;~ use-type-classes
```

```autohotkey test
#Requires AutoHotkey v2.0

DllCall("Crypt32\CryptStringToBinary", 
    "Str", codeB64,
    "UInt", 0,                          ;~ use-type-classes
    "UInt", 1,                          ;~ use-type-classes
    "Ptr", buf := Buffer(5872),         ;~ use-type-classes
    "UInt*", buf.Size,                  ;~ use-type-classes
    "Ptr", 0,                           ;~ use-type-classes
    "Ptr", 0,                           ;~ use-type-classes
    "UInt")                             ;~ use-type-classes
```
