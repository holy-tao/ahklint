
A script should include exactly one [`#Requires`] directive.

Conventionally, it should be the first statement in the .ahk file, but the lint does not enforce this.

If the script uses syntax or functions which are unavailable in earlier versions, using the [`#Requires`] directive ensures
that error messages are informative. Without it, the interpreter will symply show a syntax error. This cannot be checked
at runtime, because a syntax error would prevent script execution.

When sharing a script or posting code online, using this directive allows anyone who finds the code to readily identify
which version of AutoHotkey it was intended for.

The [`#Requires`] directive also drives a variety of other behaviors:

- The [launcher] uses the presence of a [`#Requires`] directive to determine which interpreter to use when executing
  a script. If no [`#Requires`] directive is present, it will fall back to heuristics, which is slower and less reliable.
- As of [v2.1-alpha.28], the [`#Requires`] will set the script's [compatibility mode], which can change the behavior of
  certain built-ins. *Without* a [`#Requires`] directive, a script that relies on behavior affected by its compatibility
  mode may not work as intended when imported or included into other scripts which run a different compatibility mode.
- Editors and related tools (including ahklint itself) may use a [`#Requires`] directive to figure out how to interpret
  or highlight a script file.

[`#Requires`]: https://www.autohotkey.com/docs/v2/lib/_Requires.htm
[launcher]: https://www.autohotkey.com/docs/alpha/Program.htm#launcher
[compatibility mode]: https://www.autohotkey.com/docs/alpha/lib/_Requires.htm#CompatMode
[v2.1-alpha.28]: https://www.autohotkey.com/docs/alpha/ChangeLog.htm#v2.1-alpha.28

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
