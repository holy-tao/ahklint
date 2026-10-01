A hotkey contained more than one of the same [hotkey modifier] or [hotstring option]. While this *generally* has no
effect on the hotkey or hotstring itself (it's usually the same as if it were only present once), it likely indicates
a mistake on the part of the programmer and in some cases can cause unintended behavior (for example if you specify
conflicting versions of the same option).

[hotkey modifier]: https://www.autohotkey.com/docs/alpha/Hotkeys.htm#Symbols
[hotstring option]: https://www.autohotkey.com/docs/alpha/Hotstrings.htm#Options

## Examples

### Correct

```autohotkey test
^Numpad1::DoSomething()
```

Using the same modifier in a compound hotkey trigger is not an error:

```autohotkey test
^c & ^v::MsgBox "You pressed Ctrl+C and Ctrl+V at the same time"
```

```autohotkey test
:*:j@::jsmith@somedomain.com
```

```autohotkey test
::omw::On my way!
```

### Incorrect

```autohotkey test
^^Numpad1::DoSomething() ;~ duplicate-hotkey-modifier
```

```autohotkey test
:**:j@::jsmith@somedomain.com ;~ duplicate-hotkey-modifier
```

```autohotkey test
:SS0:ex::Example hotstring ;~ duplicate-hotkey-modifier
```
