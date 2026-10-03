Checks for [structs][struct] definitions that include untyped instance properties. These are allowed by
the syntax but will always error at runtime.

Structs cannot have OwnProps -- they can only have typed properties. They _can_, however, have static properties
and [dynamic properties]:

> All elements of a [class definition] are permitted, but an initializer such as `x := 0` cannot create a new property.

[struct]: https://www.autohotkey.com/docs/alpha/Structs.htm
[dynamic properties]: https://www.autohotkey.com/docs/alpha/Objects.htm#Custom_Classes_property
[class definition]: https://www.autohotkey.com/docs/alpha/Objects.htm#Custom_Classes

## Examples

### Incorrect

```authotkey test
struct MyStruct {
    typed: IntPtr

    untyped := "illegal!"   ;~ untyped-struct-property
}
```

```authotkey test
struct MyStruct {
    typed: IntPtr

    untyped := "illegal!", alsoUntyped := "still illegal"   ;~ untyped-struct-property
}
```

### Correcet

```autohotkey test
struct MyStruct {
    typed: IntPtr
}
```

Struct class definitions _can_ include static and dynamic properties

```autohotkey test
struct MyStruct {
    static staticProp := "allowed"

    typed: IntPtr

    ptr => ObjGetDataPtr(this)
}
```

Classes can have typed properties (structs are just special classes):

```authotkey test
class MyClass {
    typed: IntPtr

    untyped := "legal here"
}
```
