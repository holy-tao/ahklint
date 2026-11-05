Enforces that all members of [classes][class] and [structs][struct] have unique names.

It's a load-time error for two class members of the same kind (like methods or properties) to have the same name, but
it is a *runtime* error at construction for two members of *different* kinds to have the same name, like the names of
properties and methods. In any case, a duplicate declaration like this is almost certainly a mistake..

Recall that AutoHotkey identifiers are case-insensitive.

[class]: https://www.autohotkey.com/docs/v2/Objects.htm#Custom_Classes
[struct]: https://www.autohotkey.com/docs/alpha/Structs.htm

## Examples

### Incorrect

```autohotkey test
class Evil {
    prop := "this script"
    prop := "won't load" ;~ duplicate-class-member
}
```

```autohotkey test
class Bad {
    name := "John Jacob Jingleheimer Schmidt"

    Name => "Something else" ;~ duplicate-class-member
}
```

```autohotkey test
struct Confusing {
    ptr: IntPtr

    Ptr() { ;~ duplicate-class-member
        return 42
    }
}
```

```autohotkey test
class StaticTwice {
    static count := 0
    static Count := 1 ;~ duplicate-class-member
}
```

Every declarator in a multi-declarator property is checked against the others.

```autohotkey test
class Multi {
    static a := 1, b := 2
    static B := 3, c := 4 ;~ duplicate-class-member
    x := 1, y := 2, X := 3 ;~ duplicate-class-member
}
```

### Correct

Static members live on the class and instance members on its prototype, so the same name
may be used once in each.

```autohotkey test
class Both {
    static value := 1
    value := 2

    static Create() => 1
    Create() => 2
}
```

```autohotkey test
class Multi {
    static a := 1, b := 2
    a := 3, b := 4
}
```

Each class, including a nested one, has its own namespace.

```autohotkey test
class Outer {
    name := 1

    class Inner {
        name := 2
    }
}

class Other {
    name := 3
}
```
