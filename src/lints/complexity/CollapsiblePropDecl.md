Identifies [dynamic property declarations][dynamic property declaration] that can be collapsed into their
fat-arrow forms, or whose getters and/or setters can be collapsed into their fat-arrow forms.

Using blocks in this case makes your code unnecessarily verbose.

[dynamic property declaration]: https://www.autohotkey.com/docs/v2/Objects.htm#Custom_Classes_property

## Examples

### Incorrect

A property declaration with only a getter can be collapsed into the `propName => getterBody` form:

```autohotkey test
class Example {
    property { ;~ collapsible-property-decl
        get {
            return this.GetProperty()
        }
    }
}
```

If a getter and a setter are both present, they can be collapsed to use the `get =>getterBody`
and `set => setterBody(value)` forms.

```autohotkey test
class Example {
    property {
        get { ;~ collapsible-property-decl
            return this.GetProperty()
        }
        set { ;~ collapsible-property-decl
            this.SetProperty(value)
        }
    }
}
```

In [v2.1-alpha.3] and later, `throw` is a built-in function instead of a statement, so it can be collapsed too.

```autohotkey test
class Example {
    property {
        get { ;~ collapsible-property-decl
            return this.GetProperty()
        }
        set { ;~ collapsible-property-decl
            throw Error("property is read-only")
        }
    }
}
```

[v2.1-alpha.3]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.3

### Correct

```autohotkey test
class Example {
    property => this.GetProperty()
}
```

```autohotkey test
class Example {
    property {
        get => this.GetProperty()
        set => this.SetProperty(value)
    }
}
```

```autohotkey test
class Example {
    property {
        get => this.GetProperty()
        set => throw(Error("property is read-only"))
    }
}
```
