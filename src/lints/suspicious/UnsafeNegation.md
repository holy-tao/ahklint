Flags the use of the `!` operator on the left-hand side of certain relational operations.

By default, this rule is enabled only for the [`is`][is] operator.

[is]: https://eslint.org/docs/latest/rules/no-unsafe-negation

This rule is based on the ESLint rule [`no-unsafe-negation`](https://eslint.org/docs/latest/rules/no-unsafe-negation).

### Examples

## Incorrect

It's easy to accidentally negate the object you want to type check instead of the entire expression itself:

```autohotkey test
if !obj is String { ;~ unsafe-negation
    obj := String(obj)
}
```

Set `enforceForOrderingRelations` to `true` to also enforce this for the `>`, `<`, `>=`, and `<=` operators:

```autohotkey test { "enforceForOrderingRelations": true }
if !val < 1 { ;~ unsafe-negation
    ; do stuff
}
```

## Correct

```autohotkey test
if !(obj is String) {
    obj := String(obj)
}
```

```autohotkey test { "enforceForOrderingRelations": true }
if !(val < 1) {
    ; do stuff
}
```
