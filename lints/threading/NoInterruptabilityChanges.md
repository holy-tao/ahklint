
By default, every newly launched thread is uninterruptible for a Duration of 17 milliseconds or a LineCount of 1000
script lines, whichever comes first. This gives the thread a chance to finish rather than being immediately interrupted
by another thread that is waiting to launch (such as a buffered hotkey or a series of timed subroutines that are all due
to be run).

Modifying the interrupt duration should be avoided as it can cause inconsistent script behavior and difficult to debug
problems.

> [!IMPORTANT] Interruptability is Global
> Changing thread interrupt settings silently affects all subsequently created threads.

If you need to perform an uninterruptible (atomic) action, use [`Critical`] instead. Critical threads do [buffer events]:

> Unlike high-priority threads, events that occur while the thread is uninterruptible are not discarded.

[`Critical`]: https://www.autohotkey.com/docs/alpha/lib/Critical.htm
[buffer events]: https://www.autohotkey.com/docs/alpha/misc/Threads.htm#Behave

## Examples

### Incorrect

```autohotkey test
Thread("interrupt", 10) ;~ no-interrupt-changes
```

### Correct

```autohotkey test
Thread("NoTimers", true)
```
