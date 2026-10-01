Flags [blocks][block] that don't contain any statements. Are you sure you're not forgetting anything?

By default, comments count as statements for the purposes of this lint; it will not fire for a block that contains
nothing but comments. This is configurable via the `allowComments` option.

This lint covers all blocks, including those in control-flow constructs, function bodies, getters, and setters.

[block]: https://www.autohotkey.com/docs/alpha/lib/Block.htm

## Examples

### Incorrect

```autohotkey test
if condition { ;~ empty-block

}
```

```autohotkey test
Unimplemented() { ;~ empty-block

}
```

```autohotkey test { "allowComments": false }
Noop() { ;~ empty-block
    ; Does nothing but must exist for some reason
}
```

### Correct

```autohotkey test
Unimplemented() {
    throw MethodError("Not implemented yet!")
}
```

```autohotkey test { "allowComments": true }
Noop() {
    ; Does nothing but must exist for some reason
}
```
