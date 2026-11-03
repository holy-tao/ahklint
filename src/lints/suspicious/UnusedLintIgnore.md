An `;@ahklint-ignore*` directive that no longer matches any diagnostic violations is likely included by mistake,
and should be removed to avoid confusion.

## Examples

### Incorrect

```autohotkey test
;@ahklint-ignore-next-line unused-param ;~ unused-lint-ignore
myFunc(param) {
    return param.property
}
```

```autohotkey test
myFunc(param) { ;@ahklint-ignore unused-param ;~ unused-lint-ignore
    return param.property
}
```
