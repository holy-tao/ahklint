Reports [`Format`][Format] placeholders with no corresponding argument, or an argument with no corresponding
placeholder.

While not an _error_ (the unmatched placeholder will be included literally in the output, and extra arguments are
simply ignored), this is probably a mistake.

[Format]: https://www.autohotkey.com/docs/v2/lib/Format.htm

## Example

### Incorrect

```autohotkey test
Format("{1} {2} {3}", first, second) ;~ unmatched-format-placeholder
```

```autohotkey test
Format("{} {}", first, second, third) ;~ unmatched-format-placeholder
```

```autohotkey test
Format("{} {1} {}", first, second, third) ;~ unmatched-format-placeholder
```

An [invalid placeholder](./invalid-format-placeholder) is output as-is and doesn't consume an argument, so here `{}`
refers to `first` and `second` is unused:

```autohotkey test
Format("{:q} {}", first, second) ;~ unmatched-format-placeholder
```

### Correct

```autohotkey test
Format("{1} {2} {3}", first, second, third)
```

```autohotkey test
Format("{1} {2} {1}", first, second)
```

`{{}` and `{}}` are escaped braces, not placeholders:

```autohotkey test
Format("{{}{}{}}", value)
```
