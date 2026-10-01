[SendPlay] mode is deprecated and should never be used. Scripts should use one of the other [sending mode]s instead.
Per the AutoHotkey documentation:

> [!WARNING]
> SendPlay does not tend to work if [User Account Control (UAC)] is enabled, even if the script is running as an
> administrator. For more information, refer to the [FAQ](https://www.autohotkey.com/docs/alpha/FAQ.htm#uac). On
> Windows 11 and later, SendPlay may have no effect at all.

The use of [InputThenPlay] is also an illegal, because it falls back to [SendPlay] when Input fails. This applies
to the [`SendPlay`](https://www.autohotkey.com/docs/alpha/lib/Send.htm) method as well as other input sending modes
that use "SendPlay mode", as it were, like the [SP hotstring option].

[SendPlay]: https://www.autohotkey.com/docs/alpha/lib/SendMode.htm#Play
[sending mode]: https://www.autohotkey.com/docs/alpha/lib/SendMode.htm#Sending_Modes
[User Account Control (UAC)]: https://en.wikipedia.org/wiki/User_Account_Control
[InputThenPlay]: https://www.autohotkey.com/docs/alpha/lib/SendMode.htm#InputThenPlay
[SP hotstring option]: https://www.autohotkey.com/docs/alpha/Hotstrings.htm#SendMode

## Examples

### Correct

```autohotkey test
SendMode("Input")
SendEvent("{Escape}")
SendText("I met a traveller in an antique land...")
```

### Incorrect

```autohotkey test
SendPlay("Some text") ;~ sendplay-deprecated
```

```autohotkey test
:SP:btw::By the way ;~ sendplay-deprecated
```

```autohotkey test
PrevMode := SendMode("play") ;~ sendplay-deprecated
SendMode 'Play' ;~ sendplay-deprecated
```

```autohotkey test
PrevMode := SendMode('InputThenPlay') ;~ sendplay-deprecated
SendMode "InputThenPlay" ;~ sendplay-deprecated
```
