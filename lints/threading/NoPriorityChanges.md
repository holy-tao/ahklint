
Never change [thread priority]. Threads with a lower priority that the current thread cannot interrupt it, however,
they are ***not buffered***, instead they are dropped. Increasing the thread priority will cause timers, hotkeys,
hotstrings, menu items, button presses, and so forth to be ignored. *Decreasing* the thread priority may prevent it
from restarting if it is interrupted.

If you need to perform an uninterruptible (atomic) action, use [`Critical`] instead. Critical threads do [buffer events]:

> Unlike high-priority threads, events that occur while the thread is uninterruptible are not discarded.

[`Critical`]: https://www.autohotkey.com/docs/alpha/lib/Critical.htm
[thread priority]: https://www.autohotkey.com/docs/alpha/misc/Threads.htm#Priority
[buffer events]: https://www.autohotkey.com/docs/alpha/misc/Threads.htm#Behave

## Examples

### Incorrect

```autohotkey test
Thread("priority", 10) ;~ no-priority-changes
```

### Correct

```autohotkey test
Thread("NoTimers", true)
```
