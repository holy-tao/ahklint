Checks for calls to [`Object.Prototype.DefineProp`][ObjDefineProp] or, if the target is [v2.1-alpha.22] or later,
the free [`DefineProp`][DefineProp], which pass invalid property descriptors.

Property descriptors have two (three in [v2.1-alpha.19] and later) mutually exclusive forms, and they ignore unknown
properties.

[ObjDefineProp]: https://www.autohotkey.com/docs/v2/lib/Object.htm#DefineProp
[v2.1-alpha.19]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.19
[v2.1-alpha.22]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.22
[DefineProp]: https://www.autohotkey.com/docs/alpha/lib/Object.htm#DefineProp

## Examples

### Incorrect

```autohotkey test
obj.DefineProp("malformed", { get: (_) => 42, value: 42 }) ;~ invalid-property-descriptor
```

```autohotkey test
obj.DefineProp("malformed", { unrecognized: "ignored" }) ;~ invalid-property-descriptor
```

```autohotkey test
DefineProp(obj.Prototype, "malformed", { get: (_) => 42, type: IntPtr }) ;~ invalid-property-descriptor
```

The lint can validate arguments to `Pack` and `Offset` as well:

```autohotkey test
DefineProp(obj.Prototype, "malformed", { type: IntPtr, pack: 3 }) ;~ invalid-property-descriptor
DefineProp(obj.Prototype, "malformed", { type: Float32, offset: 2.5 }) ;~ invalid-property-descriptor
```

`Pack` and `Offset` describe a typed property, so they need a `Type`:

```autohotkey test
DefineProp(obj.Prototype, "malformed", { pack: 4 }) ;~ invalid-property-descriptor
```

### Correct

```autohotkey test
obj.DefineProp("malformed", { get: (_) => 42 })
```

```autohotkey test
DefineProp(obj.Prototype, "malformed", { type: Int8, pack: 4, offset: 4 })
DefineProp(obj.Prototype, "malformed", { type: Int8, pack: 4, offset: "unionMember1" })
```
