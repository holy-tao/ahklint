Checks for calls to [`Object.Prototype.DefineProp`][ObjDefineProp] or, if the target is [v2.1-alpha.22] or later,
the free [`DefineProp`][DefineProp], which use its `{ Value: "something" }` form.

Creating value properties with `DefineProp` is only worth it if you intend to overwrite any _existing_ property
with the name you're using. In most cases, calling `DefineProp` is no different or faster than just setting the
property normally, but is less readable.

[ObjDefineProp]: https://www.autohotkey.com/docs/v2/lib/Object.htm#DefineProp
[v2.1-alpha.22]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.22
[DefineProp]: https://www.autohotkey.com/docs/alpha/lib/Object.htm#DefineProp

## Examples

### Correct

```autohotkey test
obj.prop := 42
```

```autohotkey test
DefineProp(obj, "prop", { get: (*) => 42 })
```

### Incorrect

```autohotkey test
obj.DefineProp("prop", { value: 42 })  ;~ define-prop-value
```

```autohotkey test
DefineProp(obj, "prop", { value: 42 })  ;~ define-prop-value
```
