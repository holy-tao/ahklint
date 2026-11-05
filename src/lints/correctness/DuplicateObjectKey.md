Multiple properties with the same key in object literals can cause unexpected behavior and probably indicate a
mistake. Recall that identifiers in AutoHotkey are case-insensitive.

## Examples

### Incorrect

```autohotkey test
foo := {
    bar: "baz",
    Bar: "qux"  ;~ duplicate-object-key
}
```
