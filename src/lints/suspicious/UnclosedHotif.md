All [`#HotIf`] directives should be closed by either another `#HotIf` directive or a blank `#HotIf` directive. An
unclosed `#HotIf` could have unintended effects on hotkeys or hotstrings defined in scripts that include the script
with the unclosed directive.

This is less important in v2.1-alpha if using [`#Import`], because [modules] have their own auto-execute sections and
`#HotIf` is module-scoped:

> #HotIf affects only the current module. #HotIf and HotIf expressions are module-scoped, as they may contain
> references to module-level variables. For instance, the effect of #HotIf myToggle depends on what value myToggle
> has in the current module.

[`#HotIf`]: https://www.autohotkey.com/docs/alpha/lib/_HotIf.htm
[`#Import`]: https://www.autohotkey.com/docs/alpha/lib/_Import.htm
[modules]: https://www.autohotkey.com/docs/alpha/Modules.htm

## Examples

### Correct

```autohotkey test
#HotIf WinActive("notepad.exe")
^!c::MsgBox "You pressed Control+Alt+C in Notepad."
#HotIf
```

A `#HotIf` directive may be "closed" by another `#HotIf` directive that has an expression:

```autohotkey test
#HotIf WinActive("ahk_class Notepad")
^!c::MsgBox "You pressed Control+Alt+C in Notepad."
#HotIf WinActive("ahk_class WordPadClass")
^!c::MsgBox "You pressed Control+Alt+C in WordPad."
#HotIf
^!c::MsgBox "You pressed Control+Alt+C in a window other than Notepad/WordPad."
```

### Incorrect

```autohotkey test
#HotIf WinActive("notepad.exe") ;~ unclosed-hotif
^!c::MsgBox "You pressed Control+Alt+C in Notepad."
```

```autohotkey test
#HotIf WinActive("ahk_class Notepad")
^!c::MsgBox "You pressed Control+Alt+C in Notepad."
#HotIf WinActive("ahk_class WordPadClass") ;~ unclosed-hotif
^!c::MsgBox "You pressed Control+Alt+C in WordPad."
```
