Looks for string literals that appear to be JavaScript-style slash-delimited [regular expressions][regex] like
`/pattern/opts`, as you would get from copying a regex from tools like [regex101].

AHK uses a slightly different format `opts)pattern`. The `/pattern/opts` form will treat the slashes and options
literally, and is almost certainly not what was intended.

> [!NOTE]
> This lint intentionally scans _all_ string literals, since it's common to store regular expressions in variables

[regex]: https://www.autohotkey.com/docs/alpha/misc/RegEx-QuickRef.htm
[regex101]: https://regex101.com/

## Examples

### Incorrect

```autohotkey test
EMAIL_PATTERN := "/(^[a-zA-Z0-9_.]+[@]{1}[a-z0-9]+[\.][a-z]+$)/mg" ;~ slash-delimited-regex
```

```autohotkey test
EMAIL_PATTERN := "/(^[a-zA-Z0-9_.]+[@]{1}[a-z0-9]+[\.][a-z]+$)/" ;~ slash-delimited-regex
```

### Correct

```authotkey test
EMAIL_PATTERN := "gm)(^[a-zA-Z0-9_.]+[@]{1}[a-z0-9]+[\.][a-z]+$)"
```
