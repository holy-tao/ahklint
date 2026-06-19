
A script should include exactly one [`#Requires`] directive.

If the script uses syntax or functions which are unavailable in earlier versions, using the `#Requires` directive ensures
that error messages are informative. Without it, the interpreter will symply show a syntax error. This cannot be checked
at runtime, because a syntax error would prevent script execution.

When sharing a script or posting code online, using this directive allows anyone who finds the code to readily identify
which version of AutoHotkey it was intended for.

Other programs or scripts can check for this directive for various purposes. For example, the launcher installed with
AutoHotkey v2 uses it to determine which AutoHotkey executable to launch, while a script editor or related tools might
use it to determine how to interpret or highlight the script file.

[`#Requires`]: https://www.autohotkey.com/docs/v2/lib/_Requires.htm

## Examples

### Correct

``` autohotkey test
#Requires AutoHotkey v2.0
; <...>
```

### Incorrect

``` autohotkey test
#Requires AutoHotkey v2.0
; <...>
#Requires AutoHotkey v2.1-alpha.2 ;~ one-requires
```
