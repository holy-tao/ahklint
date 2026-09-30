Don't call functions that would block the OS thread.

This will prevent timers, hotkeys, hotstrings, the interpreter's own message loop, and so forth from working
properly. At best, this can cause missed inputs and hurts script performance, at worst, you may miss window
messages.

Instead, prefer using builtins like [`Sleep`] or [`RunWait`] that will sleep the _script_ [thread] and allow the
interpreter to continue processing others. Alternatively, poll the blocking function with a timeout of zero and
[`Sleep`].

[`Sleep`]: https://www.autohotkey.com/docs/v2/lib/Sleep.htm
[`RunWait`]: https://www.autohotkey.com/docs/v2/lib/Run.htm
[thread]: https://www.autohotkey.com/docs/v2/misc/Threads.htm

## Examples

### Correct

Use the built-in equivalents:

```autohotkey test
Sleep 1000
ProcessWaitClose pid
```

A zero timeout makes a wait return immediately, so polling a handle with `Sleep` between checks is fine:

```autohotkey test
while DllCall("WaitForSingleObject", "Ptr", hEvent, "UInt", 0) == 0x102
    Sleep 50
```

Named pipe calls given an [`OVERLAPPED`] structure are asynchronous:

```autohotkey test
DllCall("ConnectNamedPipe", "Ptr", hPipe, "Ptr", overlapped)
```

[`OVERLAPPED`]: https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-overlapped

### Incorrect

```autohotkey test
DllCall("Sleep", "UInt", 1000) ;~ os-thread-block
```

```autohotkey test
DllCall("kernel32.dll\WaitForSingleObject", "Ptr", hProcess, "UInt", 0xFFFFFFFF) ;~ os-thread-block
```

```autohotkey test
DllCall("EnterCriticalSection", "Ptr", cs) ;~ os-thread-block
```

```autohotkey test
DllCall("WaitNamedPipeW", "Str", name, "UInt", 0) ;~ os-thread-block
```

```autohotkey test
DllCall("ConnectNamedPipe", "Ptr", hPipe, "Ptr", 0) ;~ os-thread-block
```
