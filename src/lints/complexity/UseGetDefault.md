Checks for code that tests a map for a key with [`Has`], then either reads the key or falls back to a default.
[`Map.Prototype.Get`] takes a default value, so `m.Get(key, default)` is does the same thing in one function call
and only looks the key up once. [`Array.Prototype.Get`] takes a default too.

> [!WARNING]
> The proposed fix is potentially destructive and may change the runtime behavior of your script.

Note the following:

- `Get` will always evaluate its default, where a `if m.Has(key) { ... }` construct only evaluates it if the key
  (or index) is missing. If your default has side effects or is slow to compute, this may be undesireable.
- The fix may delete comments in the if block.
- The lint can't tell what kind of object it is looking at. If your own class has `Has` and `__Item` but no `Get`,
  this lint will report it but the proposed fix will be incorrect.

[`Has`]: https://www.autohotkey.com/docs/alpha/lib/Map.htm#Has
[`Map.Prototype.Get`]: https://www.autohotkey.com/docs/alpha/lib/Map.htm#Get
[`Array.Prototype.Get`]: https://www.autohotkey.com/docs/alpha/lib/Array.htm#Get

## Examples

### Incorrect

```autohotkey test
val := myMap.Has("key") ? myMap["key"] : "default" ;~ use-get-default

if myMap.Has("key") { ;~ use-get-default
    val := myMap["key"]
} else {
    val := "default"
}
```

The check may be negated, or the `if` may not use braces:

```autohotkey test
val := !myMap.Has(key) ? 0 : myMap[key] ;~ use-get-default

if !(myMap.Has(key)) ;~ use-get-default
    val := 0
else
    val := myMap[key]
```

It fires anywhere the expression appears, not just in assignments:

```autohotkey test
Lookup(m, k) {
    return m.Has(k) ? m[k] : "" ;~ use-get-default
}
```

### Correct

```autohotkey test
val := myMap.Get("key", "default")
```

The lint only fires when the `Has` check and the index access use the same object and key, and both branches
assign the same variable:

```autohotkey test
a := m.Has(k1) ? m[k2] : 0
b := m.Has(k) ? n[k] : 0

if m.Has(k) {
    x := m[k]
} else {
    y := 0
}
```

Branches that do more than one thing, `else if` chains, and compound assignments are left alone:

```autohotkey test
if m.Has(k) {
    val := m[k]
    found := true
} else {
    val := 0
}

if m.Has(k)
    val := m[k]
else if n.Has(k)
    val := n[k]

if m.Has(k)
    total += m[k]
else
    total := 0
```
