The use of `goto` is discouraged because it generally makes scripts less readable and harder to maintain. Consider using [`else`], [`blocks`], [`break`], and [`continue`] as substitutes for `goto`.

[`else`]: https://www.autohotkey.com/docs/v2/lib/Else.htm
[`blocks`]: https://www.autohotkey.com/docs/v2/lib/Block.htm
[`break`]: https://www.autohotkey.com/docs/v2/lib/Break.htm
[`continue`]: https://www.autohotkey.com/docs/v2/lib/Continue.htm

## Examples

### Incorect
```autohotkey test
#Requires AutoHotkey v2.0
goto label ;~ no-goto

label:
MsgBox "In label!"
```